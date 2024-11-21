unit Core;

interface

uses
	Windows, Classes, Sysutils, IniFiles, BaseScript, ExtraFuncs;

const
	MAX_SCRIPT_FIELDS = 21;
	SCRIPTS_DIR = 'Scripts';
  SPECIFY_PARSER_PATH = 'File does not exists: "%s".'#10'Specify the correct path to "%s", which can process *.%s files (in options.ini)';

type

	TCore = class
	private
		fDupTitleCount: integer;       // if title of column is duplicated then title(1), title(2) etc. See CheckChangeDupTitle
		fColumnsTitles: TStringList;
		fScripts: TScriptsMan;
		procedure LoadOptions;
		procedure CheckAndChangeDupTitle(var aTitle: string);
	public
		constructor Create;
		destructor Destroy; override;
		function GetFieldTitle(aField: integer; out aTitle: ansistring): boolean;  // false = no more fields
		function GetFieldValue(aField: integer; const aPath: string; out aValue: string): boolean;  // false = no value for any reason
	end;


var
	gCore: TCore;


implementation


{ TCore }

constructor TCore.Create;
begin
	fScripts := TScriptsMan.Create;
end;

destructor TCore.Destroy;
begin
	fScripts.Free;
	fColumnsTitles.Free;
  inherited;
end;

// false means no more titles
function TCore.GetFieldTitle(aField: integer; out aTitle: ansistring): boolean;
begin
	Result := false;
	if not Assigned(fColumnsTitles) then
		LoadOptions;

	if aField = fColumnsTitles.Count then exit;

	aTitle := ansistring(fColumnsTitles[aField]);
	Result := true;
end;

procedure TCore.LoadOptions;

	function GetDllPath: string;   // with "\" at end
	var
		vBuf : array[0..MAX_PATH] of char;
	begin
		GetModuleFileName(HInstance, vBuf, Length(vBuf));
		Result := ExtractFilePath(vBuf);
	end;

var
	vIni: TMemIniFile;
	i: integer;
	vScriptsSections: TStringList;

	procedure LoadTitlesAndScript(const aScriptSect: string);
  const
    SectExeScriptParsers = 'ExeScriptParsers';
	var
		i: integer;
		vVarName, vTitle: string;
		vBeforeCount: integer;
		vScriptPath,
		vExtensions: string;
		vUseDirs: boolean;
    vExeParserPath: string;
    vScriptExt: string;
    vFileNameVarFormat: string;
    vStdOutFormat: string;
    vExeArgs: string;
    vDoubleSlash: boolean;
	begin
		Assert(aScriptSect <> '');
  	vScriptPath := GetDllPath + SCRIPTS_DIR + '\' + vIni.ReadString(aScriptSect, 'Script', '');
    if not FileExists(vScriptPath) then exit;

		vBeforeCount := fColumnsTitles.Count;
		for i := 0 to MAX_SCRIPT_FIELDS - 1 do
		begin
			if i = 0 then
				vVarName := SCRIPT_VAR_NAME
			else
				vVarName := SCRIPT_VAR_NAME + IntToStr(i);

			vTitle := vIni.ReadString(aScriptSect, vVarName, ';');
			if vTitle = ';' then break; // no such such key exists cause returned default value - ;

			CheckAndChangeDupTitle(vTitle);
			fColumnsTitles.Add(vTitle);
		end;

		vExtensions := vIni.ReadString(aScriptSect, 'extensions', '*');
		vUseDirs := vIni.ReadBool(aScriptSect, 'FoldersPaths', false);


    // Load and process section [ExeScriptParsers] for this file type (vScriptExt):
    // get ExeParser for this extension if exists
    vDoubleSlash := false;
    vScriptExt := ExtractFileExt(vScriptPath);
    Delete(vScriptExt, 1, 1);
    vExeParserPath := vIni.ReadString(SectExeScriptParsers, vScriptExt, '');

    if (vExeParserPath <> '') then
    begin
      if not FileExists(vExeParserPath) then
      begin
        // check maybe path use %env_variable%
        vExeParserPath := ExpandEnvironmentPath(vExeParserPath);
        if not FileExists(vExeParserPath) then
        begin
          ShowMsg(Format(SPECIFY_PARSER_PATH,
              [vExeParserPath, ExtractFileName(vExeParserPath), vScriptExt]) );
          exit;
        end;
      end;
      vFileNameVarFormat := vIni.ReadString(SectExeScriptParsers, vScriptExt + 'VarFormat', '');
      if vFileNameVarFormat = '' then exit;
      vStdOutFormat := vIni.ReadString(SectExeScriptParsers, vScriptExt + 'StdOutFormat', '');
      vDoubleSlash := vIni.ReadBool(SectExeScriptParsers, vScriptExt + 'DoubleSlashPath', false);
      vExeArgs := vIni.ReadString(SectExeScriptParsers, vScriptExt + 'CmdArgs', '');


    end;

		fScripts.AddScript(vScriptPath,
                       vExtensions,
                       vExeParserPath, vExeArgs,
                       vFileNameVarFormat,
                       vStdOutFormat,
                       fColumnsTitles.Count - vBeforeCount,
                       vUseDirs,
                       vDoubleSlash);
	end;

begin
	if fColumnsTitles = nil then
		fColumnsTitles := TStringList.Create
	else
		fColumnsTitles.Clear;

	vIni := TMemIniFile.Create(GetDllPath + 'options.ini');
	vScriptsSections := TStringList.Create;
	try
		vScriptsSections.Delimiter := '|';
		vScriptsSections.DelimitedText := vIni.ReadString('Script', 'ActiveScripts', '');
		for i := 0 to vScriptsSections.Count - 1 do
			LoadTitlesAndScript(vScriptsSections[i]);

	finally
		vIni.Free;
		vScriptsSections.Free;
	end;
end;

{ Check new column title for duplicates. If there will be 2 columns A and B, with same titles -
	TC will ask value only for A column two times (return field index of column A).
}
procedure TCore.CheckAndChangeDupTitle(var aTitle: string);
begin
	if fColumnsTitles.IndexOf(aTitle) <> -1 then
	begin
		inc(fDupTitleCount);
		aTitle := aTitle + '(' + IntToStr(fDupTitleCount) + ')';
	end;
end;

function TCore.GetFieldValue(aField: integer; const aPath: string; out aValue: string): boolean;
begin
	Result := fScripts.GetColumnValue(aField, aPath, aValue);
end;

procedure InitCore;
begin
	gCore := TCore.Create;
end;

procedure DestroyCore;
begin
	gCore.Free;
end;


initialization
	InitCore;

finalization
	DestroyCore;

end.
