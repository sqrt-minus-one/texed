package editor

import "shared:base"
import "core:os"
import "core:mem"

buffer_chunk_offset :: struct
{
  Chunk : ^buffer_chunk,
  Offset : int, // NOTE(fakhri): offset in the chunk
}

// NOTE(fakhri): if we want to support projects with lot of 
// files we should find out a way to handle memory
// if for example we want to support editing the linux kernel
// that have around 20'000 files, loading all of the files to memory 
// at all times assuming the chunk size is 16kb and we assume
// that we only need one chunk for each file (this is obviously not true
// as there are files bigger than 16kb in size) then a back of the envolope 
// computation shows that we need 20'000 * 16kb= 320'000kb = 312mb
// this is an acceptable cost, but if things went out of control we
// must think of an alternative solution, one idea worth investigating
// is to only keep modified buffers in memory because the number of modified 
// buffers tends to be lower than the total number of buffers in a project

CHUNK_CAPACITY :: 16 * base.Kilobyte

buffer_chunk :: struct
{
  Next :^buffer_chunk,
  Prev :^buffer_chunk,
  UsedSpace : int,
  Data : [CHUNK_CAPACITY]u8,
}

text_buffer :: struct
{
  First : buffer_chunk,
  Last  : ^buffer_chunk,
  
  Size : int,
  Cursor : cursor,
  Lines : buffer_lines,
  Path : string,
}

LoadBufferFromDisk :: proc(Editor : ^editor_context, Path : string) -> (Buffer : ^text_buffer, Ok : bool)
{
  FileContent := os.read_entire_file_from_filename(Path, context.temp_allocator) or_return;
  Buffer = MakeBuffer(Editor);
  assert(Buffer != nil);
  Chunk := &Buffer.First;
  for len(FileContent) != 0
  {
    Buffer.Size = len(FileContent);
    if Chunk.UsedSpace == CHUNK_CAPACITY
    {
      Chunk.Next = MakeBufferChunk(Editor);
      assert(Chunk != nil);
      Chunk = Chunk.Next;
      Buffer.Last = Chunk;
    }
    BytesToCopy := min(len(FileContent), CHUNK_CAPACITY - Chunk.UsedSpace);
    mem.copy(dst = &Chunk.Data[Chunk.UsedSpace],
             src = &FileContent[0],
             len = BytesToCopy); 
    Chunk.UsedSpace += BytesToCopy;
    FileContent = FileContent[BytesToCopy:];
  }
  
  Ok = true;
  Buffer.Path = Path;
  BuildBufferLines(Buffer);
  return;
}

SaveBufferToDisk :: proc(Editor : ^editor_context, Buffer : ^text_buffer) -> (Ok : bool)
{
  File, err := os.open(Buffer.Path, os.O_WRONLY);
  if err != os.ERROR_NONE do return;
  defer os.close(File);
  Offset := i64(0);
  for Chunk := &Buffer.First; Chunk != nil; Chunk = Chunk.Next
  {
    Written : int;
    Written, err = os.write_at(File, Chunk.Data[:Chunk.UsedSpace], Offset);
    Offset += i64(Chunk.UsedSpace);
  }
  Ok = true;
  return;
}

MakeBuffer :: proc(Editor : ^editor_context) -> (Buffer : ^text_buffer)
{
  Buffer = new(text_buffer);
  // TODO(fakhri): reuse buffers
  Buffer.Last = &Buffer.First;
  return;
}

MakeBufferChunk :: proc(Editor : ^editor_context) -> (Chunk : ^buffer_chunk)
{
  if Editor.FreeChunks != nil
  {
    Chunk = Editor.FreeChunks;
    Editor.FreeChunks = Editor.FreeChunks.Next;
    Chunk^ = buffer_chunk{};
  }
  if Chunk == nil do Chunk = new(buffer_chunk);
  return;
}

