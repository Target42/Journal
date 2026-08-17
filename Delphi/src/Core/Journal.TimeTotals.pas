unit Journal.TimeTotals;

interface

uses
  System.SysUtils, System.Generics.Collections, Journal.Types, Journal.Events;

type
  TTimeTotals = class
  private
    FOnDayRecalculated: TDateHub;
    FOnMonthRecalculated: TYearMonthHub;
    FOnYearRecalculated: TIntHub;
    FMonths: TDictionary<string, TMonthTotals>;
    FYears: TDictionary<Integer, TYearTotals>;
    FFirstMonthFile: TDate;
    FFirstMonthFileKnown: Boolean;
    constructor Create;
    class function MonthKey(AYear, AMonth: Integer): string; static;
    function YearFilePath(AYear: Integer): string;
    function EarliestDataYear: Integer;
    function FirstMonthFile: TDate;
    function ComputeMonth(AYear, AMonth: Integer; CarryIn: Double): TMonthTotals;
    function AssembleYear(AYear: Integer): TYearTotals;
    function OpeningCarry(AYear, AMonth: Integer): Double;
    procedure FillYearMonths(AYear: Integer; EmitMonthSignals: Boolean);
    procedure PersistYear(AYear: Integer);
    procedure RecalculateLiveMonth(const ChangedDay: TDate);
    procedure RecalculateFrom(AYear, AMonth: Integer);
    procedure OnPackagesChanged(const ADate: TDate);
    procedure OnAbsencesChanged(const AFrom, ATo: TDate);
    procedure OnActiveDayTicked;
    procedure OnDataReloaded;
    procedure OnSettingsChanged;
    procedure OnYearDataChanged(AYear: Integer);
    procedure ClearCache;
    function LoadYearFile(AYear: Integer): TYearTotals;
  public
    destructor Destroy; override;
    class function Instance: TTimeTotals; static;
    property OnDayRecalculated: TDateHub read FOnDayRecalculated;
    property OnMonthRecalculated: TYearMonthHub read FOnMonthRecalculated;
    property OnYearRecalculated: TIntHub read FOnYearRecalculated;
    procedure EnsureYear(AYear: Integer);
    function MonthTotals(AYear, AMonth: Integer): TMonthTotals;
    function YearTotals(AYear: Integer): TYearTotals;
    function CreditedHoursForDate(const ADate: TDate): Double;
    function AccountTrend(WorkedDays: Integer = 30): TAccountTrend;
  end;

implementation

uses
  System.JSON, System.IOUtils, System.DateUtils, System.Math,
  Journal.Settings, Journal.Store, Journal.Calendar, Journal.JsonUtil;

var
  GTotals: TTimeTotals;

procedure AddMonth(var Year, Month: Integer);
begin
  if Month >= 12 then
  begin
    Inc(Year);
    Month := 1;
  end
  else
    Inc(Month);
end;

function IsOvertimeLimitMonth(Month: Integer; Period: TOvertimeLimitPeriod): Boolean;
begin
  if Period = olpMonthly then
    Result := True
  else
    Result := (Month = 3) or (Month = 6) or (Month = 9) or (Month = 12);
end;

function OvertimePeriodHasEnded(AYear, AMonth: Integer): Boolean;
var
  LastDay: TDate;
begin
  LastDay := EncodeDate(AYear, AMonth, DaysInAMonth(AYear, AMonth));
  Result := LastDay < Date;
end;

procedure ApplyOvertimeLimits(var Totals: TMonthTotals);
var
  Account: TOvertimeAccountSettings;
  Limited: Double;
begin
  Totals.ClippedHours := 0;
  Totals.ClosingSaldo := Totals.CarryIn + Totals.MonthSaldo;
  Account := TAppSettings.Instance.OvertimeAccount;
  if not Account.LimitsEnabled then
    Exit;
  if not IsOvertimeLimitMonth(Totals.Month, Account.Period) then
    Exit;
  if not OvertimePeriodHasEnded(Totals.Year, Totals.Month) then
    Exit;
  Limited := ClampDouble(Totals.ClosingSaldo, Account.MinHours, Account.MaxHours);
  Totals.ClippedHours := Totals.ClosingSaldo - Limited;
  Totals.ClosingSaldo := Limited;
