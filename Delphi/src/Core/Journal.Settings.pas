unit Journal.Settings;

interface

uses
  System.SysUtils, System.Classes, Journal.Types, Journal.Events;

type
  TAppSettings = class
  private
    FOnChanged: TNotifyHub;
    function ReadString(const Key, Default: string): string;
    procedure WriteString(const Key, Value: string);
    function ReadBool(const Key: string; Default: Boolean): Boolean;
    procedure WriteBool(const Key: string; Value: Boolean);
    function ReadFloat(const Key: string; Default: Double): Double;
    procedure WriteFloat(const Key: string; Value: Double);
    function ReadInt(const Key: string; Default: Integer): Integer;
    procedure WriteInt(const Key: string; Value: Integer);
    procedure Changed;
    procedure MigrateLegacyDataPath;
    constructor Create;
  public
    destructor Destroy; override;
    class function Instance: TAppSettings; static;
    class function GermanStates: TArray<TGermanState>; static;
    property OnChanged: TNotifyHub read FOnChanged;

    function DataPath: string;
    procedure SetDataPath(const Path: string);
    function StateCode: string;
    procedure SetStateCode(const Code: string);
    function StateDisplayName: string;
    function WorkSettings: TWorkSettings;
    procedure SetWorkSettings(const Settings: TWorkSettings);
    function OvertimeAccount: TOvertimeAccountSettings;
    procedure SetOvertimeAccount(const Settings: TOvertimeAccountSettings);
    function RetirementDate: TDate;
    procedure SetRetirementDate(const ADate: TDate);
    function ProrateVacationInExitYear: Boolean;
    procedure SetProrateVacationInExitYear(Enabled: Boolean);
    function DayStartMinute: Integer;
    function DayEndMinute: Integer;
    procedure SetDayWindow(AStart, AEnd: Integer);
    function UsualPauseWindow: TDayBounds;
    procedure SetUsualPauseWindow(AStart, AEnd: Integer);
    function IsWorkDay(DayOfWeek: Integer): Boolean;
    function WorkDayCount: Integer;
    function TargetHoursForWeekday(DayOfWeek: Integer): Double;
    function TargetHoursForDate(const ADate: TDate): Double;
  end;

implementation

uses
  System.Win.Registry, Winapi.Windows, System.IOUtils, System.DateUtils, System.Math;

var
  GSettings: TAppSettings;

const
  RegRoot = 'Software\Journal\Journal';

function DefaultDataPath: string;
begin
  Result := TPath.Combine(GetEnvironmentVariable('APPDATA'), 'Journal');
end;

function LegacyNestedDataPath: string;
begin
  Result := TPath.Combine(DefaultDataPath, 'Journal');
end;

function SamePath(const A, B: string): Boolean;
begin
  Result := SameText(ExcludeTrailingPathDelimiter(ExpandFileName(A)),
    ExcludeTrailingPathDelimiter(ExpandFileName(B)));
end;

function LooksLikeJournalData(const Path: string): Boolean;
begin
  Result := TDirectory.Exists(TPath.Combine(Path, 'monate'))
    or TDirectory.Exists(TPath.Combine(Path, 'jahre'))
    or TDirectory.Exists(TPath.Combine(Path, 'kalender'))
    or TFile.Exists(TPath.Combine(Path, 'titel.json'));
end;

function MoveEntry(const FromPath, ToPath: string): Boolean;
var
  Entry, DestChild: string;
begin
  Result := True;
  try
    if TFile.Exists(ToPath) then
      TFile.Delete(ToPath);
    if not (TFile.Exists(ToPath) or TDirectory.Exists(ToPath)) then
    begin
      if TDirectory.Exists(FromPath) then
        TDirectory.Move(FromPath, ToPath)
      else
        TFile.Move(FromPath, ToPath);
      Exit;
    end;
    if not (TDirectory.Exists(FromPath) and TDirectory.Exists(ToPath)) then
      Exit(False);
    for Entry in TDirectory.GetFileSystemEntries(FromPath) do
    begin
      DestChild := TPath.Combine(ToPath, TPath.GetFileName(Entry));
      if not MoveEntry(Entry, DestChild) then
        Result := False;
    end;
    if Length(TDirectory.GetFileSystemEntries(FromPath)) = 0 then
      TDirectory.Delete(FromPath);
  except
    Result := False;
  end;
