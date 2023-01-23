package editor

// NOTE(fakhri): offset into the buffer
cursor :: #type int;

MoveCursorRight :: proc(Buffer : ^text_buffer)
{
  if Buffer.Size != 0
  {
    Buffer.Cursor += 1;
  }
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
    Buffer.Cursor = Buffer.Lines.Offsets[Pos.Row - 1] + min(Pos.Col, LineLength - 1);
  }
}

MoveCursorDown :: proc (Buffer : ^text_buffer)
{
  Pos := GetBufferPos(Buffer, Buffer.Cursor);
  Buffer.Cursor = Buffer.Size;
  if Pos.Row < Buffer.Lines.Count - 1
  {
    NextLineLength :int;
    if Pos.Row + 2 < Buffer.Lines.Count
    {
      NextLineLength = Buffer.Lines.Offsets[Pos.Row + 2] - Buffer.Lines.Offsets[Pos.Row + 1];
    }
    else
    {
      NextLineLength = Buffer.Size - Buffer.Lines.Offsets[Pos.Row + 1];
    }
    
    Buffer.Cursor = Buffer.Lines.Offsets[Pos.Row + 1] + min(Pos.Col, NextLineLength - 1);
  }
}
