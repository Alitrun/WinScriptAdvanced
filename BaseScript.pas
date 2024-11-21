unit BaseScript;

interface

uses
	Windows, Classes, Contnrs, SysUtils, ExtraFuncs;

const
	EXT_DELIMITER = '|'; // wav|mp3|doc
	SCRIPT_VAR_NAME = 'content'; // base name for the result variable of script - content, content1 .. content20

type
	TScriptLanguage = (
      slUnknown, slVBScript, slJScript, slPython,  // these languages work via IActiveSCript
      slAutoHotKey, slPHP, slAutoIt, slPowerShell);                        // these work via direct exe parser
  TStrArray = array of string;

  TScriptParamsRec = record
    ScriptText: string;
    ColOffset: integer;
    UseDirs: boolean;
    Language: TScriptLanguage;
    DoubleSlash: boolean;
    ResultsCount: integer;
  end;

	TScript = class;

	TScriptsMan = class
	private
		fScriptsList: TObjectList;
		fColumnsIndex: TList; // to quickly find the right script for the column index. Count is the total num of columns
		procedure AddNewColumns(aColumnsCount: integer; aScript: TScript);
		procedure OptimizeScriptText(aScript: TStringList; aLanguage: TScriptLanguage);
	private // caching routins.
		fCurrentDir: string;
		fCache: TFieldsCache;
	public
		constructor Create;
		destructor Destroy; override;
		procedure AddScript(const aFilePath, aExtensions, aParserPath, aArgs, aFileNameVarFormat,
      aStdOutFormat: string; aColumnsCount: integer; aUseDirs, aDoubleSlash: boolean);
		function GetColumnValue(aIndex: integer; const aPath: string; out aValue: string): boolean;
	end;


	TScript = class
	strict private
		fExtensions: TMyStringList;
		fAllFilesExt: boolean;
    procedure ResetScriptVars;
  protected
    fParams: TScriptParamsRec;
    fVarsNamesAr: TStrArray;     // allocated once 'content, content1,..' strings
    fResultVarsAr: TStrArray;    { Why not TStrings? Cause in this case  the cache is more faster, less mem
     to use with arrays, than TStrings. Each script has one results array with some strings
     from 1 to 20, one file can have unlimited scripts results.
     For example user activated 4 scripts, each script has one array with 2 strings.
     So one file have = 4 arrays of strings. Current dir has 100 files - so 400 arrays cached,
     so it's faster to use arrays than TStringList }
    function FormatFileNameToScript(const aPath: string): string; virtual; abstract;
    function PrepareScriptText(const aPath: string): string; virtual;
    procedure RunScript(const aScriptText: string); virtual; abstract;
	public
		constructor Create(const aParams: TScriptParamsRec; const aExtensions: string);
		destructor Destroy; override;
		function FileFitCriteria(const aPath: string): boolean;
		procedure Run(const aPath: string);
	end;



implementation

uses
  ScriptEngines; // to init ScriptEngines in TScriptsMan.AddScript (to create TScript and
  // inherited classes in one constructor-method )

{ TScriptsMan }

constructor TScriptsMan.Create;
begin
	fScriptsList := TObjectList.Create;
	fColumnsIndex := TList.Create;
	fCache := TFieldsCache.Create;
end;

destructor TScriptsMan.Destroy;
begin
	fScriptsList.Free;
	fColumnsIndex.Free;
	fCache.Free;
	inherited;
end;

procedure TScriptsMan.AddScript(const aFilePath, aExtensions, aParserPath, aArgs, aFileNameVarFormat,
    aStdOutFormat: string; aColumnsCount: integer; aUseDirs, aDoubleSlash: boolean);
var
	vScript: TScript;
	vScriptText: TStringList;
	vSciptLanguage: TScriptLanguage;
  vExt: string;
  vParams: TScriptParamsRec;
begin
	// Detect Script Language
  vSciptLanguage := slUnknown;
  vExt := LowerCase(ExtractFileExt(aFilePath));
  if vExt = '.vbs' then
    vSciptLanguage  :=	slVBScript
  else if vExt = '.js' then
    vSciptLanguage := slJScript
  else if vExt = '.ps1' then
    vSciptLanguage := slPowerShell
  else if (vExt = '.py') or (vExt = '.pys') then
    vSciptLanguage := slPython
  else if vExt = ('.ahk') then
    vSciptLanguage :=  slAutoHotKey
  else if vExt = ('.php') then
    vSciptLanguage :=  slPHP
  else if vExt = ('.au3') then
    vSciptLanguage := slAutoIt;

  Assert(vSciptLanguage <> slUnknown);

	// load script text
	vScriptText := TStringList.Create;
	try
		vScriptText.LoadFromFile(aFilePath);
		OptimizeScriptText(vScriptText, vSciptLanguage);

    vParams.ScriptText := vScriptText.Text;
    vParams.ColOffset := fColumnsIndex.Count;
    vParams.UseDirs := aUseDirs;
    vParams.Language := vSciptLanguage;
    vParams.DoubleSlash := aDoubleSlash;
    vParams.ResultsCount := aColumnsCount;

      // for scripts that do not support IActiveScript
    if (aParserPath <> '') or (vSciptLanguage = slPowerShell) then
    begin
      if vSciptLanguage = slPowerShell then
        vScript := TPowerShell.Create(vParams, aExtensions)
      else
        vScript := TScriptExeParser.Create(vParams, aParserPath, aArgs, vExt, aFileNameVarFormat,
          aStdOutFormat, aExtensions);
    end
    else
      vScript := TScriptActiveX.Create(vParams, aExtensions);
	finally
		vScriptText.Free;
	end;

	fScriptsList.Add(vScript);
	AddNewColumns(aColumnsCount, vScript);
end;

{ fColumnsIndex index is a column (field) number (fColumnsIndex[0] = column num 0 etc.
	Need it for quick access, cause one script can create more than 1 columns,
	and in one panel can be more than 1 scripts )
}
procedure TScriptsMan.AddNewColumns(aColumnsCount: integer; aScript: TScript);
var
	i: integer;
begin
	for i := 1 to aColumnsCount do
		fColumnsIndex.Add(aScript);
end;

function TScriptsMan.GetColumnValue(aIndex: integer; const aPath: string; out aValue: string): boolean;
var
	vScript: TScript;
	vDir, vFileName: string;
	vCachedValues: PScriptValues;
begin
	Result := false;
	aValue := '';

	vDir := ExtractFilePath(aPath);
	if not IsSameStrings(fCurrentDir, vDir) then
	begin
		fCurrentDir := vDir;
    fCache.Clear;        // cache files only in current opened dir
	end;

	vScript := TScript(fColumnsIndex[aIndex]);
	if not vScript.FileFitCriteria(aPath) then exit;

	// check maybe we already have this data cached
	vFileName := ExtractFileName(aPath);
	if fCache.FindValues(vFileName, integer(vScript), vCachedValues) then
		aValue := vCachedValues^[aIndex - vScript.fParams.ColOffset]
	else
	begin  // no cached data
		vScript.Run(aPath);
		fCache.AddToCache(vScript.fResultVarsAr, vFileName, integer(vScript));
		aValue := vScript.fResultVarsAr[aIndex - vScript.fParams.ColOffset];
	end;
	Result := true;
end;

// optimize for parser - remove comments, empty lines, trim left
procedure TScriptsMan.OptimizeScriptText(aScript: TStringList; aLanguage: TScriptLanguage);

  procedure CleanScript(aCommentChar: Char);
  var
    vChars: TSomeChars;
  	vTrimmed: boolean;
   	vLine: string;
   	i: integer;
  begin
    vChars := [' ', #9];
    for i := aScript.Count - 1 downto 0 do
		begin
			vTrimmed := TrimLeftChars(aScript[i], vChars, vLine);
			if (Length(vLine) = 0) or (vLine[1] = aCommentChar) then
				aScript.Delete(i)
			else
				if vTrimmed then
					aScript[i] := vLine;
		end;
  end;

begin
  case aLanguage of
    slVBScript:   CleanScript(''''); // '
    slJScript:    CleanScript('/'); // - //
    slPython,
    slPowerShell: CleanScript('#');
    slAutoHotKey,
    slAutoIt:     CleanScript(';');
    slPHP       : CleanScript('/');
  end;
end;


{ TScript }                  // aColCount  DoubleSlash: boolean;
// aParserPath  aScriptExt aFileNameVarFormat - указываем в конструкторе exe

constructor TScript.Create(const aParams: TScriptParamsRec; const aExtensions: string);
var
	i: integer;
begin
  // allow these file extensions to process by script, all another will be ignored
  if aExtensions = '*' then
		fAllFilesExt := true
	else
	begin
		fExtensions := TMyStringList.Create;
		fExtensions.Sorted := true;
		fExtensions.CaseSensitive := true;     // !! Low case ()!`
		fExtensions.Delimiter := EXT_DELIMITER;
		fExtensions.DelimitedText := LowerCase(aExtensions);
	end;
  fParams := aParams;

  // check do path in script need double slash (for registered languages, else use flag DoubleSlashPath
  // from ini file)
  case fParams.Language of
//    slVBScript, slAutoHotKey : fParams.DoubleSlash := false; // + slPerl slRuby
    slJScript, slPython : fParams.DoubleSlash := true;
  end;

	SetLength(fResultVarsAr, aParams.ResultsCount);
  // LoadVarsNames;
	SetLength(fVarsNamesAr, aParams.ResultsCount);
	fVarsNamesAr[0] := SCRIPT_VAR_NAME;  // first result var is alsways named 'content'. then content1 etc..
	for i := 1 to High(fVarsNamesAr) do
		fVarsNamesAr[i] := SCRIPT_VAR_NAME + IntToStr(i);
end;

destructor TScript.Destroy;
begin
	fExtensions.Free;
	inherited;
end;

procedure TScript.ResetScriptVars;
var
	i: integer;
begin
	for i := 0 to Length(fResultVarsAr) - 1 do
		fResultVarsAr[i] := '';
end;

function TScript.FileFitCriteria(const aPath: string): boolean;
var
	vIsDir: boolean;
	vFileExt: string;
begin
	Result := false;

	vIsDir := (GetFileAttributes(PChar(aPath)) and FILE_ATTRIBUTE_DIRECTORY = FILE_ATTRIBUTE_DIRECTORY);
	if vIsDir and not fParams.UseDirs then exit;

	// check if script supports this extension
	if not vIsDir and not fAllFilesExt then
	begin
		vFileExt := LowerCase(ExtractFileExt(aPath));
		if Length(vFileExt) > 0 then
			Delete(vFileExt, 1, 1);  // deletes . ('.wav' = 'wav')
		if fExtensions.IndexOf(vFileExt) = -1 then exit;   // searchs in sorted list, case sens - so it's fastest way
	end;
	Result := true;
end;

  // aPath - path to a file that script will process
procedure TScript.Run(const aPath: string);
begin
	ResetScriptVars;

  RunScript(PrepareScriptText(aPath));
end;

function TScript.PrepareScriptText(const aPath: string): string;
var
  vFilePathProcessing: string;

  // aFileNameVar is smth like (PHP syntax in example): '$filename = 'd:\qwe.txt';#13#10'
  // Result is a ready to start script text
  function AddFileNameVarToScriptText(const aFileNameVar, aScriptText: string): string;
  var
    vPos: integer;
  begin
    { for such scripts, that has tags before working script code, such like php:
     <?php
     ...phpCode
     We  insert filename after line that start from '<'  (<?php)}
    if aScriptText[1] = '<' then
    begin
      Result := aScriptText;
      vPos := Pos(#10, Result);
      Insert(aFileNameVar, Result, vPos + 1)
    end
    else
      Result := vFilePathProcessing + fParams.ScriptText;
  end;

begin
  vFilePathProcessing := FormatFileNameToScript(aPath);
  Result := AddFileNameVarToScriptText(vFilePathProcessing, fParams.ScriptText);
end;


end.
