# BATCHCOM

BATCHCOM is a Batch Compiler. It compiles DOS batch files (.BAT) into
executable DOS programs (.COM). In addition to the normal DOS commands, 
BATCHCOM supports many extra commands for program flow, variables and screen handling.
BATCHCOM was designed to work with DOS 3.30, so some newer command options
(found in DOS 5 or 6 and Windows NT, etc.) are not supported. However,
with the extra commands, BATCHCOM is like a complete programming language.

Written in Turbo Pascal in 1992. To try this program, use DosBox-X.

## Usage

BATCHCOM [filename[.bat]] [options]

Options:
       
       /M     -  include error messages
       /S     -  use fast CRT screen procedures
       /O     -  overwrite existing files without asking
       /E n   -  environment size (default: 8192 bytes)
       /L     -  list all commands

## Supported DOS commands

|  Command              |  Description
| --------------------- | ---------------------------------------------
|  BREAK [on/off]       |  Turn BREAK on or off
|  CALL ...             |  Run a batch file and return to your program
|  CD/CHDIR ...         |  Change directory
|  CLS                  |  Clear the screen or the current window
|  COMMAND [/c ...]     |  Run COMMAND.COM
|  COPY ...             |  Copy file(s) (COPY is handled by COMMAND.COM)
|  DEL/ERASE ...        |  Delete file(s)
|  DIR [/p][/w]         |  Show a list of files in a directory
|  ECHO ...             |  Write text to the screen
|  EXIT                 |  Exit program and return to DOS
|  FOR %%C in (list) do ... |  Set the variable %%C to all items of list and perform a command
|  GOTO label           |  Go to another line in the batch file (a label is any word after a colon ":")
|  IF [NOT] EXIST ...   |  If the file exists, then ...
|  IF ERRORLEVEL x ...  |  If the ERRORLEVEL is x or below x, then ...
|  IF ... == ...        |  If the two strings are equal, then ...
|  MD/MKDIR ...         |  Create a new directory
|  PATH ...             |  Set or show the PATH
|  PAUSE [...]          |  Wait for a keystroke
|  PROMPT ...           |  Change the DOS prompt
|  REM ...              |  Remark
|  RD/RMDIR ...         |  Remove a directory
|  REN/RENAME ...       |  Rename a file or a group of files
|  SET [var=[value]]    |  Set an environment variable (Note: All variables are restored after running the program)
|  SHIFT                |  Move all parameters (%1, %2, ..) one place back
|  TYPE ...             |  Show the contents of a file
|  VER                  |  Show the current DOS version
|  VERIFY [on | off]    |  Set VERIFY on or off
|  VOL ...              |  Show the volume of a drive

## Special characters in strings
Available for the commands ECHO, PAUSE, IF and SET:

     $g    ">"              $q    "="                $s    <Space>
     $l    "<"              $h    <BackSpace>        $e    <Esc>
     $b    "|"              $_    <CR/LF>            $$    "$"
     $(n)  ASCII number

     $  at the end of a line:  No <CR>


## Variables

Besides the environment variables you may also define up to 100
32-bit variables to work with numbers. You can set these variables to
integer numbers in the range -2147483648...+2147483647.

### Variable commands

| Syntax                 | Description
|------------------------|----------------------
| VAR varname [=number]  | Define a new variable (if no number is specified the variable is set to 0)
| LET var = number       | Set the variable to a new value
| LET var1 = var2        | Copy the value of var2 into var1
| LET var = %1           | If %1 is not a valid number, the ERRORLEVEL is set to the position of the error
| LET var = ERRORLEVEL   | Sets var to the current errorlevel
| ADD var, x             | Add the value of x to var
| SUB var, x             | Subtract the value of x from var
| NEG var                | Change the sign of var (+/-)
| ABS var                | If var < 0 then the sign is changed
| MUL var, x             | Multiply var with x
| DIV var, x             | Integer division

### Writing variable numbers

        ECHO ... %VAR% ...      Show the number of VAR (decimal)
        ECHO %VAR:10%           Use 10 spaces for the number (like this: "       123")
        ECHO %VAR:-10%          Spaces after the number ("123       ")
        ECHO %VAR:010%          Use "0" instead of spaces ("0000000123")
        ECHO %VAR:b%            Show the binary value ("1111011")
        ECHO %VAR:X%            Show the hexadecimal value ("7B")
        ECHO %VAR:x%            The same, but use lowercase letters ("7b")
        ECHO %VAR:o%            Show the octal value (173)

### Comparing variables

        IF %var1% = %var2% ...    If the two variables are the same then ...
        IF %var1% <> %var2% ..    If the variables are different then ...
        IF %var1% > %var2% ...    If var1 is larger than var2 then ...
        IF %var1% < %var2% ...    If var1 is smaller than var2 then ...
        IF %var1% >= %var2% ..    If var1 is larger than or equal to var2 then ...
        IF %var1% <= %var2% ..    If var1 is smaller than or equal to var2 then ...

- You may always insert the word NOT to reverse the condition
- If you compare strings with <, >, <= or >=, first the length is compared

## GOSUB and RETURN

You can create subroutines in your programs by using these commands. Example:

     GoTo Start
     :Proc1
     ...
     Return
     :Start
     ...
     GoSub Proc1
     ...
     GoSub Proc1

You can run the same procedure as often as you like without having to write it again.

- NOTE: Never go to a subroutine using the GOTO command. 
- RETURN without GOSUB could cause the system to crach.

## Other commands

