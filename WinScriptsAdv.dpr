{ Windows Script content (wdx) plugin for Total Commander, x86\x64
  Created with Delphi XE5
 (C) Alex Shy (Alex Shyshko), 2016
}

library WinScriptsAdv;


{$R *.res}
{$IFDEF Win64}
	{$E .wdx64}
{$ELSE}
  {$E .wdx}
{$ENDIF}

{$IFDEF RELEASE}   // set size smaller
  {$WEAKLINKRTTI ON}
  {$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$ENDIF}

uses
  Windows,
  contplug in 'contplug.pas',
  System.SysUtils,
  AnsiStrings,
  Core in 'Core.pas',
  BaseScript in 'BaseScript.pas',
  ExtraFuncs in 'ExtraFuncs.pas',
  COMScriptEngine in 'COMScriptEngine.pas',
  ScriptEngines in 'ScriptEngines.pas';

{$IFDEF RELEASE}   // set size smaller
	{$SETPEFLAGS IMAGE_FILE_DEBUG_STRIPPED or IMAGE_FILE_LINE_NUMS_STRIPPED or
			IMAGE_FILE_LOCAL_SYMS_STRIPPED}
{$ENDIF}

function ContentGetSupportedField(FieldIndex: integer; FieldName, Units: PAnsiChar;
	Maxlen: integer): integer; stdcall;
var
	vStr: ansistring;
begin
	if gCore.GetFieldTitle(FieldIndex, vStr) then
	begin
		AnsiStrings.StrLCopy(FieldName, PAnsiChar(vStr), Maxlen);
		Result := ft_String;
	end
	else
		Result := ftNoMoreFields;
end;

function ContentGetValue(FileName: PAnsiChar; FieldIndex, UnitIndex: integer; FieldValue: pbyte;
	Maxlen, Flags: integer): integer; stdcall;
begin
	Result := ft_NoSuchField;
end;

function ContentGetValueW(FileName: PChar; FieldIndex, UnitIndex: integer; FieldValue: PChar;
	Maxlen, Flags: integer): integer; stdcall;
var
	vValue: string;
begin
  if (Flags and CONTENT_DELAYIFSLOW) > 0 then
  begin
    Result:= FT_DELAYED;
    Exit;
  end;
	if gCore.GetFieldValue(FieldIndex, FileName, vValue) then
	begin
		StrLCopy(FieldValue, Pchar(vValue), Maxlen);
		Result := ft_StringW;
	end
	else
		Result := ft_FieldEmpty;
end;


procedure ContentGetDetectString(DetectString: PAnsiChar; Maxlen: integer); stdcall;
begin

end;

exports
	ContentGetSupportedField,
	ContentGetValue,
	ContentGetValueW,
	ContentGetDetectString;

begin


end.
