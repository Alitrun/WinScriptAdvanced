unit ScriptEngines;

interface

uses
  Windows, ExtraFuncs, Classes, SysUtils, Messages, BaseScript, COMScriptEngine;

const
  TIMEOUT_TERMINATE = 2000;
  { waiting for exe parser (that executes a script) to close. Usually it takes ~150 - 200 ms (AHK, PHP) }

type
  TScriptActiveX = class(TScript)
  protected
    procedure RunScript(const aScriptText: string); override;
    function FormatFileNameToScript(const aPath: string): string; override;
  end;


  { class that runs scripts with exe interpretetor. This is for script engines that do not support
   IActiveScript interace or has problems with it (like Perl IActiveParser that cann't read variables
   values after script was executed or Ruby that creates Access Violation on init.
   Read details in ScriptEngine.pas) or stopped supporting IActiveScript like PHP.
  }
  TScriptExeParser = class(TScript)
  strict private
    fExeParserPath: string;
    fExeArgs: string;
    fScriptExt: string;    // with dot - '.ahk', '.php'
    fFileNameVarFormat: string; // e.g. ahkVarFormat = filename=%s
    fStdOutFormat: string;      // e.g: ahkStdOutFormat = FileAppend, %s `n, *
  protected
    function StartParserGetResults(const aScriptFilePath: string;
           out aOutPut: AnsiString): boolean; virtual;
    function FormatFileNameToScript(const aPath: string): string; override;
    procedure RunScript(const aScriptText: string); override;
    function PrepareScriptText(const aPath: string): string; override;
  public
    constructor Create(const aParams: TScriptParamsRec; const aParserPath, aArgs, aScriptExt,
        aFileNameVarFormat, aStdOutFormat, aExtensions: string);
  end;


  TPowerShell = class(TScript)
  strict private
    fPSStarted: boolean;
    fPSWindow: THandle;
    fProcessHandle: THandle;
    fEndScriptLines: string;        // add to a script code that saves script results to file
    fResltFilePath: string;        // file with results, that was created from PS script
    fFirstKeyStrokeDone: boolean;
    function StartPowerShell: boolean;
    function FindPSWindow(aProcessId: THandle): THandle;
    procedure EnterKeyStorkesToPS(const aCMD: string);
    function WaitForFileAndReadAll(const aPath: string; out aContent: ansistring): boolean;
  protected
    function FormatFileNameToScript(const aPath: string): string; override;
    function PrepareScriptText(const aPath: string): string; override;
    procedure RunScript(const aScriptText: string); override;
  public
    constructor Create(const aParams: TScriptParamsRec; const aExtensions: string);
    destructor Destroy; override;
  end;


implementation

const
  READ_BUF_SIZE = 4096;
  TEMP_FILENAME = 'WinScriptAdvFile_';
  // powershell:
  PS_RESULT_FILENAME = 'wsa_PS_Result.wsa';   // file name where PS script saves result vars

{ TScriptActiveX }

{ Prepare line 'filename = "Path"' for a particular script language format.
   This line will be added at the beginning of the script code.  }
function TScriptActiveX.FormatFileNameToScript(const aPath: string): string;
begin
    // double slashes or single?
  if fParams.DoubleSlash then
    Result := MakeDoubleSlashPath(aPath)
  else
    Result := aPath;

  case fParams.Language of
    slVBScript, slJScript, slPython:
        Result := 'filename="' + Result + '"'#13#10;
    else Assert(false);
  end;
  // PERL: Result := '$filename = "' + Result + '";'#13#10
end;

{Creates ScriptEngine - IActiveScript and IActiveScriptParse and destroy it after using script.
	This is the normal operating mode for IActiveScript.
	We cant reset or reinit it - cause we will use another script code. We can only re-execute same
	code but it's not our case - cause again - we have changed script code (another filename) or
	changed sciptcode fully with another script text.
	Read http://e.craft.free.fr/ActiveScriptingLostFAQ/hostrun.htm
	(What is the easiest way to re-execute a script) }

procedure TScriptActiveX.RunScript(const aScriptText: string);
var
  vScriptEngine: TActiveXScriptEngine;