InsertCharaterToBuffer :: proc(Editor : ^editor_context, Buffer : ^text_buffer, Char : u8)
{
  // NOTE(fakhri): ignore windows \r bs
  if Char == '\r' do return;
  ChunkOffset := GetBufferOffsetFromCursor(Buffer);
  if ChunkOffset.Offset == CHUNK_CAPACITY
  {
    if ChunkOffset.Chunk.Next != nil
    {
      ChunkOffset.Chunk = ChunkOffset.Chunk.Next;
      ChunkOffset.Offset = 0;
    }
  }
  
  if ChunkOffset.Chunk.UsedSpace == CHUNK_CAPACITY
  {
    // TODO(fakhri): see if we can use the next chunk instead of 
    // creating a new one
    
    // NOTE(fakhri): create a new chunk and add it to the buffer
    // right after chunk
    NewChunk := MakeBufferChunk(Editor);
    assert(NewChunk != nil);
    
    if ChunkOffset.Chunk == Buffer.Last
    {
      Buffer.Last = NewChunk;
    }
    
    NewChunk.Prev = ChunkOffset.Chunk;
    NewChunk.Next = ChunkOffset.Chunk.Next;
    if NewChunk.Next != nil
    {
      NewChunk.Next.Prev = NewChunk;
    }
    ChunkOffset.Chunk.Next = NewChunk;
    
    if ChunkOffset.Offset < CHUNK_CAPACITY
    {
      // NOTE(fakhri): copy everything after offset to the new chunk
      mem.copy(dst = &NewChunk.Data[0],
               src = &ChunkOffset.Chunk.Data[ChunkOffset.Offset],
               len = ChunkOffset.Chunk.UsedSpace - ChunkOffset.Offset); 
      NewChunk.UsedSpace = ChunkOffset.Chunk.UsedSpace - ChunkOffset.Offset;
      ChunkOffset.Chunk.UsedSpace -= NewChunk.UsedSpace;
    }
    else
    {
      ChunkOffset.Chunk = NewChunk;
      ChunkOffset.Offset = 0;
    }
  }
  
  if ChunkOffset.Offset + 1 < CHUNK_CAPACITY
  {
    mem.copy(dst = &ChunkOffset.Chunk.Data[ChunkOffset.Offset + 1],
             src = &ChunkOffset.Chunk.Data[ChunkOffset.Offset],
             len = ChunkOffset.Chunk.UsedSpace - ChunkOffset.Offset); 
  }
  ChunkOffset.Chunk.UsedSpace += 1;
  ChunkOffset.Chunk.Data[ChunkOffset.Offset] = Char;
  Buffer.Size += 1;
  BuildBufferLines(Buffer);
  MoveCursorRight(Buffer);
}

DeleteCharacterFromBuffer :: proc(Editor : ^editor_context, Buffer :^text_buffer)
{
  ChunkOffset := GetBufferOffsetFromCursor(Buffer);
  
  if ChunkOffset.Chunk.UsedSpace == 0
  {
    // NOTE(fakhri): delete the chunk
    ChunkToFree := ChunkOffset.Chunk;
    PrevChunk := ChunkToFree.Prev;
    NextChunk := ChunkToFree.Next;
    if ChunkToFree != &Editor.Buffer.First
    {
      if ChunkToFree == Editor.Buffer.Last
      {
        Editor.Buffer.Last = PrevChunk;
        PrevChunk.Next = nil;
      }
      else
      {
        PrevChunk.Next = ChunkToFree.Next;
        PrevChunk.Next.Prev = PrevChunk;
      }
    }
    else
    {
      if NextChunk != nil
      {
        // NOTE(fakhri): copy the next chunk
        // to the head of the buffer and free
        // the next chunk
        Editor.Buffer.First = NextChunk^;
        ChunkToFree = NextChunk;
        if ChunkToFree.Next != nil
        {
          // NOTE(fakhri): update the prev pointer of the next
          // chunk
          ChunkToFree.Next.Prev = &Editor.Buffer.First;
        }
      }
      else
      {
        // NOTE(fakhri): nothing to free
        ChunkToFree = nil;
      }
    }
    
    if ChunkToFree != nil
    {
      ChunkToFree.Next = Editor.FreeChunks;
      Editor.FreeChunks = ChunkToFree;
    }
  }
  
  if ChunkOffset.Chunk.UsedSpace > 0 && Buffer.Cursor > 0
  {
    // TODO(fakhri): test with multi chunks
    if ChunkOffset.Offset > 0
    {
      mem.copy(dst = &ChunkOffset.Chunk.Data[ChunkOffset.Offset - 1],
               src = &ChunkOffset.Chunk.Data[ChunkOffset.Offset],
               len = ChunkOffset.Chunk.UsedSpace - ChunkOffset.Offset); 
    }
    ChunkOffset.Chunk.UsedSpace -= 1;
    Buffer.Size -= 1;
    BuildBufferLines(Buffer);
    MoveCursorLeft(Buffer);
  }
}
