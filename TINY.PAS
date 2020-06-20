Program Tiny;

   {  Program to compress .COM programs  }

{$I-}

Uses
  Dos,
  Crt;

Const
  mdStoreB      =  1;
  mdStoreW      =  2;
  mdDupB        =  3;
  mdDupW        =  4;
  mdDupWord     =  5;
  mdIncB        =  6;
  mdIncW        =  7;
  mdDecB        =  8;
  mdDecW        =  9;
  mdSkipOne     = 10;
  mdCopy        = 11;
  mdSpaceB      = 12;
  mdSpaceW      = 13;

Const
  DupBase       =  4;
  DupWordBase   =  3;
  IncBase       =  5;
  IncWordBase   =  4;
  DecBase       =  6;
  DecWordBase   =  4;
  SkipBase      =  3;
  CopyBase      =  5;
  SpaceBase     =  0;

Const
  ProgId = 'TINY V1.0 (C) Copyright June 1993, by Mike Wiering';
  Max = $FFFF;
  MaxMethods = 13;
  MethodsUsed: Byte = 0;
  TotalProcLength: Word = 0;

Const
  Safe = $10;

Type
  BufferPtr = ^Buffer;
  Buffer = Array[1..Max] of Char;

Type
  MethodRec = Record
    Number: Byte;
    UnpackProc: Pointer;
    ProcLength: Word;
  end;

Var
  Prog,
  NewProg: BufferPtr;
  Filename, Oldname: String;
  OrigSize,
  ProgSize,
  NewSize,
  NewProgSize,
  MaxBytes,
  MaxGain: Word;
  InputFile,
  OutputFile: File;
  Percent,
  OldPercent,
  MaxMethod, LastMethod: Byte;
  M: Array[1..MaxMethods] of MethodRec;
  StartSize, DoneSize: Byte;


Procedure StartUnpack; Assembler;
asm
        mov     si, 0000        { Program offset }
        mov     di, 0000        { Unpack buffer }
        mov     ax, 0000        { Program size }
        mov     bx, 0000        { Adderss UnpackDone }
        mov     dx, 0000        { Procedure tabel }
        mov     bp, di
        push    ax
        push    bx
        cld
@1:     lodsb
        mov     ah, 0
        shl     al, 1
        jnc     @2
        ret

        db      0
        db      'TINY'
        db      0

@2:     mov     bx, ax
        add     bx, dx
        lodsb
        mov     cx, ax
        call    Word Ptr [bx]
        jmp     @1
        ret
end;

Procedure UnpackDone; Assembler;
asm
        pop     cx
        mov     si, bp
        mov     di, 100h
        push    di
        rep
        movsb
        ret
end;


Procedure UnpackMoveB; Assembler;
asm
        rep
        movsb
        ret
end;

Procedure UnpackMoveW; Assembler;
asm
        lodsb
        mov     ch, al
        rep
        movsb
        ret
end;

Procedure UnpackDupB; Assembler;
asm
        lodsb
        rep
        stosb
        ret
end;

Procedure UnpackDupW; Assembler;
asm
        lodsb
        mov     ch, al
        lodsb
        rep
        stosb
        ret
end;

Procedure UnpackDupWord; Assembler;
asm
        lodsw
        rep
        stosw
        ret
end;

Procedure UnpackIncB; Assembler;
asm
        lodsb
@1:     stosb
        inc     al
        loop    @1
        ret
end;

Procedure UnpackIncW; Assembler;
asm
        lodsw
@1:     stosw
        inc     ax
        loop    @1
        ret
end;

Procedure UnpackDecB; Assembler;
asm
        lodsb
@1:     stosb
        dec     al
        loop    @1
        ret
end;

Procedure UnpackDecW; Assembler;
asm
        lodsw
@1:     stosw
        dec     ax
        loop    @1
        ret
end;

Procedure UnpackSkip; Assembler;
asm
        lodsb
@1:     stosb
        movsb
        loop    @1
        ret
end;

Procedure UnpackCopy; Assembler;
asm
        lodsw
        push    si
        mov     si, bp
        add     si, ax
        rep
        movsb
        pop     si
        ret