end;

constructor TAppSettings.Create;
begin
  inherited Create;
  FOnChanged := TNotifyHub.Create;
  MigrateLegacyDataPath;
end;

procedure TAppSettings.MigrateLegacyDataPath;
var
  Stored, Dest, Legacy: string;
  Custom: Boolean;
begin
  Stored := Trim(ReadString('dataPath', ''));
  Dest := DefaultDataPath;
  Legacy := LegacyNestedDataPath;
  Custom := (Stored <> '') and not SamePath(Stored, Dest) and not SamePath(Stored, Legacy);
  if Custom then
    Exit;

  if TDirectory.Exists(Legacy) and LooksLikeJournalData(Legacy) then
  begin
    TDirectory.CreateDirectory(Dest);
    MoveEntry(Legacy, Dest);
  end;

  if LooksLikeJournalData(Legacy) and not TDirectory.Exists(TPath.Combine(Dest, 'monate')) then
  begin
    WriteString('dataPath', Legacy);
    Exit;
  end;

  if (Stored = '') or SamePath(Stored, Legacy) then
    WriteString('dataPath', Dest);
end;

destructor TAppSettings.Destroy;
begin
  FOnChanged.Free;
  inherited;
end;

class function TAppSettings.Instance: TAppSettings;
begin
  if GSettings = nil then
    GSettings := TAppSettings.Create;
  Result := GSettings;
end;

procedure TAppSettings.Changed;
begin
  FOnChanged.Notify;
end;

function TAppSettings.ReadString(const Key, Default: string): string;
var
  Reg: TRegistry;
