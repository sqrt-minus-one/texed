package editor


cursor :: struct
{
  ChunkOffset : buffer_chunk_offset,
  using Pos : screen_position,
}


AdjustCursorPos :: proc(Text : string, Cursor : ^cursor)
{
  SafeOffset := 0;
  SafePos, NextPos : screen_position;
  for Ch, Index in Text
  {
    if SafePos.Col == Cursor.Col && SafePos.Row == Cursor.Row do break;
    if Ch == '\r' || Ch == '\n'
    {
      NextPos.Row += 1;
      NextPos.Col  = 0;
      if NextPos.Row > Cursor.Row do break;
    }
    else do NextPos.Col += TAB_WIDTH if Ch == '\t' else 1;
    SafePos = NextPos;
    SafeOffset = Index + 1;
  }
  
  Cursor.Pos    = SafePos;
  Cursor.ChunkOffset.Offset = SafeOffset;
}

MoveCursorRight :: proc(Text : string, Cursor : ^cursor)
{
  if Cursor.ChunkOffset.Offset < len(Text)
  {
    CharAtCursor := Text[Cursor.ChunkOffset.Offset];
    
    Cursor.ChunkOffset.Offset += 1;
    Cursor.Col += TAB_WIDTH if CharAtCursor == '\t' else 1;
    if CharAtCursor == '\r' || CharAtCursor == '\n'
    {
      Cursor.Col = 0;
      Cursor.Row += 1;
    }
  }
}

MoveCursorLeft :: proc(Text : string, Cursor : ^cursor)
{
  if Cursor.ChunkOffset.Offset > 0
  {
    CharBeforeCursor := Text[Cursor.ChunkOffset.Offset - 1];
    Cursor.Col -= TAB_WIDTH if CharBeforeCursor == '\t' else 1;
    Cursor.ChunkOffset.Offset -= 1;
    
    if Cursor.Col < 0
    {
      // TODO(fakhri): pick a safe big number
      Cursor.Col = 100_000;
      if Cursor.Row > 0 do Cursor.Row -= 1;
      AdjustCursorPos(Text, Cursor);
    }
  }
}
