unit ExtraFuncs;

interface

uses
	Windows, Classes, SysUtils;


type
	TSomeChars = set of AnsiChar;   // function TrimLeftChars(

	{ TStringList uses while compare strings WinAPI CompareString,
		but Delphi CompareText\CompareStr is ~7 times faster.
		Used while sorting lists.
	}

	TMyStringList = class(TStringList)
	protected
		function CompareStrings(const S1: string; const S2: string): Integer; override;
  end;


{ Cache for script results. We need it for such situation:
	User choose to sort script results by one of column, so TC first will ask the plugin only for this one column
	for ALL files in a current directory, then TC will ask for the rest of columns for the same files.
	So we need to cache these results at the first request, so script runs only once per file.
	When current folder is changed cache will be purged.
}
	PScriptValues = ^TScriptValues;
	TScriptValues = array of string;          // 3

	PCachedValues = ^TCachedValues;           // 2
	TCachedValues = record
		ScriptID: integer;
		Values: TScriptValues;
	end;

	PCacheArray = ^TCacheArray;               // 1 - main array that contains 2 and 3
	TCacheArray = array of TCachedValues;


	TFieldsCache = class
	strict private
		fFileNames: TMyStringList;
	public
		constructor Create;
		destructor Destroy; override;
		procedure AddToCache(const aScriptValues: array of string; const aFileName: string; aScriptID: integer);
		function FindValues(const aFileName: string; aScriptId: integer; out aValues: PScriptValues): boolean;
		procedure Clear;
	end;

	// check strings length, if same length then compare strings
	function IsSameStrings(const aStr1, aStr2: string): boolean;
	function TrimLeftChars(const aStr: string; const aChars: TSomeChars; out aResultStr: string): boolean;
	function MakeDoubleSlashPath(const aPath: string): string;
  function GetTempPath: string;
  procedure ShowMsg(const aText: string);
  function ExpandEnvironmentPath(const aPathWithEnvVar: string): string;

implementation


function IsSameStrings(const aStr1, aStr2: string): boolean;
begin
	Result := false;
	if Length(aStr1) = Length(aStr2) then
		Result := CompareStr(aStr1, aStr2) = 0;
end;

// usually this used for standart chars like space or #9 (tab char), so while comparing we using AnsiChar
function TrimLeftChars(const aStr: string; const aChars: TSomeChars; out aResultStr: string): boolean;
var
	i, L: Integer;
begin
	L := aStr.Length;
	i := 1;
	while (i <= L) and (AnsiChar(aStr[i]) in aChars) do
		Inc(i);

	Result := i > 1;
	if Result then
		aResultStr := aStr.SubString(i-1)
	else
		aResultStr := aStr;
end;

function MakeDoubleSlashPath(const aPath: string): string;
var
	i: integer;
begin
	Result := aPath;
	for i := High(Result) downto 1 do
		if Result[i] = '\' then
			Insert('\', Result, i);
end;

// The returned string ends with a backslash, for example, "C:\TEMP\".
function GetTempPath: string;
var
  vLen: integer;
begin
  SetLength(Result, MAX_PATH);
  vLen := Windows.GetTempPath(MAX_PATH, Pchar(Result));
  if vLen > 0 then
    SetLength(Result, vLen)
  else
    Result := '';
end;

procedure ShowMsg(const aText: string);
begin
  MessageBox(0, Pchar(aText), 'WinScriptAdv plugin (wdx)', MB_ICONINFORMATION);
end;

function ExpandEnvironmentPath(const aPathWithEnvVar: string): string;
var
  vReturnSize: integer;
  vBuf: array [0..1023] of char;
begin
  vReturnSize := ExpandEnvironmentStrings( Pchar(aPathWithEnvVar), @vBuf[0], Length(vBuf) ); // not size!
  if vReturnSize > 0 then
    Result := vBuf;
end;



{ TMyStringList }

function TMyStringList.CompareStrings(const S1, S2: string): Integer;
begin
	if CaseSensitive then
		Result := CompareStr(S1, S2)
	else
		Result := CompareText(S1, S2);
end;



{ TMemCache }

constructor TFieldsCache.Create;
begin
	fFileNames := TMyStringList.Create;
	fFileNames.CaseSensitive := true;
	fFileNames.Sorted := true;
end;

destructor TFieldsCache.Destroy;
begin
	fFileNames.Free;
	inherited;
end;

procedure TFieldsCache.AddToCache(const aScriptValues: array of string; const aFileName: string;
	aScriptID: integer);
var
	vIndex, i: integer;
	vCacheArray: PCacheArray;
	vAddNew: boolean;
begin
	vAddNew := false;
	if not fFileNames.Find(aFileName, vIndex) then
	begin
		New(vCacheArray);     // free in ClearCache
		vAddNew := true;
	end
	else
		vCacheArray := PCacheArray(fFileNames.Objects[vIndex]);

	SetLength(vCacheArray^, Length(vCacheArray^) + 1);  // create new or enlarge (TCachedValues record)
	with vCacheArray^[High(vCacheArray^)] do
	begin
		ScriptID := aScriptID;
		SetLength( Values, Length(aScriptValues) );
		for i := 0 to High(Values) do
			Values[i] := aScriptValues[i];
	end;

	if vAddNew then
		fFileNames.AddObject(aFileName, TObject(vCacheArray));
end;

function TFieldsCache.FindValues(const aFileName: string; aScriptId: integer;
	out aValues: PScriptValues): boolean;
var
	i, vIndex: integer;
	vCacheArray: PCacheArray;
begin
	aValues := nil;
	Result := fFileNames.Find(aFileName, vIndex);
	if Result then
	begin
		vCacheArray := PCacheArray( fFileNames.Objects[vIndex] );

		for i := 0 to High(vCacheArray^) do
			if vCacheArray^[i].ScriptID = aScriptId then
			begin
				aValues := @vCacheArray^[i].Values;
				break;
			end;

		Result := aValues <> nil;
	end;
end;

procedure TFieldsCache.Clear;
var
	i, k: integer;
	vCacheArray: PCacheArray;
begin
	for i := 0 to fFileNames.Count - 1 do
	begin
		vCacheArray := PCacheArray( fFileNames.Objects[i] );
		for k := 0 to High(vCacheArray^) do
			SetLength(vCacheArray^[k].Values, 0);

		SetLength(vCacheArray^, 0);
		Dispose(vCacheArray);
	end;
	fFileNames.Clear;
end;


end.
