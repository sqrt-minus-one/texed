package editor

import "shared:base"
import "core:os"
import "core:mem"

BUFFER_CAPACITY :: 10 * base.Megabyte

text_buffer :: struct
{
  Data: [BUFFER_CAPACITY]u8,
  Size: int,
  Cursor: cursor,
  Lines: buffer_lines,
  Path: string,
}

LoadBufferFromDisk :: proc(Editor : ^editor_context, Path : string) -> (Buffer : ^text_buffer, Ok : bool)
{
  FileContent := os.read_entire_file_from_filename(Path, context.temp_allocator) or_return;
  Buffer = MakeBuffer(Editor);
  assert(Buffer != nil);
  assert(len(FileContent) <= BUFFER_CAPACITY);
  Buffer.Size = len(FileContent);
  mem.copy(dst = &Buffer.Data[0],
           src = &FileContent[0],
           len = Buffer.Size); 
  
  Ok = true;
  Buffer.Path = Path;
  MakeBufferLines(Buffer);
  return;
}

SaveBufferToDisk :: proc(Editor : ^editor_context, Buffer : ^text_buffer) -> (Ok : bool)
{
  File, err := os.open(Buffer.Path, os.O_WRONLY);
  if err != os.ERROR_NONE do return;
  defer os.close(File);
  
  Written : int;
  Written, err = os.write(File, Buffer.Data[:Buffer.Size]);
  if err != os.ERROR_NONE do return;
  
  Ok = true;
  return;
}

MakeBuffer :: proc(Editor: ^editor_context) -> (Buffer : ^text_buffer)
{
  Buffer = new(text_buffer);
  // TODO(fakhri): reuse buffers
  return;
}

InsertCharaterToBuffer :: proc(Editor: ^editor_context, Buffer: ^text_buffer, Char : u8)
{
  // NOTE(fakhri): ignore windows \r bs
  if Char == '\r' do return;
  assert(Buffer.Size + 1 <= BUFFER_CAPACITY);
  if Buffer.Size + 1 <= BUFFER_CAPACITY
  {
    mem.copy(dst = &Buffer.Data[Buffer.Cursor + 1],
             src = &Buffer.Data[Buffer.Cursor],
             len = Buffer.Size - Buffer.Cursor); 
  }
  Buffer.Data[Buffer.Cursor] = Char;
  Buffer.Size += 1;
  MakeBufferLines(Buffer);
  MoveCursorRight(Buffer);
}

DeleteCharacterFromBuffer :: proc(Editor : ^editor_context, Buffer :^text_buffer)
{
  if Buffer.Size > 0 && Buffer.Cursor > 0
  {
    mem.copy(dst = &Buffer.Data[Buffer.Cursor - 1],
             src = &Buffer.Data[Buffer.Cursor],
             len = Buffer.Size - Buffer.Cursor); 
    
    Buffer.Size -= 1;
    MakeBufferLines(Buffer);
    MoveCursorLeft(Buffer);
  }
}
