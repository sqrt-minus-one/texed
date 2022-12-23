package editor

import "core:os"
import "core:mem"

buffer_chunk_offset :: struct
{
  Chunk : ^buffer_chunk,
  Offset : int, // NOTE(fakhri): offset in the chunk
}

CHUNK_CAPACITY :: 1024

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
  
  Cursor : cursor,
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
  Buffer.Cursor.ChunkOffset.Chunk = &Buffer.First;
  Buffer.Cursor.ChunkOffset.Offset = 0;
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

InsertCharaterToBuffer :: proc(Editor : ^editor_context, Cursor : ^cursor, Char : u8)
{
  ChunkOffset := &Cursor.ChunkOffset;
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
    // NOTE(fakhri): create a new chunk and add it to the buffer
    // right after chunk
    
    NewChunk := MakeBufferChunk(Editor);
    assert(NewChunk != nil);
    
    if ChunkOffset.Chunk == Editor.Buffer.Last
    {
      Editor.Buffer.Last = NewChunk;
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
  MoveCursorRight(Editor.Buffer);
}

DeleteCharacterFromBuffer :: proc(Editor : ^editor_context, Cursor : ^cursor)
{
  ChunkOffset := &Cursor.ChunkOffset;
  
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
      Cursor.ChunkOffset.Chunk = PrevChunk;
      Cursor.ChunkOffset.Offset = PrevChunk.UsedSpace;
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
        Cursor.ChunkOffset.Chunk = &Editor.Buffer.First;
        Cursor.ChunkOffset.Offset = 0;
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
  
  if ChunkOffset.Chunk.UsedSpace > 0 && MoveCursorLeft(Editor.Buffer)
  {
    if ChunkOffset.Offset + 1 < CHUNK_CAPACITY
    {
      mem.copy(dst = &ChunkOffset.Chunk.Data[ChunkOffset.Offset],
               src = &ChunkOffset.Chunk.Data[ChunkOffset.Offset + 1],
               len = ChunkOffset.Chunk.UsedSpace - ChunkOffset.Offset); 
    }
    ChunkOffset.Chunk.UsedSpace -= 1;
  }
  
  if ChunkOffset.Offset == ChunkOffset.Chunk.UsedSpace && ChunkOffset.Chunk.Next != nil
  {
    ChunkOffset.Chunk = ChunkOffset.Chunk.Next;
    ChunkOffset.Offset = 0;
  }
}