end;

function CreditedHours(const ADate: TDate; Target, WorkHours: Double;
  const Absence: TAbsence): Double;
begin
  if (not Absence.IsSet) or (Target <= 0) or (ADate > Date) then
    Exit(WorkHours);
  if Absence.Fraction >= 0.999 then
    Result := Target
  else
    Result := WorkHours + Target * Absence.Fraction;
end;

constructor TTimeTotals.Create;
begin
  inherited Create;
  FOnDayRecalculated := TDateHub.Create;
  FOnMonthRecalculated := TYearMonthHub.Create;
  FOnYearRecalculated := TIntHub.Create;
  FMonths := TDictionary<string, TMonthTotals>.Create;
  FYears := TDictionary<Integer, TYearTotals>.Create;
  TJournalStore.Instance.OnPackagesChanged.Add(OnPackagesChanged);
  TJournalStore.Instance.OnAbsencesChanged.Add(OnAbsencesChanged);
  TJournalStore.Instance.OnDayBoundsChanged.Add(OnPackagesChanged);
  TJournalStore.Instance.OnActiveDayTicked.Add(OnActiveDayTicked);
  TJournalStore.Instance.OnDataReloaded.Add(OnDataReloaded);
  TAppSettings.Instance.OnChanged.Add(OnSettingsChanged);
  TCalendarService.Instance.OnYearDataChanged.Add(OnYearDataChanged);
end;

destructor TTimeTotals.Destroy;
begin
  TJournalStore.Instance.OnPackagesChanged.Remove(OnPackagesChanged);
  TJournalStore.Instance.OnAbsencesChanged.Remove(OnAbsencesChanged);
  TJournalStore.Instance.OnDayBoundsChanged.Remove(OnPackagesChanged);
  TJournalStore.Instance.OnActiveDayTicked.Remove(OnActiveDayTicked);
  TJournalStore.Instance.OnDataReloaded.Remove(OnDataReloaded);
  TAppSettings.Instance.OnChanged.Remove(OnSettingsChanged);
  TCalendarService.Instance.OnYearDataChanged.Remove(OnYearDataChanged);
  FMonths.Free;
  FYears.Free;
  FOnDayRecalculated.Free;
  FOnMonthRecalculated.Free;
  FOnYearRecalculated.Free;
  inherited;
end;

class function TTimeTotals.Instance: TTimeTotals;
begin
  if GTotals = nil then
    GTotals := TTimeTotals.Create;
  Result := GTotals;
end;

procedure TTimeTotals.OnActiveDayTicked;
begin
  RecalculateLiveMonth(0);
end;

procedure TTimeTotals.OnDataReloaded;
begin
  ClearCache;
end;

procedure TTimeTotals.OnSettingsChanged;
begin
  ClearCache;
end;

procedure TTimeTotals.OnYearDataChanged(AYear: Integer);
var
  Month: Integer;
begin
  FYears.Remove(AYear);
  for Month := 1 to 12 do
    FMonths.Remove(MonthKey(AYear, Month));
  EnsureYear(AYear);
  FOnYearRecalculated.Notify(AYear);
end;

class function TTimeTotals.MonthKey(AYear, AMonth: Integer): string;
begin
  Result := Format('%d-%.2d', [AYear, AMonth]);
end;

function TTimeTotals.YearFilePath(AYear: Integer): string;
begin
  Result := TPath.Combine(TPath.Combine(TAppSettings.Instance.DataPath, 'jahre'),
    Format('%d.json', [AYear]));
end;

function TTimeTotals.EarliestDataYear: Integer;
var
  DataPath, Name, Base: string;
  Year, Dash: Integer;
  Files: TArray<string>;

  procedure Consider(AYear: Integer);
  begin
    if (AYear >= 1970) and (AYear <= 2100) and (AYear < Result) then
      Result := AYear;
  end;

