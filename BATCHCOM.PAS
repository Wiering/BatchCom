program BatchCompiler;

{$I+}
{$M 65520, 0, 655360}

  uses
    Dos, Crt, BCHelp;

  procedure ShowAllCommands;
  begin
    ShowCommands;
  end;

  const
    adNumParameters       = $100 +   3;
    adParameters          = $100 +   4;
    adDosVersionPart1     = $100 +  84;
    adDosVersionPart2     = $100 +  85;
    adEnviron             = $100 +  86;
    adTextAttribute       = $100 +  88;
    adScreenWidth         = $100 +  89;
    adScreenHeight        = $100 +  91;
    adWriteASCIIZString   = $100 +  93;
    adScreenBuffer        = $100 +  95;
    adWriteChar           = $100 +  97;
    adCRLF                = $100 +  99;
    adDraft               = $100 + 102;
    adErrorProc           = $100 + 104;
    adCheckErrors         = $100 + 106;
    adExtraErrorProc      = $100 + 107;
    adReadKey             = $100 + 109;
    adCheckBreak          = $100 + 111;
    adDTA                 = $100 + 112;
    adForAllFilesDo       = $100 + 114;
    adFileAttr            = $100 + 116;
    adVersionError        = $100 + 118;
    adFormatStr           = $100 + 120;
    adDraft2              = $100 + 122;
    adEL                  = $100 + 124;
    adReadVal             = $100 + 125;
    adForDTA              = $100 + 127;
    adEnvSeg              = $100 + 129;
    adSP                  = $100 + 131;
    adCrtWriteChar        = $100 + 133;
    adCrtWriteString      = $100 + 135;
    adMore                = $100 + 137;
    adMoreLine            = $100 + 138;
    adOP                  = $100 + 139;
    adMoreProc            = $100 + 140;
    adBreak               = $100 + 142;
    adHandleOutput        = $100 + 144;
    adWindMin             = $100 + 146;
    adWindMax             = $100 + 148;
    adActivePage          = $100 + 150;
    adPCopyBuffer         = $100 + 151;
    adInputStr            = $100 + 153;
    adUseCRT              = $100 + 155;
    adNumberFormat        = $100 + 156;
    adReturnAddr          = $100 + 160;


    opNUL         = $FF;
    opPRN         = $05;
    opAUX         = $04;
    opCON         = $00;


  const
    IncludeErrMsg: Boolean = False;
    IncludeFormatStr: Boolean = False;
    ForAllUsed: Boolean = False;
    ForInDoUsed: Boolean = False;
    ReadValUsed: Boolean = False;
    OverwriteFiles: Boolean = False;
    IncludeMore: Boolean = False;
    IncludeSaveScreen: Boolean = False;
    IncludeCRTInput: Boolean = False;
    CommentSet: Boolean = False;
    OnLine: Boolean = True;

  const
    MaxLabels = 750;
    MaxVars = 100;
    VarPos: Word = 0;
    LabelPos: Word = 0;
    Lab = True;
    Ref = False;
    IFAddr: Word = 0;
    FORAddr: Word = 0;
    FORAddr2: Word = 0;
    EnvLength: Word = $8192;
    StackSpace: Word = $0200;


  type
    VarType = record
      Name: string[16];
      Address: Word;
    end;

  var
    InputFile,
    OutputFile: Text;
    InputName,
    OutputName: string[94];
    CurLine, S, T, U, V: string;
    PrNum, Lin: Word;
    CmdDone: Boolean;
    Labels: Array[1..MaxLabels] of LongInt;
    LabelAddr: Array[1..MaxLabels] of Word;
    LabelTp: Array[1..MaxLabels] of Boolean;
    LabelLine: Array[1..MaxLabels] of Word;
    Vars: Array[1..MaxVars] of VarType;
    Number: Longint;

  const
    txVersionError: string[80] =
      'DOS version 2.0 or higher required';
    Comment: string[80] =
      #9;


  procedure StartProgramCode; assembler;
  asm
                  jmp     @StartProgram

                  db      00                         { Number of parameters }
                  db      00, 00, 00, 00, 00  { Addresses of all parameters }
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00, 00, 00, 00
                  db      00, 00                              { DOS version }
                  dw      0000                          { Environment table }
                  db      07                                  { Text attrib }
                  dw      80 - 1                             { Screen Width }
                  dw      25 - 1                            { Screen Height }
                  dw      0000, 0000, 0000               { Write procedures }
                  db      0dh, 0ah, 0                               { CR/LF }
                  dw      0000                      { 255-byte draft string }
                  dw      0000                 { procedure to handle errors }
                  db      01                             { Check for errors }
                  dw      0000                        { Some error messages }
                  dw      0000                                   { Read key }
                  db      0FFh                                { Check Break }
                  dw      0000                                { DTA address }
                  dw      0000                       { For all files do ... }
                  dw      0000                            { File attributes }
                  dw      0000                         { Version Error Text }
                  dw      0000                                  { FormatStr }
                  dw      0000                               { Draft string }
                  db      00                                  { Error level }
                  dw      0000                         { Read dec/hex value }
                  dw      0000            { DTA address for FOR .. IN .. DO }
                  dw      0000                        { Environment segment }
                  dw      0000                              { Stack Pointer }
                  dw      0000                             { CRT Write Char }
                  dw      0000                           { CRT Write string }
                  db      00                                         { More }
                  db      00                                    { More Line }
                  db      00                                          { NUL }
                  dw      0000                                   { --More-- }
                  dw      0000                               { Check Ctrl-C }
                  dw      0000                      { output to PRN/AUX/NUL }
                  db      0, 0, 79, 24                 { Window coordinates }
                  db      00                           { Active screen page }
                  dw      0000                  { Buffer for screen contens }
                  dw      0000                           { CRT input string }
                  db      00                                     { Use CRT? }
                  db      '%Ld', 0                          { Number Format }
                  dw      0000                 { Return address after error }


  @StartProgram:  mov     sp, [adSP]
                  mov     ah, 0Fh
                  int     10h
                  mov     [adActivePage], bh
                  call    @GetString
                  db      ' ', 8, '$'
  @GetString:     pop     dx
                  mov     ah, 9
                  int     21h
                  mov     ah, 8
                  mov     bh, [adActivePage]
                  int     10h
                  mov     [adTextAttribute], ah
                  push    es
                  mov     ax, 0040h
                  mov     es, ax
                  mov     ax, 0b800h
                  seges
                  cmp     Byte Ptr [0049h], 7
                  jnz     @SBOk
                  mov     ah, 0b0h
  @SBOk:          pop     es
                  mov     [adScreenBuffer], ax
                  mov     si, 0081h
                  mov     di, 0080h
                  mov     dx, adParameters
                  mov     Byte Ptr [adNumParameters], 00
  @GetParams:     lodsb
                  cmp     al, ' '
                  jz      @GetParams
                  cmp     al, 9
                  jz      @GetParams
                  cmp     al, 0dh
                  jz      @ParamsDone
                  dec     si
                  inc     Byte Ptr [adNumParameters]
                  mov     ax, di
                  push    di
                  mov     di, dx
                  stosb
                  mov     dx, di
                  pop     di
  @CopyParam:     lodsb
                  cmp     al, ' '
                  jz      @CopyDone
                  cmp     al, 9
                  jz      @CopyDone
                  cmp     al, 0dh
                  jz      @CopyDone
                  stosb
                  jmp     @CopyParam
  @CopyDone:      dec     si
                  mov     al, 0
                  stosb
                  jmp     @GetParams
  @ParamsDone:    mov     ax, 3000h
                  int     21h
                  or      al, al
                  jnz     @VersionOk
                  mov     dx, [adVersionError]
  @Error:         mov     ah, 9
                  int     21h
                  mov     ax, 4c01h
                  int     21h
  @VersionOk:     mov     [adDosVersionPart1], al
                  mov     [adDosVersionPart2], ah
                  mov     dx, [adDTA]
                  mov     ah, 1ah
                  int     21h
                  mov     ax, [002ch]
                  xor     si, si
                  mov     di, [adEnviron]
                  push    ds
                  mov     ds, ax
  @CopyEnv:       lodsb
                  stosb
                  or      al, al
                  jnz     @CopyEnv
                  cmp     Byte Ptr [si], 0
                  jnz     @CopyEnv
                  stosb
                  pop     ds
                  mov     ax, cs
                  add     [adEnvSeg], ax
                  mov     ah, 4Ah
                  mov     bx, [adSP]
                  add     bx, 10h
                  mov     cl, 4
                  shr     bx, cl
                  int     21h
                  xor     si, si      { for RETURN without GOSUB }
                  push    si
                  ret
                  dw      1011h
  end;

  procedure HandleOutput; assembler;
  asm
                  push    ax
                  push    dx
                  mov     ah, [adOP]
                  or      ah, ah
                  jz      @GoBack
                  cmp     ah, 0FFh
                  jz      @GoBack
                  mov     dl, al
                  int     21h
  @GoBack:        pop     dx
                  pop     ax
                  ret
                  dw      1011h
  end;

  procedure CheckBreak; assembler;
  asm
                  cmp     Byte Ptr [adCheckBreak], 0
                  jz      @GoBack
                  push    ax
                  mov     ah, 0Bh
                  int     21h
                  pop     ax
  @GoBack:        ret
                  dw      1011h
  end;

  procedure HandleError; assembler;
  asm
                  mov     Byte Ptr [adEL], al
                  cmp     Byte Ptr [adCheckErrors], 0
                  jz      @End
                  mov     bx, [adWriteASCIIZString]
                  or      ax, ax
                  jz      @End
                  call    @Start
                  db      0dh, 0ah, 'DOS error ', 0
  @Start:         pop     si
                  push    ax
                  call    bx
                  pop     ax
                  aam
                  add     ax, 3030h
                  push    ax
                  mov     al, ah
                  call    Word Ptr [adWriteChar]
                  pop     ax
                  call    Word Ptr [adWriteChar]
                  cmp     Word Ptr [adExtraErrorProc], 0000
                  jz      @NotInstalled
                  mov     al, ':'
                  call    Word Ptr [adWriteChar]
                  mov     al, ' '
                  call    Word Ptr [adWriteChar]
                  mov     al, [adEL]
                  call    Word ptr [adExtraErrorProc]
  @NotInstalled:  call    @PrtLine
                  db      '.', 0dh, 0ah, 'Continue (y/n)? ', 0
  @PrtLine:       pop     si
                  call    bx
  @Again:         call    Word Ptr [adReadKey]
                  mov     si, adCRLF
                  and     al, 0DFh
                  cmp     al, 'Y'
                  jz      @Continue
                  cmp     al, 'N'
                  jnz     @Again
                  call    Word Ptr [adWriteChar]
                  call    bx
                  mov     ax, 4c01h
                  int     21h
  @Continue:      call    Word Ptr [adWriteChar]
                  call    bx
  @End:           ret
                  dw      1011h
  end;

  procedure ErrorMessages; assembler;
  asm
                  cmp     al, 1
                  jnz     @NotEr1
                  call    @Show
                  db      'Invalid function number', 0
  @NotEr1:        cmp     al, 2
                  jnz     @NotEr2
                  call    @Show
                  db      'File not found', 0
  @NotEr2:        cmp     al, 3
                  jnz     @NotEr3
                  call    @Show
                  db      'Path not found', 0
  @NotEr3:        cmp     al, 4
                  jnz     @NotEr4
                  call    @Show
                  db      'Too many open files', 0
  @NotEr4:        cmp     al, 5
                  jnz     @NotEr5
                  call    @Show
                  db      'File access denied', 0
  @NotEr5:        cmp     al, 6
                  jnz     @NotEr6
                  call    @Show
                  db      'Invalid file handle', 0
  @NotEr6:        cmp     al, 8
                  jnz     @NotEr8
                  call    @Show
                  db      'Insufficient memory', 0
  @NotEr8:        cmp     al, 10
                  jnz     @NotEr10
                  call    @Show
                  db      'Environment invalid', 0
  @NotEr10:       cmp     al, 12
                  jnz     @NotEr12
                  call    @Show
                  db      'Invalid file access code', 0
  @NotEr12:       cmp     al, 15
                  jnz     @NotEr15
                  call    @Show
                  db      'Invalid disk drive', 0
  @NotEr15:       cmp     al, 16
                  jnz     @NotEr16
                  call    @Show
                  db      'Cannot remove current directory', 0
  @NotEr16:       cmp     al, 17
                  jnz     @NotEr17
                  call    @Show
                  db      'Cannot rename across drives', 0
  @NotEr17:       cmp     al, 19
                  jnz     @NotEr19
                  call    @Show
                  db      'Disk write-protected', 0
  @NotEr19:       cmp     al, 21
                  jnz     @NotEr21
                  call    @Show
                  db      'Drive not ready', 0
  @NotEr21:       cmp     al, 23
                  jnz     @NotEr23
                  call    @Show
                  db      'CRC error in data', 0
  @NotEr23:       cmp     al, 25
                  jnz     @NotEr25
                  call    @Show
                  db      'Disk seek error', 0
  @NotEr25:       cmp     al, 27
                  jnz     @NotEr27
                  call    @Show
                  db      'Sector not found', 0
  @NotEr27:       cmp     al, 28
                  jnz     @NotEr28
                  call    @Show
                  db      'Printer out of paper', 0
  @NotEr28:       cmp     al, 29
                  jnz     @NotEr29
                  call    @Show
                  db      'Write fault', 0
  @NotEr29:       cmp     al, 30
                  jnz     @NotEr30
                  call    @Show
                  db      'Read fault', 0
  @NotEr30:       cmp     al, 31
                  jnz     @NotEr31
                  call    @Show
                  db      'General failure', 0
  @NotEr31:       call    @Show
                  db      8, 8, 0
  @Show:          pop     si
                  call    Word Ptr [adWriteASCIIZString]
  @End:           ret
                  dw      1011h
  end;

  procedure DOSWriteChar; assembler;
  asm
                  cmp     Byte Ptr [adOP], opCON
                  jz      @Ok
                  call    Word Ptr [adHandleOutput]
                  ret
  @Ok:            push    ax
                  push    dx
                  mov     dl, al
                  mov     ah, 02
                  int     21h
                  pop     dx
                  pop     ax
                  cmp     al, 0Ah
                  jnz     @NotLF
                  call    Word Ptr [adMoreProc]
  @NotLF:         ret
                  dw      1011h
  end;

  procedure BIOSWriteChar; assembler;
  asm
                  cmp     Byte Ptr [adOP], opCON
                  jz      @Ok
                  call    Word Ptr [adHandleOutput]
                  ret
  @Ok:            push    ax
                  push    bx
                  mov     ah, 0eh
                  mov     bh, [adActivePage]
                  mov     bl, [adTextAttribute]
                  int     10h
                  pop     bx
                  pop     ax
                  call    Word Ptr [adBreak]
                  cmp     al, 0Ah
                  jnz     @NotLF
                  call    Word Ptr [adMoreProc]
  @NotLF:         ret
                  dw      1011h
  end;

  procedure WriteASCIIZString; assembler;
  asm
                  cmp     Byte Ptr [adOP], opCON
                  jz      @Ok
                  ret
  @Ok:            push    ax
  @Repeat:        lodsb
                  or      al, al
                  jz      @End
                  call    Word Ptr [adWriteChar]
                  jmp     @Repeat
  @End:           pop     ax
                  ret
                  dw      1011h
  end;

  procedure CRTWriteChar; assembler;
  asm
                  cmp     Byte Ptr [adOP], opCON
                  jz      @Ok
                  call    Word Ptr [adHandleOutput]
                  ret
  @Ok:            push    ax
                  push    bx
                  push    cx
                  push    dx
                  push    di
                  push    bp
                  push    ax
                  mov     ah, 3
                  mov     bh, [adActivePage]
                  int     10h
                  pop     ax
                  cmp     al, 9
                  jz      @Tab
                  cmp     al, 8
                  jz      @BS
                  cmp     al, 7
                  jnz     @NotBeep
                  mov     ax, 0E07h
                  int     10h
                  jmp     @Done
  @NotBeep:       call    @WriteChar
  @Done:          mov     ah, 2
                  mov     bh, [adActivePage]
                  int     10h
                  call    Word Ptr [adBreak]
                  pop     bp
                  pop     di
                  pop     dx
                  pop     cx
                  pop     bx
                  pop     ax
                  ret

  @BS:            or      dl, dl
                  jz      @Done
                  dec     dl
                  jmp     @Done

  @Tab:           mov     al, ' '
                  call    @WriteChar
                  test    dl, 7
                  jnz     @Tab
                  jmp     @Done

  @WriteChar:     cmp     al, 0Ah
                  jz      @LF
                  cmp     al, 0Dh
                  jnz     @NotCr
                  mov     dl, 0
                  ret
  @NotCr:         push    ax
                  push    dx
                  mov     ax, [adScreenWidth]
                  inc     ax
                  mul     dh
                  mov     dh, 0
                  add     ax, dx
                  shl     ax, 1
                  mov     di, ax
                  pop     dx
                  pop     ax
                  mov     ah, [adTextAttribute]
                  push    es
                  mov     es, [adScreenBuffer]
                  stosw
                  pop     es
                  cmp     dl, [adScreenWidth]
                  jz      @NewLine
                  inc     dl
                  ret

  @NewLine:       mov     dl, 0
  @LF:            cmp     dh, [adScreenHeight]
                  jnb     @Scroll
                  inc     dh
                  jmp     @CheckLine
  @Scroll:        push    ax
                  push    bx
                  push    cx
                  push    dx
                  mov     ax, 601h
                  mov     bh, [adTextAttribute]
                  xor     cx, cx
                  mov     dl, [adScreenWidth]
                  mov     dh, [adScreenHeight]
                  int     10h
                  pop     dx
                  pop     cx
                  pop     bx
                  pop     ax
  @CheckLine:     push    ax
                  push    bx
                  mov     ah, 2
                  mov     bh, [adActivePage]
                  int     10h
                  call    Word Ptr [adMoreProc]
                  pop     bx
                  pop     ax
                  ret
                  dw      1011h
  end;

  procedure CRTWriteString; assembler;
  asm
                  cmp     Byte Ptr [adOP], opCON
                  jz      @Ok
                  push    ax
                  lodsb
                  or      al, al
                  jz      @OPDone
                  call    Word Ptr [adHandleOutput]
  @OPDone:        pop     ax
                  ret
  @Ok:            push    di
                  push    bp
                  push    ax
                  push    bx
                  push    cx
                  push    dx
                  mov     ah, 3
                  mov     bh, [adActivePage]
                  int     10h
  @Next:          lodsb
                  or      al, al
                  jz      @StringDone
                  cmp     al, 9
                  jz      @Tab
                  cmp     al, 8
                  jz      @BS
                  cmp     al, 7
                  jnz     @NotBeep
                  mov     ax, 0E07h
                  int     10h
                  jmp     @Next
  @NotBeep:       call    @WriteChar
                  jmp     @Next

  @BS:            or      dl, dl
                  jz      @Next
                  dec     dl
                  jmp     @Next

  @StringDone:    mov     ah, 2
                  mov     bh, [adActivePage]
                  int     10h
                  call    Word Ptr [adBreak]
                  pop     dx
                  pop     cx
                  pop     bx
                  pop     ax
                  pop     bp
                  pop     di
                  ret

  @Tab:           mov     al, ' '
                  call    @WriteChar
                  test    dl, 7
                  jnz     @Tab
                  jmp     @Next

  @WriteChar:     cmp     al, 0Ah
                  jz      @LF
                  cmp     al, 0Dh
                  jnz     @NotCr
                  mov     dl, 0
                  ret
  @NotCr:         push    ax
                  push    dx
                  mov     ax, [adScreenWidth]
                  inc     ax
                  mul     dh
                  mov     dh, 0
                  add     ax, dx
                  shl     ax, 1
                  mov     di, ax
                  pop     dx
                  pop     ax
                  mov     ah, [adTextAttribute]
                  push    es
                  mov     es, [adScreenBuffer]
                  stosw
                  pop     es
                  cmp     dl, [adScreenWidth]
                  jz      @NewLine
                  inc     dl
                  ret

  @NewLine:       mov     dl, 0
  @LF:            cmp     dh, [adScreenHeight]
                  jnb     @Scroll
                  inc     dh
                  jmp     @CheckLine
  @Scroll:        push    ax
                  push    bx
                  push    cx
                  push    dx
                  mov     ax, 601h
                  mov     bh, [adTextAttribute]
                  xor     cx, cx
                  mov     dl, [adScreenWidth]
                  mov     dh, [adScreenHeight]
                  int     10h
                  pop     dx
                  pop     cx
                  pop     bx
                  pop     ax
  @CheckLine:     push    ax
                  push    bx
                  mov     ah, 2
                  mov     bh, [adActivePage]
                  int     10h
                  call    Word Ptr [adMoreProc]
                  pop     bx
                  pop     ax
                  ret
                  dw      1011h
  end;


  procedure DOSReadKey; assembler;
  asm
                  push    dx
                  mov     ah, 8
                  int     21h
                  or      al, al
                  jnz     @1
                  push    ax
                  mov     ah, 8
                  int     21h
                  mov     dh, al
                  pop     ax
                  mov     ah, dh
  @1:             pop     dx
                  ret
                  dw      1011h
  end;

  procedure BIOSReadKey; assembler;
  asm
                  call    Word Ptr [adBreak]
                  mov     al, 0
                  int     16h
                  ret
                  dw      1011h
  end;

  procedure Shift; assembler;
  asm
                  mov     cl, [adNumParameters]
                  mov     ch, 0
                  jcxz    @End
                  mov     si, adParameters + 1
                  mov     di, adParameters
                  cld
                  rep     movsb
                  dec     Byte Ptr [adNumParameters]
  @End:           ret
                  dw      1011h
  end;

  procedure ClearScreen; assembler;
  asm
                  call    Word Ptr [adBreak]
                  mov     ax, 0600h
                  mov     bh, [adTextAttribute]
                  mov     cx, [adWindMin]
                  mov     dx, [adWindMax]
                  int     10h
                  mov     dx, [adWindMin]
                  mov     ah, 2
                  mov     bh, [adActivePage]
                  int     10h
                  ret
                  dw      1011h
  end;

  procedure ShowBreak; assembler;
  asm
                  call    @Start
                  db      'BREAK is ', 0
  @Start:         pop     si
                  mov     bx, [adWriteASCIIZString]
                  call    bx
                  mov     ax, 3300h
                  int     21h
                  shl     dl, 1
                  shl     dl, 1
                  call    @WriteOnOff
                  db      'off', 0
                  db      'on', 0
  @WriteOnOff:    pop     si
                  mov     dh, 0
                  add     si, dx
                  call    bx
                  mov     si, adCRLF
                  call    bx
                  ret
                  dw      1011h
  end;

  procedure SetBreak; assembler;
  asm
                  mov     ax, 3301h
                  int     21h
                  ret
                  dw      1011h
  end;

  procedure ShowVerify; assembler;
  asm
                  call    @Start
                  db      'VERIFY is ', 0
  @Start:         pop     si
                  mov     bx, [adWriteASCIIZString]
                  call    bx
                  mov     ah, 54h
                  int     21h
                  shl     al, 1
                  shl     al, 1
                  call    @WriteOnOff
                  db      'off', 0
                  db      'on', 0
  @WriteOnOff:    pop     si
                  mov     ah, 0
                  add     si, ax
                  call    bx
                  mov     si, adCRLF
                  call    bx
                  ret
                  dw      1011h
  end;

  procedure SetVerify; assembler;
  asm
                  mov     ah, 2eh
                  mov     al, dl
                  mov     dh, 0
                  int     21h
                  ret
                  dw      1011h
  end;

  procedure ChangeDir; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
                  mov     [adReturnAddr], sp
                  mov     si, dx
                  cld
  @GetChar:       lodsb
                  or      al, al
                  jz      @ShowDir
                  mov     dl, al
                  and     dl, 0dfh
                  lodsb
                  cmp     al, ':'
                  jz      @ShowDirDrive
  @SetDir:        mov     dx, [adDraft2]
                  mov     ah, 3bh
                  int     21h
                  jnc     @DirOk
                  call    di
  @DirOk:         ret
  @ShowDirDrive:  lodsb
                  or      al, al
                  jnz     @SetDir
                  mov     al, dl
                  sub     al, '@'
                  jmp     @DriveKnown
  @ShowDir:       mov     ah, 19h
                  int     21h
                  inc     al
  @DriveKnown:    mov     dl, al
                  push    ax
                  mov     si, [adDraft]
                  push    si
                  mov     ah, 47h
                  int     21h
                  jnc     @NoError
                  call    di
                  mov     sp, [adReturnAddr]
                  ret
  @NoError:       pop     si
                  pop     ax
                  add     al, '@'
                  call    bx
                  mov     al, ':'
                  call    bx
                  mov     al, '\'
                  call    bx
                  call    bp
                  mov     si, adCRLF
                  call    bp
                  ret
                  dw      1011h
  end;

  procedure SetDosVar; assembler;
  asm
                  mov     bx, ax
                  mov     si, bx
                  cmp     Byte Ptr [si], 0
                  jnz     @SetVar

  @ShowEnv:       mov     si, [adEnviron]
                  mov     bx, [adWriteASCIIZString]
  @ShowStr:       cmp     Byte Ptr [si], 0
                  jz      @ShowDone
                  call    bx
                  push    si
                  mov     si, adCRLF
                  call    bx
                  pop     si
                  jmp     @ShowStr
  @ShowDone:      ret

  @SetVar:        mov     di, si
                  mov     cx, 0FFFFh
                  xor     al, al
                  cld
                  repnz   scasb
                  mov     al, '='
                  dec     di
                  stosb
                  sub     di, si
                  mov     cx, di
                  mov     di, [adEnviron]
  @Search:        cmp     Byte Ptr [di], 0
                  jz      @NotFound
                  push    cx
                  push    si
                  push    di
                  rep     cmpsb
                  pop     di
                  pop     si
                  pop     cx
                  jz      @VarFound
                  mov     al, 0
                  push    cx
                  mov     cx, 0FFFFh
                  repnz   scasb
                  pop     cx
                  jmp     @Search
  @VarFound:      push    cx
                  mov     si, di
                  mov     al, 0
                  mov     cx, 0FFFFh
                  repnz   scasb
                  xchg    si, di
                  push    si
                  xor     cx, cx
                  dec     si
  @CountLen:      lodsw
                  dec     si
                  inc     cx
                  or      ax, ax
                  jnz     @CountLen
                  pop     si
                  rep     movsb
                  pop     cx
                  dec     di
  @NotFound:      mov     si, bx
                  push    di
                  mov     di, si
                  add     di, cx
                  mov     Byte Ptr [di - 1], 0
                  pop     di
                  mov     bp, dx
                  cmp     Byte Ptr [bp], 0
                  jz      @EndVar
                  dec     cx
                  rep     movsb
                  mov     al, '='
                  stosb
                  mov     si, dx
  @CopyValue:     lodsb
                  stosb
                  or      al, al
                  jnz     @CopyValue
  @EndVar:        mov     al, 0
                  stosb
  @End:           call    Word Ptr [adBreak]
                  ret
                  dw      1011h
  end;

  procedure CopyParams; assembler;
  asm
                  push    ax
                  push    cx
                  mov     si, dx
                  cld
                  mov     di, [adDraft2]
  @CopyChar:      lodsb
                  or      al, al
                  jz      @Done
                  cmp     al, '%'
                  jz      @InsertVar
  @JustSign:      stosb
                  jmp     @CopyChar;

  @NVariable:     cmp     Word Ptr [adFormatStr], 0000
                  jz      @JustSign
                  lodsw
                  mov     cx, di
                  call    @GetRow
                  dw      0000, 0000, 0000
  @GetRow:        pop     di
                  stosw
                  lodsw
                  push    si
                  mov     si, ax
                  lodsw
                  stosw
                  lodsw
                  cmp     ax, 07FFFh
                  jna     @Positive
                  neg     Word Ptr [di - 2]
                  not     ax
                  push    si
                  mov     si, cx
                  mov     Byte Ptr [si], '-'
                  inc     cx
                  pop     si
  @Positive:      stosw
                  sub     di, 6
                  call    @GetProc

                  dw      0000
                  call    @GetRelAddr
  @GetRelAddr:    pop     bx
                  mov     di, [bx - 5]
                  stosb
                  mov     [bx - 5], di
                  ret

  @GetProc:       pop     bx
                  mov     [bx], cx
                  add     bx, 2
                  mov     si, di
                  call    Word Ptr [adFormatStr]
                  mov     di, [bx - 2]
                  pop     si
                  jmp     @CopyChar

  @InsertVar:     lodsb
                  mov     bx, si
                  cmp     al, 0Dh
                  jz      @NVariable
                  cmp     al, '%'
                  jz      @JustSign
                  cmp     al, '1'
                  jb      @NotParam
                  cmp     al, '9'
                  ja      @NotParam
                  sub     al, '0'
                  cmp     al, [adNumParameters]
                  ja      @GoBack
                  mov     si, adParameters
                  mov     ah, 0
                  dec     al
                  add     si, ax
                  lodsb
                  mov     ah, 0
                  mov     si, ax
                  jmp     @HaveAddress
  @NotParam:      dec     si
                  mov     bx, si
                  xor     cx, cx
                  push    di
                  mov     di, [adDraft]
  @FindLastPerc:  lodsb
                  inc     cx
                  cmp     al, 'a'
                  jb      @NotUpcase
                  cmp     al, 'z'
                  ja      @NotUpcase
                  sub     al, ' '
  @NotUpCase:     stosb
                  or      al, al
                  jz      @EmptyVar
                  cmp     al, '%'
                  jnz     @FindLastPerc
                  mov     al, '='
                  mov     bx, si
                  dec     di
                  stosb
                  mov     si, [adEnviron]
                  mov     di, [adDraft]
                  dec     si
                  mov     Byte Ptr [si], 0
  @FindEnvVar:    lodsw
                  dec     si
                  or      ax, ax
                  jz      @EmptyVar
                  push    cx
                  push    di
                  push    si
                  repz    cmpsb
                  pop     si
                  pop     di
                  pop     cx
                  jnz     @FindEnvVar
                  cmp     Byte Ptr [si - 1], 0
                  jnz     @FindEnvVar
                  pop     di
                  add     si, cx
                  jmp     @HaveAddress
  @EmptyVar:      pop     di
                  mov     si, bx
                  jmp     @GoBack
  @HaveAddress:   lodsb
                  stosb
                  or      al, al
                  jnz     @HaveAddress
                  dec     di
                  mov     si, bx
  @GoBack:        jmp     @CopyChar
  @Done:          stosb
                  call    Word Ptr [adBreak]
                  mov     bp, [adWriteASCIIZString]
                  mov     bx, [adWriteChar]
                  mov     di, [adErrorProc]
                  mov     dx, [adDraft2]
                  pop     cx
                  pop     ax
                  ret
                  dw      1011h
  end;

  procedure Prefix; assembler;
  asm
                  call    Word Ptr [adBreak]
                  mov     bp, [adWriteASCIIZString]
                  mov     bx, [adWriteChar]
                  mov     di, [adErrorProc]
                  ret
                  dw      1011h
  end;

  procedure ReadVal; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
                  mov     si, dx
                  xor     cx, cx
  @FindStart:     lodsb
                  cmp     al, ' '
                  jz      @FindStart
                  cmp     al, '+'
                  jz      @FindStart
                  cmp     al, '-'
                  jnz     @Pos
                  inc     cx
                  jmp     @FindStart
  @Pos:           push    cx
                  dec     si
                  mov     bx, 10
                  cmp     al, '$'
                  jnz     @NotHex
                  mov     bx, 16
                  inc     si
                  inc     Byte Ptr [adEL]
  @NotHex:        xor     ax, ax
                  xor     dx, dx
  @Char:          mov     cl, [si]
                  inc     si
                  inc     Byte Ptr [adEL]
                  or      cl, cl
                  jz      @EndOfLine
                  cmp     cl, ' '
                  jz      @End
                  cmp     cl, '0'
                  jb      @Error
                  cmp     bl, 10
                  jz      @DecMax
                  cmp     cl, '9'
                  jbe     @NotTooHigh
                  or      cl, 20h
                  sub     cl, 39
                  cmp     cl, 'a' - 39
                  jb      @Error
                  cmp     cl, 'f' - 39
                  ja      @Error
                  jmp     @NotTooHigh
  @DecMax:        cmp     cl, '9'
                  ja      @Error
  @NotTooHigh:    sub     cl, '0'
                  mov     ch, 0
                  mov     di, dx
                  mul     bx
                  push    ax
                  mov     ax, di
                  mov     di, dx
                  mul     bx
                  mov     dx, ax
                  add     dx, di
                  pop     ax
                  add     ax, cx
                  jnc     @Char
                  inc     dx
                  jmp     @Char
  @EndOfLine:     cmp     Byte Ptr [adEL], 1
                  ja      @End
  @Error:         pop     cx
                  jcxz    @ErNotNeg
                  neg     ax
                  not     dx
  @ErNotNeg:      stc
                  ret
  @End:           mov     Byte Ptr [adEL], 0
                  pop     cx
                  jcxz    @NotNeg
                  neg     ax
                  not     dx
  @NotNeg:        clc
                  ret
                  dw      1011h
  end;

  procedure Dir; assembler;
  asm
                  mov     Word Ptr [adEL], 0
                  push    Word Ptr [adFileAttr]
                  mov     Word Ptr [adReturnAddr], sp
                  mov     Word Ptr [adFileAttr], Archive + Directory + ReadOnly
                  mov     si, ax
                  push    bx
                  push    bp
                  push    dx
                  call    si      { Volume }
                  pop     dx
                  pop     bp
                  pop     bx
                  mov     si, dx
                  push    si
                  pop     di
                  xor     cx, cx
  @GetOptions:    lodsb
                  cmp     al, '/'
                  jnz     @NotOption
                  lodsb
                  or      al, ' '
                  cmp     al, 'w'
                  jnz     @NotWrap
                  inc     cl
                  jmp     @GetOptions
  @NotWrap:       cmp     al, 'p'
                  jnz     @GetOptions
                  inc     ch
                  jmp     @GetOptions
  @NotOption:     stosb
                  or      al, al
                  jnz     @GetOptions
                  mov     [0100h], cx
                  mov     di, [adDraft]
                  mov     si, dx
                  push    si
  @FindEnd:       lodsb
                  or      al, al
                  jnz     @FindEnd
                  dec     si
                  mov     cx, si
                  pop     si
                  lodsw
                  cmp     si, cx
                  ja      @NotDrive
                  cmp     ah, ':'
                  jnz     @NotDrive
                  cmp     al, 'a'
                  jb      @DriveKnown
                  cmp     al, 'z'
                  ja      @DriveKnown
                  sub     al, ' '
                  jmp     @DriveKnown
  @NotDrive:      sub     si, 2
                  mov     ah, 19h
                  int     21h
                  add     al, 'A'
                  mov     ah, ':'
  @DriveKnown:    stosw
                  cmp     si, cx
                  jz      @FillGap
                  cmp     Byte Ptr [si], '\'
                  jz      @Root
  @FillGap:       sub     al, '@'
                  mov     dl, al
                  mov     al, '\'
                  stosb
                  push    si
                  mov     ah, 47h
                  mov     si, di
                  int     21h
                  pop     si
                  jc      @Root
                  cmp     Byte Ptr [di], 0
                  jz      @Root
                  push    cx
                  xor     cx, cx
                  dec     cx
                  mov     al, 0
                  repnz   scasb
                  dec     di
                  mov     al, '\'
                  stosb
                  pop     cx
  @Root:          sub     cx, si
                  repz    movsb
                  mov     al, 0
                  stosb
                  mov     si, [adDraft]
                  inc     si
                  mov     di, si
  @Copy:          lodsb
                  or      al, al
                  jz      @1
                  cmp     al, '\'
                  jz      @1
                  cmp     al, 'a'
                  jb      @UpCase
                  cmp     al, 'z'
                  ja      @UpCase
                  sub     al, ' '
  @UpCase:        stosb
                  jmp     @Copy
  @1:             cmp     Word Ptr [di-2], 2E5Ch  { \. }
                  jnz     @2
                  dec     di
                  dec     di
                  jmp     @4
  @2:             cmp     Word Ptr [di-2], 2E2Eh  { .. }
                  jnz     @4
                  cmp     Byte Ptr [di-3], '\'
                  jnz     @4
                  sub     di, 3
                  cmp     Byte Ptr [di-1], ':'
                  jz      @4
  @3:             dec     di
                  cmp     Byte Ptr [di], '\'
                  jnz     @3
  @4:             or      al, al
                  jnz     @UpCase
                  cmp     Byte Ptr [di-1], ':'
                  jnz     @NotOnlyDrive
                  mov     al, '\'
                  stosb
                  jmp     @DirOnly
  @NotOnlyDrive:  cmp     Byte Ptr [di-1], '\'
                  jz      @DirOnly
                  mov     al, 0
                  stosb
                  xor     cx, cx
  @FindLast:      dec     di
                  mov     al, [di]
                  cmp     al, '?'
                  jnz     @NotQu
                  inc     cl
  @NotQu:         cmp     al, '*'
                  jnz     @NotAsterisk
                  inc     cl
  @NotAsterisk:   cmp     al, '.'
                  jnz     @NotDot
                  inc     ch
  @NotDot:        cmp     al, '\'
                  jnz     @FindLast
                  jcxz    @NoFileName
                  mov     si, di
                  inc     si
                  lodsb
                  cmp     al, '.'
                  jnz     @NotInsert
                  mov     al, '*'
                  dec     si
  @Insert:        mov     ah, al
                  lodsb
                  mov     [si - 1], ah
                  or      ah, ah
                  jnz     @Insert
                  inc     cx
  @NotInsert:     jmp     @JustFile
  @NoFileName:    mov     si, [adDraft]
  @SearchEnd:     lodsb
                  or      al, al
                  jnz     @SearchEnd
                  cmp     Byte Ptr [si-2], '\'
                  jnz     @PathNameOk
                  mov     Byte Ptr [si-2], 0
                  cmp     Byte Ptr [si-3], ':'
                  jz      @NoError
  @PathNameOk:    mov     ah, 4Eh
                  mov     cx, 10h
                  mov     dx, [adDraft]
                  int     21h
                  jnc     @NoError
                  cmp     ax, 12h
                  jz      @JustFile
                  cmp     ax, 2
                  jz      @JustFile
                  cmp     ax, 3
                  jz      @JustFile
                  call    Word Ptr [adErrorProc]
                  mov     sp, [adReturnAddr]
                  pop     Word Ptr [adFileAttr]
                  ret
  @NoError:       mov     si, [adDTA]
                  cmp     Byte Ptr [si + 21], 10h
                  jnz     @JustFile
                  mov     si, [adDraft]
  @FindEndOfDir:  lodsb
                  or      al, al
                  jnz     @FindEndOfDir
                  mov     di, si
                  dec     di
                  mov     al, '\'
                  stosb
                  jmp     @DirOnly
  @JustFile:      mov     si, [adDraft]
  @FindEndFile:   lodsb
                  or      al, al
                  jnz     @FindEndFile
                  mov     di, si
                  dec     di
                  or      ch, ch
                  jnz     @CompleteName
                  mov     al, '.'
                  stosb
                  jmp     @AddAst
  @DirOnly:       mov     ax, 2E2Ah  { '*.*', 0 }
                  stosw
  @AddAst:        mov     ax, 002Ah
                  stosw
  @CompleteName:  call    @GetText
                  db      ' Directory of  ', 0
  @GetText:       pop     si
                  call    bp
                  mov     si, [adDraft]
                  push    si
  @FindDirNameEnd:lodsb
                  or      al, al
                  jnz     @FindDirNameEnd
  @FindLastSlash: dec     si
                  cmp     Byte Ptr [si], '\'
                  jnz     @FindLastSlash
                  cmp     Byte Ptr [si - 1], ':'
                  jnz     @5
                  inc     si
  @5:             mov     dl, Byte Ptr [si]
                  mov     Byte Ptr [si], 0
                  mov     di, si
                  pop     si
                  push    si
                  call    bp
                  mov     al, dl
                  stosb
                  pop     si
                  lodsb
                  mov     dl, al
                  sub     dl, '@'
                  mov     si, adCrLf
                  push    si
                  call    bp
                  pop     si
                  call    bp
                  call    @GetProc

  @ShowFile:      push    cx
                  mov     di, cx
                  mov     si, dx
                  mov     bx, [adWriteChar]
                  mov     ah, 0
  @CheckDot:      lodsb
                  dec     si
                  cmp     al, '.'
                  jnz     @WriteName
                  inc     si
                  push    ax
                  call    bx
                  pop     ax
                  inc     ah
                  jmp     @CheckDot
  @WriteName:     lodsb
                  dec     si
                  or      al, al
                  jz      @NameDone
                  inc     si
                  cmp     al, '.'
                  jz      @NameDone
                  push    ax
                  call    bx
                  pop     ax
                  inc     ah
                  jmp     @WriteName
  @NameDone:      mov     cx, 9
                  sub     cl, ah
  @Tab:           mov     al, ' '
                  call    bx
                  loop    @Tab
                  mov     cl, 3
  @WriteExt:      lodsb
                  or      al, al
                  jnz     @ExtChar
                  mov     al, ' '
                  dec     si
  @ExtChar:       call    bx
                  loop    @WriteExt
                  cmp     Byte Ptr [100h], 0
                  jz      @ShowAll
                  mov     ax, di
                  inc     ax
                  mov     cl, 5
                  div     cl
                  or      ah, ah
                  jz      @NewLine
                  mov     al, 9
                  call    bx
                  jmp     @EndShow
  @ShowAll:       sub     dx, 30
                  mov     si, dx
                  mov     al, [si + 21]
                  and     al, Directory
                  jz      @NotDir
                  push    si
                  call    @GetDIRStr
                  db      ' <DIR>   ', 0
  @GetDIRStr:     pop     si
                  call    bp
                  pop     si
                  jmp     @ShowTime
  @NotDir:        call    @GetSizeStr
                  db      '%9ld',0
  @GetSizeStr:    pop     ax
                  call    @GetRow2
                  dw      0000, 0000, 0000
  @GetRow2:       pop     di
                  push    di
                  stosw
                  mov     ax, [si + 26]
                  stosw
                  mov     ax, [si + 28]
                  stosw
                  mov     dx, si
                  pop     si
                  call    Word Ptr [adFormatStr]
                  mov     si, dx
  @ShowTime:      call    @GetTimeStr
                  db      '  %2d-%02d-%02d  %2d:%02d%c', 0
  @GetTimeStr:    pop     ax
                  call    @GetRow3
                  dw      0000, 0000, 0000, 0000, 0000, 0000, 0000
  @GetRow3:       pop     di
                  push    di
                  stosw
                  mov     ax, [si + 24]
                  push    ax
                  shr     ax, 1
                  xor     ah, ah
                  mov     cl, 4
                  shr     ax, cl
                  stosw
                  pop     ax
                  push    ax
                  and     ax, 001Fh
                  stosw
                  pop     ax
                  mov     cl, 9
                  shr     ax, cl
                  add     ax, 180


                  { bug fix: Y2K }
  @@1:            sub ax, 100
                  cmp ax, 100
                  jnb @@1


                  stosw
                  mov     ax, [si + 22]
                  push    ax
                  mov     cl, 11
                  shr     ax, cl
                  mov     ch, 'a'
                  cmp     ax, 12
                  jna     @am
                  mov     ch, 'p'
                  sub     ax, 12
  @am:            stosw
                  pop     ax
                  mov     cl, 5
                  shl     ax, cl
                  mov     cl, 10
                  shr     ax, cl
                  stosw
                  push    di
                  mov     al, ch
                  mov     ah, 0
                  call    @GetSpace
                  dw      0000
  @GetSpace:      pop     di
                  stosw
                  mov     ax, di
                  sub     ax, 2
                  pop     di
                  stosw
                  pop     si
                  call    Word Ptr [adFormatStr]
  @NewLine:       mov     si, adCRLF
                  call    bp
                  call    Word Ptr [adBreak]
                  mov     dx, [100h]
                  or      dh, dh
                  jz      @EndShow
                  mov     bx, [adScreenHeight]
                  dec     bl
                  pop     ax
                  push    ax
                  inc     ax
                  or      dl, dl
                  jz      @NotWrapPage
                  mov     bh, bl
                  shl     bl, 1
                  shl     bl, 1
                  add     bl, bh
  @NotWrapPage:   div     bl
                  or      ah, ah
                  jnz     @EndShow
  @Pause:         call    @Pause2
                  db      'Strike a key when ready . . .', 0
  @Pause2:        pop     si
                  call    bp
                  call    Word Ptr [adReadKey]
                  mov     si, adCRLF
                  call    bp
  @EndShow:       pop     cx
                  inc     cx
                  ret

  @GetProc:       pop     bx
                  push    dx
                  mov     dx, [adDraft]
                  xor     cx, cx
                  call    Word Ptr [adForAllFilesDo]
                  pop     dx
                  jcxz    @End
                  cmp     Byte Ptr [100h], 0
                  jz      @NoNewLine
                  mov     ax, cx
                  push    cx
                  mov     cl, 5
                  div     cl
                  pop     cx
                  or      ah, ah
                  jz      @NoNewLine
                  mov     si, adCRLF
                  call    bp
  @NoNewLine:     call    @GetEndStr
                  db      '%9d File(s) %9ld bytes free', 0dh, 0ah, 0
  @GetEndStr:     pop     ax
                  call    @GetRow
                  dw      0000, 0000, 0000, 0000
  @GetRow:        pop     di
                  mov     si, di
                  stosw
                  mov     ax, cx
                  stosw
                  mov     ah, 36h
                  int     21h
                  xor     dx, dx
                  mul     bx
                  mul     cx
                  stosw
                  mov     ax, dx
                  stosw
                  mov     bx, [adWriteChar]
                  call    Word Ptr [adFormatStr]
  @End:           call    Word Ptr [adBreak]
                  pop     Word Ptr [adFileAttr]
                  ret
                  dw      1011h
  end;

  procedure ForAllFilesDo; assembler;
  asm
                  push    ax
                  push    cx
                  mov     ah, 4eh
                  mov     cx, [adFileAttr]
                  int     21h
                  pop     cx
                  pop     ax
                  jc      @NoFiles
  @Repeat:        mov     dx, 30
                  add     dx, [adDTA]
                  push    bx
                  call    Word Ptr [adBreak]
                  call    bx
                  pop     bx
                  push    ax
                  mov     ah, 4fh
                  int     21h
                  pop     ax
                  jnc     @Repeat
                  jmp     @End
  @NoFiles:       call    @WrError
                  db      'File not found', 0dh, 0ah, 0
  @WrError:       pop     si
                  call    Word Ptr [adWriteASCIIZString]
                  mov     Byte Ptr [adEL], 2
  @End:           ret
                  dw      1011h
  end;

  procedure DeleteFile; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
                  mov     si, dx
  @GetChar:       lodsb
                  or      al, al
                  jz      @Delete
                  cmp     al, '*'
                  jz      @CheckNext
  @Check:         lodsw
                  or      al, al
                  jz      @Delete
                  dec     si
                  cmp     ax, 2a5ch
                  jnz     @Check
                  lodsb
  @CheckNext:     lodsw
                  cmp     ax, 2a2eh
                  jnz     @Delete
                  call    @GoOn
                  db      'Are you sure (y/n)? ', 0
  @GoOn:          pop     si
                  call    bp
                  call    Word Ptr [adReadKey]
                  or      al, ' '
                  cmp     al, 'y'
                  jnz     @NotSure
                  call    @WriteText
                  db      'Yes', 0dh, 0ah, 0
  @WriteText:     pop     si
                  call    bp
                  jmp     @Delete
  @NotSure:       call    @WriteTextNo
                  db      'No', 0dh, 0ah, 0
  @WriteTextNo:   pop     si
                  call    bp
                  ret
  @Delete:        call    @Run
  @DelProc:       mov     ah, 41h
                  int     21h
                  jnc     @NoError
                  call    Word Ptr [adErrorProc]
  @NoError:       ret
  @Run:           pop     bx
                  call    Word Ptr [adForAllFilesDo]
  @End:           ret
                  dw      1011h
  end;

  procedure MakeDir; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
                  mov     ah, 39h
                  int     21h
                  jnc     @End
                  call    di
  @End:           ret
                  dw      1011h
  end;

  procedure RemoveDir; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
                  mov     ah, 3ah
                  int     21h
                  jnc     @End
                  call    di
  @End:           ret
                  dw      1011h
  end;

  procedure ShowDOSVersion; assembler;
  asm
                  call    @Start
                  db      'MS-DOS Version ', 0
  @Start:         pop     si
                  mov     bx, [adWriteASCIIZString]
                  call    bx
                  mov     al, [adDosVersionPart1]
                  add     al, '0'
                  mov     bp, [adWriteChar]
                  call    bp
                  mov     al, '.'
                  call    bp
                  mov     al, [adDosVersionPart2]
                  mov     ah, 0
                  aam
                  add     ax, 3030h
                  push    ax
                  mov     al, ah
                  call    bp
                  pop     ax
                  call    bp
                  mov     si, adCRLF
                  call    bx
                  ret
                  dw      1011h
  end;

  procedure Volume; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
                  mov     si, dx
                  lodsw
                  or      al, al
                  jz      @Default
                  cmp     ah, ':'
                  jnz     @Default
                  or      al, ' '
                  sub     al, 'a'
                  jmp     @Start
  @Default:       mov     ah, 19h
                  int     21h
  @Start:         add     al, 'A'
                  call    @GoOn
                  db      '?:\*.*', 0
  @GoOn:          pop     di
                  mov     dx, di
                  stosb
                  push    ax
                  mov     cx, $0008  { VolumeID }
                  mov     ah, 4eh
                  int     21h
                  pop     dx
                  pushf
                  call    @WriteText
                  db      0dh, 0ah, ' Volume in drive ? ', 0
  @WriteText:     pop     si
                  mov     [si + 19], dl
                  call    bp
                  popf
                  jc      @NoLabel
                  call    @WrLabel
                  db      'is ', 0
  @WrLabel:       pop     si
                  call    bp
                  mov     si, [adDTA]
                  add     si, 30
  @WrLabelChar:   lodsb
                  or      al, al
                  jz      @EndWrLabel
                  cmp     al, '.'
                  jz      @WrLabelChar
                  call    bx
                  jmp     @WrLabelChar
  @EndWrLabel:    mov     si, adCRLF
                  call    bp
                  jmp     @End
  @NoLabel:       cmp     ax, 12h  { No more files }
                  jz      @NoError
                  call    Word Ptr [adErrorProc]
                  ret
  @NoError:       call    @WrNoLabel
                  db      'has no label', 0dh, 0ah, 0
  @WrNoLabel:     pop     si
                  call    bp
  @End:           ret
                  dw      1011h
  end;

  procedure Pause; assembler;
  asm
                  call    @Start
                  db      'Strike a key when ready . . . ', 0
  @Start:         pop     si
                  mov     bx, [adWriteASCIIZString]
                  call    bx
                  call    Word Ptr [adReadKey]
                  mov     si, adCRLF
                  call    bx
                  ret
                  dw      1011h
  end;

  procedure PauseWithText; assembler;
  asm
                  mov     si, dx
                  call    bp
                  call    Word Ptr [adReadKey]
                  mov     si, adCRLF
                  call    bp
                  ret
                  dw      1011h
  end;

  procedure Echo; assembler;
  asm
                  call    Word Ptr [adBreak]
                  mov     si, dx
                  call    bp
                  mov     si, adCRLF
                  call    bp
                  ret
                  dw      1011h
  end;

  procedure FormatStr; External;
  {$L formatst.obj}

  procedure SetActiveDrive; assembler;
  asm
                  mov     ah, 0eh
                  int     21h
                  ret
                  dw      1011h
  end;

  procedure Beep; assembler;
  asm
                  mov     ax, 0e07h
                  int     10h
                  ret
                  dw      1011h
  end;

  procedure Exist; assembler;
  asm
                  mov     ah, 4eh
                  mov     cx, ReadOnly + Sysfile + Archive;
                  int     21h
                  ret
                  dw      1011h
  end;

  procedure TheSame1; assembler;
  asm
                  cld
                  mov     si, [adEnviron]
  @FindEnd:       lodsw
                  dec     si
                  or      ax, ax
                  jnz     @FindEnd
                  inc     si
                  inc     si
                  mov     di, si
                  mov     bx, si
                  mov     si, dx
                  xor     cx, cx
  @Copy:          lodsb
                  stosb
                  inc     cx
                  or      al, al
                  jnz     @Copy
                  mov     si, bx
  @DelSpaces:     lodsb
                  cmp     al, ' '
                  jnz     @NoMoreSpaces
                  inc     bx
                  dec     cx
                  jmp     @DelSpaces
  @NoMoreSpaces:  dec     di
                  cmp     Byte Ptr [di], ' '
                  jnz     @EndOk
                  mov     Byte Ptr [di], 0
                  dec     cx
                  jmp     @NoMoreSpaces
  @EndOk:         mov     [0100h], bx
                  dec     cx
                  mov     [00FEh], cx
                  ret
                  dw      1011h
  end;

  procedure TheSame2; assembler;
  asm
                  mov     bp, [00FEh]
                  mov     si, dx
  @FindStart:     lodsb
                  cmp     al, ' '
                  jz      @FindStart
                  dec     si
                  push    si
  @FindEnd:       lodsb
                  or      al, al
                  jnz     @FindEnd;
                  dec     si
  @CheckEnd:      dec     si
                  cmp     Byte Ptr [si], ' '
                  jnz     @EndOk
                  mov     Byte Ptr [si], 0
                  jmp     @CheckEnd
  @EndOk:         pop     si
                  push    si
                  xor     cx, cx
  @CountLength:   lodsb
                  inc     cx
                  or      al, al
                  jnz     @CountLength
                  pop     si
                  dec     cx
                  xor     ax, ax
                  mov     di, [0100h]
                  cmp     Byte Ptr [si], '-'
                  jnz     @NotMinus
                  inc     al
  @NotMinus:      cmp     Byte Ptr [di], '-'
                  jnz     @NotMinus2
                  inc     ah
  @NotMinus2:     cmp     ax, 0101h
                  jnz     @NotBothMinus
                  xchg    si, di
  @NotBothMinus:  cmp     ah, al
                  jnz     @Different
                  cmp     cx, bp
                  jnz     @Different
                  repz
                  cmpsb
  @Different:     ret
                  dw      1011h
  end;

  procedure TypeFile; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
                  mov     di, bx
                  mov     ax, 3D00h
                  int     21h
                  jnc     @Ok
  @Error:         call    Word Ptr [adErrorProc]
                  ret
  @Ok:            mov     bx, ax
  @TypeChar:      mov     ah, 3Fh
                  mov     cx, 0001
                  mov     dx, 0100h
                  int     21h
                  jc      @Error
                  or      ax, ax
                  jz      @Eof
                  mov     al, [0100h]
                  cmp     al, 0ah
                  jnz     @NotCheck
                  call    Word Ptr [adBreak]
  @NotCheck:      cmp     al, 26
                  jz      @Eof
                  call    di
                  jmp     @TypeChar
  @Eof:           mov     ah, 3Eh
                  int     21h
                  jc      @Error
                  ret
                  dw      1011h
  end;

  procedure ForInDo; assembler;
  asm
  {
    DS:DX -> wildcard(s)
    CS:AX -> procedure to run
    CX = attr
  }
                  call    Word Ptr [adBreak]

                  push    ax
                  push    es
                  mov     ah, 2Fh
                  int     21h
                  mov     di, es    { get DTA in cx }
                  pop     es
                  pop     ax

                  push    di   { push DTA }

                  push    bx

                  push    ax
                  push    dx
                  mov     ah, 1Ah
                  mov     dx, [adForDTA]   { set DTA }
                  int     21h
                  pop     dx
                  pop     ax

                  call    @GetSETAddr

                  dw      0000
                  dw      0000
                  db      00

  @GetSetAddr:    pop     di

                  mov     bp, [di]
                  mov     si, [di + 2]
                  or      ax, ax
                  jz      @NotFirst
 { @First: }
                  mov     bp, ax
                  stosw
                  push    di
                  mov     si, dx
                  mov     di, [adForDTA]
                  add     di, 80h
                  mov     dx, di
                  cld
  @CopyList:      lodsb
                  stosb
                  or      al, al
                  jnz     @CopyList
                  pop     di
                  mov     ax, dx
                  mov     si, dx
                  stosw
                  mov     al, 00
                  stosb
                  sub     di, 5
  @First:         lodsb
                  or      al, al
                  jz      @AllDone
                  cmp     al, ' '
                  jz      @First
                  dec     si
                  push    di
                  mov     di, [adVersionError]
                  xor     ah, ah
  @Copy:          lodsb
                  stosb
                  or      al, al
                  jz      @CopyDone
                  cmp     al, '?'
                  jnz     @NotQu
                  inc     ah
  @NotQu:         cmp     al, '*'
                  jnz     @NotAst
                  inc     ah
  @NotAst:        cmp     al, ' '
                  jnz     @Copy
  @CopyDone:      dec     si
                  dec     di
                  mov     al, 0
                  stosb
                  pop     di
                  mov     [di + 2], si
                  mov     [di + 4], ah
                  mov     dx, [adVersionError]
                  or      ah, ah
                  jz      @SetVar
                  mov     ah, 4Eh
              {    mov     cx, Archive + Sysfile + ReadOnly }
                  int     21h
                  jc      @First
                  jmp     @Found


  @NotFirst:      cmp     Byte Ptr [di + 4], 0
                  jz      @First
                  mov     ah, 4Fh
                  int     21h
                  jc      @First
  @Found:         mov     dx, [adForDTA]
                  add     dx, 30
  @SetVar:        call    @GetVarName
                  db      26, 0
  @GetVarName:    pop     ax
                  call    @@SetVar26
                   jc @NotFirst
                  clc                    { more files }
                  jmp     @Return

  @AllDone:       call    @GetAddr2
                  db      26, 0
  @GetAddr2:      pop     ax
                  mov     dx, ax
                  inc     dx
                  call    bp
                  stc                    { last file }

  @Return:        pop     dx

                  pop     bx         { pop DTA }
                  pushf
                  mov     ah, 1Ah
                  push    ds
                  mov     ds, bx
                  int     21h
                  pop     ds

                  popf
                  ret

  @@SetVar26:     push    cx
                  push    ax
                  push    si
                  mov     si, dx
                  sub     si, 1eh - 15h
                  mov     ah, [si]
                  mov     si, dx
                  cmp     byte ptr [si], '.'
                  pop     si
                  jz      @@Dot
                  cmp     cx, Directory
                  jnz     @@Ok
                  and     ah, Directory
                  cmp     ah, Directory
                  jnz     @@Dot
  @@Ok:
                  pop     ax
                  call    bp
                  pop     cx
                  clc
                  ret

  @@Dot:          pop     ax
                  pop     cx
                  stc
                  ret

                  dw      1011h
  end;

  procedure Stop; assembler;
  asm
                  mov     ax, 4C00h
                  int     21h
                  ret
                  dw      1011h
  end;

  procedure RenameFile; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
                  mov     si, dx
  @FindStart:     lodsb
                  cmp     al, ' '
                  jz      @FindStart
                  cmp     al, 0
                  jz      @Error
                  dec     si
                  mov     dx, si
  @FindNext:      lodsb
                  cmp     al, ' '
                  jz      @NextFound
                  cmp     al, 0
                  jz      @Error
                  jmp     @FindNext
  @NextFound:     mov     Byte Ptr [si - 1], 0
  @FindNewName:   lodsb
                  cmp     al, ' '
                  jz      @FindNewName
                  cmp     al, 0
                  jz      @Error
                  dec     si
                  mov     di, si
  @CheckName:     lodsb
                  cmp     al, ' '
                  jz      @NameOk
                  or      al, al
                  jz      @NameOk
                  cmp     al, '\'
                  jz      @Error
                  jmp     @CheckName
  @NameOk:        dec     si
                  mov     Byte Ptr [si], 0
                  mov     si, di
                  call    @GetProc

  @RenProc:       mov     bx, dx
                  push    si
                  mov     di, [adDraft]

  @MakeName:      mov     ah, [bx]
                  or      ah, ah
                  jz      @Space
                  cmp     ah, '.'
                  jz      @Space
                  inc     bx
                  jmp     @Valid
  @Space:         mov     ah, ' '
  @Valid:         lodsb
                  cmp     al, '?'
                  jnz     @NotQu
                  mov     al, ah
                  jmp     @GotChar
  @NotQu:         cmp     al, '.'
                  jnz     @NotDot
  @UpDate:        mov     ah, [bx]
                  inc     bx
                  cmp     ah, '.'
                  jz      @GotChar
                  or      ah, ah
                  jnz     @UpDate
                  dec     bx
                  cmp     Byte Ptr [di - 1], ' '
                  jnz     @NotDot
                  dec     di
  @NotDot:        cmp     al, '*'
                  jnz     @GotChar
                  mov     al, ah
                  cmp     al, ' '
                  jz      @GotChar
                  dec     si
  @GotChar:       stosb
                  or      al, al
                  jnz     @MakeName

                  mov     ah, 56h
                  mov     di, [adDraft]
                  int     21h
                  jnc     @NoError
                  call    Word Ptr [adErrorProc]
  @NoError:       pop     si
                  ret

  @GetProc:       pop     bx
                  call    Word Ptr [adForAllFilesDo]
                  ret

  @Error:         call    @GetErrorText
                  db      'Duplicate filename', 0dh, 0ah, 0
  @GetErrorText:  pop     si
                  call    bp
                  ret
                  dw      1011h
  end;

  procedure Command; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
                  call    Word Ptr [adBreak]
                  mov     si, dx
                  lodsw
                  xor     cl, cl
  @CountLen:      lodsb
                  inc     cl
                  or      al, al
                  jnz     @CountLen
                  mov     Word Ptr [si - 1], 000Dh
                  mov     di, dx
                  mov     al, cl
                  stosb
                  mov     al, ' '
                  stosb
                  call    @GetParams

                  dw      0000  { Environment Segment }
                  dw      0000  { CmdLine }
                  dw      0000  { CmdLine Segment }
                  dw      5Ch   { FCB 1 }
                  dw      0000
                  dw      6Ch   { FCB 2 }
                  dw      0000

  @GetParams:     pop     bx
                  mov     ax, [adEnvSeg]
                  mov     [bx], ax
                  mov     [bx + 2], dx
                  mov     ax, ds
                  mov     [bx + 4], ax
                  mov     [bx + 8], ax
                  mov     [bx + 12], ax
                  call    @FindComspec
                  db      'COMSPEC='
  @FindComspec:   pop     si
                  mov     di, [adEnviron]
  @FindVar:       cmp     Byte Ptr [di], 0
                  jz      @NotFound
                  mov     cx, 8
                  push    si
                  push    di
                  cld
                  rep     cmpsb
                  pop     di
                  pop     si
                  jz      @Found
                  mov     al, 0
                  mov     cx, 0FFFFh
                  repnz   scasb
                  jmp     @FindVar

  @Found:         add     di, 8
                  mov     dx, di
                  jmp     @CommandOk

  @NotFound:      call    @GetComspec
                  db      '\COMMAND.COM',0
  @GetComspec:    pop     dx
  @CommandOk:     mov     ax, 4b00h
                  push    ds
                  push    es
                  mov     [0100h], sp
                  int     21h
                  segcs
                  mov     sp, [0100h]
                  mov     bx, cs
                  mov     ss, bx
                  pop     es
                  pop     ds
                  jnc     @NoError
                  call    Word Ptr [adErrorProc]
                  ret
  @NoError:       mov     ah, 4Dh
                  int     21h
                  mov     Byte Ptr [adEL], al
                  ret
                  dw      1011h
  end;

  procedure More; assembler;
  asm
                  cmp     Byte Ptr [adMore], 0
                  jnz     @Ok
  @GoBack:        ret
  @Ok:            push    dx
                  inc     Byte Ptr [adMoreLine]
                  mov     dh, [adScreenHeight]
                  cmp     Byte Ptr [adMoreLine], dh
                  pop     dx
                  jb      @GoBack
                  mov     Byte Ptr [adMoreLine], 0
                  push    dx
                  call    @GetText
                  db      '-- More --$'
  @GetText:       pop     dx
                  push    ax
                  mov     ah, 09
                  int     21h
                  call    Word Ptr [adReadKey]
                  mov     dl, 0dh
                  mov     ah, 2
                  int     21h
                  mov     dl, 0ah
                  mov     ah, 2
                  int     21h
                  pop     ax
                  pop     dx
                  ret
                  dw      1011h
  end;

  procedure RunProg; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
                  push    ax
                  call    Word Ptr [adBreak]
                  mov     si, dx
                  lodsw
                  xor     cl, cl
  @CountLen:      lodsb
                  inc     cl
                  or      al, al
                  jnz     @CountLen
                  mov     Word Ptr [si - 1], 000Dh
                  mov     di, dx
                  mov     al, cl
                  stosb
                  mov     al, ' '
                  stosb
                  call    @GetParams

                  dw      0000  { Environment Segment }
                  dw      0000  { CmdLine }
                  dw      0000  { CmdLine Segment }
                  dw      5Ch   { FCB 1 }
                  dw      0000
                  dw      6Ch   { FCB 2 }
                  dw      0000

  @GetParams:     pop     bx
                  mov     ax, [adEnvSeg]
                  mov     [bx], ax
                  mov     [bx + 2], dx
                  mov     ax, ds
                  mov     [bx + 4], ax
                  mov     [bx + 8], ax
                  mov     [bx + 12], ax
                  pop     dx
                  mov     ax, 4b00h
                  push    ds
                  push    es
                  mov     [0100h], sp
                  int     21h
                  segcs
                  mov     sp, [0100h]
                  mov     bx, cs
                  mov     ss, bx
                  pop     es
                  pop     ds
                  jnc     @NoError
                  call    Word Ptr [adErrorProc]
                  ret
  @NoError:       mov     ah, 4Dh
                  int     21h
                  mov     Byte Ptr [adEL], al
                  ret
                  dw      1011h
  end;

  procedure FrameWindow; assembler;
  asm
                  mov     si, dx
                  mov     dx, [adWindMin]
                  lodsb
                  call    @WriteChar
                  mov     ch, 0
                  mov     cl, [adWindMax]
                  sub     cl, [adWindMin]
                  dec     cl
                  push    cx
                  lodsb
  @WriteLine:     call    @WriteChar
                  loop    @WriteLine
                  lodsb
                  call    @WriteChar
                  mov     dx, [adWindMin]
  @Vertical:      inc     dh
                  cmp     dh, [adWindMax + 1]
                  jnb     @VertDone
                  mov     dl, [adWindMin]
                  push    si
                  lodsb
                  call    @WriteChar
                  lodsb
                  mov     dl, [adWindMax]
                  call    @WriteChar
                  pop     si
                  jmp     @Vertical
  @VertDone:      inc     si
                  inc     si
                  mov     dl, [adWindMin]
                  lodsb
                  call    @WriteChar
                  pop     cx
                  mov     bx, cx
                  lodsb
  @WriteLine2:    call    @WriteChar
                  loop    @WriteLine2
                  lodsb
                  call    @WriteChar
                  lodsb
                  or      al, al
                  jz      @Done
                  xor     cx, cx
                  mov     dx, si
  @CountLength:   lodsb
                  inc     cx
                  or      al, al
                  jnz     @CountLength
                  dec     cx
                  jcxz    @Done
                  cmp     cx, bx
                  ja      @Done
                  sub     bx, cx
                  shr     bx, 1
                  inc     bx
                  mov     si, dx
                  mov     dx, bx
                  add     dx, [adWindMin]
  @WriteTitle:    lodsb
                  or      al, al
                  jz      @Done
                  call    @WriteChar
                  jmp     @WriteTitle
  @Done:          ret

  @WriteChar:     push    ax
                  push    dx
                  mov     ax, [adScreenWidth]
                  inc     ax
                  mul     dh
                  mov     dh, 0
                  add     ax, dx
                  shl     ax, 1
                  mov     di, ax
                  pop     dx
                  pop     ax
                  mov     ah, [adTextAttribute]
                  push    es
                  mov     es, [adScreenBuffer]
                  stosw
                  pop     es
                  inc     dl
                  ret
                  dw      1011h
  end;

  procedure GetDrive; assembler;
  asm
                  push    ax
                  call    @GetDr
                  db      '?:', 0
  @GetDr:         pop     di
                  mov     ah, 19h
                  int     21h
                  mov     dx, di
                  add     al, 'A'
                  stosb
                  pop     ax
                  ret
                  dw      1011h
  end;

  procedure GetDirectory; assembler;
  asm
                  push    ax
                  mov     di, [adDraft]
                  mov     ah, 19h
                  int     21h
                  add     al, 'A'
                  stosb
                  mov     al, ':'
                  stosb
                  mov     al, '\'
                  stosb
                  mov     dl, 0
                  mov     si, di
                  mov     ah, 47h
                  int     21h
                  pop     ax
                  mov     dx, [adDraft]
                  ret
                  dw      1011h
  end;

  procedure GetDate; assembler;
  asm
                  push    ax
                  call    @GetDateStr
                  db      '%2d-%02d-%4d', 0
  @GetDateStr:    pop     ax
                  call    @GetPars
                  dw      0000, 0000, 0000, 0000
  @GetPars:       pop     di
                  mov     si, di
                  stosw
                  mov     ah, 2Ah
                  int     21h
                  mov     al, dh
                  mov     ah, 0
                  stosw
                  mov     al, dl
                  stosw
                  mov     ax, cx
                  stosw
                  call    @GetProc

  @Proc:          push    di
                  mov     di, [0100h]
                  stosb
                  mov     [0100h], di
                  pop     di
                  ret

  @GetProc:       pop     bx
                  mov     di, [adDraft]
                  mov     dx, di
                  mov     [0100h], di
                  call    Word Ptr [adFormatStr]
                  mov     di, [0100h]
                  mov     al, 0
                  stosb
                  pop     ax
                  ret
                  dw      1011h
  end;

  procedure GetTime; assembler;
  asm
                  push    ax
                  call    @GetTimeStr
                  db      '%2d:%02d:%02d.%02d', 0
  @GetTimeStr:    pop     ax
                  call    @GetPars
                  dw      0000, 0000, 0000, 0000, 0000
  @GetPars:       pop     di
                  mov     si, di
                  stosw
                  mov     ah, 2Ch
                  int     21h
                  mov     al, ch
                  mov     ah, 0
                  stosw
                  mov     al, cl
                  stosw
                  mov     al, dh
                  stosw
                  mov     al, dl
                  stosw
                  call    @GetProc

  @Proc:          push    di
                  mov     di, [0100h]
                  stosb
                  mov     [0100h], di
                  pop     di
                  ret

  @GetProc:       pop     bx
                  mov     di, [adDraft]
                  mov     dx, di
                  mov     [0100h], di
                  call    Word Ptr [adFormatStr]
                  mov     di, [0100h]
                  mov     al, 0
                  stosb
                  pop     ax
                  ret
                  dw      1011h
  end;

  procedure GetDay; assembler;
  asm
                  push    ax
                  mov     ah, 2Ah
                  int     21h
                  call    @GetTabel

                  db      7, 14, 21, 29, 39, 48, 55
                  db      'Sunday', 0
                  db      'Monday', 0
                  db      'Tuesday', 0
                  db      'Wednesday', 0
                  db      'Thursday', 0
                  db      'Friday', 0
                  db      'Saturday', 0

  @GetTabel:      pop     bx
                  xlat
                  mov     ah, 0
                  add     bx, ax
                  mov     dx, bx
                  pop     ax
                  ret
                  dw      1011h
  end;

  procedure CheckANSI; assembler;
  asm
                  mov     ah, 8
                  mov     bh, [adActivePage]
                  int     10h
                  push    ax
                  mov     Byte Ptr [adEL], 0
                  mov     ah, 3
                  mov     bh, [adActivePage]
                  int     10h
                  push    dx
                  mov     ah, 2
                  mov     dl, 27
                  int     21h
                  mov     ah, 3
                  mov     bh, [adActivePage]
                  int     10h
                  pop     cx
                  cmp     dx, cx
                  jz      @Installed
                  mov     ah, 2
                  mov     dl, 8
                  int     21h
                  jmp     @GoBack
  @Installed:     inc     Byte Ptr [adEL]
  @GoBack:        pop     ax
                  mov     bl, ah
                  mov     bh, [adActivePage]
                  mov     cx, 1
                  mov     ah, 9
                  int     10h
                  ret
                  dw      1011h
  end;

  procedure GetScreen; assembler;
  asm
                  mov     di, [adPCopyBuffer]
                  xor     si, si
                  mov     cx, 80 * 25
                  cld
                  push    ds
                  mov     ds, [adScreenBuffer]
                  rep
                  movsw
                  pop     ds
                  ret
                  dw      1011h
  end;

  procedure PutScreen; assembler;
  asm
                  mov     si, [adPCopyBuffer]
                  xor     di, di
                  mov     cx, 80 * 25
                  cld
                  push    es
                  mov     es, [adScreenBuffer]
                  rep
                  movsw
                  pop     es
                  ret
                  dw      1011h
  end;

  procedure SwapScreen; assembler;
  asm
                  mov     si, [adPCopyBuffer]
                  xor     di, di
                  mov     cx, 80 * 25
                  cld
                  push    es
                  mov     es, [adScreenBuffer]
  @Char:          mov     ax, es:[di]
                  xchg    ax, [si]
                  inc     si
                  inc     si
                  stosw
                  loop    @Char
                  pop     es
                  ret
                  dw      1011h
  end;

  procedure LoadScreen; assembler;
  asm
                  mov     ax, 3D00h
                  int     21h
                  jc      @Error
                  mov     bx, ax
                  mov     ah, 3Fh
                  mov     cx, 80 * 25 * 2
                  mov     dx, [adPCopyBuffer]
                  or      dx, dx
                  jz      @DontLoad
                  int     21h
                  jc      @Error
  @DontLoad:      mov     ah, 3Eh
                  int     21h
                  jc      @Error
                  ret
  @Error:         call    Word Ptr [adErrorProc]
                  ret
                  dw      1011h
  end;

  procedure SaveScreen; assembler;
  asm
                  mov     ah, 3Ch
                  xor     cx, cx
                  int     21h
                  jc      @Error
                  mov     bx, ax
                  mov     ah, 40h
                  mov     cx, 80 * 25 * 2
                  push    ds
                  mov     ds, [adScreenBuffer]
                  xor     dx, dx
                  int     21h
                  pop     ds
                  jc      @Error
                  mov     ah, 3Eh
                  int     21h
                  jc      @Error
                  ret
  @Error:         call    Word Ptr [adErrorProc]
                  ret
                  dw      1011h
  end;



  procedure Menu; assembler;
  asm
                  push    ax
                  push    cx
                  push    dx
                  mov     ah, 3
                  mov     bh, [adActivePage]
                  int     10h
                  mov     [0100h], cx
                  mov     ah, 1
                  mov     cx, 1F00h
                  int     10h
                  pop     dx
                  pop     cx
                  pop     ax
                  mov     si, dx
                  or      ax, ax
                  jnz     @ColorOk
                  mov     al, [adTextAttribute]
                  or      al, 8
                  or      ah, ah
                  jnz     @ColorOk
                  mov     ah, [adTextAttribute]
                  xor     ah, 77h
  @ColorOk:       mov     bx, ax
  @FindStart:     lodsb
                  cmp     al, '['
                  jz      @Found
                  or      al, al
                  jnz     @FindStart
                  ret
  @Found:         call    @GetMem

                  dw      0000                             { attr }
                  dw      0000                               { si }
                  db      00
                  db      00
                  db      00

  @GetMem:        pop     bp
                  mov     [bp], bx
                  mov     [bp + 2], si
                  or      cl, cl
                  jnz     @CrachAttrOk
                  or      bl, bh
                  mov     cl, bl
  @CrachAttrOk:   mov     [bp + 4], cl
                  mov     bh, 0
                  mov     cl, 0
                  mov     [bp + 6], cl
  @DrawMenu:      mov     si, [bp + 2]
                  mov     dx, [adWindMin]
                  mov     bl, 0
  @DrawLine:      mov     Byte Ptr [bp + 5], 0
                  cmp     bl, bh
                  jz      @Selected
                  mov     ah, [adTextAttribute]
                  mov     ch, [bp]
                  jmp     @WriteItem
  @Selected:      mov     ah, [bp + 1]
                  mov     ch, [bp + 4]
  @WriteItem:     lodsb
                  cmp     al, '~'
                  jnz     @NotTilde
                  not     Byte Ptr [bp + 5]
                  xchg    ah, ch
                  cmp     Byte Ptr [bp + 5], 0
                  jz      @WriteItem
                  or      cl, 20h
                  cmp     cl, [si]
                  jz      @HotKey
                  and     cl, 0DFh
                  cmp     cl, [si]
                  jnz     @WriteItem
  @HotKey:        mov     cl, bl
                  inc     cl
                  jmp     @WriteItem
  @NotTilde:      cmp     al, '/'
                  jz      @EndItem
                  cmp     al, ']'
                  jz      @EndItem
                  call    @WriteChar
                  jmp     @WriteItem
  @EndItem:       push    ax
  @FillUp:        mov     al, ' '
                  cmp     dl, [adWindMax]
                  ja      @Eol
                  call    @WriteChar
                  jmp     @FillUp
  @Eol:           pop     ax
                  cmp     al, ']'
                  jz      @DrawDone
                  inc     bl
                  inc     dh
                  mov     dl, [adWindMin]
                  jmp     @DrawLine
  @DrawDone:      or      cl, cl
                  jz      @ReadKey
                  not     Byte Ptr [bp + 6]
                  dec     cl
                  mov     bh, cl
                  mov     cl, 0
                  jmp     @DrawMenu
  @ReadKey:       cmp     Byte Ptr [bp + 6], 0
                  jnz     @Done
                  call    Word Ptr [adReadKey]
                  or      al, al
                  jz      @Ext
                  cmp     al, 27
                  jz      @Esc
                  cmp     al, 13
                  jz      @Done
                  mov     cl, al
                  jmp     @DrawMenu
  @Esc:           mov     bh, 0FFh

  @Done:          inc     bh
                  mov     [adEL], bh
  @MenuDone:      mov     ah, 1
                  mov     bh, [adActivePage]
                  mov     cx, [0100h]
                  int     10h
                  ret

  @Ext:           cmp     ah, 'G'
                  jz      @kbHome
                  cmp     ah, 'O'
                  jz      @kbEnd
                  cmp     ah, 'K'
                  jz      @kbLeft
                  cmp     ah, 'M'
                  jz      @kbRight
                  cmp     ah, 'H'
                  jz      @Up
                  cmp     ah, 'P'
                  jnz     @ReadKey
  @Down:          inc     bh
                  cmp     bh, bl
                  jna     @DrawMenu
                  jmp     @kbHome
  @Up:            dec     bh
                  cmp     bh, $FF
                  jz      @kbEnd
                  jmp     @DrawMenu
  @kbHome:        mov     bh, 0
                  jmp     @DrawMenu
  @kbEnd:         mov     bh, bl
                  jmp     @DrawMenu
  @kbLeft:        cmp     Byte Ptr [si], '*'
                  jnz     @DrawMenu
                  mov     Byte Ptr [adEL], $FE
                  jmp     @MenuDone
  @kbRight:       cmp     Byte Ptr [si], ';'
                  jnz     @DrawMenu
                  mov     Byte Ptr [adEL], $FF
                  jmp     @MenuDone

  @WriteChar:     push    ax
                  push    dx
                  mov     ax, [adScreenWidth]
                  inc     ax
                  mul     dh
                  mov     dh, 0
                  add     ax, dx
                  shl     ax, 1
                  mov     di, ax
                  pop     dx
                  pop     ax
                  push    es
                  mov     es, [adScreenBuffer]
                  stosw
                  pop     es
                  inc     dl
                  ret
                  dw      1011h
  end;

  procedure InputString; assembler;
  asm
                  push    ax
                  cmp     Byte Ptr [adUseCRT], 0
                  jz      @UseDOS
                  call    Word Ptr [adInputStr]
                  pop     ax
                  ret
  @UseDOS:        mov     di, [adDraft]
                  or      cl, cl
                  jnz     @HaveLength
                  mov     ah, 3
                  mov     bh, [adActivePage]
                  int     10h
                  mov     cl, [adScreenWidth]
                  sub     cl, dl
  @HaveLength:    inc     cl
                  mov     [di], cl
                  mov     dx, di
                  mov     ah, 0Ah
                  int     21h
                  inc     di
                  mov     cl, [di]
                  mov     [adEL], cl
                  mov     dx, di
                  inc     dx
  @FindEnd:       inc     di
                  cmp     Byte Ptr [di], 13
                  jnz     @FindEnd
                  mov     Byte Ptr [di], 0
                  mov     si, adCRLF
                  call    Word Ptr [adWriteASCIIZString]
                  pop     ax
                  ret
                  dw      1011h
  end;

  procedure CRTInputStr; assembler;
  asm
                  push    cx
                  mov     ah, 3
                  mov     bh, [adActivePage]
                  int     10h
                  mov     bp, dx
                  mov     [0100h], cx
                  pop     cx
                  mov     ch, cl
                  mov     cl, 0
                  or      ch, ch
                  jnz     @LengthOk
                  mov     ch, [adWindMax]
                  cmp     dl, ch
                  ja      @Error
                  sub     ch, dl
  @LengthOk:      mov     si, [adDraft]
                  mov     di, si
                  mov     bl, 0FFh
  @Repeat:        mov     Byte Ptr [di], 0
                  call    @ShowString
                  mov     ah, 2
                  mov     bh, [adActivePage]
                  int     10h
                  push    cx
                  or      bl, bl
                  jz      @OverWriteCSR
                  mov     cx, 0B0Ch
                  jmp     @SetCursor
  @OverWriteCSR:  mov     cx, 001Fh
  @SetCursor:     mov     ah, 1
                  int     10h
                  pop     cx
                  call    Word Ptr [adReadKey]
                  cmp     al, 0
                  jz      @Function
                  cmp     al, 8
                  jz      @kbBackSpace
                  cmp     al, 13
                  jz      @Done
                  cmp     al, 27
  {               jz      @Clear }
                  jz      @Esc
                  cmp     al, ' '
                  jb      @Repeat
                  cmp     bl, 0
                  jnz     @Insert
                  cmp     si, di
                  jz      @Insert
                  mov     [si], al
  @GoRight:       mov     ah, 'M'
                  jmp     @Function
  @Insert:        push    si
                  push    di
                  push    cx
                  mov     cx, di
                  sub     cx, si
                  inc     cx
                  mov     si, di
                  inc     di
                  std
                  rep     movsb
                  cld
                  pop     cx
                  pop     di
                  pop     si
                  mov     [si], al
                  push    di
                  push    cx
                  sub     di, [adDraft]
                  mov     cl, ch
                  mov     ch, 0
                  cmp     di, cx
                  pop     cx
                  pop     di
                  jae     @GoRight
                  inc     cl
                  inc     di
                  jmp     @GoRight
  @Clear:         mov     dx, bp
                  mov     si, [adDraft]
                  mov     di, si
                  mov     cl, 0
                  mov     [si], cl
                  jmp     @Repeat
  @kbBackSpace:   cmp     dx, bp
                  jz      @Repeat
                  mov     ah, 'K'
                  call    @DoKey
                  mov     ah, 'S'
  @Function:      call    @DoKey
                  jmp     @Repeat
  @DoKey:         cmp     ah, 'G'
                  jz      @kbHome
                  cmp     ah, 'O'
                  jz      @kbEnd
                  cmp     ah, 'K'
                  jz      @kbLeft
                  cmp     ah, 'M'
                  jz      @kbRight
                  cmp     ah, 'R'
                  jz      @kbIns
                  cmp     ah, 'S'
                  jz      @kbDel
  @GoBack:        ret
  @kbHome:        mov     si, [adDraft]
                  mov     dx, bp
                  ret
  @kbEnd:         mov     si, di
                  mov     ax, bp
                  add     al, cl
                  mov     dx, ax
                  ret
  @kbLeft:        cmp     dx, bp
                  jz      @GoBack
                  dec     dl
                  dec     si
                  ret
  @kbRight:       cmp     si, di
                  jnb     @GoBack
                  inc     dl
                  inc     si
                  ret
  @kbIns:         not     bl
                  ret
  @kbDel:         cmp     si, di
                  jnb     @GoBack
                  push    si
                  push    di
                  push    cx
                  mov     di, si
                  inc     si
                  xchg    ch, cl
                  mov     ch, 0
                  inc     cx
                  cld
                  rep     movsb
                  pop     cx
                  pop     di
                  pop     si
                  dec     cl
                  dec     di
                  ret

  @Esc:           mov     cl, 255
  @Done:          push    cx
                  mov     cx, [0100h]
                  mov     bh, [adActivePage]
                  mov     ah, 1
                  int     10h
                  pop     cx
  @Error:         mov     Byte Ptr [adEL], cl
                  mov     si, adCRLF
                  call    Word Ptr [adWriteASCIIZString]
                  mov     dx, [adDraft]
                  ret

  @ShowString:    push    di
                  push    si
                  push    cx
                  push    dx
                  mov     dx, bp
                  mov     ax, [adScreenWidth]
                  inc     ax
                  mul     dh
                  mov     dh, 0
                  add     ax, dx
                  shl     ax, 1
                  mov     di, ax
                  mov     si, [adDraft]
                  mov     ah, [adTextAttribute]
                  push    es
                  mov     es, [adScreenBuffer]
  @WriteChar:     lodsb
                  or      al, al
                  jz      @StrDone
                  stosw
                  jmp     @WriteChar
  @StrDone:       cmp     cl, ch
                  ja      @FillDone
                  stosw
                  inc     cl
                  jmp     @StrDone
  @FillDone:      pop     es
                  pop     dx
                  pop     cx
                  pop     si
                  pop     di
                  ret
                  dw      1011h
  end;

  procedure FindEnvVar; assembler;
  asm
                  mov     si, dx
                  cmp     Byte Ptr [si], '%'
                  jz      @Param
  @NotParams:     xor     cx, cx
  @CountLength:   mov     bp, si
                  lodsb
                  inc     cx
                  or      al, al
                  jnz     @CountLength
                  mov     Byte Ptr [bp], '='
                  mov     bx, cx
                  mov     si, dx
                  mov     di, [adEnviron]
  @FindVar:       cmp     Byte Ptr [di], 0
                  jz      @NotFound
                  mov     cx, bx
                  push    si
                  push    di
                  cld
                  rep     cmpsb
                  pop     di
                  pop     si
                  jz      @Found
                  mov     al, 0
                  mov     cx, 0FFFFh
                  repnz   scasb
                  jmp     @FindVar
  @Found:         add     di, bx
  @NotFound:      mov     dx, di
                  mov     Byte Ptr [bp], 0
                  ret
  @Param:         mov     ax, [si + 1]
                  or      ah, ah
                  jnz     @NotParams
                  cmp     al, '1'
                  jb      @NotParams
                  cmp     al, '9'
                  ja      @NotParams
                  sub     al, '0'
                  cmp     Byte Ptr [adNumParameters], al
                  jb      @NotParams
                  mov     ah, 0
                  mov     si, adParameters - 1
                  add     si, ax
                  lodsb
                  mov     dx, ax
                  ret
                  dw      1011h
  end;

  procedure UpCaseVar; assembler;
  asm
                  mov     si, dx
  @Char:          lodsb
                  or      al, al
                  jz      @Done
                  cmp     al, 'a'
                  jb      @Char
                  cmp     al, 'z'
                  ja      @Char
                  sub     Byte Ptr [si - 1], ' '
                  jmp     @Char
  @Done:          ret
                  dw      1011h
  end;

  procedure LowCaseVar; assembler;
  asm
                  mov     si, dx
  @Char:          lodsb
                  or      al, al
                  jz      @Done
                  cmp     al, 'A'
                  jb      @Char
                  cmp     al, 'Z'
                  ja      @Char
                  add     Byte Ptr [si - 1], ' '
                  jmp     @Char
  @Done:          ret
                  dw      1011h
  end;

  procedure GetLength; assembler;
  asm
                  mov     si, dx
                  mov     cl, -1
  @Char:          lodsb
                  inc     cl
                  or      al, al
                  jnz     @Char
  @Done:          mov     [adEL], cl
                  ret
                  dw      1011h
  end;

  procedure AskYN; assembler;
  asm
                  mov     Byte Ptr [adEL], 0
  @ReadKey:       call    Word Ptr [adReadKey]
                  or      al, ' '
                  cmp     al, 'n'
                  jz      @No
                  cmp     al, 'y'
                  jnz     @ReadKey
                  inc     Byte Ptr [adEL]
                  call    @GetText
                  db      'Yes', 0Dh, 0Ah, 0
  @No:            call    @GetText
                  db      'No', 0Dh, 0Ah, 0
  @GetText:       pop     si
                  call    bp
                  ret
                  dw      1011h
  end;

  procedure Ask; assembler;
  asm
  @Start:         call    Word Ptr [adReadKey]
                  mov     cl, al
                  mov     Byte Ptr [adEL], 0
                  mov     si, dx
                  cmp     Byte Ptr [si], 0
                  jz      @NoChoice
  @FindChar:      lodsb
                  inc     Byte Ptr [adEL]
                  or      al, al
                  jz      @Start
                  cmp     al, cl
                  jnz     @FindChar
                  call    bx
                  mov     si, adCRLF
                  call    bp
                  ret
  @NoChoice:      mov     [adEL], al
                  ret
                  dw      1011h
  end;

  procedure GetKey; assembler;
  asm
                  call    @GetAddress
                  db      0
  @GetAddress:    pop     di
                  cmp     Byte Ptr [di], 0
                  jnz     @Extended
                  call    Word Ptr [adReadKey]
                  or      al, al
                  jnz     @End
                  mov     Byte Ptr [di], ah
                  jmp     @End
  @Extended:      mov     al, [di]
                  mov     Byte Ptr [di], 0
  @End:           mov     [adEL], al
                  ret
                  dw      1011h
  end;

  procedure CheckErrors; assembler;
  asm
                  mov     [adCheckErrors], dl
                  ret
                  dw      1011h
  end;

  procedure FillWindow; assembler;
  asm
                  mov     si, ax
                  mov     ah, 3
                  mov     bh, [adActivePage]
                  int     10h
                  push    dx
                  mov     dx, [adWindMin]
  @Line:          mov     ah, 2
                  mov     bh, [adActivePage]
                  int     10h
                  mov     ch, 0
                  mov     cl, [adWindMax]
                  sub     cl, [adWindMin]
                  inc     cx
                  mov     ax, si
                  mov     ah, 9
                  mov     bl, [adTextAttribute]
                  int     10h
                  inc     dh
                  cmp     dh, [adWindMax + 1]
                  jbe     @Line
                  pop     dx
                  mov     ah, 2
                  mov     bh, [adActivePage]
                  int     10h
                  ret
                  dw      1011h
  end;

  procedure GetRandom; assembler;
  asm
                  call    @GetAddress
                  dw      0000
                  dw      0000
  @GetAddress:    pop     bp
                  mov     ax, [bp]
                  mov     bx, [bp + 2]
                  add     ax, 152h
                  add     ax, bx
                  xor     bx, 259h
                  shl     ax, 1
                  add     bx, ax
                  shl     ax, 1
                  add     ax, bx
                  xchg    bh, bl
                  mov     [bp + 2], bx
                  mov     [bp], ax
                  mov     [adEL], al
                  ret
                  dw      1011h
  end;


  procedure GetFileCRC; assembler;
    const
      BUF_SIZE = 2 * 80 * 25;
  asm
                  call    @GetBP

                  dw      0
                  dw      0

  @GetBP:         pop     bp
                  xor     ax, ax
                  mov     [bp], ax
                  mov     [bp + 2], ax

                  mov     ax, 3D00h
                  int     21h
                  jc      @Error
  @Found:
                  mov     bx, ax
  @Repeat:
                  mov     ah, 3Fh
                  mov     cx, BUF_SIZE
                  mov     dx, [adPCopyBuffer]
                  or      dx, dx
                  jz      @DontLoad
                  int     21h
                  jc      @Error
                  cmp     ax, BUF_SIZE
                  pushf
                  mov     cx, ax
                  jcxz    @NoBytes
                  mov     si, [adPCopyBuffer]
  @CheckWord:
                  lodsb
                  mov     ah, 0
                  add     [bp], ax
                  xor     [bp + 2], ax
                  rol     word ptr [bp + 2], 1
                  dec     cx
                  jnz     @CheckWord
  @NoBytes:
                  popf
                  jz      @Repeat

  @DontLoad:      mov     ah, 3Eh
                  int     21h
                  jc      @Error
                  mov     bx, word ptr [bp]
                  mov     cx, word ptr [bp + 2]
                  ret
  @Error:         call    Word Ptr [adErrorProc]
                  ret
                  dw      1011h
  end;


  procedure GetFileSize; assembler;
  asm
                  mov     ax, 3D00h
                  int     21h
                  jc      @Error
                  mov     bx, ax
                  xor     cx, cx
                  mov     dx, cx
                  mov     ax, 4202h             { file ptr to eof - 0 }
                  int     21h
                  jc      @Error
                  mov     si, ax
                  mov     di, dx
                  mov     ah, 3Eh
                  int     21h
                  jc      @Error
                  mov     cx, di
                  mov     bx, si
                  ret
  @Error:         call    Word Ptr [adErrorProc]
                  ret
                  dw      1011h
  end;



  procedure Error(Msg: string);
  begin
    if Lin > 0 then
    begin
      WriteLn('Error in line ', Lin);
      WriteLn(CurLine);
    end;
    WriteLn(Msg);
    Halt(1);
  end;

  function UpCaseStr (Str: string): string; Assembler;
  asm
    push    ds
    cld
    lds     si, Str
    les     di, @Result
    lodsb
    stosb
    xor     ah, ah
    xchg    ax, cx
    jcxz    @3
  @1:
    lodsb
    cmp     al, 'a'
    jb      @2
    cmp     al, 'z'
    ja      @2
    sub     al, 20H
  @2:
    stosb
    loop    @1
  @3:
    pop     ds
  end;

  function WordStr(W: Word): string;
  begin
    WordStr := Chr(Lo(W)) + Chr(Hi(W));
  end;

  procedure Replace (Var Str: string; S1, S2: string);
  Var i: Byte;
  begin
    i := Pos (UpCaseStr(S1), UpCaseStr(Str));
    if i > 0 then
    begin
      Delete (Str, i, Length (S1));
      Insert (S2, Str, i);
    end;
  end;

  procedure ReplaceAll (Var Str: string; S1, S2: string);
  begin
    While Pos (UpCaseStr(S1), UpCaseStr(Str)) > 0 do
      Replace (Str, S1, S2);
  end;

  Type
    TProcRec = record
      Proc: Pointer;
      Cmd: string[6];
      Tp: Byte;
      Address: Word;
    end;

  Const
    tpNoParams    = 0;
    tpOnOff       = 1;
    tpDir         = 2;
    tpPrepare     = 3;
    tpText        = 4;
    tpSet         = 5;
    tpVar         = 6;
    tpChangeVar   = 7;

  Const
    prStartProgramCode    =  1;
    prHandleError         =  2;
    prErrorMsg            =  3;
    prDosWriteChar        =  4;
    prBIOSWriteChar       =  5;
    prWriteASCIIZString   =  6;
    prDOSReadKey          =  7;
    prBIOSReadKey         =  8;
    prCRTWriteString      =  9;
    prShift               = 10;
    prClearScreen         = 11;
    prShowBreak           = 12;
    prSetBreak            = 13;
    prShowVerify          = 14;
    prSetVerify           = 15;
    prChangeDir           = 16;
    prCopyParams          = 17;
    prDirectory           = 18;
    prForAllFilesDo       = 19;
    prDelete              = 20;
    prMakeDir             = 21;
    prRemoveDir           = 22;
    prDOSVersion          = 23;
    prVolume              = 24;
    prPause               = 25;
    prPauseWithText       = 26;
    prEcho                = 27;
    prFormatStr           = 28;
    prSetActiveDrive      = 29;
    prBeep                = 30;
    prSetDosVar           = 31;
    prExist               = 32;
    prCompare1            = 33;
    prCompare2            = 34;
    prReadVal             = 35;
    prType                = 36;
    prForInDo             = 37;
    prStop                = 38;
    prRename              = 39;
    prCommand             = 40;
    prCrtWriteChar        = 41;
    prMore                = 42;
    prBreak               = 43;
    prRunProg             = 44;
    prHandleOutput        = 45;
    prFrameWindow         = 46;
    prGetDrive            = 47;
    prGetDir              = 48;
    prGetDate             = 49;
    prGetTime             = 50;
    prGetDay              = 51;
    prCheckANSI           = 52;
    prGetScreen           = 53;
    prPutScreen           = 54;
    prLoadScreen          = 55;
    prSaveScreen          = 56;
    prMenu                = 57;
    prInput               = 58;
    prCRTInput            = 59;
    prFindEnvVar          = 60;
    prUpCaseVar           = 61;
    prLowCaseVar          = 62;
    prGetLength           = 63;
    prAskYN               = 64;
    prAsk                 = 65;
    prGetKey              = 66;
    prCheckErrors         = 67;
    prFillWindow          = 68;
    prGetRandom           = 69;
    prPrefix              = 70;
    prSwapScreen          = 71;
    prGetFileCRC          = 72;
    prGetFileSize         = 73;

  Const
    NumProc = 73;
    WC: Word = prDOSWriteChar;
    WS: Word = prWriteASCIIZString;

  Const
    ProcRec: Array[1..NumProc] of TProcRec = (
      (Proc: @StartProgramCode;  Cmd: ''),
      (Proc: @HandleError;       Cmd: ''),
      (Proc: @ErrorMessages;     Cmd: ''),
      (Proc: @DOSWriteChar;      Cmd: ''),
      (Proc: @BIOSWriteChar;     Cmd: ''),
      (Proc: @WriteASCIIZString; Cmd: ''),
      (Proc: @DOSReadKey;        Cmd: ''),
      (Proc: @BIOSReadKey;       Cmd: ''),
      (Proc: @CRTWriteString;    Cmd: ''),
      (Proc: @Shift;             Cmd: 'SHIFT';    Tp: tpNoParams),
      (Proc: @ClearScreen;       Cmd: 'CLS';      Tp: tpNoParams),
      (Proc: @ShowBreak;         Cmd: 'BREAK';    Tp: tpNoParams),
      (Proc: @SetBreak;          Cmd: 'BREAK';    Tp: tpOnOff),
      (Proc: @ShowVerify;        Cmd: 'VERIFY';   Tp: tpNoParams),
      (Proc: @SetVerify;         Cmd: 'VERIFY';   Tp: tpOnOff),
      (Proc: @ChangeDir;         Cmd: 'CD';       Tp: tpPrepare),
      (Proc: @CopyParams;        Cmd: ''),
      (Proc: @Dir;               Cmd: 'DIR';      Tp: tpDir),
      (Proc: @ForAllFilesDo;     Cmd: ''),
      (Proc: @DeleteFile;        Cmd: 'DEL';      Tp: tpPrepare),
      (Proc: @MakeDir;           Cmd: 'MD';       Tp: tpPrepare),
      (Proc: @RemoveDir;         Cmd: 'RD';       Tp: tpPrepare),
      (Proc: @ShowDOSVersion;    Cmd: 'VER';      Tp: tpNoParams),
      (Proc: @Volume;            Cmd: 'VOL';      Tp: tpPrepare),
      (Proc: @Pause;             Cmd: 'PAUSE';    Tp: tpNoParams),
      (Proc: @PauseWithText;     Cmd: 'PAUSE';    Tp: tpText),
      (Proc: @Echo;              Cmd: 'ECHO';     Tp: tpText),
      (Proc: @FormatStr;         Cmd: ''),
      (Proc: @SetActiveDrive;    Cmd: ''),
      (Proc: @Beep;              Cmd: 'BEEP';     Tp: tpNoParams),
      (Proc: @SetDosVar;         Cmd: 'SET';      Tp: tpSet),
      (Proc: @Exist;             Cmd: ''),
      (Proc: @TheSame1;          Cmd: ''),
      (Proc: @TheSame2;          Cmd: ''),
      (Proc: @ReadVal;           Cmd: ''),
      (Proc: @TypeFile;          Cmd: 'TYPE';     Tp: tpPrepare),
      (Proc: @ForInDo;           Cmd: ''),
      (Proc: @Stop;              Cmd: 'EXIT';     Tp: tpNoParams),
      (Proc: @RenameFile;        Cmd: 'REN';      Tp: tpPrepare),
      (Proc: @Command;           Cmd: ''),
      (Proc: @CrtWriteChar;      Cmd: ''),
      (Proc: @More;              Cmd: ''),
      (Proc: @CheckBreak;        Cmd: ''),
      (Proc: @RunProg;           Cmd: ''),
      (Proc: @HandleOutput;      Cmd: ''),
      (Proc: @FrameWindow;       Cmd: 'frame';    Tp: tpText),
      (Proc: @GetDrive;          Cmd: 'getdr';    Tp: tpVar),
      (Proc: @GetDirectory;      Cmd: 'GETDIR';   Tp: tpVar),
      (Proc: @GetDate;           Cmd: 'getdat';   Tp: tpVar),
      (Proc: @GetTime;           Cmd: 'gettim';   Tp: tpVar),
      (Proc: @GetDay;            Cmd: 'GETDAY';   Tp: tpVar),
      (Proc: @CheckANSI;         Cmd: 'chansi';   Tp: tpNoParams),
      (Proc: @PutScreen;         Cmd: 'putscr';   Tp: tpNoParams),
      (Proc: @GetScreen;         Cmd: 'getscr';   Tp: tpNoParams),
      (Proc: @LoadScreen;        Cmd: 'loadsc';   Tp: tpPrepare),
      (Proc: @SaveScreen;        Cmd: 'savesc';   Tp: tpPrepare),
      (Proc: @Menu;              Cmd: ''),
      (Proc: @InputString;       Cmd: 'INPUT';    Tp: tpVar),
      (Proc: @CRTInputStr;       Cmd: ''),
      (Proc: @FindEnvVar;        Cmd: ''),
      (Proc: @UpCaseVar;         Cmd: 'upcase';   Tp: tpChangeVar),
      (Proc: @LowCaseVar;        Cmd: 'locase';   Tp: tpChangeVar),
      (Proc: @GetLength;         Cmd: 'getlen';   Tp: tpChangeVar),
      (Proc: @AskYN;             Cmd: 'ASKYN';    Tp: tpVar),
      (Proc: @Ask;               Cmd: 'ASK';      Tp: tpVar),
      (Proc: @GetKey;            Cmd: 'GETKEY';   Tp: tpNoParams),
      (Proc: @CheckErrors;       Cmd: 'check';    Tp: tpOnOff),
      (Proc: @FillWindow;        Cmd: 'fill';     Tp: tpNoParams),
      (Proc: @GetRandom;         Cmd: 'random';   Tp: tpNoParams),
      (Proc: @Prefix;            Cmd: ''),
      (Proc: @SwapScreen;        Cmd: 'swpscr';   Tp: tpNoParams),
      (Proc: @GetFileCRC;        Cmd: 'getcrc';   Tp: tpPrepare),
      (Proc: @GetFileSize;       Cmd: 'getsiz';   Tp: tpPrepare)
      );



  procedure CompileProgram;

  Const
    MaxProgSize = $100 + 50000;
    CodePos: Word = $100;
    CodeEnd: Word = $100;
    OutputToNUL: Boolean = False;
    OutputToAUX: Boolean = False;
    OutputToPRN: Boolean = False;
    UseMore: Boolean = False;

  var
    ProgramCode: array[$100..MaxProgSize] of Char;

  procedure DeleteFirst(Var S: string);
  begin
    While (Length(S) > 0) and (S[1] in [' ', #9, '@', ';', '=']) do
      Delete(S, 1, 1);
  end;

  function Power(X, N: Byte): Byte;
  var i, j: Byte;
  begin
    j := X;
    if N = 0 then begin Power := 1; Exit end;
    for i := 1 to N - 1 do
      X := X * j;
    Power := X;
  end;

  procedure AppendProg(S: string);
  var
    i: Byte;
  begin
    if CodePos + Length(S) > MaxProgSize then Error('Program too large');
    for i := 1 to Length(S) do
    begin
      ProgramCode[CodePos] := S[i];
      inc(CodePos);
    end;
  end;

  function ProcLength(ProcNumber: Word): Word;
  var
    P: Pointer;
    Count: Word;
  begin
    P := ProcRec[ProcNumber].Proc;
    asm
          push    ds
          xor     cx, cx
          lds     si, P
          cld
  @1:     lodsb
          inc     cx
          cmp     al, 0c3h
          jnz     @1
          cmp     Word Ptr [si], 1011h
          jnz     @1
          pop     ds
          mov     Count, cx
    end;
    ProcLength := Count;
  end;

  procedure AppendProc(ProcNumber: Word);
  var
    Len: Word;
    P1, P2: Pointer;
  begin
    Len := ProcLength(ProcNumber);
    if CodePos + Len > MaxProgSize then Error('Program too large');
    ProcRec[ProcNumber].Address := CodePos;
    P1 := ProcRec[ProcNumber].Proc;
    P2 := Addr(ProgramCode[CodePos]);
    asm
          mov     cx, Len
          cld
          push    ds
          push    es
          lds     si, P1
          les     di, P2
          rep     movsb
          pop     es
          pop     ds
    end;
    Inc(CodePos, Len);
  end;

  procedure WriteWord(Pos, W: Word);
  begin
    ProgramCode[Pos] := Chr(Lo(W));
    ProgramCode[Pos + 1] := Chr(Hi(W));
  end;

  procedure AppendWord(W: Word);
  begin
    WriteWord(CodePos, W);
    Inc(CodePos, 2);
  end;

  procedure WriteJumpForward(NumBytes: Word);
  begin
    if Numbytes < $80 then
      AppendProg(#$eb + Chr(NumBytes))
    else
    begin
      AppendProg(#$e9);
      AppendWord(NumBytes);
    end;
  end;

  procedure InstallProc(ProcNumber: Word; CallIt: Boolean);
  begin
    if ProcRec[ProcNumber].Address = 0 then
    begin
      WriteJumpForward(ProcLength(ProcNumber));
      AppendProc(ProcNumber);
    end;
    if CallIt then
    begin
      AppendProg(#$E8#0#0);
      WriteWord(CodePos - 2, ProcRec[ProcNumber].Address - CodePos);
        { call ... }
    end;
  end;

  function GetLabelName(S: string): string;
  var
    T: string;
    i: Word;
  begin
    While (S[1] = ' ') and (S[0] > #0) do
      delete(S, 1, 1);
    if S[1] = ':' then Delete(S, 1, 1);
    S := S + ' ';
    T := '';
    i := 1;
    While not (S[i] in [' ', #9, #13]) do
    begin
      T := T + UpCase(S[i]);
      inc(i);
    end;
    GetLabelName := T;
  end;

  function GetLabelCode(S: string): LongInt;
  var
    i: Byte;
    L: LongInt;
  begin
    L := 0;
    for i := 1 to Length(S) do
    begin
      L := L * 32 + Ord(S[i]) - Ord('@');
    end;
    GetLabelCode := L;
  end;

  procedure StoreLabel(S: string);
  begin
    S := GetLabelName(S);
    inc(LabelPos);
    if LabelPos > MaxLabels then Error('Too many labels');
    LabelTp[LabelPos] := Lab;
    Labels[LabelPos] := GetLabelCode(S);
    LabelAddr[LabelPos] := CodePos;
    LabelLine[LabelPos] := Lin;
  end;

  procedure StoreRef(S: string);
  begin
    inc(LabelPos);
    if LabelPos > MaxLabels then Error('Too many labels');
    LabelTp[LabelPos] := Ref;
    Labels[LabelPos] := GetLabelCode(GetLabelName(S));
    LabelAddr[LabelPos] := CodePos;
    LabelLine[LabelPos] := Lin;
  end;

  procedure CompileGoTo;
  begin
    AppendProg(#$FF#$16 + WordStr(adBreak));  { call [...] }
    AppendProg(#$be);  { mov si, ... }
    StoreRef(S);
    AppendProg(#0#0#$ff#$e6);  { jmp si }
  end;

  procedure CompileGoSub;
  begin
    AppendProg(#$FF#$16 + WordStr(adBreak));  { call [...] }
    AppendProg(#$be);  { mov si, ... }
    StoreRef(S);
    AppendProg(#0#0#$ff#$d6);  { call si }
  end;

  procedure SetAllJumps;
  var
    i, j, k: Word;
    Found: Boolean;
  begin
    for i := 1 to LabelPos do
      if LabelTp[i] = Ref then
      begin
        Found := False;
        for j := LabelPos downto 1 do
          if (Labels[j] = Labels[i]) and (LabelTp[j] = Lab) then
          begin
            WriteWord(LabelAddr[i], LabelAddr[j]);
            Found := True;
          end;
        if not Found then
        begin
          Lin := LabelLine[i];
          Close(InputFile);
          Reset(InputFile);
          for k := 1 to Lin do
            ReadLn(InputFile, CurLine);
          Error('Label not found');
        end;
      end;
  end;

  procedure CompileOnOff;
  var
    St: Byte;
  begin
    St := $FF;
    if U = 'OFF' then St := 0;
    if U = 'ON' then St := 1;
    if St = $FF then Error('Must specify ON or OFF');
    AppendProg(#$b2 + Chr(St));  { mov dl, ... }
    InstallProc(PrNum, True);
    CmdDone := True;
  end;

  function TextFrom(S: string): string;
  var
    i, j: Byte;
    T: string;
  begin
    TextFrom := '';
    S := UpCaseStr(S);
    if (S = '') or (S = ' ') then Exit;
    j := 1;
    T := ' ';
    for i := 1 to Length(S) do
    case S[i] of
      ' ', #9: if T[j] <> ' ' then begin T := T + ' '; inc(j); end;
      'A'..'Z','\',':','.','0'..'9','_','@','-','#','$','{','}'..#255,'[',']','=','%', '<', '>', '|':
        begin T := T + S[i]; inc(j); end;
    end;
    if T = '' then Exit;
    if T[1] = ' ' then Delete(T, 1, 1);
    if T[Length(T)] = ' ' then Delete(T, Length(T), 1);
    TextFrom := T;
  end;

  procedure CompileGoToDrive;
  var
    Dr: Byte;
    U: string;
  begin
    U := TextFrom(S);
    if (Length(U) = 2) and (U[2] = ':') then
    begin
      Dr := Ord(U[1]) - (Ord('A'));
      AppendProg(#$b2 + Chr(Dr));  { mov dl, ... }
      InstallProc(PrSetActiveDrive, True);
      CmdDone := True;
    end;
  end;

  procedure ReplaceVars;
  var
    W: Word;
    i: Byte;
  procedure CheckFormat;
  var
    Str: string;
    j: Byte;
    PFound: Boolean;
    NFStr: string;
    NFAddr: Word;
  begin
    repeat
      Str := '%'#13 + WordStr(Vars[W].Address);
      i := Pos(Str, S);
      if i > 0 then
      begin
        i := i + Length(Str);
        PFound := False;
        for j := i to Length(S) do
          if S[j] = '%' then PFound := True;
        if not PFound then Error('Missing '#39'%'#39);
        if S[i] = '%' then Replace(S, Str + '%', '%'#13 +
          WordStr(adNumberFormat) + WordStr(Vars[W].Address))
        else
        begin
          While S[i] in [' ', #9] do
            Delete(S, i, 1);
          if S[i] <> ':' then Error(#39'%'#39' or '#39':'#39' expected');
          Delete(S, i, 1);
          While S[i] in [' ', #9] do
            Delete(S, i, 1);
          NFStr := '%';
          While S[i] in ['0'..'9', '+', '-', 'L', 'l'] do
          begin
            NFStr := NFStr + S[i];
            Delete(S, i, 1);
          end;
          if Pos('L', UpCaseStr(NFStr)) = 0 then NFStr := NFStr + 'L';
          if S[i] = '%' then Insert('d', S, i);
          if not ((UpCase(S[i]) in ['D', 'X', 'B', 'O']) and (S[i + 1] = '%'))
            then Error('Invalid number format');
          NFStr := NFStr + S[i] + #0;
          Delete(S, i, 2);
          WriteJumpForward(Length(NFStr));
          NFAddr := CodePos;
          AppendProg(NFStr);
          Replace(S, Str, '%'#13 + WordStr(NFAddr) + WordStr(Vars[W].Address));
        end;
      end;
    until i = 0;
  end;

  begin
    if Pos('%', S) > 0 then
    for W := 1 to VarPos do
    begin
      ReplaceAll (S, '%' + Vars[W].Name, '%'#13 + WordStr(Vars[W].Address));
      CheckFormat;
    end;
  end;

  procedure ReplaceChars;
  var
    i: Byte;
    N, Code: Integer;
    S2: string;
  begin
    i := 1;
    While i < Length(S) do
      if S[i] = '$' then
      begin
        S2 := '';
        Delete(S, i, 1);
        case UpCase(S[i]) of
          'G': S[i] := '>';
          'L': S[i] := '<';
          'B': S[i] := '|';
          'Q': S[i] := '=';
          'H': S[i] := #8;
          '_': begin Insert(' ', S, i); S[i] := #13; S[i + 1] := #10; inc(i) end;
          'S': S[i] := ' ';
          'E': S[i] := #27;
          '(': begin
                 Delete(S, i, 1);
                 While (S[i] <> ')') and (i <= Length(S)) do
                 begin
                   S2 := S2 + S[i];
                   Delete(S, i, 1);
                 end;
                 if S[i] <> ')' then Error(#39')'#39' Expected');
                 Val(S2, N, Code);
                 if (Code <> 0) or (not(N in [0..255])) then Error('Invalid ASCII number');
                 S[i] := Chr(N);
               end;
          else if S[i] <> '$' then begin Insert(' ', S, i); S[i] := '$'; inc(i) end;
        end;
        inc(i);
      end
      else inc(i);
  end;

  procedure CompileText;
  var
    TextOfs: Word;
    NoCRLF: Boolean;
  begin
    NoCRLF := False;
    if S[Length(S)] = #13 then Delete(S, Length(S), 1);
    if (T = 'ECHO') and (S[Length(S)] = '$') and (S[Length(S) - 1] <> '$')
      then begin NoCRLF := True; Delete(S, Length(S), 1) end;
    if T = 'frame' then
    begin
      Replace(S, 'SINGLEFRAME', 'ÚÄ¿³³ÀÄÙ');
      Replace(S, 'DOUBLEFRAME', 'ÉÍ»ººÈÍ¼');
    end;
    ReplaceVars;
    ReplaceChars;
    WriteJumpForward(Length(S) + 1);
    TextOfs := CodePos;
    AppendProg(S + #0);
    AppendProg(#$ba);  { mov dx, ... }
    AppendWord(TextOfs);
    if Pos('%', S) > 0
      then InstallProc(prCopyParams, True)
      else InstallProc(prPrefix, True);
    if NoCRLF
      then AppendProg(#$89#$D6#$FF#$D5)  { mov si, dx / call bp }
      else InstallProc(prNum, True);
    CmdDone := True;
  end;

  procedure WritePrompt;
  var
    OldS, OldT: string;
    C: Char;
    i: Byte;
  begin
    While S[1] in [' ', #9] do
      Delete (S, 1, 1);
    if S[1] in ['"', #39] then
    begin
      OldT := T;
      C := S[1];
      Delete(S, 1, 1);
      i := Pos(C, S);
      if i = 0 then Error('Missing quotation mark');
      T := Copy(S, 1, i - 1);
      Delete(S, 1, i);
      OldS := S;
      S := T + '$';
      T := 'ECHO';
      CompileText;
      S := OldS;
      T := OldT;
      While S[1] in [' ', ',', #9] do
        Delete(S, 1, 1);
    end;
  end;

  procedure PreparePathProc;
  var
    PathOfs: Word;
  begin
    if prNum in [prDelete, prRename] then ForAllUsed := True;
    S := UpCaseStr(S);
    ReplaceVars;
    ReplaceChars;
    While (Length(S) > 0) and (S[1] in [' ', #9, ';']) do
      Delete(S, 1, 1);
    While S[Length(S)] in [' ', #9, ';', #$d] do
      Delete(S, Length(S), 1);
    WriteJumpForward(Length(S) + 1);
    PathOfs := CodePos;
    AppendProg(S + #0);
    AppendProg(#$ba);  { mov dx, ... }
    AppendWord(PathOfs);
    InstallProc(prCopyParams, True);
    InstallProc(prNum, True);
    CmdDone := True;
  end;

  procedure CompileDir;
  begin
    IncludeFormatStr := True;
    ForAllUsed := True;
    InstallProc(prVolume, False);
    AppendProg(#$b8);
    AppendWord(ProcRec[prVolume].Address);
    PreparePathProc;
  end;

  procedure CompileSet;
  var
    i, j: Byte;
    VarOfs, ValOfs: Word;
  begin
    if Pos('=', S) = 0 then
    begin
      AppendProg(#$B8);  { mov ax, ... }
      AppendWord(adCRLF + 2);
      InstallProc(prNum, True);
      CmdDone := True;
      Exit;
    end;
    Delete(S, Length(S), 1);
    ReplaceVars;
    i := Pos('=', S);
    j := Pos('=', U);
    Delete(S, 1, i);
    Delete(U, j, 255);
    While (U[Length(U)] = ' ') and (Length(U) > 0) do
      Delete(U, Length(U), 1);
    if U = '' then Error('Syntax error');
    WriteJumpForward(Length(U) + 1);
    VarOfs := CodePos;
    AppendProg(U + #0);
    AppendProg(#$B8);  { mov ax, ... }
    AppendWord(VarOfs);
    if U <> 'PROMPT' then ReplaceChars;
    WriteJumpForward(Length(S) + 1);
    ValOfs := CodePos;
    AppendProg(S + #0);
    AppendProg(#$ba);  { mov dx, ... }
    AppendWord(ValOfs);
    InstallProc(prCopyParams, True);
    InstallProc(prNum, True);
    CmdDone := True;
  end;

  procedure CompileDOSVar;
  begin
    if prNum in [prInput] then begin WritePrompt; U := TextFrom(S) end;
    if prNum in [prAsk, prAskYN] then
    begin
      WritePrompt;
      CompileText;
      Exit;
    end;
    U := U + #0;
    WriteJumpForward(Length(U));
    AppendProg(U);
    AppendProg(#$B8 + WordStr(CodePos - Length(U)));
    InstallProc(prNum, True);
    InstallProc(prSetDosVar, True);
    CmdDone := True;
  end;

  procedure CompileChangeVar;
  begin
    U := U + #0;
    WriteJumpForward(Length(U));
    AppendProg(U);
    AppendProg(#$BA + WordStr(CodePos - Length(U)));
    InstallProc(prFindEnvVar, True);
    InstallProc(prNum, True);
    CmdDone := True;
  end;

  procedure CompileVar;
  var
    i: Byte;
    w: Word;
    N: LongInt;
    Code: Integer;
    NBytes: Array[1..4] of Char;
  begin
    if Pos ('=', S) = 0 then S := S + '=0';
    S := TextFrom(S);
    i := 1;
    While i < Length(S) do
      if S[i] = ' ' then Delete(S, i, 1) else inc(i);
    i := Pos ('=', S);
    if i = 1 then Error('Variable expected');
    Inc(VarPos);
    Vars[VarPos].Name := UpCaseStr(Copy(S, 1, i - 1));
    for w := 1 to VarPos - 1 do
      if Vars[w].Name = Vars[VarPos].Name then Error('Duplicate identifier');
    if Online then AppendProg(#$EB+#4);
    Vars[VarPos].Address := CodePos;
    T := Copy(S, i+1, 255);
    Val(T, N, Code);
    if Code <> 0 then Error('Error in integer number');
    Move(N, NBytes, 4);
    for i := 1 to 4 do
      AppendProg(NBytes[i]);
    IncludeFormatStr := True;
    T := 'VAR';
  end;

  procedure DoVars;
  Var
    i: Byte; C: Char;
    U, OldS: string;
    w, Addr, Addr2: Word;
    N: LongInt;
    NChars: Array[1..4] of Char;
    Code: Integer;
  begin
    if T = 'INC' then
    begin
      T := 'ADD';
      S := S + ' 1';
    end;
    if T = 'DEC' then
    begin
      T := 'SUB';
      S := S + ' 1';
    end;
    S := TextFrom(S);
    if T = 'LET' then C := '=' else C := ',';
    for i := 1 to Length(S) do
      if S[i] = C then S[i] := ' ';
    i := Pos(' ', S);
    if (i <> 0) xor (Pos(T, 'LET ADD SUB DIV MUL') > 0) then Error('Syntax error');
    if i = 0 then i := Length(S) + 1;
    U := TextFrom(Copy(S, 1, i-1));
    Addr := 0;
    for w := 1 to VarPos do
      if Vars[w].Name = UpCaseStr(U) then Addr := Vars[w].Address;
    if Addr = 0 then Error('Undefined variable (' + U + ')');
    U := TextFrom(Copy(S, i + 1, 255));
    if Pos(T, 'LET ADD SUB DIV MUL') > 0 then
    begin
    Addr2 := 0;
    for w := 1 to VarPos do
      if Vars[w].Name = UpCaseStr(U) then Addr2 := Vars[w].Address;
    if Addr2 = 0 then
    begin
      Val(U, N, Code);
      if Code <> 0 then
      begin
        if U[1] in ['0'..'9'] then Error('Error in integer number')
        else
        if U = 'ERRORLEVEL' then
        begin
          AppendProg(#$8A#$1E + WordStr(adEL));  { mov bl, [EL] }
          AppendProg(#$B7#0#$31#$C9);  { mov bh, 0 / xor cx, cx }
        end
        else
        if U = 'LASTRESULT' then
        begin
          AppendProg(#$90);
        end
        else
        begin
          OldS := S;
          S := U;
          if (S[1] <> '%') then
            Error('Undefined variable (' + U + ')');
          ReadValUsed := True;
          prNum := prReadVal;
          PreparePathProc;
          AppendProg(#$89#$C3);  { mov bx, ax }
          AppendProg(#$89#$D1);  { mov cx, dx }
          S := OldS;
        end;
      end
      else
      begin
        Move(N, NChars, 4);
        AppendProg(#$BB + NChars[1] + NChars[2]);  { mov bx, .... }
        AppendProg(#$B9 + NChars[3] + NChars[4]);  { mov cx, .... }
      end;
    end
    else
      begin
        AppendProg(#$8B#$1E + WordStr(Addr2));      { mov bx, [...] }
        AppendProg(#$8B#$0E + WordStr(Addr2 + 2));  { mov cx, [...] }
      end;
    end;
    Case Ord(T[1])+Ord(T[2]) of
    Ord('L')+Ord('E'): AppendProg(#$89#$1E); { mov [...], bx }
    Ord('A')+Ord('D'): AppendProg(#1#$1E);   { add [...], bx }
    Ord('S')+Ord('U'): AppendProg(#$29#$1E); { sub [...], bx }
    Ord('N')+Ord('E'): AppendProg(#$F7#$1E); { neg [...] }
    Ord('A')+Ord('B'): AppendProg(#$8B#$1E); { mov bx, [...] }
    Ord('D')+Ord('I'): AppendProg(#$A1);     { mov ax, [...] }
    Ord('M')+Ord('U'): AppendProg(#$A1);     { mov ax, [...] }
    end;
    AppendWord(Addr);
    Case Ord(T[1])+Ord(T[2]) of
    Ord('L')+Ord('E'): AppendProg(#$89#$E);  { mov [...], cx }
    Ord('A')+Ord('D'): AppendProg(#$11#$E);  { adc [...], cx }
    Ord('S')+Ord('U'): AppendProg(#$19#$E);  { sbb [...], cx }
    Ord('N')+Ord('E'): AppendProg(#$F7#$16); { not [...] }
    Ord('A')+Ord('B'): AppendProg(#$8B#$E);  { mov cx, [...] }
    Ord('D')+Ord('I'): AppendProg(#$8B#$16); { mov dx, [...] }
    Ord('M')+Ord('U'): AppendProg(#$8B#$16); { mov dx, [...] }
    end;
    AppendWord(Addr + 2);
    if T = 'DIV' then
    begin
      AppendProg(#$F7#$FB#$A3 + WordStr(Addr)); { idiv bx / mov [...], ax }
      AppendProg(#$99#$89#$16 + WordStr(Addr + 2)); { cwd / mov [...], dx }
    end;
    if T = 'MUL' then
    begin
      AppendProg(#$F7#$EB#$A3 + WordStr(Addr)); { imul bx / mov [...], ax }
      AppendProg(#$89#$16 + WordStr(Addr + 2)); { mov [...], dx }
    end;
    if T = 'ABS' then
    begin
      AppendProg(#$80#$FD#$7F);  { cmp ch, 7fh }
      AppendProg(#$76#4);        { jbe .. }
      AppendProg(#$F7#$DB#$F7#$D1);  { neg bx / not cx }
      AppendProg(#$89#$1E + WordStr(Addr)); { mov [..], bx }
      AppendProg(#$89#$0E + WordStr(Addr + 2))  { mov [..], cx }
    end;
  end;

  procedure GetNumber;
  var
    Num: Byte;
    Code: Integer;
    W: Word;
    OldS: string;
  begin
    OldS := S;
    T := '';
    While (S[1] in [' ', #9, ',']) and (S[0] > #0) do
      Delete(S, 1, 1);
    While not (S[1] in [' ', #9, ',', #13]) and (S[0] > #0) do
    begin
      T := T + UpCase(S[1]);
      Delete (S, 1, 1);
    end;
    if T = '' then begin T := 'e'; S := OldS; Exit; end;
    Val (T, Number, Code);
    if Code <> 0 then
    begin
      ReplaceAll (T, '%', '');
      for W := 1 to VarPos do
        if Vars[W].Name = T then
        begin
          Number := Vars[W].Address;
          T := 'v';
          Exit;
        end;
        S := OldS;
    end
    else
      T := 'n';
  end;

  procedure CompileGetNum(N: Longint; C: Char; Tp: Byte; Rg: Byte);
  var
    LC: Array[1..4] of Byte;
  begin
    Move(N, LC, 4);
    case C of
      'v': Case Rg of
           1:     begin
                    if Tp = 1 then AppendProg(#$A0) else AppendProg(#$A1);
                    AppendProg(Chr(LC[1]) + Chr(LC[2]));  { mov al/ax, [...] }
                    if Tp > 2 then
                      AppendProg(#$8B#$16 + WordStr(LC[1] + LC[2] * 256 + 2));  { mov dx, [...] }
                  end;
           3:     begin
                    if Tp = 1 then AppendProg(#$8A#$0E)
                      else AppendProg(#$8B#$E);
                    AppendProg(Chr(LC[1]) + Chr(LC[2])); { mov cl/cx, [...] }
                  end;
           4:     AppendProg(#$8A#$16 + Chr(LC[1]) + Chr(LC[2])); { mov dl, [...] }
           5:     AppendProg(#$8A#$26 + Chr(LC[1]) + Chr(LC[2])); { mov ah, [...] }
           8:     AppendProg(#$8A#$36 + Chr(LC[1]) + Chr(LC[2])); { mov dh, [...] }
           end;
      'n': Case Rg of
           1:     begin
                    if Tp = 1 then AppendProg(#$B0) else AppendProg(#$B8);
                    AppendProg(Chr(LC[1]));
                    if Tp > 1 then AppendProg(Chr(LC[2]));
                    if Tp > 2 then
                      AppendProg(#$BA + Chr(LC[3]) + Chr(LC[4]));
                  end;
           3:     if Tp = 1 then AppendProg(#$B1 + Chr(LC[1])) else
                    AppendProg(#$B9 + Chr(LC[1]) + Chr(LC[2]));
           4:     AppendProg(#$B2 + Chr(LC[1])); { mov dl, ... }
           5:     AppendProg(#$B4 + Chr(LC[1])); { mov ah, ... }
           8:     AppendProg(#$B6 + Chr(LC[1])); { mov dh, ... }
           end;
    end;
  end;


  procedure CompileNumCmd;
  var
    N1, N2, N3, N4: LongInt;
    T1, T2, T3, T4: Char;
    OldS: string;
    i, j, Code: Integer;
  begin
    CmdDone := False;
    if T = 'SETCOLOR' then
    begin
      GetNumber;
      if not (T[1] in ['n', 'v']) then Error('Must specify a number or a variable');
      CompileGetNum (Number, T[1], 1, 1);
      AppendProg(#$A2 + WordStr(adTextAttribute));
      CmdDone := True;
    end;
    if T = 'MOVETO' then
    begin
      GetNumber;
      N1 := Number;
      T1 := T[1];
      GetNumber;
      N2 := Number;
      T2 := T[1];
      if (not (T1 in ['n', 'v'])) or (not (T2 in ['n', 'v']))
        then Error('Correct syntax is: ''MoveTo X, Y');
      CompileGetNum (N1, T1, 1, 4);
      CompileGetNum (N2, T2, 1, 8);
      AppendProg (#$B4#2#$B7#0#$81#$EA#1#1#$CD#$10);
      CmdDone := True;
    end;
    if T = 'GETX' then
    begin
      GetNumber;
      if T[1] <> 'v' then Error('Correct syntax is: ''GetX <var>''');
      AppendProg (#$B4#3#$B7#0#$CD#$10#$FE#$C2#$B6#0);
      AppendProg (#$89#$16 + WordStr(Number));
      AppendProg (#$31#$C0#$A3 + WordStr(Number + 2));
      CmdDone := True;
    end;
    if T = 'GETY' then
    begin
      GetNumber;
      if T[1] <> 'v' then Error('Correct syntax is: ''GetY <var>''');
      AppendProg (#$B4#3#$B7#0#$CD#$10#$FE#$C6#$B2#0#$86#$D6);
      AppendProg (#$89#$16 + WordStr(Number));
      AppendProg (#$31#$C0#$A3 + WordStr(Number + 2));
      CmdDone := True;
    end;
    if T = 'DISKFREE' then
    begin
      GetNumber;
      if T[1] <> 'v' then Error('Correct syntax is: ''DiskFree <var>''');
      AppendProg (#$B4#$36#$B2#0#$CD#$21);
      AppendProg (#$31#$D2#$F7#$E3#$F7#$E1);
      AppendProg (#$A3 + WordStr(Number) + #$89#$16 + WordStr(Number + 2));
      CmdDone := True;
    end;
    if T = 'WRITECHAR' then
    begin
      GetNumber;
      T1 := T[1];
      N1 := Number;
      GetNumber;
      if (T[1] <> 'v') and (T[1] <> 'n') then begin T[1] := 'n'; Number := 1 end;
      if not (T1 in ['v', 'n']) then Error ('Correct syntax is: ''WriteChar <ascii code> [<number>]');
      AppendProg(#$B4#9);
      CompileGetNum(N1, T1, 1, 1);
      AppendProg(#$8A#$3E + WordStr(adActivePage));
      AppendProg(#$8A#$1E + WordStr(adTextAttribute));
      CompileGetNum(Number, T[1], 2, 3);
      AppendProg(#$CD#$10);
      CmdDone := True;
    end;
    if T = 'SETWINDOW' then
    begin
      GetNumber;
      N1 := Number;
      T1 := T[1];
      GetNumber;
      N2 := Number;
      T2 := T[1];
      GetNumber;
      N3 := Number;
      T3 := T[1];
      GetNumber;
      N4 := Number;
      T4 := T[1];
      if not ((T1 in ['n', 'v']) and (T1 in ['n', 'v']) and (T1 in ['n', 'v'])
        and (T1 in ['n', 'v'])) then Error('Correct syntax is: ''SetWindow X1, Y1, X2, Y2''');
      CompileGetNum (N1, T1, 1, 4);
      CompileGetNum (N2, T2, 1, 8);
      AppendProg (#$81#$EA#1#1#$89#$16 + WordStr(adWindMin));
      CompileGetNum (N3, T3, 1, 4);
      CompileGetNum (N4, T4, 1, 8);
      AppendProg (#$81#$EA#1#1#$89#$16 + WordStr(adWindMax));
      CmdDone := True;
    end;
    if T = 'SCROLL' then
    begin
      GetNumber;
      if (T[1] <> 'v') and (T[1] <> 'n') then Error('Correct syntax is: ''Scroll <number of lines>''');
      CompileGetNum (Number, T[1], 1, 1);
      AppendProg (#$B4#6#$3C#$7F#$76#4#$F6#$D8#$FE#$C4);
      AppendProg (#$8A#$3E + WordStr(adTextAttribute));
      AppendProg (#$8B#$E + WordStr(adWindMin));
      AppendProg (#$8B#$16 + WordStr(adWindMax));
      AppendProg (#$CD#$10);
      CmdDone := True;
    end;
    if T = 'FILLWINDOW' then
    begin
      GetNumber;
      if (T[1] <> 'v') and (T[1] <> 'n') then
        Error ('ASCII number expected');
      CompileGetNum(Number, T[1], 1, 1);
      T := 'fill';
    end;
    if T = 'GETKBFLAGS' then
    begin
      AppendProg (#$B4#2#$CD#$16#$A2 + WordStr(adEL));
      CmdDone := True;
    end;
    if T = 'SETKBFLAGS' then
    begin
      GetNumber;
      if not (T[1] in ['v', 'n']) then Error ('Must specify a number or variable');
      CompileGetNum (Number, T[1], 1, 4);
      AppendProg (#$31#$C0#6#$8E#$C0#$26);
      AppendProg (#$88#$16#$17#4#7);
      CmdDone := True;
    end;
    if T = 'GETCURSOR' then
    begin
      GetNumber;
      if (T[1] <> 'v') then Error('Correct syntax is: ''GetCursor <var>''');
      AppendProg (#$B4#3#$B7#0#$CD#$10);
      AppendProg (#$89#$E + WordStr(Number));
      AppendProg (#$C7#6 + WordStr(Number + 2) + #0#0);
      CmdDone := True;
    end;
    if T = 'SETCURSOR' then
    begin
      GetNumber;
      if (T[1] <> 'v') and (T[1] <> 'n') then Error('Correct syntax is: ''SetCursor <var/number>''');
      CompileGetNum (Number, T[1], 2, 3);
      AppendProg (#$B4#1#$CD#$10);
      CmdDone := True;
    end;
    if T = 'MENU' then
    begin
      GetNumber;
      N1 := Number;
      T1 := T[1];
      GetNumber;
      N2 := Number;
      T2 := T[1];
      GetNumber;
      N3 := Number;
      T3 := T[1];
      if not (T1 in ['n', 'v']) then begin T1 := 'n'; N1 := 0; end;
      if not (T2 in ['n', 'v']) then begin T2 := 'n'; N2 := 0; end;
      if not (T3 in ['n', 'v']) then begin T3 := 'n'; N3 := 0; end;
      CompileGetNum(N1, T1, 1, 5);
      CompileGetNum(N2, T2, 1, 1);
      CompileGetNum(N3, T3, 1, 3);
      prNum := prMenu;
      CompileText;
      CmdDone := True;
    end;
    if T = 'INPUT' then
    begin
      GetNumber;
      if not (T[1] in ['n', 'v']) then begin Number := 0; T[1] := 'n' end;
      CompileGetNum(Number, T[1], 1, 3);
      T := 'INPUT';
    end;
    if (T = 'SETBIT') or (T = 'RESETBIT') or (T = 'GETBIT') then
    begin
      T4 := T[1];
      GetNumber;
      if (T[1] <> 'n') or not (Number in [0..31])
        then Error('First parameter must be a number [0..31]');
      N1 := Number;
      GetNumber;
      if T[1] <> 'v' then Error('Second parameter must be a variable');
      N2 := Number + (N1 div 8);
      N1 := N1 mod 8;
      if T4 = 'G' then AppendProg(#$C6#6 + WordStr(adEL) + #0);
      if (T4 = 'S') or (T4 = 'G') then N1 := Power(2, N1) else
        N1 := 255 - Power(2, N1);
      Case T4 of
        'S': AppendProg(#$80#$E + WordStr(N2) + Chr(N1));  { or by [..], .. }
        'R': AppendProg(#$80#$26 + WordStr(N2) + Chr(N1)); { and by [..], .. }
        'G': AppendProg(#$F6#6 + WordStr(N2) + Chr(N1) +
               #$74#4 + #$FE#6 + WordStr(adEL));
                 { test by [..], .. / jz ... / inc [EL] }
      end;
      CmdDone := True;
    end;
    if T = 'INLINE' then
    begin
      CmdDone := True;
      repeat
        While S[1] in [' ', #9, ',', '-'] do
          Delete(S, 1, 1);
        if (S = #13) or (S[1] = ';') then Exit;
        T := '';
        While S[1] in ['0'..'9', 'a'..'f', 'A'..'F'] do
        begin
          T := T + S[1];
          Delete(S, 1, 1);
        end;
        if (T = '') or (Length(T) > 2) then Error('Only hexadecimal numbers allowed (0..FF)');
        Val ('$'+T, Number, Code);
        AppendProg(Chr(Number));
      until S = #13;
      Exit;
    end;
    if T = 'COUNTPARAMS' then
    begin
      AppendProg(#$A0 + WordStr(adNumParameters));
      AppendProg(#$A2 + WordStr(adEL));
      CmdDone := True;
    end;

  end;

  procedure CompileIF;
  var
    i, j: Integer;
    Inv: Boolean;
    OldS: string;
    Cmp: string;
  Label
    GetNext;
  begin
    Inv := False;
  GetNext:
    T := '';
    While S[1] in [' ', #9] do
      Delete(S, 1, 1);
    While not (S[1] in [' ', #9, '>', '<', '|', #13]) do
    begin
      T := T + S[1];
      Delete(S, 1, 1);
    end;
    While S[1] in [' ', #9] do
      Delete(S, 1, 1);
    if S = #13 then Exit;
    U := '';
    if UpCaseStr(T) = 'NOT' then
    begin
      Inv := True;
      GoTo GetNext;
    end;
    if UpCaseStr(T) = 'KEYPRESSED' then
    begin
      j := $75;
      if Inv then j := $74;
      AppendProg(#$B4#1#$CD#$16 + Chr(j) + #3#$E9#0#0);
      IFAddr := CodePos - 2;
      Exit;
    end;
    if UpCaseStr(T) = 'ERRORLEVEL' then
    begin
      While S[1] in [' ', #9, '='] do
        Delete(S, 1, 1);
      While S[1] in ['0'..'9'] do
        begin U := U + S[1]; Delete(S, 1, 1); end;
      Val(U, i, j);
      if (j <> 0) or (not(i in [0..255])) then
        Error('Valid numbers are 0..255');
      j := $73;
      if Inv then j := $72;
      AppendProg(#$80#$3E + WordStr(adEL) + Chr(i) + Chr(j) + #3#$E9#0#0);
      IFAddr := CodePos - 2;
      Exit;
    end;
    if UpCaseStr(T) = 'EXIST' then
    begin
      While not (S[1] in ['/', ' ', #9, '>', '<', '|', #13]) do
      begin
        U := U + UpCase(S[1]);
        Delete(S, 1, 1);
      end;
      OldS := S;
      S := U;
      PrNum := prExist;
      PreparePathProc;
      S := OldS;
      if Inv then AppendProg(#$F5);  { cmc }
      AppendProg(#$73#3#$E9#0#0);
      IFAddr := CodePos - 2;
      CmdDone := False;
      Exit;
    end;
    While S[1] in [' ', #9] do
      Delete(S, 1, 1);
    Cmp := '';
    While S[1] in ['=', '>', '<'] do
    begin
      Cmp := Cmp + S[1];
      Delete(S, 1, 1);
    end;
    if Cmp = '<>' then Inv := not Inv;
    Replace (Cmp, '<>', '==');
    if Length(Cmp) = 2 then
      if Cmp[2] <> '=' then Cmp := '';
    if (not (Length(Cmp) in [1, 2])) then
      Error('Valid operators are '#39'=='#39', '#39'<>'#39', '#39'>'#39', '#39'<'#39', '#39'>='#39' and '#39'<='#39'.');
    Replace(Cmp, '>=', 'ò');
    Replace(Cmp, '<=', 'ó');
    S := T + ' ' + S;
    i := Pos(' ', S);
    T := Copy(S, 1, i - 1);
    Delete(S, 1, i);
    While T[Length(T)] in [' ', #9] do Delete(T, Length(T), 1);
    While S[1] in [' ', #9] do Delete(S, 1, 1);
    U := '';
    While not (S[1] in [' ', #9, #13]) do
    begin
      U := U + S[1];
      Delete(S, 1, 1);
    end;
    if (T = '') or (U = '') then Error('Syntax error');
    OldS := S;
    S := T;
    PrNum := prCompare1;
    CompileText;
    S := U;
    PrNum := prCompare2;
    CompileText;
    case Cmp[1] of
      '=': if Inv then j := $75 else j := $74;
      '>': if Inv then j := $73 else j := $72;
      '<': if Inv then j := $76 else j := $77;
      'ò': if Inv then j := $77 else j := $76;
      'ó': if Inv then j := $72 else j := $73;
    end;
    AppendProg(Chr(j) + #3#$E9#0#0);
    IFAddr := CodePos - 2;
    S := OldS;
    CmdDone := False;
  end;

  procedure CompileFOR;

    procedure Shift;
    begin
      U := '';
      While S[1] in [' ', #9] do
        Delete(S, 1, 1);
      While not (S[1] in [' ', #9, #13]) do
      begin
        U := U + S[1];
        Delete(S, 1, 1);
      end;
    end;

  var
    C: Char;
    List, OldS: string;
    ProcOfs, TextOfs: Word;
    foRecursive,
    foDirectories: Boolean;
  begin
    ForInDoUsed := True;
    foRecursive := FALSE;
    foDirectories := FALSE;
    repeat
      Shift;
      U := UpCaseStr(U);
      if U = '' then
        Error ('Syntax error');
      if (U = '-R') or (U = '/R') then
        foRecursive := TRUE;
      if (U = '-D') or (U = '/D') then
        foDirectories := TRUE;

    until U[1] = '%';
    if { (Length(U) <> 3) or } (U[1] <> '%') { or (U[2] <> '%') } then
      Error('Invalid FOR variable');
    C := U[Length (U)];
    ReplaceAll(S, U, '%'#26'%');
    Shift;
    if UpCaseStr(U) <> 'IN' then Error(#39'IN'#39' expected');
    Replace(S, ')', ') ');
    Shift;
    if Pos('(', U) <> 1 then Error(#39'('#39' expected');
    if Pos(')', U + S) = 0 then Error(#39')'#39' expected');
    List := '';
    Repeat
      List := List + ' ' + U;
      Shift;
    Until Pos(')', List) > 0;
    Delete(List, 1, 2);
    Delete(List, Length(List), 1);
    if UpCaseStr(U) <> 'DO' then Error(#39'DO'#39' expected');
    InstallProc(prSetDosVar, False);
    ProcOfs := ProcRec[prSetDosVar].Address;
    OldS := S;
    S := List;
    ReplaceVars;
    List := S;
    S := OldS;
    WriteJumpForward(Length(List) + 1);
    TextOfs := CodePos;
    AppendProg(List + #0);
    AppendProg(#$b9);  { mov cx, ... }
    if foDirectories then
      AppendWord(Directory)
    else
      AppendWord(Archive + SysFile + ReadOnly);
    AppendProg(#$ba);  { mov dx, ... }
    AppendWord(TextOfs);
    InstallProc(prCopyParams, True);
    AppendProg(#$B8 + WordStr(ProcOfs));  { mov ax, ... }
    FORAddr := CodePos;
    InstallProc(prForInDo, True);
    AppendProg(#$73#3);  { jnb ... }
    AppendProg(#$E9#0#0);  { jmp ... }
    FORAddr2 := CodePos - 2;
    CmdDone := False;
  end;

  function ExtendedFORSyntax (s: string): Boolean;
    var
      i: Integer;
      U: string;

    procedure Shift;
    begin
      U := '';
      While S[1] in [' ', #9] do
        Delete(S, 1, 1);
      While not (S[1] in [' ', #9, #13]) do
      begin
        U := U + S[1];
        Delete(S, 1, 1);
      end;
    end;

  begin
    ExtendedFORSyntax := TRUE;
    repeat
      Shift;
      U := UpcaseStr (U);
      if Pos (' ' + U + ' ', ' /F -F /L -L /R -R ') > 0 then
        Exit;
    until (U = '') or (U[1] in ['%']);
    ExtendedFORSyntax := FALSE;
  end;

  procedure InstallWriteProc;
  begin
    InstallProc (WC, False);
    InstallProc (WS, False);
    WriteWord (adWriteChar, ProcRec[WC].Address);
    WriteWord (adWriteASCIIZString, ProcRec[WS].Address);
  end;

  var
    i, j: Word;
    CmdLine: string;

  procedure CompileLine;
  Label
    Start,
    UseDos;
  begin
  Start:
    DeleteFirst(S);
    if S = '' then
      if IFAddr <> 0 then Error('Syntax error') else Exit;
    if S[1] = ':' then
    begin
      StoreLabel(S);
      Exit;
    end;
    if S[Length(S)] <> #13 then S := S + #13;
    T := '';
    CmdDone := False;
    CompileGoToDrive;
    if CmdDone then Exit;
    i := Pos('DIR.', UpcaseStr(S));
    if i > 0 then
      Insert(' ', S, i + 3);
    i := Pos('ECHO.', UpcaseStr(S));
    if i > 0 then S[i + 4] := ' ';
    i := Pos('PAUSE.', UpcaseStr(S));
    if i > 0 then S[i + 5] := ' ';

    While not (S[1] in ['/', ' ', #9, '>', '<', '|', #13]) do
    begin
      T := T + UpCase(S[1]);
      Delete(S, 1, 1);
    end;

    if T = 'REM' then
    begin
      if CommentSet then Exit;
      if S[1] = ' ' then Delete(S, 1, 1);
      if S <> '' then Comment := S;
      CommentSet := True;
      Exit;
    end;

    if T = 'IF' then
    begin
      if IFAddr <> 0 then Error('Syntax error');
      CompileIF;
      if IFAddr = 0 then Exit else GoTo Start;
    end;

    if T = 'CRT' then
    begin
      WC := prCRTWriteChar;
      WS := prCRTWriteString;
      InstallProc (WC, False);
      InstallProc (WS, False);
      IncludeCRTInput := True;
      AppendProg (#$C6#6 + WordStr(adUseCRT) + #$FF);
      AppendProg (#$C7#6 + WordStr(adWriteChar) + WordStr(ProcRec[WC].Address));
      AppendProg (#$C7#6 + WordStr(adWriteASCIIZString) +
        WordStr(ProcRec[WS].Address));
      Exit;
    end;
    if T = 'DOS' then
    begin
      WC := prDOSWriteChar;
      WS := prWriteASCIIZString;
      InstallProc (WC, False);
      InstallProc (WS, False);
      AppendProg (#$C6#6 + WordStr(adUseCRT) + #0);
      AppendProg (#$C7#6 + WordStr(adWriteChar) + WordStr(ProcRec[WC].Address));
      AppendProg (#$C7#6 + WordStr(adWriteASCIIZString) +
        WordStr(ProcRec[WS].Address));
      Exit;
    end;
    if T = 'BIOS' then
    begin
      WC := prBIOSWriteChar;
      WS := prWriteASCIIZString;
      InstallProc (WC, False);
      InstallProc (WS, False);
      AppendProg (#$C7#6 + WordStr(adWriteChar) + WordStr(ProcRec[WC].Address));
      AppendProg (#$C7#6 + WordStr(adWriteASCIIZString) +
        WordStr(ProcRec[WS].Address));
      Exit;
    end;

    if Pos('<', S) > 0 then GoTo UseDos;
    U := TextFrom(S);
    i := Pos('|', S);
    j := Pos('>', S);
    if (i > 0) or (j > 0) then
    begin
      if ((j < i) and (j <> 0)) or (i = 0) then i := j;
      U := TextFrom (Copy(S, i, 255));
      Delete (S, i, 255);
      ReplaceAll(U, '| ', '|');
      ReplaceAll(U, '> ', '>');
      if Pos('>PRN', U) > 0 then
      begin
        Replace(U, '>PRN', '');
        OutputToPRN := True;
      end;
      if Pos('>AUX', U) > 0 then
      begin
        Replace(U, '>AUX', '');
        OutputToAUX := True;
      end;
      if Pos('>LPT1', U) > 0 then
      begin
        Replace(U, '>LPT1', '');
        OutputToPRN := True;
      end;
      if Pos('>NUL', U) > 0 then
      begin
        Replace(U, '>NUL', '');
        OutputToNUL := True;
      end;
      if Pos('|MORE', U) > 0 then
      begin
        Replace(U, '|MORE', '');
        UseMore := True;
      end;

      if Pos('|', S + U) > 0 then GoTo UseDos;
      if Pos('>', S + U) > 0 then GoTo UseDos;
    end;

    CompileNumCmd;
    if CmdDone then Exit;

    U := TextFrom(S);

    if OutputToPRN then
      AppendProg(#$C6#6 + WordStr(adOP) + Chr(opPRN));
    if OutputToAUX then
      AppendProg(#$C6#6 + WordStr(adOP) + Chr(opAUX));
    if OutputToNUL then
      AppendProg(#$C6#6 + WordStr(adOP) + Chr(opNUL));

    if UseMore then
    begin
      AppendProg(#$C6#6 + WordStr(adMore) + #$FF);
      AppendProg(#$C6#6 + WordStr(adMoreLine) + #0);
    end;
    if (T = 'FOR') and (not ExtendedFORSyntax (s)) then
    begin
      if FORAddr <> 0 then Error('Syntax error');
      CompileFor;
      if FORAddr = 0 then Exit else GoTo Start;
    end;
    if (T = 'PATH') or (T = 'PROMPT') then
    begin
      While (S[1] in [' ', #9]) do
        Delete(S, 1, 1);
      if (S = #13) and (T = 'PATH') then
      begin
        S := 'ECHO PATH=%path%';
        GoTo Start;
      end;
      S := 'SET ' + T + '=' + S;
      GoTo Start;
    end;
    if T = 'GOTO' then
    begin
      CompileGoto;
      Exit;
    end;
    if T = 'GOSUB' then
    begin
      CompileGoSub;
      Exit;
    end;
    if T = 'RETURN' then
    begin
      AppendProg(#$C3);  { ret }
      Exit;
    end;
    if T = 'VAR' then
    begin
      CompileVar;
      Exit;
    end;
    if S[1] = ' ' then Delete(S, 1, 1);
    if (T[0]=#3) and (Pos(T, 'LET ADD SUB INC DEC NEG ABS DIV MUL') > 0) then
    begin
      DoVars;
      Exit;
    end;

    if T = 'ECHO' then
      if U = 'OFF' then Exit;
    While (Length(S) > 0) and (S[Length(S)] in [' ', #9])
      do Delete(S, Length(S), 1);
    if T <> '' then
    begin
      if T = 'CHDIR' then T := 'CD';
      if T = 'RMDIR' then T := 'RD';
      if T = 'MKDIR' then T := 'MD';
      if T = 'ERASE' then T := 'DEL';
      if T = 'RENAME' then T := 'REN';
      if T = 'FRAMEWINDOW' then T := 'frame';
      if T = 'GETDRIVE' then T := 'getdr';
      if T = 'GETDATE' then begin T := 'getdat'; IncludeFormatStr := True end;
      if T = 'GETTIME' then begin T := 'gettim'; IncludeFormatStr := True end;
      if T = 'CHECKANSI' then T := 'chansi';
      if T = 'GETSCREEN' then begin T := 'getscr'; IncludeSaveScreen := True end;
      if T = 'PUTSCREEN' then begin T := 'putscr'; IncludeSaveScreen := True end;
      if T = 'SWAPSCREEN' then begin T := 'swpscr'; IncludeSaveScreen := True end;
      if T = 'LOADSCREEN' then T := 'loadsc';
      if T = 'SAVESCREEN' then T := 'savesc';
      if T = 'UPPERCASE' then T := 'upcase';
      if T = 'LOWERCASE' then T := 'locase';
      if T = 'GETLENGTH' then T := 'getlen';
      if T = 'CHECKERRORS' then T := 'check';
      if T = 'GETRANDOM' then T := 'random';
      if T = 'GETFILECRC' then begin T := 'getcrc'; IncludeSaveScreen := True end;
      if T = 'GETFILESIZE' then T := 'getsiz';
      for PrNum := 1 to NumProc do
        if ProcRec[PrNum].Cmd = T then
        begin
          Case ProcRec[PrNum].Tp of
            tpNoParams:  if U = '' then
                         begin
                           InstallProc(PrNum, True);
                           CmdDone := True;
                         end;
            tpOnOff:     CompileOnOff;
            tpPrepare:   PreparePathProc;
            tpDir:       CompileDir;
            tpText:      CompileText;
            tpSet:       CompileSet;
            tpVar:       CompileDOSVar;
            tpChangeVar: CompileChangeVar;
          end;
          if CmdDone then Exit;
        end;
      UseDos:
        CmdLine := CurLine + #13;
        OutputToNul := false;
        OutputToPRN := false;
        OutputToAUX := False;

        if (Pos('\', T) = 0) or (Pos('>', S) > 0) or (Pos('<', S) > 0) or
           (Pos('|', S) > 0) or (T = 'COPY') or (T = 'CALL') or (T = 'COMMAND')
          or ((T = 'FOR') and (ExtendedFORSyntax (s)))
          or (Pos('.BAT', T) > 0) or ((Pos('.EXE', T) = 0) and
          (Pos('.COM', T) = 0)) or (Pos('%', T) > 0) then
        begin
          if T = 'CALL' then Replace(CmdLine, 'CALL', '');
          While CmdLine[1] in [' ', #9] do Delete(CmdLine, 1, 1);
          if T = 'COMMAND' then
            Replace(CmdLine, 'COMMAND', '')
          else
            CmdLine := '/c ' + CmdLine;
          S := #255#255 + CmdLine;
          UseMore := False;
          prNum := prCommand;
          CompileText;
          Exit;
        end;

        WriteJumpForward(Length(T) + 1);
        AppendProg(T + #0);
        AppendProg(#$B8 + WordStr(CodePos - (Length(T) + 1)));
        S := #255#255 + S;
        UseMore := False;
        prNum := prRunProg;
        CompileText;
    end;


  end;


  begin   { CompileProgram }

    for i := 1 to NumProc do
      ProcRec[i].Address := 0;
    AppendProc(prStartProgramCode);
    Dec(CodePos);  { Exclude 'RET' }

    Lin := 0;
    Assign(InputFile, InputName);
    Reset(InputFile);
    InstallWriteProc;
    repeat
      ReadLn(InputFile, S);
      Inc(Lin);
      CurLine := S;
      CompileLine;
      if CurLine <> '' then
        if (T = 'GOTO') or (T = 'RETURN') or ((T = 'VAR') and not Online)
          then OnLine := false
          else OnLine := True;
      if IFAddr <> 0 then
      begin
        WriteWord(IFAddr, CodePos - IFAddr - 2);
        IFAddr := 0;
      end;
      if FORAddr <> 0 then
      begin
        AppendProg(#$31#$C0);  { xor ax, ax }
        AppendProg(#$E9#0#0);  { jmp ... }
        WriteWord(CodePos - 2, FORAddr - CodePos);
        WriteWord(FORAddr2, CodePos - FORAddr2 - 2);
        FORAddr := 0;
      end;
      if OutputToNul or OutputToPRN or OutputToAUX then
      begin
        AppendProg(#$C6#6 + WordStr(adOP) + Chr(opCON));
        OutputToPRN := false;
        OutputToAUX := False;
        OutputToNUL := False;
      end;
      if UseMore then
      begin
        AppendProg(#$C6#6 + WordStr(adMore) + #0);
        UseMore := False;
        IncludeMore := True;
      end;
    until Eof(InputFile);


    AppendProg(#$b8#0#$4c#$cd#$21);  { mov ax, 4c00;  int 21h }
    SetAllJumps;
    WriteWord(adBreak, CodePos);
    AppendProc(prBreak);

    WriteWord(adReadKey, CodePos);
    AppendProc(prDOSReadKey);

    WriteWord(adErrorProc, CodePos);
    AppendProc(prHandleError);
    if IncludeErrMsg then
    begin
      WriteWord(adExtraErrorProc, CodePos);
      AppendProc(prErrorMsg);
    end;
    if ReadValUsed then
    begin
      WriteWord(adReadVal, CodePos);
      AppendProc(prReadVal);
    end;
    WriteWord(adMoreProc, CodePos);
    if IncludeMore then
      AppendProc(prMore)
    else
      AppendProg(#$C3);
    if ForAllUsed then
    begin
      WriteWord(adForAllFilesDo, CodePos);
      AppendProc(prForAllFilesDo);
    end;
    WriteWord(adHandleOutput, CodePos);
    AppendProc(prHandleOutput);
    WriteWord(adVersionError, CodePos);
    AppendProg(txVersionError + #13#10'$');
    if IncludeFormatStr then
    begin
      WriteWord(adFormatStr, CodePos);
      AppendProc(prFormatStr);
    end;
    if IncludeCRTInput then
    begin
      WriteWord(adInputStr, CodePos);
      AppendProc(prCRTInput);
    end;
    CodeEnd := CodePos;

    WriteWord(adDraft, CodePos);
    Inc(CodePos, $400);
    WriteWord(adDraft2, CodePos);
    Inc(CodePos, $400);
    WriteWord(adDTA, CodePos);
    Inc(CodePos, $80);
    if ForInDoUsed then
    begin
      WriteWord(adForDTA, CodePos);
      Inc(CodePos, $100);
    end;
    if IncludeSaveScreen then
    begin
      WriteWord(adPCopyBuffer, CodePos);
      Inc(CodePos, 80 * 25 * 2);
    end;
    While (CodePos div 16) <> (CodePos / 16) do
      Inc(CodePos);
    WriteWord(adEnviron, CodePos);
    WriteWord(adEnvSeg, CodePos div 16);
    WriteWord(adSP, CodePos + EnvLength + StackSpace);

    S := #13 + Comment + #13#10#26;
    for i := 1 to Length(S) do
      ProgramCode[i + adNumParameters - 1] := S[i];


    Assign(OutputFile, OutputName);
    ReWrite(OutputFile);

    for i := $100 to CodeEnd - 1 do
      Write(OutputFile, ProgramCode[i]);

    Close(OutputFile);
    if Lin = 1 then S := '' else S := 's';
    WriteLn (Lin, ' line', S, ', Compiled program: ', OutPutName, ', Size: ',
      CodeEnd - $100, ' bytes');
  end;



  procedure ShowInformation;
  begin
    WriteLn;
    WriteLn ('BATCHCOM compiles batch files into COM-programs.');
    WriteLn;
    WriteLn ('Syntax: BATCHCOM [filename[.bat]] [options]');
    WriteLn;
    WriteLn ('Options:');
    WriteLn ('  /M     -  Include error messages');
    WriteLn ('  /S     -  Use fast CRT screen procedures');
    WriteLn ('  /O     -  Overwrite existing files without asking');
    WriteLn ('  /E n   -  Environment size (default: 8192 bytes)');
    WriteLn ('  /L     -  List all commands');
    Halt(0);
  end;

  procedure HandleOption(S: string);
  var
    N, Code: Integer;
  begin
    While (S[0] > #0) and (S[1] in ['/', '-']) do
    begin
      Delete (S, 1, 1);
      if S = '' then
      begin
        WriteLn ('Invalid parameter');
        ShowInformation;
      end
      else
        Case UpCase(S[1]) of
          '?': ShowInformation;
          'M': IncludeErrMsg := True;
          'O': OverwriteFiles := True;
          'S': begin
                 WS := prCRTWriteString;
                 WC := prCRTWriteChar;
               end;
          'E': begin
                 Val (Copy(S, 2, 255), N, Code);
                 if Code > 0 then
                 begin
                   WriteLn('Invalid number');
                   Halt(1);
                 end;
                 EnvLength := N;
               end;
          'L': ShowAllCommands;
          else
            begin
              WriteLn ('Invalid parameter (', S[1], ')');
              ShowInformation;
            end;
        end;
      Delete(S, 1, 1);
    end;
  end;

  function FileExists(F: string): Boolean;
  var
    SR: SearchRec;
  begin
    FindFirst(F, AnyFile, SR);
    FileExists := (DosError = 0);
  end;

  Function FileName(S, Ext: string): string;
  begin
    if Pos('.', S) = 0 then FileName := UpCaseStr(S) + Ext
    else FileName := UpCaseStr(S);
  end;

  {$I-}

  var
    i, j: Word;
    InpOk, OutpOk: Boolean;
    C: Char;
begin
  WriteLn(#13'BATCHCOM - Batch Compiler  Version 1.2, (C) 1992-2002, by Mike Wiering.');
  if ParamCount = 0 then
    ShowInformation;
  InputName := '';
  OutputName := '';
  InpOk := False;
  OutpOk := False;
  for i := 1 to ParamCount do
  begin
    S := ParamStr(i);
    if S[1] in ['/','-'] then
      HandleOption(S)
    else
      if InputName = '' then
        InputName := S
      else
        if OutputName = '' then
          OutputName := S;
  end;
  if InputName = '?' then
    ShowInformation;
  repeat
    InputName := FileName(InputName, '.BAT');
    if Not FileExists(InputName) then
    begin
      if InputName <> '.BAT' then
        WriteLn('"', InputName, '" not found');
      Write('Batch file [.BAT]: ');
      ReadLn(InputName);
    end
    else InpOk := True;
  until InpOk;
  S := InputName;
  i := Pos('.', InputName);
  if i > 0 then Delete(S, i, 255);
  if OutputName = '' then OutputName := S;
  repeat
    OutputName := FileName(OutputName, '.COM');
    if FileExists(OutputName) and not OverwriteFiles then
    begin
      Write('"', OutputName, '" already exists. Overwrite (y/n)? ');
      C := ReadKey;
      if C = #0
        then C := ReadKey
      else
        if UpCase(C) = 'Y' then
        begin
          OutpOk := True;
          WriteLn('Yes');
        end
        else
          WriteLn('No');
    end
    else
      OutpOk := True;
    if OutpOk then
    begin
      Assign(OutputFile, OutputName);
      ReWrite(OutputFile);
      OutpOk := (IOresult = 0);
      if OutpOk then
        Close(OutputFile)
      else
        WriteLn('Cannot open file "', OutputName, '"');
    end;
    if not OutpOk then
    begin
      Write('Program name [', S, '.COM]: ');
      ReadLn(OutputName);
    end;
  until OutpOk;
  CompileProgram;
end.
