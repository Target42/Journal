unit Journal.Settings;

interface

uses
  System.SysUtils, System.Classes, System.JSON, Journal.Types, Journal.Events;

type
  TAppSettings = class
  private
    FOnChanged: TNotifyHub;
    FStore: TJSONObject;
    FStoreLoaded: Boolean;
    function ReadString(const Key, Default: string): string;
    procedure WriteString(const Key, Value: string);
    function SettingsFilePath: string;
    procedure EnsureStore;
    procedure PersistStore;
    procedure MigrateFromNative;
    procedure ReplacePair(Obj: TJSONObject; const Name: string; Value: TJSONValue);
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
    function ImpliedAbsenceForDate(const ADate: TDate): TAbsence;
    function IsCompanyFreeEveDate(const ADate: TDate): Boolean;
  end;

implementation

uses
  System.Win.Registry, Winapi.Windows, System.IOUtils, System.DateUtils, System.Math,
  Journal.JsonUtil;

var
  GSettings: TAppSettings;

const
  RegRoot = 'Software\Journal\Journal';

function ReadSubString(const SubKey, ValueName, Default: string): string; forward;
function ReadSubFloat(const SubKey, ValueName: string; Default: Double): Double; forward;
function ReadSubBool(const SubKey, ValueName: string; Default: Boolean): Boolean; forward;
function ReadSubInt(const SubKey, ValueName: string; Default: Integer): Integer; forward;

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
    or TFile.Exists(TPath.Combine(Path, 'titel.json'))
    or TFile.Exists(TPath.Combine(Path, 'einstellungen.json'));
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
  FStore.Free;
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

function JsonArrBool(Arr: TJSONArray; Index: Integer; Default: Boolean): Boolean;
var
  V: TJSONValue;
begin
  Result := Default;
  if (Arr = nil) or (Index < 0) or (Index >= Arr.Count) then
    Exit;
  V := Arr.Items[Index];
  if V is TJSONBool then
    Result := TJSONBool(V).AsBoolean
  else if V is TJSONTrue then
    Result := True
  else if V is TJSONFalse then
    Result := False;
end;

function JsonArrFloat(Arr: TJSONArray; Index: Integer; Default: Double): Double;
var
  V: TJSONValue;
begin
  Result := Default;
  if (Arr = nil) or (Index < 0) or (Index >= Arr.Count) then
    Exit;
  V := Arr.Items[Index];
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsDouble;
end;

procedure TAppSettings.ReplacePair(Obj: TJSONObject; const Name: string; Value: TJSONValue);
var
  Pair: TJSONPair;
begin
  if Obj = nil then
  begin
    Value.Free;
    Exit;
  end;
  Pair := Obj.RemovePair(Name);
  Pair.Free;
  Obj.AddPair(Name, Value);
end;

function TAppSettings.SettingsFilePath: string;
begin
  Result := TPath.Combine(DataPath, 'einstellungen.json');
end;

procedure TAppSettings.EnsureStore;
var
  Root: TJSONValue;
begin
  if FStoreLoaded then
    Exit;
  FStoreLoaded := True;
  Root := LoadJsonFile(SettingsFilePath);
  if Root is TJSONObject then
  begin
    FStore := TJSONObject(Root);
    Exit;
  end;
  Root.Free;
  MigrateFromNative;
  PersistStore;
end;

procedure TAppSettings.PersistStore;
begin
  if FStore = nil then
    Exit;
  ForceDirectories(DataPath);
  SaveJsonFile(SettingsFilePath, FStore);
end;

procedure TAppSettings.MigrateFromNative;
const
  DefaultDays: array[0..6] of Boolean = (True, True, True, True, True, False, False);
  DefaultHours: array[0..6] of Double = (8, 8, 8, 8, 8, 0, 0);
var
  Vacation, WorkTime, Overtime, Retirement, DayBounds, Pause, Slot: TJSONObject;
  Hours, WorkDays, Presets: TJSONArray;
  I: Integer;
  UsualStart, UsualEnd: Integer;