| Command        | Description
| -------------- | ---------------
| CRT            |  After this command all the output to screen is written directly to the video buffer
| DOS            |  Use DOS routines to handle output to screen
| SETCOLOR n     |  Change the attribute. Only if CRT procedures are installed (valid attributes are 0..255 or $00..$FF)
| MOVETO x, y    |  Change the position of the cursor
| SETWINDOW x1, y1, x2, y2  |   Define a window (Use this command before CLS, FILLWINDOW, FRAMEWIN, MENU, SCROLL). Default: 1, 1, 80, 25
| SCROLL n       |  Scroll the current window n lines up (or down: n < 0)
| FRAMEWINDOW  chars, title   |   Draw a frame in the current window. Chars is either DOUBLEFRAME or SINGLEFRAME or the characters to be used in the frame, eg. ╔═╗║║╚═╝. Title is any text
| FILLWINDOW n   |  Fills the window with one character (n = 0..255)
| CHECKANSI      |  Set the errorlevel to 1 if ANSI.SYS is installed
| GETSCREEN      |  Save the contents of the entire screen in memory
| PUTSCREEN      |  Restores the last screen saved by GETSCREEN or LOADSCREEN
| SAVESCREEN file | Save a screen to the disk
| LOADSCREEN file | Load a screen from the disk into memory (use PUTSCREEN to display it)
| COUNTPARAMS    |  Set the errorlevel to the number of parameters

## Menus

    MENU [c1,] [c2,] [c3,] "[" ~O~ption1 "/" O~p~tion2 [/...] "]" [";"]

    c1           Attribute of highlighted bar
    c2           Attribute of hot keys
    c3           Attribute of hot key in highlighted bar
    ~X~          Hot key
    ";"          Return if the user presses <-- or --> (errorlevel 254, 255)

If the user presses a hot key or <Enter>, the errorlevel will be set to the
number of the option. If <Esc> is pressed the errorlevel is set to 0.
Example:

    Cls
    SetWindow 10, 5, 20, 9
    FrameWindow SingleFrame, Menu 
    SetWindow 11, 6, 19, 8
    Menu $70, $0F, $70, [ ~E~dit / ~R~un / ~Q~uit ]
    if ErrorLevel 3 GoTo Quit
    if ErrorLevel 2 GoTo Run
    ...

## Input and other commands / functions:

| Command              | Description
| -------------------- | ---------------
| ASK ["prompt"], keylist   |  Set the errorlevel to the position in the list
| ASKYN ["prompt"]     |  Yes: errorlevel = 1, No errorlevel = 0
| GETKEY               |  Set the errorlevel to the ASCII value of a keystroke
| GETKBFLAGS           |  Set the errorlevel to the keyboard flags byte
| SETKBFLAGS <var>     |  Change the keyboard flags
| SETBIT n <var>       |  Set bit n of <var> to 1
| RESETBIT n <var>     |  Set bit n of <var> to 0
| GETBIT n <var>       |  Set the errorlevel to the value of bit n of <var> (see keyboard flag bits table below)
| INPUT <Env-var>      | Input any environment variable (from the keyboard)
| IF KEYPRESSED ...    | If the user has pressed any key on the keyboard then ...
| GETX <var>           | Store the cursor position in a variable
| GETY <var>           | Store the cursor line in a variable
| GETCURSOR <var>      | Store the cursor size in a variable
| SETCURSOR <var>      | Set the size of the cursor (default $0B0C, block cursor: $001F, no cursor: $1F00)
| DISKFREE <var>       | Get the free space on a disk into a variable
| UPPERCASE <env-var>  | Change all letters in a variable to capitals
| LOWERCASE <env-var>  | Change the capitals into lowercase letters
| GETDRIVE <env-var>   | Set an environment variable to the current drive
| GETDIR <env-var>     | Set a variable to the current directory
| GETDAY <env-var>     | Set a variable to the day of the week
| GETDATE <env-var>    | Set a variable to the current date
| GETTIME <env-var>    | Set a variable to the current time
| GETLENGTH <env-var>  | Set the errorlevel to the length of the var
| CHECKERRORS ON|off   | if on the program will stop and ask the user wether to continue or not. If off, the error number is stored in the ERRORLEVEL (see example below)
| BEEP                 | Make a short sound.
| GETRANDOM            | Set the errorlevel to a random number (0..255)
| WRITECHAR n1 [,n2]   | Write 1 (or n2) character(s) with ASCII code n1
| INLINE n1, n2, ...   | Use machine language in your programs (Hex numbers only), for example "INLINE cd 05" will print the screen. An INLINE procedure may destroy the values of the registers AX, BX, CX, DX, SI, DI and BP. The other registers must be restored.

        Keyboard flag bits:

        76543210
        .......1      Right Shift key pressed
        ......1.      Left Shift key pressed
        .....1..      Ctrl key pressed
        ....1...      Alt key pressed
        ...1....      ScrollLock on
        ..1.....      NumLock on
        .1......      CapsLock on
        1.......      Insert mode on

Example for CheckErrors:

      CheckErrors OFF
      ChDir %1
      if ErrorLevel 1 Echo THERE IS NO DIRECTORY NAMED "%1".

There are two ways to run an external program:

- Type only the name. A copy of COMMAND.COM is loaded and searches all
  directories of the PATH for the program. If the program is not found,
  you will get the message "Bad command or filename".
- Type the full pathname and extension ("C:\UTIL\BC.EXE"). Use this
  method if you want to know what errorlevel is left by the program.

## EXAMPLES

To learn more about BATCHCOM, take a look at the examples in the EXAMPLES folder. 
BATCHCOM programs usually have the extension .BC, because they can't be run as normal .BAT files.

# TINY

The program TINY compresses .COM programs to make them even smaller.