begin
  vScriptEngine := TActiveXScriptEngine.Create(fParams.Language);
  try
    if vScriptEngine.StartScript(aScriptText) then
      vScriptEngine.LoadScriptVarsValues(fVarsNamesAr, fResultVarsAr)
    else
      fResultVarsAr[0] := vScriptEngine.LastErrorText;
  finally
    vScriptEngine.Free;
  end;
end;


{ TScriptExeParser }

constructor TScriptExeParser.Create(const aParams: TScriptParamsRec; const aParserPath, aArgs, aScriptExt,
        aFileNameVarFormat, aStdOutFormat, aExtensions: string);
begin
  inherited Create(aParams, aExtensions);
  fExeParserPath := aParserPath;
  fExeArgs := aArgs;
  fScriptExt := aScriptExt;
  fFileNameVarFormat := aFileNameVarFormat;
  fStdOutFormat := aStdOutFormat;
end;

function TScriptExeParser.FormatFileNameToScript(const aPath: string): string;
begin
    // double slashes or single?
  if fParams.DoubleSlash then
    Result := MakeDoubleSlashPath(aPath)
  else
    Result := aPath;
  Result := Format(fFileNameVarFormat, [Result]) + #13#10;
end;

function TScriptExeParser.PrepareScriptText(const aPath: string): string;
var
  i: Integer;
  vStr: string;
begin
  // in base inherited method of PrepareScriptText - add filename variable to script text
  Result := inherited;

  // now add commands to write to console StdOut, print all variables with name "content", "contentX"

  for i := 0 to High(fVarsNamesAr) do
  begin
    vStr := Format(fStdOutFormat, [fVarsNamesAr[i]]);
    Result := Result + vStr + #13#10;
  end;
end;

