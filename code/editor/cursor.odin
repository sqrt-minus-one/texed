package editor

// NOTE(fakhri): offset into the buffer
cursor :: #type int;

GetBufferOffsetFromCursor :: proc(Buffer : ^text_buffer) -> (Result :buffer_chunk_offset)
{
  Cursor := Buffer.Cursor;
  for Chunk := &Buffer.First; Chunk != nil; Chunk = Chunk.Next
  {
    if Cursor < Chunk.UsedSpace
    {
      Result.Chunk = Chunk;
      Result.Offset = Cursor;
      return;
    }
    Cursor -= Chunk.UsedSpace;
  }
  Result.Chunk = Buffer.Last;
  Result.Offset = Buffer.Last.UsedSpace;
  return;
}


MoveCursorRight :: proc(Buffer : ^text_buffer)
{
  Buffer.Cursor += 1;
  if Buffer.Cursor > Buffer.Size do Buffer.Cursor = Buffer.Size;
}

MoveCursorLeft :: proc(Buffer : ^text_buffer)
{
  Buffer.Cursor -= 1;
  if Buffer.Cursor < 0 do Buffer.Cursor = 0;
}

MoveCursorUp :: proc (Buffer : ^text_buffer)
{
  Pos := GetBufferPos(Buffer, Buffer.Cursor);
  Buffer.Cursor = 0;
  if Pos.Row > 0
  {
    LineLength := Buffer.Lines.Offsets[Pos.Row] - Buffer.Lines.Offsets[Pos.Row - 1];
    Buffer.Cursor = Buffer.Lines.Offsets[Pos.Row - 1] + min(Pos.Col, LineLength);
  }
}

MoveCursorDown :: proc (Buffer : ^text_buffer)
{
  Pos := GetBufferPos(Buffer, Buffer.Cursor);
  Buffer.Cursor = Buffer.Size;
  if Pos.Row < Buffer.Lines.Count - 1
  {
    LineLength := Buffer.Lines.Offsets[Pos.Row + 1] - Buffer.Lines.Offsets[Pos.Row];
    Buffer.Cursor = Buffer.Lines.Offsets[Pos.Row + 1] + min(Pos.Col, LineLength);
  }
}
