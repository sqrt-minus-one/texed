package editor


buffer_lines :: struct
{
  Offsets : [10_000]int,
  Count : int,
}

GetBufferPos :: proc(Buffer : ^text_buffer, Offset : int) -> (Result : buffer_position)
{
  Result.Row = Buffer.Lines.Count - 1;
  Offset := Offset;
  if Offset > Buffer.Size do Offset = Buffer.Size;
  for Index in 0..<(Buffer.Lines.Count - 1)
  {
    if Buffer.Lines.Offsets[Index + 1] > Offset
    {
      Result.Row = Index;
      break;
    }
  }
  Result.Col = Offset - Buffer.Lines.Offsets[Result.Row];
  return;
}

OffsetFromRowCol :: proc(Buffer : ^text_buffer, Row : int, Col : int) -> (Result : int)
{
  Row := Row;
  if Row > Buffer.Lines.Count - 1
  {
    Row = Buffer.Lines.Count - 1;
  }
  Result = Buffer.Lines.Offsets[Row] + Col;
  if Result > Buffer.Size do Result = Buffer.Size;
  return;
}

MakeBufferLines :: proc(Buffer :^text_buffer)
{
  Buffer.Lines.Offsets[0] = 0;
  Buffer.Lines.Count = 1;
  
  TotalOffset := 0;
  
  Text := string(Buffer.Data[:Buffer.Size]);
  for Ch, ChIndex in Text
  {
    if Ch == '\n'
    {
      assert(Buffer.Lines.Count < len(Buffer.Lines.Offsets));
      Buffer.Lines.Offsets[Buffer.Lines.Count] = TotalOffset + 1;
      Buffer.Lines.Count += 1;
    }
    TotalOffset += 1;
  }
}