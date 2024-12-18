unit contplug;
  { Contents of file contplug.pas }

interface

uses
  Windows;

const
  ftNoMoreFields    = 0;
  ftNumeric32       = 1;
  ftNumeric64       = 2;
  ftNumericFloating = 3;
  ftDate            = 4;
  ft_Time           = 5;
  ft_Boolean        = 6;
  ft_MultipleChoice = 7;
  ft_String         = 8;
  ft_Fulltext       = 9;
  ft_DateTime       = 10;
  ft_StringW        = 11;

// for ContentGetValue
  ft_NoSuchField    = -1;
  ft_FileError      = -2;
  ft_FieldEmpty     = -3;
  ft_OnDemand       = -4;
  ft_NotSupported   = -5;
  ft_SetCancel      = -6;
  ft_Delayed        = 0;

// for ContentSetValue
  ft_SetSuccess     = 0; // setting of the attribute succeeded

// for ContentGetSupportedFieldFlags
  contFlags_Edit                   = 1;
  contFlags_SubstSize              = 2;
  contFlags_SubstDateTime          = 4;
  contFlags_SubstDate              = 6;
  contFlags_SubstTime              = 8;
  contFlags_SubstAttributes        = 10;
  contFlags_SubstAttributeStr      = 12;
  contFlags_PassThrough_Size_Float = 14;
  contFlags_SubstMask              = 14;
  contFlags_FieldEdit              = 16;

// for ContentSendStateInformation
  contst_ReadNewDir        = 1;
  contst_RefreshPressed    = 2;
  contst_ShowHint          = 4;
  setflags_First_Attribute = 1;  // First attribute of this file
  setflags_Last_Attribute  = 2;  // Last attribute of this file
  setflags_Only_Date       = 4;  // Only set the date of the datetime value!
  CONTENT_DELAYIFSLOW      = 1;  // ContentGetValue called in foreground
  CONTENT_PASSTHROUGH      = 2;  { If requested via contflags_passthrough_size_float: The size
                                  is passed in as floating value, TC expects correct value
                                  from the given units value, and optionally a text string}

type
  PContentDefaultParamStruct = ^TContentDefaultParamStruct;
  TContentDefaultParamStruct = record
    Size,
    PluginInterfaceVersionLow,
    PluginInterfaceVersionHi: LongInt;
    DefaultIniName: array[0..MAX_PATH-1] of char;
  end;

  PDateFormat = ^TDateFormat;
  TDateFormat = record
    wYear,
    wMonth,
		wDay: Word;
	end;

	PTimeFormat = ^TTimeFormat;
  TTimeFormat = record
		wHour,
    wMinute,
		wSecond : Word;
	end;


implementation
    { Function prototypes: }

	{
procedure ContentGetDetectString(DetectString: PAnsiChar; MaxLen: integer); stdcall;
function ContentGetSupportedField(FieldIndex: integer; FieldName, Units: PAnsiChar;
  MaxLen: integer): integer; stdcall;
function ContentGetValue(FileName: PAnsiChar; FieldIndex, UnitIndex: integer; FieldValue: PByte;
  MaxLen, Flags: integer): integer; stdcall;
function ContentGetValueW(FileName: PWideChar; FieldIndex, UnitIndex: integer; FieldValue: PByte;
  MaxLen, Flags: integer): integer; stdcall;
procedure ContentSetDefaultParams(Dps: PContentDefaultParamStruct); stdcall;
procedure ContentPluginUnloading; stdcall;
procedure ContentStopGetValue(FileName: PAnsiChar); stdcall;
procedure ContentStopGetValueW(FileName: PWideChar); stdcall;
function ContentGetDefaultSortOrder(FieldIndex: integer): integer; stdcall;
function ContentGetSupportedFieldFlags(FieldIndex: integer): integer; stdcall;
function ContentSetValue(FileName: PAnsiChar; FieldIndex, UnitIndex, FieldType: integer;
  FieldValue: PByte; Flags: integer): integer; stdcall;
function ContentSetValueW(FileName: PWideChar; FieldIndex, UnitIndex, FieldType: integer;
  FieldValue: PByte; Flags: integer): integer; stdcall;
procedure ContentSendStateInformation(State: integer; Path: PAnsiChar); stdcall;
procedure ContentSendStateInformationW(State: integer; Path: PWideChar); stdcall;
function ContentEditValue(Handle: THandle; FieldIndex, UnitIndex, FieldType: integer;
  FieldValue: PAnsiChar; MaxLen: integer; Flags: integer; LangIdentifier: PAnsiChar): integer; stdcall;

}


end.