begin
  Result := YearOf(Date);
  DataPath := TAppSettings.Instance.DataPath;
  if TDirectory.Exists(TPath.Combine(DataPath, 'jahre')) then
  begin
    Files := TDirectory.GetFiles(TPath.Combine(DataPath, 'jahre'), '*.json');
    for Name in Files do
    begin
      Base := TPath.GetFileNameWithoutExtension(Name);
      if TryStrToInt(Base, Year) then
        Consider(Year);
    end;
  end;
  if TDirectory.Exists(TPath.Combine(DataPath, 'monate')) then
  begin
    Files := TDirectory.GetFiles(TPath.Combine(DataPath, 'monate'), '*.json');
    for Name in Files do
    begin
      Base := TPath.GetFileNameWithoutExtension(Name);
      Dash := Pos('-', Base);
      if Dash > 0 then
        Base := Copy(Base, 1, Dash - 1);
      if TryStrToInt(Base, Year) then
        Consider(Year);
    end;
  end;
end;

procedure TTimeTotals.ClearCache;
begin
  FMonths.Clear;
  FYears.Clear;
  FFirstMonthFile := 0;
  FFirstMonthFileKnown := False;
end;

function TTimeTotals.FirstMonthFile: TDate;
var
  Dir, Name, Base: string;
  Files: TArray<string>;
  Parts: TArray<string>;
  Year, Month: Integer;
  Candidate: TDateTime;
begin
  if FFirstMonthFileKnown then
    Exit(FFirstMonthFile);
  Result := 0;
  Dir := TPath.Combine(TAppSettings.Instance.DataPath, 'monate');
  if TDirectory.Exists(Dir) then
  begin
    Files := TDirectory.GetFiles(Dir, '*.json');
    for Name in Files do
    begin
      Base := TPath.GetFileNameWithoutExtension(Name);
      Parts := Base.Split(['-']);
      if Length(Parts) <> 2 then
        Continue;
      if not TryStrToInt(Parts[0], Year) or not TryStrToInt(Parts[1], Month) then
        Continue;
      if not TryEncodeDate(Year, Month, 1, Candidate) then
        Continue;
      if (Result = 0) or (Candidate < Result) then
        Result := Candidate;
    end;
  end;
  FFirstMonthFile := Result;
  FFirstMonthFileKnown := True;
end;

procedure TTimeTotals.EnsureYear(AYear: Integer);
begin
  if (AYear < 1970) or (AYear > 2100) then
    Exit;
  if FYears.ContainsKey(AYear) then
    Exit;
  FillYearMonths(AYear, False);
  PersistYear(AYear);
end;

function TTimeTotals.MonthTotals(AYear, AMonth: Integer): TMonthTotals;
begin
  EnsureYear(AYear);
  if not FMonths.TryGetValue(MonthKey(AYear, AMonth), Result) or (Result.Year <> AYear) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;
  Result.CarryIn := OpeningCarry(AYear, AMonth);
  ApplyOvertimeLimits(Result);
  FMonths.AddOrSetValue(MonthKey(AYear, AMonth), Result);
end;

function TTimeTotals.YearTotals(AYear: Integer): TYearTotals;
begin
  EnsureYear(AYear);
  if not FYears.TryGetValue(AYear, Result) then
    FillChar(Result, SizeOf(Result), 0);
end;

function TTimeTotals.CreditedHoursForDate(const ADate: TDate): Double;
var
  Target, WorkHours: Double;
begin
  if not DateValid(ADate) then
    Exit(0);
  if TCalendarService.Instance.IsPublicHoliday(ADate) then
    Target := 0
  else
    Target := TAppSettings.Instance.TargetHoursForDate(ADate);
  WorkHours := TJournalStore.Instance.ActualHoursForDate(ADate);
  Result := CreditedHours(ADate, Target, WorkHours, TJournalStore.Instance.AbsenceForDate(ADate));
end;

function TTimeTotals.AccountTrend(WorkedDays: Integer): TAccountTrend;
var
  Today, Limit, DataStart, ADate: TDate;
  Newest: TList<TAccountTrendPoint>;
  Point: TAccountTrendPoint;
  WorkHours, Target, Actual: Double;
  Absence: TAbsence;
  WorkDayCount, I: Integer;
