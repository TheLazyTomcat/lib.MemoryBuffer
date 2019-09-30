{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
{===============================================================================

  Memory buffer

    This library provides simple memory buffer that is intended to simplify
    work with dynamically allocated memory - mainly by storing pointer and
    size in one place.

    The buffer is implemented as a record, but you should treat it as an opaque
    object and never access individual fields directly. Instead, use provided
    functions for any desired access.

    Note that the object does not directly contain any buffered data, merely a
    pointer to them. So if you want to access this data, use function that
    provides access to memory pointer - BufferMemory.

    Also remember that this buffer does not automatically free or allocate
    the memory, you are responsible to call proper functions for that.

    In current implementation, the buffer has two sizes - indicated and
    allocated. Indicated size is number of bytes of data stored, allocated is
    size of the memory allocated for the buffer. This two numbers might differ
    (indicated size might be smaller) if the buffer was reallocated with
    AllowShrink set to false.
    To access the data, always use indicated size.

  Version 1.1.1 (2019-09-30)

  Last change 2019-09-30

  ©2015-2019 František Milt

  Contacts:
    František Milt: frantisek.milt@gmail.com

  Support:
    If you find this code useful, please consider supporting its author(s) by
    making a small donation using the following link(s):

      https://www.paypal.me/FMilt

  Changelog:
    For detailed changelog and history please refer to this git repository:

      github.com/TheLazyTomcat/Lib.MemoryBuffer

  Dependencies:
    AuxTypes - github.com/TheLazyTomcat/Lib.AuxTypes

===============================================================================}
unit MemoryBuffer;

{$IF defined(CPU64) or defined(CPU64BITS)}
  {$DEFINE 64bit}
{$ELSEIF defined(CPU16)}
  {$MESSAGE FATAL '16bit CPU not supported'}
{$ELSE}
  {$DEFINE 32bit}
{$IFEND}

{$IFDEF FPC}
  {$MODE ObjFPC}{$H+}
  {$DEFINE FPC_DisableWarns}
  {$MACRO ON}
{$ENDIF}

interface

uses
  SysUtils, Classes,
  AuxTypes;

type
  TMemoryBuffer = record
    Memory:     Pointer;
    Signature:  PtrUInt;
    Size:       TMemSize;
    AllocSize:  TMemSize;
    UserData:   PtrInt;
    Checksum:   PtrUInt;
    CheckStr:   String;
  end;
  PMemoryBuffer = ^TMemoryBuffer;

//- Exceptions -----------------------------------------------------------------

type
  EMBException = class(Exception);

  EMBInvalidBuffer = class(EMBException);

//- initialization -------------------------------------------------------------

{
  BufferIsValid

  Returns true when buffer is considered to be valid (ie. was initialized),
  false otherwise.

  Invalid buffers cannot be worked with (eg. copied from).

  To make buffer valid, it must be passed to function BufferInit or any other
  function that initializes it implicitly.
}
Function BufferIsValid(const Buff: TMemoryBuffer): Boolean;

{
  BufferInit

  Initializes the buffer object (makes it valid) so it can be used in other
  functions.

  Note that if the buffer was already initialized, it will be re-initialized
  without freeing potentially allocated memory. You are responsible for
  checking buffer (in)validity before passing it to this function.

  You are not required to explicitly call BufferInit to work with the buffer,
  as most functions call it when uninitialized buffer is passed to them.
  Nevertheless, it is a recommended practice to do so.
}
procedure BufferInit(out Buff: TMemoryBuffer);

{
  BufferFinal

  Makes the buffer invalid.

  If buffer with allocated memory is passed to this function, it is first freed
  and then invalidated.

  Note that it is not required that the buffer is invalidated at the end of its
  lifespan, it must only be freed.
}
procedure BufferFinal(var Buff: TMemoryBuffer);

{
  BufferBuild

  Builds a new buffer from provided memory location.

  Note that the provided pointer is directly incorporated into the buffer
  without any checking and without any copying, so make sure it is valid and
  do not free it after calling this function. Instead, leave the freeing on
  the buffer itself.
  This also means that the provided pointer is required to be previously
  allocated using standard memory management functions (GetMem, AllocMem,
  ReallocMem)
}
Function BufferBuild(Memory: Pointer; Size: TMemSize; UserData: PtrInt = 0): TMemoryBuffer;

//- allocation -----------------------------------------------------------------

{
  BufferGet

  Allocates memory of requested size for the buffer.

  If an uninitialized buffer is passed into these functions, it is automatically
  initialized.
}
procedure BufferGet(var Buff: TMemoryBuffer; Size: TMemSize); overload;
Function BufferGet(Size: TMemSize): TMemoryBuffer; overload;

{
  BufferAlloc

  Allocates memory of requested size for the buffer, and initializes this
  memory (fills it with zeroes).

  If an uninitialized buffer is passed into these functions, it is automatically
  initialized.
}
procedure BufferAlloc(var Buff: TMemoryBuffer; Size: TMemSize); overload;
Function BufferAlloc(Size: TMemSize): TMemoryBuffer; overload;

{
  BufferFree

  Frees memory allocated for the buffer.

  If an uninitialized buffer is passed into this function, it is initialized
  and no freeing is performed.

  This function does not invalidate the buffer, so it can be used for further
  allocation.
}
procedure BufferFree(var Buff: TMemoryBuffer);

{
  BufferRealloc

  Reallocates memory of the buffer (changes size while preserving stored data).

  When AllowShrink is set to false, the memory is reallocated only when new
  size is larger than currently allocated memory, otherwise the memory is
  preserved as is and only indicated size is changed.

  If an uninitialized buffer is passed into this function, it is initialized
  and normally allocated - equivalent to calling BufferGet function.
}
procedure BufferRealloc(var Buff: TMemoryBuffer; NewSize: TMemSize; AllowShrink: Boolean = True);

//- manipulation ---------------------------------------------------------------

{
  BufferCopy

  Creates (allocates) new buffer and copies all indicated data from the source
  buffer into it. Also copies user data.

  Do not use this function to assign buffer variable that might have been
  already allocated, this function will rewrite it without freeing the memory,
  causing a memory leak.
  In that situation, use the second overload that can better manage such
  situation.

  If the passed source buffer is not valid, this function will raise an
  EMBInvalidBuffer exception.
}
Function BufferCopy(const Src: TMemoryBuffer): TMemoryBuffer; overload;

{
  BufferCopy

  Copies indicated data from source buffer into preexisting destination buffer,
  reallocating it if required. Also copies user data.

  If the destination buffer is not initialized, it will be initialized and
  allocated to required size.

  If the passed source buffer is not valid, this function will raise an
  EMBInvalidBuffer exception.
}
procedure BufferCopy(const Src: TMemoryBuffer; var Dest: TMemoryBuffer); overload;

//- data access ----------------------------------------------------------------

{
  BufferMemory

  Returns pointer to the memory location allocated for the buffer.

  When the passed buffer is invalid, it returns nil.
}
Function BufferMemory(const Buff: TMemoryBuffer): Pointer;

{
  BufferSize

  Returns indicated size of the buffer - that is, number of bytes of stored
  data.

  When the passed buffer is invalid, it returns 0.
}
Function BufferSize(const Buff: TMemoryBuffer): TMemSize;

{
  BufferAllocSize

  Returns allocated size of the buffer - that is, number of bytes allocated
  in the memory for the passed buffer.

  When the passed buffer is invalid, it returns 0.
}
Function BufferAllocSize(const Buff: TMemoryBuffer): TMemSize;

{
  BufferGetUserData

  Returns value of stored user data.

  When the passed buffer is invalid, it returns 0.
}
Function BufferGetUserData(const Buff: TMemoryBuffer): PtrInt;

{
  BufferSetUserData

  Stores new value of user data and returns previous value of stored user data.

  When the passed buffer is invalid, it returns 0 and does not store anything.
}
Function BufferSetUserData(var Buff: TMemoryBuffer; UserData: PtrInt): PtrInt;

//- utility function -----------------------------------------------------------

{
  BufferStore

  Stores data from provided untyped variable of given size into the buffer,
  reallocating the buffer if necessary.

  If the passed buffer is invalid, it is first initialized.  
}
procedure BufferStore(var Buff: TMemoryBuffer; const Src; Size: TMemSize); overload;

{
  BufferStore

  Stores data from provided memory location of given size into the buffer,
  reallocating the buffer if necessary.

  If the passed buffer is invalid, it is first initialized.  
}
procedure BufferStore(var Buff: TMemoryBuffer; Src: Pointer; Size: TMemSize); overload;

{
  Stream_WriteMemoryBuffer

  Writes content (if any) of provided buffer into the stream.

  If buffer is invalid, this function raises an EMBInvalidBuffer exception.

  When Advance is true, the stream position is changed accordingly to number of
  bytes written, otherwise it is preserved.

  Note that this function merely writes the buffered data, not the size or user
  data.
}
procedure Stream_WriteMemoryBuffer(Stream: TStream; const Buff: TMemoryBuffer; Advance: Boolean = True);

{
  Stream_SaveMemoryBuffer

  Writes user data and indicated size into the stream (both are stored as
  unsigned 64bit integer) and then writes content (if any) of provided buffer.

  If buffer is invalid, this function raises an EMBInvalidBuffer exception.

  When Advance is true, the stream position is changed accordingly to number of
  bytes written, otherwise it is preserved.
}
procedure Stream_SaveMemoryBuffer(Stream: TStream; const Buff: TMemoryBuffer; Advance: Boolean = True);

{
  Stream_ReadMemoryBuffer

  Reads data from a stream into provided buffer.

  If buffer is invalid, this function raises an EMBInvalidBuffer exception.

  When Advance is true, the stream position is changed accordingly to number of
  bytes read, otherwise it is preserved.

  Number of bytes read read depends on indicated size of the buffer, so the
  buffer must be properly allocated before a call to this function.
}
procedure Stream_ReadMemoryBuffer(Stream: TStream; const Buff: TMemoryBuffer; Advance: Boolean = True);

{
  Stream_LoadMemoryBuffer

  Reads user data and indicated size from the stream, (re)allocates the buffer
  as needed and then reads data into it.

  If buffer is invalid, it will be properly initialized.

  When Advance is true, the stream position is changed accordingly to number of
  bytes written, otherwise it is preserved.
}
procedure Stream_LoadMemoryBuffer(Stream: TStream; var Buff: TMemoryBuffer; Advance: Boolean = True);

implementation

{$IFDEF FPC_DisableWarns}
  {$DEFINE FPCDWM}
  {$DEFINE W4055:={$WARN 4055 OFF}} // Conversion between ordinals and pointers is not portable
  {$DEFINE W5057:={$WARN 5057 OFF}} // Local variable "$1" does not seem to be initialized
  {$PUSH}{$WARN 2005 OFF}           // Comment level $1 found
  {$IF Defined(FPC) and (FPC_FULLVERSION >= 30000)}
    {$DEFINE W5060:=}
    {$DEFINE W5092:={$WARN 5092 OFF}} // Variable "$result" of a managed type does not seem to be initialized
    {$DEFINE W5094:={$WARN 5094 OFF}} // Function result variable of a managed type does not seem to be initialized
  {$ELSE}
    {$DEFINE W5060:={$WARN 5060 OFF}} // Function result variable of a managed type does not seem to be initialized
    {$DEFINE W5092:=}
    {$DEFINE W5094:=}
  {$IFEND}
  {$POP}
{$ENDIF}

const
  MB_CHECK_STRING = 'VALID';

//- internal utility functions -------------------------------------------------

Function BufferChecksum(const Buff: TMemoryBuffer): PtrUInt;
begin
{$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
Result := PtrUInt(Buff.Signature) xor PtrUInt(Buff.Memory) xor not PtrUInt(Buff.Size) xor not PtrUInt(Buff.AllocSize);
{$IFDEF FPCDWM}{$POP}{$ENDIF}
end;  

//==============================================================================

Function BufferIsValid(const Buff: TMemoryBuffer): Boolean;
begin
Result := (Buff.Checksum = BufferChecksum(Buff)) and (Buff.CheckStr = MB_CHECK_STRING);
end;

//------------------------------------------------------------------------------

procedure BufferInit(out Buff: TMemoryBuffer);

  Function GetSignature: PtrUInt;
  begin
  {$IFDEF 64bit}
    Result := (PtrUInt(Random($10000)) shl 48) or (PtrUInt(Random($10000)) shl 32) or
              (PtrUInt(Random($10000)) shl 16) or PtrUInt(Random($10000)) ;
  {$ELSE}
    Result := (PtrUInt(Random($10000)) shl 16) or PtrUInt(Random($10000));
  {$ENDIF}
  end;

begin
Buff.Memory := nil;
Buff.Signature := GetSignature;
Buff.Size := 0;
Buff.AllocSize := 0;
Buff.UserData := 0;
Buff.Checksum := BufferChecksum(Buff);
Buff.CheckStr := MB_CHECK_STRING;
end;

//------------------------------------------------------------------------------

procedure BufferFinal(var Buff: TMemoryBuffer);
begin
If BufferIsValid(Buff) then
  BufferFree(Buff);
Buff.Signature := 0;
Buff.Checksum := PtrUInt(-1);
Buff.CheckStr := '';
end;

//------------------------------------------------------------------------------

Function BufferBuild(Memory: Pointer; Size: TMemSize; UserData: PtrInt = 0): TMemoryBuffer;
begin
BufferInit(Result);
Result.Memory := Memory;
Result.Size := Size;
Result.AllocSize := Size;
Result.UserData := UserData;
Result.Checksum := BufferChecksum(Result);
end;

//==============================================================================

procedure BufferGet(var Buff: TMemoryBuffer; Size: TMemSize);
begin
// if buffer was already used, free it, otherwise initialize it
If BufferIsValid(Buff) then
  BufferFree(Buff)
else
  BufferInit(Buff);
// allocate memory
If Size > 0 then
  GetMem(Buff.Memory,Size)
else
  Buff.Memory := nil;
// store size
Buff.Size := Size;
Buff.AllocSize := Size;
Buff.Checksum := BufferChecksum(Buff);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

{$IFDEF FPCDWM}{$PUSH}W5060 W5092 W5094{$ENDIF}
Function BufferGet(Size: TMemSize): TMemoryBuffer;
begin
BufferGet(Result,Size);
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

//------------------------------------------------------------------------------

procedure BufferAlloc(var Buff: TMemoryBuffer; Size: TMemSize);
begin
BufferGet(Buff,Size);
FillChar(Buff.Memory^,Buff.AllocSize,0);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

{$IFDEF FPCDWM}{$PUSH}W5060 W5092 W5094{$ENDIF}
Function BufferAlloc(Size: TMemSize): TMemoryBuffer;
begin
BufferAlloc(Result,Size);
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

//------------------------------------------------------------------------------

procedure BufferFree(var Buff: TMemoryBuffer);
begin
// if buffer is already initialized, free it, otherwise initialize it
If BufferIsValid(Buff) then
  begin
    If Buff.AllocSize > 0 then
      FreeMem(Buff.Memory,Buff.AllocSize);
    Buff.Memory := nil;
    Buff.Size := 0;
    Buff.AllocSize := 0;
    Buff.Checksum := BufferChecksum(Buff);
  end
else BufferInit(Buff);
end;

//------------------------------------------------------------------------------

procedure BufferRealloc(var Buff: TMemoryBuffer; NewSize: TMemSize; AllowShrink: Boolean = True);
begin
If BufferIsValid(Buff) then
  begin
    {
      reallocate only when new size is larger than current allocated size or
      shrinking is alloved, otherwise just change indicated size
    }
    If (NewSize > Buff.AllocSize) or AllowShrink then
      begin
        If NewSize <> 0 then
          begin
            If NewSize <> Buff.Size then
              begin
                ReallocMem(Buff.Memory,NewSize);
                Buff.AllocSize := NewSize;
                Buff.Size := NewSize;
              end;
          end
        else BufferFree(Buff);
      end
    else Buff.Size := NewSize;
    Buff.Checksum := BufferChecksum(Buff);
  end
else BufferGet(Buff,NewSize);
end;

//==============================================================================

Function BufferCopy(const Src: TMemoryBuffer): TMemoryBuffer;
begin
If BufferIsValid(Src) then
  begin
    Result := BufferGet(Src.Size);  // this will also init the result
    Move(Src.Memory^,Result.Memory^,Src.Size);
    Result.UserData := Src.UserData;
    Result.Checksum := BufferChecksum(Result);
  end
else raise EMBInvalidBuffer.Create('BufferCopy: Invalid source buffer, cannot make a copy.');
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure BufferCopy(const Src: TMemoryBuffer; var Dest: TMemoryBuffer);
begin
If BufferIsValid(Src) then
  begin
    BufferRealloc(Dest,Src.Size); // allocates an uninitialized buffer
    Move(Src.Memory^,Dest.Memory^,Src.Size);
    Dest.UserData := Src.UserData;
    Dest.Checksum := BufferChecksum(Dest);
  end
else raise EMBInvalidBuffer.Create('BufferCopy: Invalid source buffer, cannot make a copy.');
end;

//==============================================================================

Function BufferMemory(const Buff: TMemoryBuffer): Pointer;
begin
If BufferIsValid(Buff) then
  Result := Buff.Memory
else
  Result := nil;
end;
 
//------------------------------------------------------------------------------

Function BufferSize(const Buff: TMemoryBuffer): TMemSize;
begin
If BufferIsValid(Buff) then
  Result := Buff.Size
else
  Result := 0;
end;

//------------------------------------------------------------------------------

Function BufferAllocSize(const Buff: TMemoryBuffer): TMemSize;
begin
If BufferIsValid(Buff) then
  Result := Buff.AllocSize
else
  Result := 0;
end;

//------------------------------------------------------------------------------

Function BufferGetUserData(const Buff: TMemoryBuffer): PtrInt;
begin
If BufferIsValid(Buff) then
  Result := Buff.UserData
else
  Result := 0;
end;

//------------------------------------------------------------------------------

Function BufferSetUserData(var Buff: TMemoryBuffer; UserData: PtrInt): PtrInt;
begin
If BufferIsValid(Buff) then
  begin
    Result := Buff.UserData;
    Buff.UserData := UserData;
  end
else Result := 0;
end;

//==============================================================================

procedure BufferStore(var Buff: TMemoryBuffer; const Src; Size: TMemSize);
begin
BufferRealloc(Buff,Size); // creates the buffer if it is invalid
Move(Src,Buff.Memory^,Size);
Buff.Checksum := BufferChecksum(Buff);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure BufferStore(var Buff: TMemoryBuffer; Src: Pointer; Size: TMemSize);
begin
BufferStore(Buff,Src^,Size);
end;

//------------------------------------------------------------------------------

procedure Stream_WriteMemoryBuffer(Stream: TStream; const Buff: TMemoryBuffer; Advance: Boolean = True);
begin
If BufferIsValid(Buff) then
  begin
    If Buff.Size <> 0 then
      begin
        Stream.WriteBuffer(Buff.Memory^,Int64(Buff.Size));
        If not Advance then
          Stream.Seek(-Int64(Buff.Size),soCurrent);
      end;
  end
else raise EMBInvalidBuffer.Create('Stream_WriteBuffer: Invalid buffer.');
end;

//------------------------------------------------------------------------------

procedure Stream_SaveMemoryBuffer(Stream: TStream; const Buff: TMemoryBuffer; Advance: Boolean = True);
var
  InitPos:  Int64;
  Temp:     UInt64;
begin
If BufferIsValid(Buff) then
  begin
    InitPos := Stream.Position;
    // save metadata (do not use binary streaming)
    Temp := UInt64(Buff.UserData);
    Stream.WriteBuffer(Temp,SizeOf(Temp));
    Temp := UInt64(Buff.Size);
    Stream.WriteBuffer(Temp,SizeOf(Temp));
    // save content
    If Buff.Size <> 0 then
      Stream.WriteBuffer(Buff.Memory^,Int64(Buff.Size));
    If not Advance then
      Stream.Seek(InitPos,soBeginning);
  end
else raise EMBInvalidBuffer.Create('Stream_SaveMemoryBuffer: Invalid buffer.');
end;

//------------------------------------------------------------------------------

procedure Stream_ReadMemoryBuffer(Stream: TStream; const Buff: TMemoryBuffer; Advance: Boolean = True);
begin
If BufferIsValid(Buff) then
  begin
    If Buff.Size <> 0 then
      begin
        Stream.ReadBuffer(Buff.Memory^,Int64(Buff.Size));
        If not Advance then
          Stream.Seek(-Int64(Buff.Size),soCurrent);
      end;
  end
else raise EMBInvalidBuffer.Create('Stream_ReadBuffer: Invalid buffer.');
end;

//------------------------------------------------------------------------------

{$IFDEF FPCDWM}{$PUSH}W5057{$ENDIF}
procedure Stream_LoadMemoryBuffer(Stream: TStream; var Buff: TMemoryBuffer; Advance: Boolean = True);
var
  InitPos:  Int64;
  UserData: UInt64;
  Size:     UInt64;
begin
InitPos := Stream.Position;
// read metadata
Stream.ReadBuffer(UserData,SizeOf(UserData));
Stream.ReadBuffer(Size,SizeOf(Size));
// prepare buffer
BufferRealloc(Buff,TMemSize(Size)); // this also initializes the buffer when needed
Buff.UserData := PtrInt(UserData);
// load content
If Buff.Size <> 0 then
  Stream.ReadBuffer(Buff.Memory^,Int64(Buff.Size));
If not Advance then
  Stream.Seek(InitPos,soBeginning);
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

//==============================================================================

initialization
  Randomize;  // required for signatures generation 

end.