begin
  Result := Default;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(RegRoot) then
    begin
      if Reg.ValueExists(Key) then
        Result := Reg.ReadString(Key);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TAppSettings.WriteString(const Key, Value: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(RegRoot, True) then
    begin
      Reg.WriteString(Key, Value);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

function TAppSettings.ReadBool(const Key: string; Default: Boolean): Boolean;
var
  S: string;
begin
  S := ReadString(Key, '');
  if S = '' then
    Result := Default
  else
    Result := (S = 'true') or (S = '1') or SameText(S, 'true');
end;

procedure TAppSettings.WriteBool(const Key: string; Value: Boolean);
begin
  if Value then
    WriteString(Key, 'true')
  else
    WriteString(Key, 'false');
end;

function TAppSettings.ReadFloat(const Key: string; Default: Double): Double;
var
  S: string;
  FS: TFormatSettings;
begin
  S := ReadString(Key, '');
  if S = '' then
    Exit(Default);
  FS := TFormatSettings.Invariant;
  if not TryStrToFloat(S, Result, FS) then
  begin
    FS := TFormatSettings.Create('de-DE');
    if not TryStrToFloat(S, Result, FS) then
      Result := Default;
  end;
end;

procedure TAppSettings.WriteFloat(const Key: string; Value: Double);
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Invariant;
  WriteString(Key, FloatToStr(Value, FS));
end;

function TAppSettings.ReadInt(const Key: string; Default: Integer): Integer;
var
  S: string;
begin
  S := ReadString(Key, '');
  if not TryStrToInt(S, Result) then
    Result := Default;
end;

procedure TAppSettings.WriteInt(const Key: string; Value: Integer);
begin
  WriteString(Key, IntToStr(Value));
end;

function ReadSubString(const SubKey, ValueName, Default: string): string;
var
  Reg: TRegistry;
begin
  Result := Default;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(RegRoot + '\' + SubKey) then
    begin
      if Reg.ValueExists(ValueName) then
        Result := Reg.ReadString(ValueName);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

procedure WriteSubString(const SubKey, ValueName, Value: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(RegRoot + '\' + SubKey, True) then
    begin
      Reg.WriteString(ValueName, Value);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

function ReadSubFloat(const SubKey, ValueName: string; Default: Double): Double;
var
  S: string;
  FS: TFormatSettings;
begin
  S := ReadSubString(SubKey, ValueName, '');
  if S = '' then
    Exit(Default);
  FS := TFormatSettings.Invariant;
  if not TryStrToFloat(S, Result, FS) then
  begin
    FS := TFormatSettings.Create('de-DE');
    if not TryStrToFloat(S, Result, FS) then
      Result := Default;
  end;
end;

procedure WriteSubFloat(const SubKey, ValueName: string; Value: Double);
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Invariant;
  WriteSubString(SubKey, ValueName, FloatToStr(Value, FS));
end;

function ReadSubBool(const SubKey, ValueName: string; Default: Boolean): Boolean;
var
  S: string;
begin
  S := ReadSubString(SubKey, ValueName, '');
  if S = '' then
    Result := Default
  else
    Result := (S = 'true') or (S = '1') or SameText(S, 'true');
end;

procedure WriteSubBool(const SubKey, ValueName: string; Value: Boolean);
begin
  if Value then
    WriteSubString(SubKey, ValueName, 'true')
  else
    WriteSubString(SubKey, ValueName, 'false');
end;

function ReadSubInt(const SubKey, ValueName: string; Default: Integer): Integer;
var
  S: string;
begin
  S := ReadSubString(SubKey, ValueName, '');
  if not TryStrToInt(S, Result) then
    Result := Default;
end;

procedure WriteSubInt(const SubKey, ValueName: string; Value: Integer);
begin
  WriteSubString(SubKey, ValueName, IntToStr(Value));
end;

class function TAppSettings.GermanStates: TArray<TGermanState>;
begin
  SetLength(Result, 16);
  Result[0].Code := 'BW'; Result[0].Name := 'Baden-W' + #$00FC + 'rttemberg';
  Result[1].Code := 'BY'; Result[1].Name := 'Bayern';
  Result[2].Code := 'BE'; Result[2].Name := 'Berlin';
  Result[3].Code := 'BB'; Result[3].Name := 'Brandenburg';
  Result[4].Code := 'HB'; Result[4].Name := 'Bremen';
  Result[5].Code := 'HH'; Result[5].Name := 'Hamburg';
  Result[6].Code := 'HE'; Result[6].Name := 'Hessen';
  Result[7].Code := 'MV'; Result[7].Name := 'Mecklenburg-Vorpommern';
  Result[8].Code := 'NI'; Result[8].Name := 'Niedersachsen';
  Result[9].Code := 'NW'; Result[9].Name := 'Nordrhein-Westfalen';
  Result[10].Code := 'RP'; Result[10].Name := 'Rheinland-Pfalz';
  Result[11].Code := 'SL'; Result[11].Name := 'Saarland';
  Result[12].Code := 'SN'; Result[12].Name := 'Sachsen';
  Result[13].Code := 'ST'; Result[13].Name := 'Sachsen-Anhalt';
  Result[14].Code := 'SH'; Result[14].Name := 'Schleswig-Holstein';
  Result[15].Code := 'TH'; Result[15].Name := 'Th' + #$00FC + 'ringen';
end;

function TAppSettings.DataPath: string;
begin
  Result := ReadString('dataPath', DefaultDataPath);
  if Result.Trim = '' then
    Result := DefaultDataPath;
end;

procedure TAppSettings.SetDataPath(const Path: string);
begin
  WriteString('dataPath', Path);
  Changed;
end;

function TAppSettings.StateCode: string;
begin
  Result := UpperCase(ReadString('stateCode', 'NI'));
end;

procedure TAppSettings.SetStateCode(const Code: string);
var
  Normalized: string;
begin
  Normalized := UpperCase(Trim(Code));
  if (Normalized = '') or (Normalized = StateCode) then
    Exit;
  WriteString('stateCode', Normalized);
  Changed;
end;

function TAppSettings.StateDisplayName: string;
var
  Code: string;
  State: TGermanState;
begin
  Code := StateCode;
  for State in GermanStates do
    if State.Code = Code then
      Exit(Format('%s (%s)', [State.Name, State.Code]));
  Result := Code;
end;

function TAppSettings.WorkSettings: TWorkSettings;
const
  DefaultDays: array[0..6] of Boolean = (True, True, True, True, True, False, False);
  DefaultHours: array[0..6] of Double = (8, 8, 8, 8, 8, 0, 0);
var
  I: Integer;
  Mode: string;
begin
  Result.AnnualVacationDays := ReadSubFloat('vacation', 'annualDays', 30);
  Mode := ReadSubString('workTime', 'mode', 'even');
  if SameText(Mode, 'individual') then
    Result.WorkTimeMode := wtmIndividual
  else
    Result.WorkTimeMode := wtmEven;
  Result.WeeklyHours := ReadSubFloat('workTime', 'weeklyHours', 40);
  for I := 0 to 6 do
  begin
    Result.WorkDays[I] := ReadSubBool('workDays', IntToStr(I), DefaultDays[I]);
    Result.HoursPerDay[I] := ReadSubFloat('workTime\hours', IntToStr(I), DefaultHours[I]);
  end;
end;

procedure TAppSettings.SetWorkSettings(const Settings: TWorkSettings);
var
  I: Integer;
  Mode: string;
begin
  WriteSubFloat('vacation', 'annualDays', Settings.AnnualVacationDays);
  if Settings.WorkTimeMode = wtmIndividual then
    Mode := 'individual'
  else
    Mode := 'even';
  WriteSubString('workTime', 'mode', Mode);
  WriteSubFloat('workTime', 'weeklyHours', Settings.WeeklyHours);
  for I := 0 to 6 do
  begin
    WriteSubBool('workDays', IntToStr(I), Settings.WorkDays[I]);
    WriteSubFloat('workTime\hours', IntToStr(I), Settings.HoursPerDay[I]);
  end;
  Changed;
end;

function TAppSettings.OvertimeAccount: TOvertimeAccountSettings;
var
  Period: string;
  Tmp: Double;
begin
  Result.LimitsEnabled := ReadSubBool('overtime', 'limitsEnabled', True);
  Period := ReadSubString('overtime', 'period', 'quarterly');
  if SameText(Period, 'monthly') then
    Result.Period := olpMonthly
  else
    Result.Period := olpQuarterly;
  Result.MinHours := ReadSubFloat('overtime', 'minHours', -20);
  Result.MaxHours := ReadSubFloat('overtime', 'maxHours', 60);
  if Result.MinHours > Result.MaxHours then
  begin
    Tmp := Result.MinHours;
    Result.MinHours := Result.MaxHours;
    Result.MaxHours := Tmp;
  end;
end;

procedure TAppSettings.SetOvertimeAccount(const Settings: TOvertimeAccountSettings);
var
  Sanitized: TOvertimeAccountSettings;
  Tmp: Double;
  Period: string;
begin
  Sanitized := Settings;
  if Sanitized.MinHours > Sanitized.MaxHours then
  begin
    Tmp := Sanitized.MinHours;
    Sanitized.MinHours := Sanitized.MaxHours;
    Sanitized.MaxHours := Tmp;
  end;
  WriteSubBool('overtime', 'limitsEnabled', Sanitized.LimitsEnabled);
  if Sanitized.Period = olpMonthly then
    Period := 'monthly'
  else
    Period := 'quarterly';
  WriteSubString('overtime', 'period', Period);
  WriteSubFloat('overtime', 'minHours', Sanitized.MinHours);
  WriteSubFloat('overtime', 'maxHours', Sanitized.MaxHours);
  Changed;
end;

function TAppSettings.RetirementDate: TDate;
var
  S: string;
  Fallback: TDate;
begin
  Fallback := EncodeDate(2037, 12, 1);
  S := ReadSubString('retirement', 'date', IsoDate(Fallback));
  Result := ParseIsoDate(S);
  if not DateValid(Result) then
    Result := Fallback;
end;

procedure TAppSettings.SetRetirementDate(const ADate: TDate);
begin
  if not DateValid(ADate) or SameDate(ADate, RetirementDate) then
    Exit;
  WriteSubString('retirement', 'date', IsoDate(ADate));
end;

function TAppSettings.ProrateVacationInExitYear: Boolean;
begin
  Result := ReadSubBool('retirement', 'prorateVacation', True);
end;

procedure TAppSettings.SetProrateVacationInExitYear(Enabled: Boolean);
begin
  if Enabled = ProrateVacationInExitYear then
    Exit;
  WriteSubBool('retirement', 'prorateVacation', Enabled);
end;

function TAppSettings.DayStartMinute: Integer;
begin
  Result := SanitizeDayBounds(
    ReadSubInt('dayBounds', 'startMinute', DefaultDayStartMinute),
    ReadSubInt('dayBounds', 'endMinute', DefaultDayEndMinute)).StartMinute;
end;

function TAppSettings.DayEndMinute: Integer;
begin
  Result := SanitizeDayBounds(
    ReadSubInt('dayBounds', 'startMinute', DefaultDayStartMinute),
    ReadSubInt('dayBounds', 'endMinute', DefaultDayEndMinute)).EndMinute;
end;

procedure TAppSettings.SetDayWindow(AStart, AEnd: Integer);
var
  Bounds: TDayBounds;
begin
  Bounds := SanitizeDayBounds(AStart, AEnd);
  WriteSubInt('dayBounds', 'startMinute', Bounds.StartMinute);
  WriteSubInt('dayBounds', 'endMinute', Bounds.EndMinute);
  Changed;
end;

function TAppSettings.UsualPauseWindow: TDayBounds;
begin
  Result := SanitizeDayBounds(
    ReadSubInt('pause', 'usualStartMinute', 11 * 60 + 30),
    ReadSubInt('pause', 'usualEndMinute', 12 * 60));
end;

procedure TAppSettings.SetUsualPauseWindow(AStart, AEnd: Integer);
var
  Bounds: TDayBounds;
begin
  Bounds := SanitizeDayBounds(AStart, AEnd);
  WriteSubInt('pause', 'usualStartMinute', Bounds.StartMinute);
  WriteSubInt('pause', 'usualEndMinute', Bounds.EndMinute);
  Changed;
end;

function TAppSettings.IsWorkDay(DayOfWeek: Integer): Boolean;
begin
  if (DayOfWeek < 1) or (DayOfWeek > 7) then
    Exit(False);
  Result := WorkSettings.WorkDays[DayOfWeek - 1];
end;

function TAppSettings.WorkDayCount: Integer;
var
  Day: Boolean;
begin
  Result := 0;
  for Day in WorkSettings.WorkDays do
    if Day then
      Inc(Result);
end;

function TAppSettings.TargetHoursForWeekday(DayOfWeek: Integer): Double;
var
  WS: TWorkSettings;
  Idx, Count: Integer;
  Day: Boolean;
begin
  if (DayOfWeek < 1) or (DayOfWeek > 7) then
    Exit(0);
  WS := WorkSettings;
  Idx := DayOfWeek - 1;
  if not WS.WorkDays[Idx] then
    Exit(0);
  if WS.WorkTimeMode = wtmEven then
  begin
    Count := 0;
    for Day in WS.WorkDays do
      if Day then
        Inc(Count);
    if Count > 0 then
      Result := WS.WeeklyHours / Count
    else
      Result := 0;
  end
  else
    Result := WS.HoursPerDay[Idx];
end;

function TAppSettings.TargetHoursForDate(const ADate: TDate): Double;
begin
  if not DateValid(ADate) then
    Exit(0);
  Result := TargetHoursForWeekday(IsoWeekDay(ADate));
end;

initialization
finalization
  FreeAndNil(GSettings);

end.