begin
  Result := Default(TAccountTrend);
  if WorkedDays <= 0 then
    Exit;
  Today := Date;
  Limit := IncMonth(Today, -18);
  DataStart := FirstMonthFile;
  if (DataStart > 0) and (DataStart > Limit) then
    Limit := DataStart;
  Newest := TList<TAccountTrendPoint>.Create;
  try
    ADate := Today;
    while DateValid(ADate) and (ADate >= Limit) and (Newest.Count < WorkedDays) do
    begin
      TCalendarService.Instance.EnsureYearLoaded(YearOf(ADate));
      WorkHours := TJournalStore.Instance.ActualHoursForDate(ADate);
      if WorkHours > 0.005 then
      begin
        Absence := TJournalStore.Instance.AbsenceForDate(ADate);
        if not (Absence.IsSet and not Absence.IsHalfDay) then
        begin
          if TCalendarService.Instance.IsPublicHoliday(ADate) then
            Target := 0
          else
            Target := TAppSettings.Instance.TargetHoursForDate(ADate);
          Actual := CreditedHours(ADate, Target, WorkHours, Absence);
          Point.Date := ADate;
          Point.Saldo := Actual - Target;
          Newest.Add(Point);
          Result.TotalSaldo := Result.TotalSaldo + Point.Saldo;
        end;
      end;
      ADate := IncDay(ADate, -1);
    end;
    SetLength(Result.Points, Newest.Count);
    for I := 0 to Newest.Count - 1 do
      Result.Points[I] := Newest[Newest.Count - 1 - I];
    if Length(Result.Points) = 0 then
      Exit;
    Result.FromDate := Result.Points[0].Date;
    Result.ToDate := Result.Points[High(Result.Points)].Date;
    Result.AveragePerWorkedDay := Result.TotalSaldo / Length(Result.Points);
    WorkDayCount := Max(1, TAppSettings.Instance.WorkDayCount);
    Result.ProjectedPerWeek := Result.AveragePerWorkedDay * WorkDayCount;
    Result.ProjectedPerMonth := Result.ProjectedPerWeek * (52.0 / 12.0);
  finally
    Newest.Free;
  end;
end;

function TTimeTotals.ComputeMonth(AYear, AMonth: Integer; CarryIn: Double): TMonthTotals;
var
  First, DataStart, Today, ADate: TDateTime;
  Days, Day: Integer;
  Target, Actual: Double;
  Absence: TAbsence;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Year := AYear;
  Result.Month := AMonth;
  Result.CarryIn := CarryIn;
  if not TryEncodeDate(AYear, AMonth, 1, First) then
  begin
    Result.ClosingSaldo := CarryIn;
    Exit;
  end;
  DataStart := FirstMonthFile;
  if (DataStart > 0) and (First < DataStart) then
  begin
    Result.ClosingSaldo := CarryIn;
    Exit;
  end;
  TCalendarService.Instance.EnsureYearLoaded(AYear);
  Today := Date;
  Days := DaysInAMonth(AYear, AMonth);
  for Day := 1 to Days do
  begin
    ADate := EncodeDate(AYear, AMonth, Day);
    if TCalendarService.Instance.IsPublicHoliday(ADate) then
      Target := 0
    else
      Target := TAppSettings.Instance.TargetHoursForDate(ADate);
    Absence := TJournalStore.Instance.AbsenceForDate(ADate);
    Actual := CreditedHours(ADate, Target, TJournalStore.Instance.ActualHoursForDate(ADate), Absence);
    Result.TargetHours := Result.TargetHours + Target;
    Result.ActualHours := Result.ActualHours + Actual;
    if ADate <= Today then
      Result.MonthSaldo := Result.MonthSaldo + Actual - Target;
    if (Absence.AbsenceType = atVacation) and (Target > 0) then
    begin
      if Absence.Fraction >= 0.999 then
      begin
        if ADate <= Today then
          Result.VacationTaken := Result.VacationTaken + 1
        else
          Result.VacationPlanned := Result.VacationPlanned + 1;
      end
      else
      begin
        if ADate <= Today then
          Result.VacationTaken := Result.VacationTaken + 0.5
        else
          Result.VacationPlanned := Result.VacationPlanned + 0.5;
      end;
    end;
  end;
  ApplyOvertimeLimits(Result);
end;

