package editor

import "core:mem"

buffer_chunk_offset :: struct
{
  Chunk : ^buffer_chunk,
  Offset : int, // NOTE(fakhri): offset in the chunk
}

CHUNK_CAPACITY :: 512
buffer_chunk :: struct
{
  Next :^buffer_chunk,
  UsedSpace : int,
  Data : [CHUNK_CAPACITY]u8,
}

text_buffer :: struct
{
  First :^buffer_chunk,
  Last  :^buffer_chunk,
}

InsertCharaterToBuffer :: proc(Editor : ^editor_context, Cursor : ^cursor, Char : u8)
{
  Chunk  := Cursor.ChunkOffset.Chunk;
  Offset := Cursor.ChunkOffset.Offset;
  if Chunk.UsedSpace < CHUNK_CAPACITY
  {
    if Offset + 1 < len(Chunk.Data)
    {
      mem.copy(dst = &Chunk.Data[Offset + 1],
               src = &Chunk.Data[Offset],
               len = Chunk.UsedSpace - Offset); 
    }
    Chunk.UsedSpace += 1;
    Chunk.Data[Offset] = Char;
  }
  
  MoveCursorRight(string(Chunk.Data[:Chunk.UsedSpace]), Cursor);
}

DeleteCharacterFromBuffer :: proc(Editor : ^editor_context, Cursor : ^cursor)
{
  Chunk  := Cursor.ChunkOffset.Chunk;
  if Chunk.UsedSpace > 0 && Cursor.ChunkOffset.Offset > 0
  {
    MoveCursorLeft(string(Chunk.Data[:Chunk.UsedSpace]), Cursor);
    Offset := Cursor.ChunkOffset.Offset;
    if Offset + 1 < CHUNK_CAPACITY
    {
      mem.copy(dst = &Chunk.Data[Offset],
               src = &Chunk.Data[Offset + 1],
               len = Chunk.UsedSpace - Offset); 
    }
    Chunk.UsedSpace -= 1;
  }
}