end;

Procedure UnpackSpaceB; Assembler;
asm
@1:     lodsb
        cmp     al, 7Fh
        jnz     @2
        movsb
        jmp     @4
@2:     test    al, 80h
        jz      @3
        and     al, 7Fh
        stosb
        mov     al, ' '
@3:     stosb
@4:     loop    @1
        ret
end;

Procedure UnpackSpaceW; Assembler;
asm
        lodsb
        mov     ch, al
@1:     lodsb
        cmp     al, 7Fh
        jnz     @2
        movsb
        jmp     @4
@2:     test    al, 80h
        jz      @3
        and     al, 7Fh
        stosb
        mov     al, ' '
@3:     stosb
@4:     loop    @1
        ret
end;


Procedure Error(Msg: String);
begin
  WriteLn(Msg);
  Halt;
end;

Procedure ShowInformation;
begin
  WriteLn(#13#10 +
    ProgId + #13#10 +
    'Program to compress COM-programs'#13#10 +
    #13#10 +
    'Syntax: TINY filename');
  Halt;
end;

Procedure ReadFile;
begin
  Assign(InputFile, Filename);
  Reset(InputFile, 1);
  if IOresult <> 0 then
    Error('Cannot open ' + Filename);
  BlockRead(InputFile, Prog^[1], SizeOf(Buffer), OrigSize);
  Close(InputFile);
  if OrigSize > $E000 then
    Error(#13'Sorry, program too large.');
end;

Function CountLength(var P): Word;
Var
  Len: Word;
begin
  asm
        push    ds
        lds     si, P
        xor     cx, cx
        cld
@1:     lodsw
        dec     si
        inc     cx
        cmp     ax, 0C3C3h
        jnz     @1
        mov     Len, cx
        pop     ds
  end;
  CountLength := Len;
end;

Procedure InitMethods;
Var
  i: Byte;
begin
  for i := 1 to MaxMethods do
    M[i].Number := $FF;
  M[mdStoreB].UnpackProc := @UnpackMoveB;
  M[mdStoreW].UnpackProc := @UnpackMoveW;
  M[mdDupB].UnpackProc := @UnpackDupB;
  M[mdDupW].UnpackProc := @UnpackDupW;
  M[mdDupWord].UnpackProc := @UnpackDupWord;
  M[mdIncB].UnpackProc := @UnpackIncB;
  M[mdIncW].UnpackProc := @UnpackIncW;
  M[mdDecB].UnpackProc := @UnpackDecB;
  M[mdDecW].UnpackProc := @UnpackDecW;
  M[mdSkipOne].UnpackProc := @UnpackSkip;
  M[mdCopy].UnpackProc := @UnpackCopy;
  M[mdSpaceB].UnpackProc := @UnpackSpaceB;
  M[mdSpaceW].UnpackProc := @UnpackSpaceW;

  for i := 1 to MaxMethods do
    M[i].ProcLength := CountLength(M[i].UnpackProc^);
end;

Procedure Init;
begin
  if ParamCount < 1 then
    ShowInformation;
  if MaxAvail < 2 * SizeOf(Buffer) then
    Error('Not enough memory');
  GetMem(Prog, SizeOf(Buffer));
  GetMem(NewProg, SizeOf(Buffer));
  Filename := ParamStr(1);
  if Pos('.', Filename) = 0 then
    Filename := Filename + '.COM';
  StartSize := CountLength(@StartUnpack^) - 1;
  DoneSize := CountLength(@UnpackDone^);
  ReadFile;
  Move(@UnpackDone^, Prog^[OrigSize + 1], DoneSize);
  ProgSize := OrigSize + DoneSize;
  NewSize := 0;
  OldPercent := $FF;
  InitMethods;
end;

Function WordStr(W: Word): String;
begin
  WordStr := Chr(Lo(W)) + Chr(Hi(W));
end;

Procedure CompressProgram;
Var
  Pos,
  Address,
  StoreNumberPos,
  StoreNumber: Word;
  PosChar,
  NextChar: Char;

Procedure CompressText;
Const
  MaxText = 10000;
Var
  Start, i, j, NumSpaces, SpecialChars: Word;
  N: Byte;
  Cmds: Integer;
  FirstTime, Special: Boolean;
  Buffer: Array[1..MaxText] of Char;
begin
  if (LastMethod = mdStoreB) and (StoreNumber = 255) then Exit;
  Start := StoreNumberPos + 1 + Byte(LastMethod = mdStoreW);
  NumSpaces := 0;
  SpecialChars := 0;
  for i := Start to NewSize do
    Case NewProg^[i] of
      #127..#255: Inc(SpecialChars);
      ' ': Inc(NumSpaces);
    end;
  if NumSpaces > SpaceBase + 2 * SpecialChars then
  begin
    Cmds := 0;
    SpecialChars := 0;
    j := 1;
    Special := False;
    for i := Start to NewSize do
      if (NewProg^[i] = ' ') and (j > 1) and
        (Buffer[j - 1] < #128) and (not Special) then
      begin
        Buffer[j - 1] := Chr(Ord(Buffer[j - 1]) + $80);
      end
      else
        if (NewProg^[i] in [#127..#255]) then
        begin
          Buffer[j] := #127;
          Buffer[j + 1] := NewProg^[i];
          Inc(j, 2);
          Inc(SpecialChars);
          Inc(Cmds);
          Special := True;
        end
        else
        begin
          Buffer[j] := NewProg^[i];
          Inc(j);
          Inc(Cmds);
          Special := False;
        end;
    Move(Buffer[1], NewProg^[Start], j);
    NewSize := NewSize + Cmds + SpecialChars - StoreNumber;
    if LastMethod = mdStoreB then N := mdSpaceB else N := mdSpaceW;
    LastMethod := N;
    FirstTime := (M[N].Number = $FF);
    if FirstTime then
    begin
      M[N].Number := MethodsUsed;
      Inc(MethodsUsed);
      Inc(TotalProcLength, M[N].ProcLength);
    end;
    NewProg^[StoreNumberPos - 1] := Chr(M[N].Number);
    StoreNumber := Cmds;
    NewProg^[StoreNumberPos] := Chr(Lo(StoreNumber));
    if N = mdSpaceW then
      NewProg^[StoreNumberPos + 1] := Chr(Hi(StoreNumber));
  end;
end;

Procedure StartNewMethod(N: Byte);
begin
  if LastMethod in [mdStoreB, mdStoreW] then
    CompressText;
  LastMethod := N;
  if M[N].Number <> $FF then Exit;
  M[N].Number := MethodsUsed;
  Inc(MethodsUsed);
  Inc(TotalProcLength, M[N].ProcLength);
end;

Procedure WriteToProg(S: String);
Var
  i: Word;
begin
  for i := 1 to Length(S) do
    NewProg^[NewSize + i] := S[i];
  Inc(NewSize, Length(S));
end;

Procedure StartNewNumber;
begin
  StartNewMethod(mdStoreB);
  WriteToProg(Chr(M[mdStoreB].Number));
  WriteToProg(#0);
  StoreNumberPos := NewSize;
  StoreNumber := 0;
end;

Procedure JustStoreChar(C: Char);
Var
  i: Word;
begin
  WriteToProg(C);
  if StoreNumber = 255 then
  begin
    StartNewMethod(mdStoreW);
    For i := NewSize DownTo StoreNumberPos + 1 do
      NewProg^[i + 1] := NewProg^[i];
    NewProg^[StoreNumberPos - 1] := Chr(M[mdStoreW].Number);
    Inc(NewSize);
  end;
  Inc(StoreNumber);
  NewProg^[StoreNumberPos] := Chr(Lo(StoreNumber));
  if StoreNumber > 255 then
    NewProg^[StoreNumberPos + 1] := Chr(Hi(StoreNumber));
end;

Procedure StopStore;
begin
  if StoreNumber = 0 then
  begin
    Dec(NewSize, 2);
    LastMethod := $FF;
  end;
end;

Procedure CheckDup;
Var
  Count: Word;
begin
  Count := 0;
  While (Prog^[Pos + Count] = PosChar) and (Pos + Count < ProgSize) do
    Inc(Count);
  if Count > MaxGain + DupBase then
  begin
    if Count > 255 then
      MaxMethod := mdDupW
    else
      MaxMethod := mdDupB;
    MaxBytes := Count;
    MaxGain := Count - DupBase;
  end;
end;

Procedure CheckDupWord;
Var
  Count: Word;
begin
  Count := 0;
  While (Prog^[Pos + (2 * Count)] = PosChar) and
    (Prog^[Pos + (2 * Count) + 1] = NextChar) and
    (Count < $FF) and (Pos + (2 * Count) + 1 < ProgSize) do
      Inc(Count);
  if Count > MaxGain + DupWordBase then
  begin
    MaxMethod := mdDupWord;
    MaxBytes := Count;
    MaxGain := (Count - DupWordBase) * 2;
  end;
end;

Procedure CheckIncByte;
Var
  Count: Word;
  Ch: Byte;
begin
  Count := 0;
  Ch := Ord(PosChar);
  While (Prog^[Pos + Count] = Chr(Ch)) and (Count < $FF)
    and (Pos + Count < ProgSize) do
  begin
    Inc(Count);
    Inc(Ch);
  end;
  if Count > MaxGain + IncBase then
  begin
    MaxMethod := mdIncB;
    MaxBytes := Count;
    MaxGain := Count - IncBase;
  end;
end;

Procedure CheckDecByte;
Var
  Count: Word;
  Ch: Byte;
begin
  Count := 0;
  Ch := Ord(PosChar);
  While (Prog^[Pos + Count] = Chr(Ch)) and (Count < $FF)
    and (Pos + Count < ProgSize) do
  begin
    Inc(Count);
    Dec(Ch);
  end;
  if Count > MaxGain + DecBase then
  begin
    MaxMethod := mdDecB;
    MaxBytes := Count;
    MaxGain := Count - DecBase;
  end;
end;

Procedure CheckIncWord;
Var
  Count: Word;
  W: Word;
begin
  Count := 0;
  W := Ord(PosChar) + Ord(NextChar) * $100;
  While (Prog^[Pos + 2 * Count] = Chr(Lo(W))) and
        (Prog^[Pos + 2 * Count + 1] = Chr(Hi(W))) and
        (Count < $FF) and (Pos + 2 * Count + 1 < ProgSize) do
  begin
    Inc(Count);
    Inc(W);
  end;
  if Count > MaxGain + IncWordBase then
  begin
    MaxMethod := mdIncW;
    MaxBytes := Count;
    MaxGain := (Count - IncWordBase) * 2;
  end;
end;

Procedure CheckDecWord;
Var
  Count: Word;
  W: Word;
begin
  Count := 0;
  W := Ord(PosChar) + Ord(NextChar) * $100;
  While (Prog^[Pos + 2 * Count] = Chr(Lo(W))) and
        (Prog^[Pos + 2 * Count + 1] = Chr(Hi(W))) and
        (Count < $FF) and (Pos + 2 * Count + 1 < ProgSize) do
  begin
    Inc(Count);
    Dec(W);
  end;
  if Count > MaxGain + DecWordBase then
  begin
    MaxMethod := mdDecW;
    MaxBytes := Count;
    MaxGain := (Count - DecWordBase) * 2;
  end;
end;

Procedure CheckSkip;
Var
  Count: Word;
  i: Byte;
begin
  Count := 0;
  i := 0;
  While (Prog^[Pos + 2 * Count] = PosChar) and (Count < $FF)
    and (i < DupWordBase) and (Pos + 2 * Count + 2 < ProgSize) do
  begin
    Inc(Count);
    if (Count > 0) and (Prog^[Pos + 2 * Count - 1] = Prog^[Pos + 2 * Count - 3]) then
      Inc(i)
    else
      i := 0;
  end;
  if (i >= DupWordBase) then
    if Count > i then
      Dec(Count, i)
    else
      Count := 0;
  if Count > MaxGain + SkipBase then
  begin
    MaxMethod := mdSkipOne;
    MaxBytes := Count;
    MaxGain := Count - SkipBase;
  end;
end;

Procedure CheckCopy;
Var
  S: String;
  StrLen: Byte Absolute S;
  MaxLen, i: Word;
  j: Byte;
begin
  Move(Prog^[Pos], S[1], SizeOf(S) - 1);
  StrLen := 255;
  if Pos + 255 > ProgSize then
    StrLen := ProgSize - Pos + 1;
  if StrLen > Pos - 1 then StrLen := Pos - 1;
  if StrLen < CopyBase then Exit;

  MaxLen := 0;
  for i := 1 to Pos - 1 do
  begin
    j := 0;
    While (S[j + 1] = Prog^[i + j]) and (j < StrLen) and (i + j < Pos) do
      Inc(j);
    if j > MaxLen then
    begin
      MaxLen := j;
      Address := i;
    end;
  end;
  if MaxLen > MaxGain + CopyBase then
  begin
    MaxMethod := mdCopy;
    MaxBytes := MaxLen;
    MaxGain := MaxLen - CopyBase;
  end;
end;

Procedure StoreDup;
begin
  if MaxBytes <= 255 then
  begin
    StartNewMethod(mdDupB);
    WriteToProg(Chr(M[mdDupB].Number));
    WriteToProg(Chr(MaxBytes));
  end
  else
  begin
    StartNewMethod(mdDupW);
    WriteToProg(Chr(M[mdDupW].Number));
    WriteToProg(WordStr(MaxBytes));
  end;
  WriteToProg(PosChar);
end;

Procedure StoreDupWord;
begin
  StartNewMethod(mdDupWord);
  WriteToProg(Chr(M[mdDupWord].Number));
  WriteToProg(Chr(MaxBytes));
  WriteToProg(PosChar + NextChar);
  Inc(Pos, MaxBytes);
end;

Procedure StoreIncB;
begin
  StartNewMethod(mdIncB);
  WriteToProg(Chr(M[mdIncB].Number));
  WriteToProg(Chr(MaxBytes));
  WriteToProg(PosChar);
end;

Procedure StoreDecB;
begin
  StartNewMethod(mdDecB);
  WriteToProg(Chr(M[mdDecB].Number));
  WriteToProg(Chr(MaxBytes));
  WriteToProg(PosChar);
end;

Procedure StoreIncW;
begin
  StartNewMethod(mdIncW);
  WriteToProg(Chr(M[mdIncW].Number));
  WriteToProg(Chr(MaxBytes));
  WriteToProg(PosChar + NextChar);
  Inc(Pos, MaxBytes);
end;

Procedure StoreDecW;
begin
  StartNewMethod(mdDecW);
  WriteToProg(Chr(M[mdDecW].Number));
  WriteToProg(Chr(MaxBytes));
  WriteToProg(PosChar + NextChar);
  Inc(Pos, MaxBytes);
end;

Procedure StoreSkip;
Var
  i: Word;
begin
  StartNewMethod(mdSkipOne);
  WriteToProg(Chr(M[mdSkipOne].Number));
  WriteToProg(Chr(MaxBytes));
  WriteToProg(PosChar);
  for i := 0 to MaxBytes - 1 do
    WriteToProg(Prog^[Pos + 1 + 2 * i]);
  Inc(Pos, MaxBytes);
end;

Procedure StoreCopy;
begin
  StartNewMethod(mdCopy);
  WriteToProg(Chr(M[mdCopy].Number));
  WriteToProg(Chr(MaxBytes));
  WriteToProg(WordStr(Address - 1));
end;

begin
  Pos := 0;
  OldPercent := $FF;
  StartNewNumber;

  repeat
    MaxMethod := 0;
    MaxBytes := 0;
    MaxGain := 0;
    Inc(Pos);
    PosChar := Prog^[Pos];
    NextChar := Prog^[Pos + 1];
    Percent := Byte((LongInt(Pos) * 100) div ProgSize);
    if Percent <> OldPercent then
    begin
      Write(#13, Percent, '%');
      OldPercent := Percent;
    end;
 
    CheckDup;
    CheckDupWord;
    CheckIncByte;
    CheckDecByte;
    CheckIncWord;
    CheckDecWord;
    CheckSkip;
    CheckCopy;

    if MaxGain = 0 then
      JustStoreChar(Prog^[Pos])
    else
    begin
      StopStore;
      Case MaxMethod of
        mdDupB,
        mdDupW: StoreDup;
        mdDupWord: StoreDupWord;
        mdIncB: StoreIncB;
        mdDecB: StoreDecB;
        mdIncW: StoreIncW;
        mdDecW: StoreDecW;
        mdSkipOne: StoreSkip;
        mdCopy: StoreCopy;

      end;
      Inc(Pos, MaxBytes - 1);
      StartNewNumber;
    end;
    if ProgSize + NewSize + $1000 > Max then
      Error(#13'Sorry, program too large.');
  until Pos >= ProgSize;
  StopStore;
  if LastMethod in [mdStoreB, mdStoreW] then
    CompressText;
  WriteToProg(#$FF);
end;

Procedure WriteProg;
Var
  Buf: Array[0..1000] of Char;
  W: String[2];
  i, j: Integer;
  Count: Word;
begin
  Assign(OutputFile, 'TINY.$$$');
  ReWrite(OutputFile, 1);

  Move(@StartUnpack^, Buf[1], StartSize);
  W := WordStr($0100 + StartSize + MethodsUsed * 2 + TotalProcLength);
  Buf[2] := W[1];
  Buf[3] := W[2];
  W := WordStr($0100 + StartSize + MethodsUsed * 2 + TotalProcLength +
    NewSize);
  Buf[5] := W[1];
  Buf[6] := W[2];
  W := WordStr(OrigSize);
  Buf[8] := W[1];
  Buf[9] := W[2];
  W := WordStr($0100 + StartSize + MethodsUsed * 2 + TotalProcLength +
    NewSize + OrigSize);
  Buf[11] := W[1];
  Buf[12] := W[2];
  W := WordStr($0100 + StartSize);
  Buf[14] := W[1];
  Buf[15] := W[2];
  BlockWrite(OutputFile, Buf[1], StartSize);

  Count := $0100 + StartSize + MethodsUsed * 2;
  for i := 0 to MaxMethods - 1 do
    for j := 1 to MaxMethods do
      if M[j].Number = i then
      begin
        W := WordStr(Count);
        BlockWrite(OutputFile, W[1], 2);
        Inc(Count, M[j].ProcLength);
      end;
  for i := 0 to MaxMethods - 1 do
    for j := 1 to MaxMethods do
      if M[j].Number = i then
      begin
        BlockWrite(OutputFile, M[j].UnpackProc^, M[j].ProcLength);
      end;


  BlockWrite(OutputFile, NewProg^[1], NewSize);

  Close(OutputFile);
end;

Procedure Done;
begin
  FreeMem(Prog, SizeOf(Buffer));
end;

begin
  Init;
  WriteLn(ProgId);
  Filename := FExpand(Filename);
  WriteLn('Compressing ' + Filename);
  CompressProgram;

  NewProgSize := StartSize + MethodsUsed * 2 + TotalProcLength + NewSize;

  Write(#13'Old size: ', OrigSize, '  New size: ', NewProgSize,
    '  Gain: ', LongInt(OrigSize) - NewProgSize, ' (');
  WriteLn(((LongInt(OrigSize) - NewProgSize) / OrigSize) * 100:1:2, '%)');
  if OrigSize > NewProgSize then
  begin
    WriteProg;
    if Pos('.', Filename) = 0 then
      OldName := Filename + '.OLD'
    else
      OldName := Copy(Filename, 1, Pos('.', Filename) - 1) + '.OLD';
    Rename(InputFile, Oldname);
    Rename(OutputFile, Filename);
  end
  else
  begin
    WriteLn('Sorry, this program cannot be compressed.');
  end;

  Done;
end.