function TTimeTotals.AssembleYear(AYear: Integer): TYearTotals;
var
  Month: Integer;
  January, December, MT: TMonthTotals;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Year := AYear;
  if FMonths.TryGetValue(MonthKey(AYear, 1), January) then
    Result.CarryIn := January.CarryIn;
  for Month := 1 to 12 do
  begin
    if FMonths.TryGetValue(MonthKey(AYear, Month), MT) then
    begin
      Result.TargetHours := Result.TargetHours + MT.TargetHours;
      Result.ActualHours := Result.ActualHours + MT.ActualHours;
      Result.Saldo := Result.Saldo + MT.MonthSaldo;
      Result.ClippedHours := Result.ClippedHours + MT.ClippedHours;
      Result.VacationTaken := Result.VacationTaken + MT.VacationTaken;
      Result.VacationPlanned := Result.VacationPlanned + MT.VacationPlanned;
    end;
  end;
  Result.Saldo := Result.Saldo + Result.CarryIn;
  Result.ClosingSaldo := Result.CarryIn;
  if FMonths.TryGetValue(MonthKey(AYear, 12), December) and (December.Year = AYear) then
    Result.ClosingSaldo := December.ClosingSaldo
  else
    Result.ClosingSaldo := Result.Saldo;
end;

function TTimeTotals.OpeningCarry(AYear, AMonth: Integer): Double;
var
  PrevYear: Integer;
  PreviousYear: TYearTotals;
  Key: string;
  Previous: TMonthTotals;
  Carry: Double;
begin
  if AMonth <= 1 then
  begin
    PrevYear := AYear - 1;
    if PrevYear < 1970 then
      Exit(0);
    if PrevYear < EarliestDataYear then
    begin
      PreviousYear := LoadYearFile(PrevYear);
      if PreviousYear.Year = PrevYear then
        Exit(PreviousYear.ClosingSaldo)
      else
        Exit(0);
    end;
    EnsureYear(PrevYear);
    if FYears.TryGetValue(PrevYear, PreviousYear) then
      Exit(PreviousYear.ClosingSaldo);
    Exit(0);
  end;
  Key := MonthKey(AYear, AMonth - 1);
  if FMonths.TryGetValue(Key, Previous) then
  begin
    ApplyOvertimeLimits(Previous);
    FMonths.AddOrSetValue(Key, Previous);
    Exit(Previous.ClosingSaldo);
  end;
  Carry := OpeningCarry(AYear, AMonth - 1);
  Previous := ComputeMonth(AYear, AMonth - 1, Carry);
  FMonths.AddOrSetValue(Key, Previous);
  Result := Previous.ClosingSaldo;
end;

procedure TTimeTotals.FillYearMonths(AYear: Integer; EmitMonthSignals: Boolean);
var
  Month: Integer;
  Carry: Double;
  Totals: TMonthTotals;
begin
  TCalendarService.Instance.EnsureYearLoaded(AYear);
  Carry := OpeningCarry(AYear, 1);
  for Month := 1 to 12 do
  begin
    Totals := ComputeMonth(AYear, Month, Carry);
    FMonths.AddOrSetValue(MonthKey(AYear, Month), Totals);
    Carry := Totals.ClosingSaldo;
    if EmitMonthSignals then
      FOnMonthRecalculated.Notify(AYear, Month);
  end;
  FYears.AddOrSetValue(AYear, AssembleYear(AYear));
end;

procedure TTimeTotals.PersistYear(AYear: Integer);
var
  Totals: TYearTotals;
  Root, Obj: TJSONObject;
  Months: TJSONArray;
  Month: Integer;
  M: TMonthTotals;
