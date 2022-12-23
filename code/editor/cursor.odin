package editor


cursor :: struct
{
  ChunkOffset : buffer_chunk_offset,
  using Pos : screen_position,
}


AdjustCursorPos :: proc(Buffer : ^text_buffer)
{
  Cursor := &Buffer.Cursor;
  
  SafePos, NextPos : screen_position;
  SafeChunk :^buffer_chunk;
  SafeOffset :int;
  
  loop: for Chunk := &Buffer.First; Chunk != nil; Chunk = Chunk.Next
  {
    SafeOffset = 0;
    SafeChunk = Chunk;
    Text := string(Chunk.Data[:Chunk.UsedSpace]);
    for Ch, Index in Text
    {
      if SafePos.Col == Cursor.Col && SafePos.Row == Cursor.Row do break loop;
      if Ch == '\r' || Ch == '\n'
      {
        NextPos.Row += 1;
        NextPos.Col  = 0;
        if NextPos.Row > Cursor.Row do break loop;
      }
      else do NextPos.Col += TAB_WIDTH if Ch == '\t' else 1;
      SafePos = NextPos;
      SafeOffset = Index + 1;
    }
  }
  
  Cursor.Pos = SafePos;
  Cursor.ChunkOffset.Offset = SafeOffset;
  Cursor.ChunkOffset.Chunk = SafeChunk;
}

MoveCursorRight :: proc(Buffer : ^text_buffer)
{
  Cursor := &Buffer.Cursor;
  Chunk  := Cursor.ChunkOffset.Chunk;
  Offset := Cursor.ChunkOffset.Offset;
  
  if Offset < Chunk.UsedSpace
  {
    CharAtCursor := Chunk.Data[Offset];
    
    Cursor.ChunkOffset.Offset += 1;
    Cursor.Col += TAB_WIDTH if CharAtCursor == '\t' else 1;
    if CharAtCursor == '\r' || CharAtCursor == '\n'
    {
      Cursor.Col = 0;
      Cursor.Row += 1;
    }
    
    if Cursor.ChunkOffset.Offset == Cursor.ChunkOffset.Chunk.UsedSpace && Chunk.Next != nil
    {
      Cursor.ChunkOffset.Chunk = Chunk.Next;
      Cursor.ChunkOffset.Offset = 0;
    }
  }
  else if Chunk.Next != nil
  {
    Cursor.ChunkOffset.Chunk = Chunk.Next;
    Cursor.ChunkOffset.Offset = 0;
    MoveCursorRight(Buffer);
  }
  else
  {
    Cursor.ChunkOffset.Offset = Chunk.UsedSpace;
  }
}

MoveCursorLeft :: proc(Buffer : ^text_buffer) -> (Ok : bool)
{
  Cursor := &Buffer.Cursor;
  Chunk  := Cursor.ChunkOffset.Chunk;
  Offset := Cursor.ChunkOffset.Offset;
  
  if Offset > 0
  {
    Ok = true;
    CharBeforeCursor := Chunk.Data[Offset - 1];
    
    Cursor.Col -= TAB_WIDTH if CharBeforeCursor == '\t' else 1;
    Cursor.ChunkOffset.Offset -= 1;
    if Cursor.Col < 0
    {
      // TODO(fakhri): pick a safe big number
      Cursor.Col = 100_000;
      if Cursor.Row > 0 do Cursor.Row -= 1;
      AdjustCursorPos(Buffer);
    }
  }
  else if Chunk.Prev != nil
  {
    Cursor.ChunkOffset.Chunk = Chunk.Prev;
    Cursor.ChunkOffset.Offset = Chunk.Prev.UsedSpace;
    Ok = MoveCursorLeft(Buffer);
  }
  else
  {
    Cursor.ChunkOffset.Offset = 0;
  }
  return;
}
