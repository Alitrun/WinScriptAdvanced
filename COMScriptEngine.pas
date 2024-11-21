unit COMScriptEngine;

interface

uses
	Windows, ActiveX, ComObj, ActiveScriptIntf, SysUtils, BaseScript;

type
	TActiveXScriptEngine = class(TObject, IActiveScriptSite)
	strict private
		fEngine: IActiveScript;
		fParser: IActiveScriptParse;
	private  // cause we're using mixed object and interface references, so disable refcounter
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
		function _AddRef: Integer; stdcall;
		function _Release: Integer; stdcall;
	protected  {IActiveScriptSite}
		function GetLCID(out plcid: LCID): HResult; stdcall;
		function GetItemInfo(pstrName: LPCOLESTR; dwReturnMask: DWORD;
			out ppiunkItem: IUnknown; out ppti: ITypeInfo): HResult; stdcall;
		function GetDocVersionString(out pbstrVersion: WideString): HResult; stdcall;
		function OnScriptTerminate(var pvarResult: OleVariant;
			var pexcepinfo: EXCEPINFO): HResult; stdcall;
		function OnStateChange(ssScriptState: SCRIPTSTATE): HResult; stdcall;
		function OnScriptError(const aScriptError: IActiveScriptError): HResult; stdcall;
		function OnEnterScript: HResult; stdcall;
		function OnLeaveScript: HResult; stdcall;
	public
		LastErrorText: string;
		constructor Create(aLanguage: TScriptLanguage);
		destructor Destroy; override;
		function StartScript(const aScriptText: string): boolean;
		procedure LoadScriptVarsValues(var aVarsNames, aVarsValues: TStrArray);
	end;



implementation

const
	ScriptProgIDs: array[TScriptLanguage] of PChar = ('',
      'VBScript',
      'JScript',
      'Python.AXScript.2', '', '', '', '');

 { 'PerlScript' (ActivePerl from Active State) - yes it works, but can't read values from
  global variables
  GetTypeInfoCount returns 0 and
  pDispatch->GetIDsOfNames(), always returns DISP_E_UNKNOWNNAME
  PERLSCRIPT
    - Supports retrieving and calling global procedures
    - No support for accessing global variables
    - No support for accessing structures and structure members
    - No support for accessing class (module) instance data
  http://code.activestate.com/lists/activeperl/8481/

  One option is to share results with Perl script, and plugin will read it. Simple text file.
 }

 { RubyScript problems: - Ruby-2.3.1 (x86-mswin32_100) Microsoft Installer Package (2016-04-26 revision 54768)
 latest release - can't Init parser - IActiveScriptParse.InitNew crash plugin with Access Violation.
 But version ActiveScriptRuby(1.8.7) works, but has problem as with perl - can't access variables -
 Unknown name.

 http://www.artonx.org/data/asr/
 }


var
	ScriptCLSIDs: array[TScriptLanguage] of TGUID;



{ TScriptEngine }

constructor TActiveXScriptEngine.Create(aLanguage: TScriptLanguage);
begin
  inherited Create;
	fEngine := CreateComObject(ScriptCLSIDs[aLanguage]) as IActiveScript;
	fParser := fEngine as IActiveScriptParse;
  fEngine.SetScriptSite(Self);
	fParser.InitNew;
end;

destructor TActiveXScriptEngine.Destroy;
begin
	fParser := nil;
	if fEngine <> nil then
		fEngine.Close;
	fEngine := nil;
	inherited;
end;

function TActiveXScriptEngine.StartScript(const aScriptText: string): boolean;
var
	vResult: OleVariant;
	vExcepInfo: TEXCEPINFO;
begin
	Assert(fParser <> nil);
	Assert(fEngine <> nil);
	LastErrorText := '';
	// run script
	Result := fParser.ParseScriptText(PChar(aScriptText), nil, nil, nil, 0, 0, 0, vResult,
			vExcepInfo) = S_OK;
end;

procedure TActiveXScriptEngine.LoadScriptVarsValues(var aVarsNames, aVarsValues: TStrArray);
var
	i: integer;
	vPropName: string;
	vDisp: IDispatch;
	vDispId: TDispId;
	vdpNoArgs: TDispParams;
	vResult: Variant;
begin
	Assert(fEngine <> nil);
	if fEngine = nil then exit;
	Assert(Length(aVarsNames) = Length(aVarsValues));

	fEngine.GetScriptDispatch(nil, vDisp);
	for i := 0 to High(aVarsNames) do
	begin
		vPropName := aVarsNames[i];
  //  OleCheck(vDisp.GetIDsOfNames(GUID_NULL, @vPropName, 1, LOCALE_SYSTEM_DEFAULT, @vDispId));
		if vDisp.GetIDsOfNames(GUID_NULL, @vPropName, 1, LOCALE_SYSTEM_DEFAULT, @vDispId) = S_OK then
		begin
			ZeroMemory(@vdpNoArgs, SizeOf(TDispParams));
			OleCheck( vDisp.Invoke (vDispId, GUID_NULL, LOCALE_SYSTEM_DEFAULT, DISPATCH_PROPERTYGET,
				vdpNoArgs, @vResult, nil, nil));
			aVarsValues[i] := vResult;
		end;
	end;
end;

function TActiveXScriptEngine.GetLCID(out plcid: LCID): HResult;
begin
	plcid := GetSystemDefaultLCID;
	Result := S_OK;
end;

function TActiveXScriptEngine.GetItemInfo(pstrName: LPCOLESTR; dwReturnMask: DWORD; out ppiunkItem: IInterface;
	out ppti: ITypeInfo): HResult;
begin
	Result := E_NOTIMPL;
end;

function TActiveXScriptEngine.GetDocVersionString(out pbstrVersion: WideString): HResult;
begin
	Result := E_NOTIMPL;
end;

function TActiveXScriptEngine.OnEnterScript: HResult;
begin
	Result := S_OK;
end;

function TActiveXScriptEngine.OnLeaveScript: HResult;
begin
	Result := S_OK;
end;

function TActiveXScriptEngine.OnScriptError(const aScriptError: IActiveScriptError): HResult;
var
	vEInfo: EXCEPINFO;
begin
	Result := S_OK;
	if aScriptError = nil then exit;

	aScriptError.GetExceptionInfo(vEInfo);
	if @vEInfo.pfnDeferredFillIn <> nil then
		vEInfo.pfnDeferredFillIn(@vEInfo);
	LastErrorText := vEInfo.bstrDescription;
end;

function TActiveXScriptEngine.OnScriptTerminate(var pvarResult: OleVariant; var pexcepinfo: EXCEPINFO): HResult;
begin
	Result := S_OK;
end;

function TActiveXScriptEngine.OnStateChange(ssScriptState: SCRIPTSTATE): HResult;
begin
	Result := S_OK;
end;

function TActiveXScriptEngine.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

function TActiveXScriptEngine._AddRef: Integer;
begin
	Result := -1;
end;

function TActiveXScriptEngine._Release: Integer;
begin
	Result := -1;
end;


procedure InitCLSIDs;
var
	i: TScriptLanguage;
begin
	for i := Low(TScriptLanguage) to High(TScriptLanguage) do
		if CLSIDFromProgID(ScriptProgIDs[i], ScriptCLSIDs[i]) <> S_OK
			then ScriptCLSIDs[i] := GUID_NULL;
end;

initialization
	InitCLSIDs;

end.