begin
  if not FYears.TryGetValue(AYear, Totals) or (Totals.Year <> AYear) then
    Exit;
  Root := TJSONObject.Create;
  try
    Months := TJSONArray.Create;
    for Month := 1 to 12 do
    begin
      if not FMonths.TryGetValue(MonthKey(AYear, Month), M) then
        FillChar(M, SizeOf(M), 0);
      Obj := TJSONObject.Create;
      Obj.AddPair('month', TJSONNumber.Create(Month));
      Obj.AddPair('targetHours', TJSONNumber.Create(M.TargetHours));
      Obj.AddPair('actualHours', TJSONNumber.Create(M.ActualHours));
      Obj.AddPair('carryIn', TJSONNumber.Create(M.CarryIn));
      Obj.AddPair('monthSaldo', TJSONNumber.Create(M.MonthSaldo));
      Obj.AddPair('closingSaldo', TJSONNumber.Create(M.ClosingSaldo));
      Obj.AddPair('clippedHours', TJSONNumber.Create(M.ClippedHours));
      Obj.AddPair('vacationTaken', TJSONNumber.Create(M.VacationTaken));
      Obj.AddPair('vacationPlanned', TJSONNumber.Create(M.VacationPlanned));
      Months.AddElement(Obj);
    end;
    Root.AddPair('year', TJSONNumber.Create(AYear));
    Root.AddPair('targetHours', TJSONNumber.Create(Totals.TargetHours));
    Root.AddPair('actualHours', TJSONNumber.Create(Totals.ActualHours));
    Root.AddPair('carryIn', TJSONNumber.Create(Totals.CarryIn));
    Root.AddPair('saldo', TJSONNumber.Create(Totals.Saldo));
    Root.AddPair('closingSaldo', TJSONNumber.Create(Totals.ClosingSaldo));
    Root.AddPair('clippedHours', TJSONNumber.Create(Totals.ClippedHours));
    Root.AddPair('vacationTaken', TJSONNumber.Create(Totals.VacationTaken));
    Root.AddPair('vacationPlanned', TJSONNumber.Create(Totals.VacationPlanned));
    Root.AddPair('months', Months);
    SaveJsonFile(YearFilePath(AYear), Root);
  finally
    Root.Free;
  end;
end;

function TTimeTotals.LoadYearFile(AYear: Integer): TYearTotals;
var
  RootVal: TJSONValue;
  Root: TJSONObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  RootVal := LoadJsonFile(YearFilePath(AYear));
  if not (RootVal is TJSONObject) then
  begin
    RootVal.Free;
    Exit;
  end;
  try
    Root := TJSONObject(RootVal);
    if JsonInt(Root, 'year') <> AYear then
      Exit;
    Result.Year := AYear;
    Result.TargetHours := JsonFloat(Root, 'targetHours');
    Result.ActualHours := JsonFloat(Root, 'actualHours');
    Result.CarryIn := JsonFloat(Root, 'carryIn');
    Result.Saldo := JsonFloat(Root, 'saldo');
    Result.ClosingSaldo := JsonFloat(Root, 'closingSaldo');
    Result.ClippedHours := JsonFloat(Root, 'clippedHours');
    Result.VacationTaken := JsonFloat(Root, 'vacationTaken');
    Result.VacationPlanned := JsonFloat(Root, 'vacationPlanned');
  finally
    RootVal.Free;
  end;
end;

procedure TTimeTotals.RecalculateLiveMonth(const ChangedDay: TDate);
var
  Today: TDate;
  Year, Month: Integer;
begin
  Today := Date;
  Year := YearOf(Today);
  Month := MonthOf(Today);
  if Month <= 1 then
  begin
    if Year - 1 >= 1970 then
      RecalculateFrom(Year - 1, 12)
    else
      RecalculateFrom(Year, 1);
  end
  else
    RecalculateFrom(Year, Month - 1);
  if DateValid(ChangedDay) then
    FOnDayRecalculated.Notify(ChangedDay)
  else
    FOnDayRecalculated.Notify(Today);
end;

procedure TTimeTotals.RecalculateFrom(AYear, AMonth: Integer);
var
  Today: TDate;
  EndYear, Y, M: Integer;
  Carry: Double;
  Totals: TMonthTotals;
  Years: TList<Integer>;
  Affected: Integer;
begin
  Today := Date;
  EndYear := Max(AYear, YearOf(Today));
  Y := AYear;
  M := AMonth;
  Carry := OpeningCarry(Y, M);
  Years := TList<Integer>.Create;
  try
    while (Y < EndYear) or ((Y = EndYear) and (M <= 12)) do
    begin
      Totals := ComputeMonth(Y, M, Carry);
      FMonths.AddOrSetValue(MonthKey(Y, M), Totals);
      Carry := Totals.ClosingSaldo;
      FOnMonthRecalculated.Notify(Y, M);
      if Years.IndexOf(Y) < 0 then
        Years.Add(Y);
      if (Y = EndYear) and (M = 12) then
        Break;
      AddMonth(Y, M);
    end;
    for Affected in Years do
    begin
      FYears.AddOrSetValue(Affected, AssembleYear(Affected));
      PersistYear(Affected);
      FOnYearRecalculated.Notify(Affected);
    end;
  finally
    Years.Free;
  end;