begin
  FreeAndNil(FStore);
  FStore := TJSONObject.Create;
  FStore.AddPair('stateCode', ReadString('stateCode', 'NI'));

  Vacation := TJSONObject.Create;
  Vacation.AddPair('annualDays', TJSONNumber.Create(ReadSubFloat('vacation', 'annualDays', 30)));
  Vacation.AddPair('eveDays', ReadSubString('vacation', 'eveDays', 'normal'));
  FStore.AddPair('vacation', Vacation);

  WorkTime := TJSONObject.Create;
  WorkTime.AddPair('mode', ReadSubString('workTime', 'mode', 'even'));
  WorkTime.AddPair('weeklyHours', TJSONNumber.Create(ReadSubFloat('workTime', 'weeklyHours', 40)));
  Hours := TJSONArray.Create;
  WorkDays := TJSONArray.Create;
  for I := 0 to 6 do
  begin
    Hours.Add(ReadSubFloat('workTime\hours', IntToStr(I), DefaultHours[I]));
    WorkDays.Add(ReadSubBool('workDays', IntToStr(I), DefaultDays[I]));
  end;
  WorkTime.AddPair('hours', Hours);
  FStore.AddPair('workTime', WorkTime);
  FStore.AddPair('workDays', WorkDays);

  Overtime := TJSONObject.Create;
  Overtime.AddPair('limitsEnabled', TJSONBool.Create(ReadSubBool('overtime', 'limitsEnabled', True)));
  Overtime.AddPair('period', ReadSubString('overtime', 'period', 'quarterly'));
  Overtime.AddPair('minHours', TJSONNumber.Create(ReadSubFloat('overtime', 'minHours', -20)));
  Overtime.AddPair('maxHours', TJSONNumber.Create(ReadSubFloat('overtime', 'maxHours', 60)));
  Overtime.AddPair('openingEnabled', TJSONBool.Create(ReadSubBool('overtime', 'openingEnabled', False)));
  Overtime.AddPair('openingYear', TJSONNumber.Create(ReadSubInt('overtime', 'openingYear', 0)));
  Overtime.AddPair('openingMonth', TJSONNumber.Create(ReadSubInt('overtime', 'openingMonth', 0)));
  Overtime.AddPair('openingHours', TJSONNumber.Create(ReadSubFloat('overtime', 'openingHours', 0)));
  FStore.AddPair('overtime', Overtime);

  Retirement := TJSONObject.Create;
  Retirement.AddPair('date', ReadSubString('retirement', 'date', '2037-12-01'));
  Retirement.AddPair('prorateVacation', TJSONBool.Create(ReadSubBool('retirement', 'prorateVacation', True)));
  FStore.AddPair('retirement', Retirement);

  DayBounds := TJSONObject.Create;
  DayBounds.AddPair('startMinute', TJSONNumber.Create(ReadSubInt('dayBounds', 'startMinute', DefaultDayStartMinute)));
  DayBounds.AddPair('endMinute', TJSONNumber.Create(ReadSubInt('dayBounds', 'endMinute', DefaultDayEndMinute)));
  FStore.AddPair('dayBounds', DayBounds);

  UsualStart := ReadSubInt('pause', 'usualStartMinute', 11 * 60 + 30);
  UsualEnd := ReadSubInt('pause', 'usualEndMinute', 12 * 60);
  Pause := TJSONObject.Create;
  Pause.AddPair('usualStartMinute', TJSONNumber.Create(UsualStart));
  Pause.AddPair('usualEndMinute', TJSONNumber.Create(UsualEnd));
  Presets := TJSONArray.Create;
  Slot := TJSONObject.Create;
  Slot.AddPair('name', 'Fr' + #$00FC + 'hst' + #$00FC + 'ck');
  Slot.AddPair('startMinute', TJSONNumber.Create(9 * 60));
  Slot.AddPair('endMinute', TJSONNumber.Create(9 * 60 + 15));
  Presets.AddElement(Slot);
  Slot := TJSONObject.Create;
  Slot.AddPair('name', 'Mittag');
  Slot.AddPair('startMinute', TJSONNumber.Create(UsualStart));
  Slot.AddPair('endMinute', TJSONNumber.Create(UsualEnd));
  Presets.AddElement(Slot);
  Slot := TJSONObject.Create;
  Slot.AddPair('name', '');
  Slot.AddPair('startMinute', TJSONNumber.Create(0));
  Slot.AddPair('endMinute', TJSONNumber.Create(0));
  Presets.AddElement(Slot);
  Pause.AddPair('presets', Presets);
  FStore.AddPair('pause', Pause);
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

function EveTreatmentFromString(const S: string): TEveDayTreatment;
begin
  if SameText(S, 'full') then
    Result := edtFullVacation
  else if SameText(S, 'half') then
    Result := edtHalfVacation
  else if SameText(S, 'free') then
    Result := edtCompanyFree
  else
    Result := edtNormal;
end;

function EveTreatmentToString(Treatment: TEveDayTreatment): string;
begin
  case Treatment of
    edtFullVacation: Result := 'full';
    edtHalfVacation: Result := 'half';
    edtCompanyFree: Result := 'free';
  else
    Result := 'normal';
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

function ReadSubInt(const SubKey, ValueName: string; Default: Integer): Integer;
var
  S: string;
begin
  S := ReadSubString(SubKey, ValueName, '');
  if not TryStrToInt(S, Result) then
    Result := Default;
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
var
  Cleaned: string;
  Current: TJSONObject;
begin
  Cleaned := ExcludeTrailingPathDelimiter(ExpandFileName(Trim(Path)));
  if (Cleaned = '') or SamePath(Cleaned, DataPath) then
    Exit;
  EnsureStore;
  Current := FStore;
  FStore := nil;
  WriteString('dataPath', Cleaned);
  FStoreLoaded := False;
  if TFile.Exists(TPath.Combine(Cleaned, 'einstellungen.json')) then
  begin
    Current.Free;
    EnsureStore;
  end
  else if Current <> nil then
  begin
    FStore := Current;
    FStoreLoaded := True;
    PersistStore;
  end
  else
    EnsureStore;
  Changed;
end;

function TAppSettings.StateCode: string;
begin
  EnsureStore;
  Result := UpperCase(JsonStr(FStore, 'stateCode', 'NI'));
end;

procedure TAppSettings.SetStateCode(const Code: string);
var
  Normalized: string;
begin
  Normalized := UpperCase(Trim(Code));
  if (Normalized = '') or (Normalized = StateCode) then
    Exit;
  EnsureStore;
  ReplacePair(FStore, 'stateCode', TJSONString.Create(Normalized));
  PersistStore;
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
  Vacation, WorkTime: TJSONObject;
begin
  EnsureStore;
  Vacation := JsonObj(FStore, 'vacation');
  WorkTime := JsonObj(FStore, 'workTime');
  Result.AnnualVacationDays := JsonFloat(Vacation, 'annualDays', 30);
  Result.EveDayTreatment := EveTreatmentFromString(JsonStr(Vacation, 'eveDays', 'normal'));
  Mode := JsonStr(WorkTime, 'mode', 'even');
  if SameText(Mode, 'individual') then
    Result.WorkTimeMode := wtmIndividual
  else
    Result.WorkTimeMode := wtmEven;
  Result.WeeklyHours := JsonFloat(WorkTime, 'weeklyHours', 40);
  for I := 0 to 6 do
  begin
    Result.WorkDays[I] := JsonArrBool(JsonArr(FStore, 'workDays'), I, DefaultDays[I]);
    Result.HoursPerDay[I] := JsonArrFloat(JsonArr(WorkTime, 'hours'), I, DefaultHours[I]);
  end;
end;

procedure TAppSettings.SetWorkSettings(const Settings: TWorkSettings);
var
  I: Integer;
  Mode: string;
  Vacation, WorkTime: TJSONObject;
  Hours, WorkDays: TJSONArray;
begin
  EnsureStore;
  Vacation := JsonObj(FStore, 'vacation');
  if Vacation = nil then
  begin
    Vacation := TJSONObject.Create;
    FStore.AddPair('vacation', Vacation);
  end;
  ReplacePair(Vacation, 'annualDays', TJSONNumber.Create(Settings.AnnualVacationDays));
  ReplacePair(Vacation, 'eveDays', TJSONString.Create(EveTreatmentToString(Settings.EveDayTreatment)));

  if Settings.WorkTimeMode = wtmIndividual then
    Mode := 'individual'
  else
    Mode := 'even';
  WorkTime := TJSONObject.Create;
  WorkTime.AddPair('mode', Mode);
  WorkTime.AddPair('weeklyHours', TJSONNumber.Create(Settings.WeeklyHours));
  Hours := TJSONArray.Create;
  WorkDays := TJSONArray.Create;
  for I := 0 to 6 do
  begin
    Hours.Add(Settings.HoursPerDay[I]);
    WorkDays.Add(Settings.WorkDays[I]);
  end;
  WorkTime.AddPair('hours', Hours);
  ReplacePair(FStore, 'workTime', WorkTime);
  ReplacePair(FStore, 'workDays', WorkDays);
  PersistStore;
  Changed;
end;

function TAppSettings.OvertimeAccount: TOvertimeAccountSettings;
var
  Period: string;
  Tmp: Double;
  Overtime: TJSONObject;
begin
  EnsureStore;
  Overtime := JsonObj(FStore, 'overtime');
  Result.LimitsEnabled := JsonBool(Overtime, 'limitsEnabled', True);
  Period := JsonStr(Overtime, 'period', 'quarterly');
  if SameText(Period, 'monthly') then
    Result.Period := olpMonthly
  else
    Result.Period := olpQuarterly;
  Result.MinHours := JsonFloat(Overtime, 'minHours', -20);
  Result.MaxHours := JsonFloat(Overtime, 'maxHours', 60);
  Result.OpeningEnabled := JsonBool(Overtime, 'openingEnabled', False);
  Result.OpeningYear := JsonInt(Overtime, 'openingYear', 0);
  Result.OpeningMonth := JsonInt(Overtime, 'openingMonth', 0);
  Result.OpeningHours := JsonFloat(Overtime, 'openingHours', 0);
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
  Overtime: TJSONObject;
begin
  Sanitized := Settings;
  if Sanitized.MinHours > Sanitized.MaxHours then
  begin
    Tmp := Sanitized.MinHours;
    Sanitized.MinHours := Sanitized.MaxHours;
    Sanitized.MaxHours := Tmp;
  end;
  if Sanitized.Period = olpMonthly then
    Period := 'monthly'
  else
    Period := 'quarterly';
  Overtime := TJSONObject.Create;
  Overtime.AddPair('limitsEnabled', TJSONBool.Create(Sanitized.LimitsEnabled));
  Overtime.AddPair('period', Period);
  Overtime.AddPair('minHours', TJSONNumber.Create(Sanitized.MinHours));
  Overtime.AddPair('maxHours', TJSONNumber.Create(Sanitized.MaxHours));
  Overtime.AddPair('openingEnabled', TJSONBool.Create(Sanitized.OpeningEnabled));
  Overtime.AddPair('openingYear', TJSONNumber.Create(Sanitized.OpeningYear));
  Overtime.AddPair('openingMonth', TJSONNumber.Create(Sanitized.OpeningMonth));
  Overtime.AddPair('openingHours', TJSONNumber.Create(Sanitized.OpeningHours));
  EnsureStore;
  ReplacePair(FStore, 'overtime', Overtime);
  PersistStore;
  Changed;
end;

function TAppSettings.RetirementDate: TDate;
var
  S: string;
  Fallback: TDate;
begin
  Fallback := EncodeDate(2037, 12, 1);
  EnsureStore;
  S := JsonStr(JsonObj(FStore, 'retirement'), 'date', IsoDate(Fallback));
  Result := ParseIsoDate(S);
  if not DateValid(Result) then
    Result := Fallback;
end;

procedure TAppSettings.SetRetirementDate(const ADate: TDate);
var
  Retirement: TJSONObject;
begin
  if not DateValid(ADate) or SameDate(ADate, RetirementDate) then
    Exit;
  EnsureStore;
  Retirement := JsonObj(FStore, 'retirement');
  if Retirement = nil then
  begin
    Retirement := TJSONObject.Create;
    FStore.AddPair('retirement', Retirement);
  end;
  ReplacePair(Retirement, 'date', TJSONString.Create(IsoDate(ADate)));
  PersistStore;
  Changed;
end;

function TAppSettings.ProrateVacationInExitYear: Boolean;
begin
  EnsureStore;
  Result := JsonBool(JsonObj(FStore, 'retirement'), 'prorateVacation', True);
end;

procedure TAppSettings.SetProrateVacationInExitYear(Enabled: Boolean);
var
  Retirement: TJSONObject;
begin
  if Enabled = ProrateVacationInExitYear then
    Exit;
  EnsureStore;
  Retirement := JsonObj(FStore, 'retirement');
  if Retirement = nil then
  begin
    Retirement := TJSONObject.Create;
    FStore.AddPair('retirement', Retirement);
  end;
  ReplacePair(Retirement, 'prorateVacation', TJSONBool.Create(Enabled));
  PersistStore;
  Changed;
end;

function TAppSettings.DayStartMinute: Integer;
var
  Bounds: TJSONObject;
begin
  EnsureStore;
  Bounds := JsonObj(FStore, 'dayBounds');
  Result := SanitizeDayBounds(
    JsonInt(Bounds, 'startMinute', DefaultDayStartMinute),
    JsonInt(Bounds, 'endMinute', DefaultDayEndMinute)).StartMinute;
end;

function TAppSettings.DayEndMinute: Integer;
var
  Bounds: TJSONObject;
begin
  EnsureStore;
  Bounds := JsonObj(FStore, 'dayBounds');
  Result := SanitizeDayBounds(
    JsonInt(Bounds, 'startMinute', DefaultDayStartMinute),
    JsonInt(Bounds, 'endMinute', DefaultDayEndMinute)).EndMinute;
end;

procedure TAppSettings.SetDayWindow(AStart, AEnd: Integer);
var
  Bounds: TDayBounds;
  Obj: TJSONObject;
begin
  Bounds := SanitizeDayBounds(AStart, AEnd);
  Obj := TJSONObject.Create;
  Obj.AddPair('startMinute', TJSONNumber.Create(Bounds.StartMinute));
  Obj.AddPair('endMinute', TJSONNumber.Create(Bounds.EndMinute));
  EnsureStore;
  ReplacePair(FStore, 'dayBounds', Obj);
  PersistStore;
  Changed;
end;

function TAppSettings.UsualPauseWindow: TDayBounds;
var
  Pause, Slot: TJSONObject;
  Presets: TJSONArray;
  I: Integer;
begin
  EnsureStore;
  Pause := JsonObj(FStore, 'pause');
  Presets := JsonArr(Pause, 'presets');
  if Presets <> nil then
    for I := 0 to Presets.Count - 1 do
    begin
      if not (Presets.Items[I] is TJSONObject) then
        Continue;
      Slot := TJSONObject(Presets.Items[I]);
      if SameText(JsonStr(Slot, 'name', ''), 'Mittag') then
        Exit(SanitizeDayBounds(
          JsonInt(Slot, 'startMinute', 11 * 60 + 30),
          JsonInt(Slot, 'endMinute', 12 * 60)));
    end;
  Result := SanitizeDayBounds(
    JsonInt(Pause, 'usualStartMinute', 11 * 60 + 30),
    JsonInt(Pause, 'usualEndMinute', 12 * 60));
end;

procedure TAppSettings.SetUsualPauseWindow(AStart, AEnd: Integer);
var
  Bounds: TDayBounds;
  Pause, Slot: TJSONObject;
  Presets: TJSONArray;
  I: Integer;
  Found: Boolean;
begin
  Bounds := SanitizeDayBounds(AStart, AEnd);
  EnsureStore;
  Pause := JsonObj(FStore, 'pause');
  if Pause = nil then
  begin
    Pause := TJSONObject.Create;
    FStore.AddPair('pause', Pause);
  end;
  ReplacePair(Pause, 'usualStartMinute', TJSONNumber.Create(Bounds.StartMinute));
  ReplacePair(Pause, 'usualEndMinute', TJSONNumber.Create(Bounds.EndMinute));
  Presets := JsonArr(Pause, 'presets');
  Found := False;
  if Presets <> nil then
    for I := 0 to Presets.Count - 1 do
    begin
      if not (Presets.Items[I] is TJSONObject) then
        Continue;
      Slot := TJSONObject(Presets.Items[I]);
      if SameText(JsonStr(Slot, 'name', ''), 'Mittag') then
      begin
        ReplacePair(Slot, 'startMinute', TJSONNumber.Create(Bounds.StartMinute));
        ReplacePair(Slot, 'endMinute', TJSONNumber.Create(Bounds.EndMinute));
        Found := True;
        Break;
      end;
    end;
  if not Found then
  begin
    if Presets = nil then
    begin
      Presets := TJSONArray.Create;
      Pause.AddPair('presets', Presets);
    end;
    Slot := TJSONObject.Create;
    Slot.AddPair('name', 'Mittag');
    Slot.AddPair('startMinute', TJSONNumber.Create(Bounds.StartMinute));
    Slot.AddPair('endMinute', TJSONNumber.Create(Bounds.EndMinute));
    Presets.AddElement(Slot);
  end;
  PersistStore;
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
  if IsEveDate(ADate) and (WorkSettings.EveDayTreatment = edtCompanyFree) then
    Exit(0);
  Result := TargetHoursForWeekday(IsoWeekDay(ADate));
end;

function TAppSettings.ImpliedAbsenceForDate(const ADate: TDate): TAbsence;
begin
  Result := Default(TAbsence);
  if not IsEveDate(ADate) or (TargetHoursForWeekday(IsoWeekDay(ADate)) <= 0) then
    Exit;
  case WorkSettings.EveDayTreatment of
    edtFullVacation:
      begin
        Result.AbsenceType := atVacation;
        Result.Fraction := 1;
      end;
    edtHalfVacation:
      begin
        Result.AbsenceType := atVacation;
        Result.Fraction := 0.5;
      end;
  else
    { normal / frei: keine automatische Abwesenheit }
  end;
end;

function TAppSettings.IsCompanyFreeEveDate(const ADate: TDate): Boolean;
begin
  Result := IsEveDate(ADate) and (WorkSettings.EveDayTreatment = edtCompanyFree)
    and (TargetHoursForWeekday(IsoWeekDay(ADate)) > 0);
end;

initialization
finalization
  FreeAndNil(GSettings);

end.