procedure TScriptExeParser.RunScript(const aScriptText: string);
var
  vScriptPath: string;
  vAnsiText: AnsiString;
  vAnsiScriptOutput: AnsiString;
  vResult: boolean;

  procedure ParseResultsToArray(const aResults: AnsiString; var aVarsValues: array of string);
  var
    P, Start: PAnsiChar;
    k: integer;
  begin
    Assert(Length(aVarsValues) <> 0);
    P := Pointer(aResults);
    if P = nil then exit;
    k := 0;

    while P^ <> #0 do
    begin
      Start := P;
      while not (P^ in [#0, #10, #13]) do
        Inc(P);

      SetString(aVarsValues[k], Start, P - Start);
      inc(k);
      if k > High(aVarsValues) then exit;

      if P^ = #13 then
        Inc(P);
      if P^ = #10 then
        Inc(P);
    end;
  end;

begin
  vAnsiText := AnsiString(aScriptText);
  // Create temp file with script text.
  vScriptPath := GetTempPath + TEMP_FILENAME + fScriptExt;
  with TFileStream.Create(vScriptPath, fmCreate or fmShareExclusive) do
  try
    Write(@vAnsiText[1], Length(vAnsiText));
  finally
    Free;
  end;

  vResult := StartParserGetResults(vScriptPath, vAnsiScriptOutput);

  // load values
  if vResult then
    ParseResultsToArray(vAnsiScriptOutput, fResultVarsAr)
  else
    fResultVarsAr[0] := string(vAnsiScriptOutput); // error message
end;

function TScriptExeParser.StartParserGetResults(const aScriptFilePath: string;
           out aOutPut: AnsiString): boolean;
const
  PIPE_ENDED = 109;

  // waiting for process to close. If time is out - kill it
  // true - Closed ok, false - terminated by timeout
  function WaitTillClose(aProcess: THandle): boolean;
  const
    WAIT_INTERVAL = 10;   // ms
    { 1. TC creates separate thread for the plugin, so it's ok to sleep it with WaitForSingleObject.
      2. Sleep (same as WaitForSingleObject with WAIT_INTERVAL) - is very light function, and do
      NOT take processor time. Do not confuse with a Heavy "SuspendThread"
      like some (many?) programmers do - it's completely different techniques.
      Sleep causes a thread to relinquish the remainder of its processor time slice.   }
  var
    vTotalTime: integer;
  begin
    Result := true;
    vTotalTime := 0;
    while  WaitForSingleObject(aProcess, WAIT_INTERVAL) <> WAIT_OBJECT_0 do
    begin
      Inc(vTotalTime, WAIT_INTERVAL);
      Result := vTotalTime < TIMEOUT_TERMINATE;

      if not Result then
      begin
        TerminateProcess(aProcess, WAIT_TIMEOUT);
        SetLastError(WAIT_TIMEOUT); // 258: The wait operation timed out.
        exit;
      end;
    end;
  end;

var
  vSecurityAtt: TSecurityAttributes;
  vInReadPipe, vInWritePipe: THandle;
  vOutReadPipe, vOutWritePipe: THandle;
  vStartInfo: TStartUpInfo;
  vProcessInfo: TProcessInformation;
  vBytesRead: DWORD;
  vCommandLine: string;
  vError: integer;
begin
  Result := false;
  vCommandLine := '"' + fExeParserPath + '" ' + fExeArgs + ' "' + aScriptFilePath + '"';

  vSecurityAtt.nLength := SizeOf(TSecurityAttributes) ;
  vSecurityAtt.bInheritHandle := true;
  vSecurityAtt.lpSecurityDescriptor := nil;

  SetLength(aOutPut, READ_BUF_SIZE);
  try
    Result := CreatePipe(vOutReadPipe, vOutWritePipe, @vSecurityAtt, 0);
    if not Result then exit;
    Result := CreatePipe(vInReadPipe, vInWritePipe, @vSecurityAtt, 0);
    if not Result then exit;

    ZeroMemory(@vStartInfo, SizeOf(vStartInfo));
    vStartInfo.cb := SizeOf(vStartInfo) ;
    vStartInfo.hStdError := vOutWritePipe;
    vStartInfo.hStdOutput := vOutWritePipe; //vWritePipe;
    vStartInfo.hStdInput := vInReadPipe;
    vStartInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    vStartInfo.wShowWindow := SW_HIDE;

    Result := CreateProcess(nil, PChar(vCommandLine), @vSecurityAtt, @vSecurityAtt, true, 0, nil, nil,
        vStartInfo, vProcessInfo);
    if not Result then exit;

    Result := WaitTillClose(vProcessInfo.hProcess);
    if not Result then exit;

    vBytesRead := 0;
    CloseHandle(vOutWritePipe); // Or ReadFile(vOutReadPipe) blocks cur thread when if no data in pipe
    vOutWritePipe := 0;
    Result := ReadFile(vOutReadPipe, aOutPut[1], READ_BUF_SIZE, vBytesRead, nil);
    if not Result then exit;

    SetLength(aOutPut, vBytesRead);
    // OemToAnsi(vBuffer, vBuffer) ;
  finally
     if not Result then
     begin
       vError := GetLastError;
       if vError = PIPE_ENDED then
         aOutPut := 'No data from script'
       else
         aOutPut := AnsiString(SysErrorMessage(vError));
     end;
     CloseHandle(vProcessInfo.hProcess);
     CloseHandle(vProcessInfo.hThread);

     CloseHandle(vInReadPipe);
     CloseHandle(vInWritePipe);
     CloseHandle(vOutReadPipe);
     if vOutWritePipe <> 0 then
       CloseHandle(vOutWritePipe);
  end;
end;


{ TPowerShell }

{Problem of PowerShell - Can't read and write to stdpipe from\to powershell native blue console (-noexit).
 Reason: Need to close PS and then can get output (in cmd.exe) else no data in pipe (read\write) (btw I tried
 to read from simple cmd.exe - write and read are working - but if I start PS with -noexit flag in cmd.exe - I already
 can't read output or write input until PS exit).
 I tried various methods from msdn - https://support.microsoft.com/en-us/kb/190351    or
 classic https://msdn.microsoft.com/en-us/library/windows/desktop/ms682499(v=vs.85).aspx  both in
 cmd.exe console + PS and in simple PS.exe blue console - nothing work.

 But we can't close it, PS must be running always until plugin has closed, cause Powershell slow as hell
 while starting -  it took about 5 seconds from starting exe to showing 'Hello world' text(!) (I just
 started ps1 script). So we need another method to input text to running PS and get output.

 Input - I decided to search hidden window, and emulate keystrokes to PS.
 OutPut - save variables to file from PS script. This part (saving to file) will be added to the end of a script
 by the plugin.
}
constructor TPowerShell.Create(const aParams: TScriptParamsRec; const aExtensions: string);

  function PrepareEndOfScript(const aPathToResltFile: string): string;
  const
    PS_LINE1 = '$file = new-object System.IO.StreamWriter("%s")'#13#10;
    PS_CONT_LINE = '$file.WriteLine($%s)'#13#10;
  var
    i: Integer;
  begin
    Result := Format(PS_LINE1, [aPathToResltFile]);
    Result := Result + Format(PS_CONT_LINE, [SCRIPT_VAR_NAME]); // adds '$file.WriteLine($content)'

    // add $file.WriteLine($content1), $file.WriteLine($content2) etc
    for i := 1 to fParams.ResultsCount - 1 do
      Result := Result + Format(PS_CONT_LINE, [SCRIPT_VAR_NAME + IntToStr(i)]);

    Result := Result + '$file.close()';
    {
    $file = new-object System.IO.StreamWriter("d:\temp\wsa_PS_Result.wsa")
    $file.WriteLine($content)
    $file.WriteLine($content1)
    $file.WriteLine($contentX)
    $file.close()}
  end;

begin
  inherited;
  fResltFilePath := GetTempPath + PS_RESULT_FILENAME; // save it for WaitForFileAppear func
  DeleteFile(fResltFilePath);

  fEndScriptLines := PrepareEndOfScript(fResltFilePath);
end;

//
destructor TPowerShell.Destroy;
begin
  TerminateProcess(fProcessHandle, 0);
  inherited;
end;

function TPowerShell.FormatFileNameToScript(const aPath: string): string;
begin
  Result := '$filename="' + aPath + '"' + #13#10;
end;

function TPowerShell.PrepareScriptText(const aPath: string): string;
begin
  Result := inherited;
  // add special lines to end of script to save results to file
  Result := Result + #13#10 + fEndScriptLines;
end;

// PrepareScriptText already done in RunScript
procedure TPowerShell.RunScript(const aScriptText: string);

  procedure ReadResults(const aContent: ansistring);
  var
    i: integer;
  begin
    with TStringList.Create do
    try
      Text := string(aContent);
      for i := 0 to Count - 1 do
      begin
        if i <= High(fVarsNamesAr) then
          fResultVarsAr[i] := Strings[i];
      end;
    finally
      Free;
    end;
  end;

  procedure CreateScriptFile(const aPath: string; const aScriptText: ansistring);
  var
    vHandle: THandle;
  begin
    // check if file was locked, then read it if not
    repeat
      vHandle := FileCreate(aPath);
      if vHandle <> INVALID_HANDLE_VALUE then
      begin
        FileWrite(vHandle, aScriptText[1], Length(aScriptText));
        FileClose(vHandle);
        break;
      end;
      sleep(10);
    until false;
  end;

var
  vScriptPath: string;
  vContent: ansistring;
begin
  // start PowerShell once with -noexit flag
  if not fPSStarted then
  begin
    fPSStarted := StartPowerShell;
    if not fPSStarted then exit;
  end;

  // Create temp file with script text. Also check if file was locked
  vScriptPath := GetTempPath + TEMP_FILENAME + '.ps1';
  CreateScriptFile(vScriptPath, AnsiString(aScriptText));

  // send (type) path to script file
  if fFirstKeyStrokeDone then  // optimizing
  begin
    PostMessage(fPSWindow, WM_KEYDOWN, VK_UP, 0);
    PostMessage(fPSWindow, WM_KEYDOWN, VK_RETURN, 0);
  end
  else
  begin
    // path for PowerShell. path with spaces has spec syntax: '&("e:\My Scripts\testPowerShell.ps1")'
    vScriptPath := '&("' + vScriptPath + '")';

    EnterKeyStorkesToPS(vScriptPath);
    fFirstKeyStrokeDone := true;
  end;

  if WaitForFileAndReadAll(fResltFilePath, vContent) then
  begin
    ReadResults(vContent);
    DeleteFile(fResltFilePath);
  end;
end;

// Emulates key strokes and press Enter at the end
procedure TPowerShell.EnterKeyStorkesToPS(const aCMD: string);
var
  i: Integer;
begin
  Assert(fPSWindow <> 0);
  for i := 1 to High(aCMD) do
    SendMessage(fPSWindow, WM_CHAR, Ord(aCMD[i]), 0);

  PostMessage(fPSWindow, WM_KEYDOWN, VK_RETURN, 0);
end;

// start PS only once, and do not exit
function TPowerShell.StartPowerShell: boolean;
var
  vStartInfo: TStartUpInfo;
  vProcessInfo: TProcessInformation;
  vCommandLine: string;
begin
  vCommandLine := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -noexit -nologo -NonInteractive';
  UniqueString(vCommandLine);

  ZeroMemory(@vStartInfo, SizeOf(vStartInfo));
  vStartInfo.cb := SizeOf(vStartInfo) ;
  vStartInfo.dwFlags := STARTF_USESHOWWINDOW;
  vStartInfo.wShowWindow := SW_HIDE;

  Result := CreateProcess(nil, PChar(vCommandLine), nil, nil, true, 0, nil, nil,
      vStartInfo, vProcessInfo);
  if not Result then exit;

  CloseHandle(vProcessInfo.hThread);
  Sleep(1000); // wating for PS starting. Usually it takes ~5 sec
  fProcessHandle := vProcessInfo.hProcess;
  fPSWindow := FindPSWindow(vProcessInfo.dwProcessId);
  Assert(fPSWindow <> 0);
end;

// false = time is out - file wasn't appeared
// Combined with ReadFromFile cause using CreateFile to check if file locked.
function TPowerShell.WaitForFileAndReadAll(const aPath: string; out aContent: ansistring): boolean;
const
  TIMEOUT = 6000;
  INTERVAL = 10;
var
  vTicks: integer;
  vHandle: THandle;
  vSize: integer;
begin
  vTicks := 0;
  while not FileExists(aPath) do
  begin
    Sleep(INTERVAL);
    inc(vTicks, INTERVAL);
    if vTicks = TIMEOUT then
      exit(false);
  end;

  // check if file was locked, then read it if not
  repeat
    vHandle := FileOpen(aPath, fmOpenRead or fmShareExclusive);
    if vHandle <> INVALID_HANDLE_VALUE then
    begin
      vSize := FileSeek(vHandle, 0, 2);
      SetLength(aContent, vSize);
      FileSeek(vHandle, 0, 0);
      FileRead(vHandle, aContent[1], vSize);
      FileClose(vHandle);
      exit(true);
    end;
    sleep(INTERVAL);
  until false;
end;

type    // EnumWindowsProc data
  PTempData = ^TTempData;
  TTempData = record
    PSProcessID: DWORD;
    ReturnHandle: THandle;
  end;

 // do not do this proc nested. In x64 it will crash
function EnumWindowsProc(aWindow: HWND; aData: PTempData): Bool; stdcall;
var
  vProcessID: DWORD;
begin
  Result := true; // true = continue
  GetWindowThreadProcessId(aWindow, @vProcessID);
  if aData^.PSProcessID = vProcessID then
  begin
    aData^.ReturnHandle := aWindow;
    Result := false;         // PS has only one Window (Win 10)
  end;
end;

function TPowerShell.FindPSWindow(aProcessId: THandle): THandle;
var
  vData: TTempData;
begin
  vData.PSProcessID := aProcessId;
  vData.ReturnHandle := 0;
  // EnumThreadWindows does not work with PowerShell ThreadId - nothing
  EnumWindows(@EnumWindowsProc, Lparam(@vData));

  Result := vData.ReturnHandle;
end;


end.