end;

procedure TTimeTotals.OnAbsencesChanged(const AFrom, ATo: TDate);
var
  StartD, EndD, Month, Last: TDate;
  Today: TDate;
  Years: TList<Integer>;
  Carry: Double;
  Totals: TMonthTotals;
  Affected: Integer;
begin
  if not DateValid(AFrom) then
    Exit;
  StartD := AFrom;
  if DateValid(ATo) then
    EndD := ATo
  else
    EndD := AFrom;
  if EndD < StartD then
  begin
    Month := StartD;
    StartD := EndD;
    EndD := Month;
  end;
  if (YearOf(StartD) = YearOf(EndD)) and (MonthOf(StartD) = MonthOf(EndD)) then
  begin
    OnPackagesChanged(StartD);
    Exit;
  end;
  Today := Date;
  if (YearOf(StartD) < YearOf(Today)) or
     ((YearOf(StartD) = YearOf(Today)) and (MonthOf(StartD) < MonthOf(Today))) then
  begin
    RecalculateFrom(YearOf(StartD), MonthOf(StartD));
    FOnDayRecalculated.Notify(StartD);
    Exit;
  end;
  Month := EncodeDate(YearOf(StartD), MonthOf(StartD), 1);
  Last := EncodeDate(YearOf(EndD), MonthOf(EndD), 1);
  Years := TList<Integer>.Create;
  try
    while (Month > 0) and (Month <= Last) do
    begin
      Carry := OpeningCarry(YearOf(Month), MonthOf(Month));
      Totals := ComputeMonth(YearOf(Month), MonthOf(Month), Carry);
      FMonths.AddOrSetValue(MonthKey(YearOf(Month), MonthOf(Month)), Totals);
      FOnMonthRecalculated.Notify(YearOf(Month), MonthOf(Month));
      if Years.IndexOf(YearOf(Month)) < 0 then
        Years.Add(YearOf(Month));
      Month := IncMonth(Month);
    end;
    for Affected in Years do
    begin
      FYears.AddOrSetValue(Affected, AssembleYear(Affected));
      PersistYear(Affected);
      FOnYearRecalculated.Notify(Affected);
    end;
    FOnDayRecalculated.Notify(StartD);
  finally
    Years.Free;
  end;
end;

procedure TTimeTotals.OnPackagesChanged(const ADate: TDate);
var
  Today: TDate;
  Carry: Double;
  Totals: TMonthTotals;
begin
  if not DateValid(ADate) then
    Exit;
  Today := Date;
  if (YearOf(ADate) > YearOf(Today)) or
     ((YearOf(ADate) = YearOf(Today)) and (MonthOf(ADate) > MonthOf(Today))) then
  begin
    Carry := OpeningCarry(YearOf(ADate), MonthOf(ADate));
    Totals := ComputeMonth(YearOf(ADate), MonthOf(ADate), Carry);
    FMonths.AddOrSetValue(MonthKey(YearOf(ADate), MonthOf(ADate)), Totals);
    if FYears.ContainsKey(YearOf(ADate)) or (YearOf(ADate) = YearOf(Today)) then
    begin
      FYears.AddOrSetValue(YearOf(ADate), AssembleYear(YearOf(ADate)));
      PersistYear(YearOf(ADate));
      FOnYearRecalculated.Notify(YearOf(ADate));
    end;
    FOnDayRecalculated.Notify(ADate);
    FOnMonthRecalculated.Notify(YearOf(ADate), MonthOf(ADate));
    Exit;
  end;
  if (YearOf(ADate) = YearOf(Today)) and (MonthOf(ADate) = MonthOf(Today)) then
  begin
    RecalculateLiveMonth(ADate);
    Exit;
  end;
  RecalculateFrom(YearOf(ADate), MonthOf(ADate));
  FOnDayRecalculated.Notify(ADate);
end;

initialization
finalization
  FreeAndNil(GTotals);

end.
