unit Journal.Store;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Classes, Vcl.ExtCtrls,
  Journal.Types, Journal.Events, Journal.BreakRules;

type
  TPackageList = TList<TWorkPackage>;

  TMonthData = class
  public
    Year: Integer;
    Month: Integer;
    Days: TObjectDictionary<Integer, TPackageList>;
    Absences: TDictionary<Integer, TAbsence>;
    DayBounds: TDictionary<Integer, TDayBounds>;
    Loaded: Boolean;
    constructor Create(AYear, AMonth: Integer);
    destructor Destroy; override;
  end;

  TJournalStore = class
  private
    FOnChanged: TNotifyHub;
    FOnPackagesChanged: TDateHub;
    FOnAbsencesChanged: TDateRangeHub;
    FOnDayBoundsChanged: TDateHub;
    FOnActiveDayTicked: TNotifyHub;
    FOnDataReloaded: TNotifyHub;
    FDataPath: string;
    FMonths: TObjectDictionary<string, TMonthData>;
    FTick: TTimer;
    constructor Create;
    class function MonthKey(AYear, AMonth: Integer): string; static;
    function MonthFilePath(AYear, AMonth: Integer): string;
    procedure ReloadIfPathChanged;
    procedure EnsureMonthLoaded(AYear, AMonth: Integer);
    procedure LoadMonth(AYear, AMonth: Integer);
    function SaveMonth(AYear, AMonth: Integer; out Error: string): Boolean;
    function MonthData(AYear, AMonth: Integer): TMonthData;
    function MonthDataIfLoaded(AYear, AMonth: Integer): TMonthData;
    function HasActivePackagesToday: Boolean;
    function PersistActivePackagesToday: Boolean;
    function LastCountableMinute(const ADate: TDate): Integer;
    function CoverageForDate(const ADate: TDate): TArray<Boolean>;
    procedure OnTick(Sender: TObject);
    procedure OnSettingsChanged;
  public
    destructor Destroy; override;
    class function Instance: TJournalStore; static;
    property OnChanged: TNotifyHub read FOnChanged;
    property OnPackagesChanged: TDateHub read FOnPackagesChanged;
    property OnAbsencesChanged: TDateRangeHub read FOnAbsencesChanged;
    property OnDayBoundsChanged: TDateHub read FOnDayBoundsChanged;
    property OnActiveDayTicked: TNotifyHub read FOnActiveDayTicked;
    property OnDataReloaded: TNotifyHub read FOnDataReloaded;

    function PackagesForDate(const ADate: TDate): TArray<TWorkPackage>;
    function PackageById(const ADate: TDate; const Id: string): TWorkPackage;
    function SavePackage(const ADate: TDate; Package: TWorkPackage; out Error: string): Boolean;
    function RemovePackage(const ADate: TDate; const Id: string; out Error: string): Boolean;
    function RenameTitle(const FromTitle, ToTitle: string; out Error: string): Boolean;
    function PausesForDate(const ADate: TDate): TArray<TPauseInterval>;
    function SuggestPause(const ADate: TDate; AtMinute: Integer; out StartMinute,
      EndMinute: Integer; out ExistingGap: Boolean): Boolean;
    function ApplyPause(const ADate: TDate; StartMinute, EndMinute: Integer;
      out Error: string): Boolean;
    function ClosePause(const ADate: TDate; StartMinute, EndMinute: Integer;
      out Error: string): Boolean;
    function StartMinuteTaken(const ADate: TDate; StartMinute: Integer;
      const ExcludeId: string = ''): Boolean;
    function ActualHoursForDate(const ADate: TDate): Double;
    function ActualHoursForMonth(AYear, AMonth: Integer): Double;
    function BreakAdjustmentForDate(const ADate: TDate): TBreakAdjustment;
    function FullDayCoverage(const ADate: TDate): TArray<Boolean>;
    function TitleHoursForMonth(AYear, AMonth: Integer): TArray<TTitleHours>;
    function AbsenceForDate(const ADate: TDate): TAbsence;
    function SetAbsences(const Dates: TArray<TDate>; const Absence: TAbsence;
      out Error: string): Boolean;
    function BoundsForDate(const ADate: TDate): TDayBounds;
    function SetBoundsForDate(const ADate: TDate; const Bounds: TDayBounds;
      out Error: string): Boolean;
  end;

implementation

uses
  System.JSON, System.IOUtils, System.DateUtils, System.Math, System.StrUtils,
  System.Generics.Defaults, Journal.Settings, Journal.TitleCatalog, Journal.JsonUtil;

var
  GStore: TJournalStore;

procedure SortByStart(var Packages: TArray<TWorkPackage>);
var
  I, J: Integer;
  Tmp: TWorkPackage;
begin
  for I := 0 to High(Packages) - 1 do
    for J := I + 1 to High(Packages) do
      if Packages[J].StartMinute < Packages[I].StartMinute then
      begin
        Tmp := Packages[I];
        Packages[I] := Packages[J];
        Packages[J] := Tmp;
      end;
end;

function PackageFromJson(Obj: TJSONObject): TWorkPackage;
begin
  Result := Default(TWorkPackage);
  if Obj = nil then
    Exit;
  Result.Id := JsonStr(Obj, 'id');
  Result.Title := JsonStr(Obj, 'title');
  Result.Details := JsonStr(Obj, 'details');
  Result.StartMinute := TextToMinute(JsonStr(Obj, 'start'));
  Result.EndMinuteStored := TextToMinute(JsonStr(Obj, 'end'));
  Result.Active := JsonBool(Obj, 'active', False);
end;

function PackageToJson(const Pkg: TWorkPackage): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', Pkg.Id);
  Result.AddPair('title', Pkg.Title);
  Result.AddPair('details', Pkg.Details);
  Result.AddPair('start', MinuteToText(Pkg.StartMinute));
  Result.AddPair('end', MinuteToText(Pkg.EndMinuteStored));
  Result.AddPair('active', TJSONBool.Create(Pkg.Active));
end;

constructor TMonthData.Create(AYear, AMonth: Integer);
begin
  inherited Create;
  Year := AYear;
  Month := AMonth;
  Days := TObjectDictionary<Integer, TPackageList>.Create([doOwnsValues]);
  Absences := TDictionary<Integer, TAbsence>.Create;
  DayBounds := TDictionary<Integer, TDayBounds>.Create;
  Loaded := False;
end;

destructor TMonthData.Destroy;
begin
  Days.Free;
  Absences.Free;
  DayBounds.Free;
  inherited;
end;

constructor TJournalStore.Create;
begin
  inherited Create;
  FOnChanged := TNotifyHub.Create;
  FOnPackagesChanged := TDateHub.Create;
  FOnAbsencesChanged := TDateRangeHub.Create;
  FOnDayBoundsChanged := TDateHub.Create;
  FOnActiveDayTicked := TNotifyHub.Create;
  FOnDataReloaded := TNotifyHub.Create;
  FMonths := TObjectDictionary<string, TMonthData>.Create([doOwnsValues]);
  FTick := TTimer.Create(nil);
  FTick.Interval := 60 * 1000;
  FTick.OnTimer := OnTick;
  FTick.Enabled := True;
  TAppSettings.Instance.OnChanged.Add(OnSettingsChanged);
  ReloadIfPathChanged;
end;

destructor TJournalStore.Destroy;
begin
  TAppSettings.Instance.OnChanged.Remove(OnSettingsChanged);
  FTick.Free;
  FMonths.Free;
  FOnChanged.Free;
  FOnPackagesChanged.Free;
  FOnAbsencesChanged.Free;
  FOnDayBoundsChanged.Free;
  FOnActiveDayTicked.Free;
  FOnDataReloaded.Free;
  inherited;
end;

class function TJournalStore.Instance: TJournalStore;
begin
  if GStore = nil then
    GStore := TJournalStore.Create;
  Result := GStore;
end;

procedure TJournalStore.OnTick(Sender: TObject);
begin
  PersistActivePackagesToday;
end;

procedure TJournalStore.OnSettingsChanged;
begin
  ReloadIfPathChanged;
end;

class function TJournalStore.MonthKey(AYear, AMonth: Integer): string;
begin
  Result := Format('%d-%.2d', [AYear, AMonth]);
end;

function TJournalStore.MonthFilePath(AYear, AMonth: Integer): string;
begin
  Result := TPath.Combine(TPath.Combine(TAppSettings.Instance.DataPath, 'monate'),
    MonthKey(AYear, AMonth) + '.json');
end;

procedure TJournalStore.ReloadIfPathChanged;
var
  Path: string;
begin
  Path := TAppSettings.Instance.DataPath;
  if (Path = FDataPath) and (FDataPath <> '') then
    Exit;
  FDataPath := Path;
  FMonths.Clear;
  FOnDataReloaded.Notify;
  FOnChanged.Notify;
end;

procedure TJournalStore.EnsureMonthLoaded(AYear, AMonth: Integer);
var
  Key: string;
  Data: TMonthData;
begin
  ReloadIfPathChanged;
  Key := MonthKey(AYear, AMonth);
  if FMonths.TryGetValue(Key, Data) and Data.Loaded then
    Exit;
  LoadMonth(AYear, AMonth);
end;

function TJournalStore.MonthData(AYear, AMonth: Integer): TMonthData;
begin
  EnsureMonthLoaded(AYear, AMonth);
  Result := FMonths[MonthKey(AYear, AMonth)];
end;

function TJournalStore.MonthDataIfLoaded(AYear, AMonth: Integer): TMonthData;
begin
  if not FMonths.TryGetValue(MonthKey(AYear, AMonth), Result) or not Result.Loaded then
    Result := nil;
end;

procedure TJournalStore.LoadMonth(AYear, AMonth: Integer);
var
  Data: TMonthData;
  RootVal: TJSONValue;
  Root, DaysObj, AbsencesObj, BoundsObj, ItemObj: TJSONObject;
  Pair: TJSONPair;
  DateVal: TDate;
  Packages: TArray<TWorkPackage>;
  List: TPackageList;
  Arr: TJSONArray;
  I: Integer;
  Pkg: TWorkPackage;
  Absence: TAbsence;
  StartT, EndT: Integer;
  Bounds: TDayBounds;
begin
  Data := TMonthData.Create(AYear, AMonth);
  Data.Loaded := True;
  RootVal := LoadJsonFile(MonthFilePath(AYear, AMonth));
  if RootVal is TJSONObject then
  begin
    Root := TJSONObject(RootVal);
    DaysObj := JsonObj(Root, 'days');
    if DaysObj <> nil then
      for Pair in DaysObj do
      begin
        DateVal := ParseIsoDate(Pair.JsonString.Value);
        if not DateValid(DateVal) or (YearOf(DateVal) <> AYear) or (MonthOf(DateVal) <> AMonth) then
          Continue;
        if not (Pair.JsonValue is TJSONArray) then
          Continue;
        Arr := TJSONArray(Pair.JsonValue);
        SetLength(Packages, 0);
        for I := 0 to Arr.Count - 1 do
        begin
          if not (Arr.Items[I] is TJSONObject) then
            Continue;
          Pkg := PackageFromJson(TJSONObject(Arr.Items[I]));
          if (Pkg.Id = '') or (Pkg.StartMinute < 0) then
            Continue;
          if Pkg.Active and not SameDate(DateVal, Date) then
            Pkg.Active := False;
          SetLength(Packages, Length(Packages) + 1);
          Packages[High(Packages)] := Pkg;
        end;
        SortByStart(Packages);
        List := TPackageList.Create;
        for Pkg in Packages do
          List.Add(Pkg);
        Data.Days.AddOrSetValue(DayOf(DateVal), List);
      end;

    AbsencesObj := JsonObj(Root, 'absences');
    if AbsencesObj <> nil then
      for Pair in AbsencesObj do
      begin
        DateVal := ParseIsoDate(Pair.JsonString.Value);
        if not DateValid(DateVal) or (YearOf(DateVal) <> AYear) or (MonthOf(DateVal) <> AMonth) then
          Continue;
        if not (Pair.JsonValue is TJSONObject) then
          Continue;
        ItemObj := TJSONObject(Pair.JsonValue);
        Absence := TAbsence.FromJson(JsonStr(ItemObj, 'type'), JsonFloat(ItemObj, 'fraction', 1));
        if Absence.IsSet then
          Data.Absences.AddOrSetValue(DayOf(DateVal), Absence);
      end;

    BoundsObj := JsonObj(Root, 'dayBounds');
    if BoundsObj <> nil then
      for Pair in BoundsObj do
      begin
        DateVal := ParseIsoDate(Pair.JsonString.Value);
        if not DateValid(DateVal) or (YearOf(DateVal) <> AYear) or (MonthOf(DateVal) <> AMonth) then
          Continue;
        if not (Pair.JsonValue is TJSONObject) then
          Continue;
        ItemObj := TJSONObject(Pair.JsonValue);
        StartT := TextToMinute(JsonStr(ItemObj, 'start'));
        EndT := TextToMinute(JsonStr(ItemObj, 'end'));
        if (StartT <= 0) and (JsonStr(ItemObj, 'start') = '') then
          Continue;
        if StartT >= EndT then
          Continue;
        Bounds := SanitizeDayBounds(StartT, EndT, True);
        Data.DayBounds.AddOrSetValue(DayOf(DateVal), Bounds);
      end;
  end;
  RootVal.Free;
  FMonths.AddOrSetValue(MonthKey(AYear, AMonth), Data);
end;

function TJournalStore.SaveMonth(AYear, AMonth: Integer; out Error: string): Boolean;
var
  Path: string;
  Data: TMonthData;
  Root, DaysObj, AbsencesObj, BoundsObj, Item: TJSONObject;
  Arr: TJSONArray;
  Pair: TPair<Integer, TPackageList>;
  AbsPair: TPair<Integer, TAbsence>;
  BndPair: TPair<Integer, TDayBounds>;
  Pkg: TWorkPackage;
  DateVal: TDate;
begin
  Error := '';
  Path := MonthFilePath(AYear, AMonth);
  Data := FMonths[MonthKey(AYear, AMonth)];
  Root := TJSONObject.Create;
  try
    Root.AddPair('year', TJSONNumber.Create(AYear));
    Root.AddPair('month', TJSONNumber.Create(AMonth));
    DaysObj := TJSONObject.Create;
    for Pair in Data.Days do
    begin
      if (Pair.Value = nil) or (Pair.Value.Count = 0) then
        Continue;
      DateVal := EncodeDate(AYear, AMonth, Pair.Key);
      Arr := TJSONArray.Create;
      for Pkg in Pair.Value do
        Arr.AddElement(PackageToJson(Pkg));
      DaysObj.AddPair(IsoDate(DateVal), Arr);
    end;
    Root.AddPair('days', DaysObj);

    AbsencesObj := TJSONObject.Create;
    for AbsPair in Data.Absences do
    begin
      if not AbsPair.Value.IsSet then
        Continue;
      DateVal := EncodeDate(AYear, AMonth, AbsPair.Key);
      Item := TJSONObject.Create;
      Item.AddPair('type', AbsPair.Value.TypeString);
      Item.AddPair('fraction', TJSONNumber.Create(AbsPair.Value.Fraction));
      AbsencesObj.AddPair(IsoDate(DateVal), Item);
    end;
    if AbsencesObj.Count > 0 then
      Root.AddPair('absences', AbsencesObj)
    else
      AbsencesObj.Free;

    BoundsObj := TJSONObject.Create;
    for BndPair in Data.DayBounds do
    begin
      if not BndPair.Value.Custom then
        Continue;
      DateVal := EncodeDate(AYear, AMonth, BndPair.Key);
      Item := TJSONObject.Create;
      Item.AddPair('start', MinuteToText(BndPair.Value.StartMinute));
      Item.AddPair('end', MinuteToText(BndPair.Value.EndMinute));
      BoundsObj.AddPair(IsoDate(DateVal), Item);
    end;
    if BoundsObj.Count > 0 then
      Root.AddPair('dayBounds', BoundsObj)
    else
      BoundsObj.Free;

    try
      SaveJsonFile(Path, Root);
      Result := True;
    except
      Error := 'Monatdatei konnte nicht geschrieben werden.';
      Result := False;
    end;
  finally
    Root.Free;
  end;
end;

function TJournalStore.PackagesForDate(const ADate: TDate): TArray<TWorkPackage>;
var
  Data: TMonthData;
  List: TPackageList;
begin
  SetLength(Result, 0);
  if not DateValid(ADate) then
    Exit;
  Data := MonthData(YearOf(ADate), MonthOf(ADate));
  if Data.Days.TryGetValue(DayOf(ADate), List) and (List <> nil) then
    Result := List.ToArray;
end;

function TJournalStore.PackageById(const ADate: TDate; const Id: string): TWorkPackage;
var
  Pkg: TWorkPackage;
begin
  Result := Default(TWorkPackage);
  for Pkg in PackagesForDate(ADate) do
    if Pkg.Id = Id then
      Exit(Pkg);
end;

function TJournalStore.StartMinuteTaken(const ADate: TDate; StartMinute: Integer;
  const ExcludeId: string): Boolean;
var
  Pkg: TWorkPackage;
begin
  Result := False;
  if not DateValid(ADate) then
    Exit;
  for Pkg in PackagesForDate(ADate) do
    if (Pkg.Id <> ExcludeId) and (Pkg.StartMinute = StartMinute) then
      Exit(True);
end;

function TJournalStore.SavePackage(const ADate: TDate; Package: TWorkPackage;
  out Error: string): Boolean;
var
  Data: TMonthData;
  List: TPackageList;
  I: Integer;
  Replaced: Boolean;
  Pkg: TWorkPackage;
begin
  Error := '';
  if not DateValid(ADate) or (Package.Id = '') or (Trim(Package.Title) = '') then
  begin
    Error := 'Ungültiges Arbeitspaket.';
    Exit(False);
  end;
  Package.Title := TTitleCatalog.Instance.CanonicalTitle(Package.Title);
  if Package.Active and not SameDate(ADate, Date) then
    Package.Active := False;
  if Package.Active then
    Package.EndMinuteStored := TimeToMinute(Time);

  Data := MonthData(YearOf(ADate), MonthOf(ADate));
  if not Data.Days.TryGetValue(DayOf(ADate), List) or (List = nil) then
  begin
    List := TPackageList.Create;
    Data.Days.AddOrSetValue(DayOf(ADate), List);
  end;

  for Pkg in List do
    if (Pkg.Id <> Package.Id) and (Pkg.StartMinute = Package.StartMinute) then
    begin
      Error := 'Ein anderes Arbeitspaket beginnt bereits in derselben Minute.';
      Exit(False);
    end;

  Replaced := False;
  for I := 0 to List.Count - 1 do
    if List[I].Id = Package.Id then
    begin
      List[I] := Package;
      Replaced := True;
      Break;
    end;
  if not Replaced then
    List.Add(Package);
  List.Sort(TComparer<TWorkPackage>.Construct(
    function(const A, B: TWorkPackage): Integer
    begin
      Result := A.StartMinute - B.StartMinute;
    end));

  if not SaveMonth(YearOf(ADate), MonthOf(ADate), Error) then
    Exit(False);
  FOnChanged.Notify;
  FOnPackagesChanged.Notify(ADate);
  Result := True;
end;

function TJournalStore.RenameTitle(const FromTitle, ToTitle: string; out Error: string): Boolean;
var
  OldTitle, NewTitle, Dir, Name, Base: string;
  Files: TArray<string>;
  Parts: TArray<string>;
  Year, Month, I: Integer;
  Data: TMonthData;
  Pair: TPair<Integer, TPackageList>;
  J: Integer;
  Pkg: TWorkPackage;
  MonthChanged, AnyChanged: Boolean;
begin
  Error := '';
  OldTitle := Trim(FromTitle);
  NewTitle := Trim(ToTitle);
  if (OldTitle = '') or (NewTitle = '') then
  begin
    Error := 'Titel darf nicht leer sein.';
    Exit(False);
  end;
  ReloadIfPathChanged;
  Dir := TPath.Combine(TAppSettings.Instance.DataPath, 'monate');
  AnyChanged := False;
  if TDirectory.Exists(Dir) then
    Files := TDirectory.GetFiles(Dir, '*.json')
  else
    SetLength(Files, 0);
  for Name in Files do
  begin
    Base := TPath.GetFileNameWithoutExtension(Name);
    Parts := Base.Split(['-']);
    if Length(Parts) <> 2 then
      Continue;
    if not TryStrToInt(Parts[0], Year) or not TryStrToInt(Parts[1], Month) then
      Continue;
    if (Year < 1970) or (Year > 2100) or (Month < 1) or (Month > 12) then
      Continue;
    Data := MonthData(Year, Month);
    MonthChanged := False;
    for Pair in Data.Days do
      if Pair.Value <> nil then
        for J := 0 to Pair.Value.Count - 1 do
        begin
          Pkg := Pair.Value[J];
          if AnsiSameText(Pkg.Title, OldTitle) and (Pkg.Title <> NewTitle) then
          begin
            Pkg.Title := NewTitle;
            Pair.Value[J] := Pkg;
            MonthChanged := True;
          end;
        end;
    if not MonthChanged then
      Continue;
    if not SaveMonth(Year, Month, Error) then
      Exit(False);
    AnyChanged := True;
  end;
  if AnyChanged then
    FOnChanged.Notify;
  Result := True;
end;

function TJournalStore.RemovePackage(const ADate: TDate; const Id: string;
  out Error: string): Boolean;
var
  Data: TMonthData;
  List: TPackageList;
  I, Before: Integer;
begin
  Error := '';
  if not DateValid(ADate) or (Id = '') then
    Exit(False);
  Data := MonthData(YearOf(ADate), MonthOf(ADate));
  if not Data.Days.TryGetValue(DayOf(ADate), List) or (List = nil) then
    Exit(False);
  Before := List.Count;
  for I := List.Count - 1 downto 0 do
    if List[I].Id = Id then
      List.Delete(I);
  if List.Count = Before then
    Exit(False);
  if List.Count = 0 then
    Data.Days.Remove(DayOf(ADate));
  if not SaveMonth(YearOf(ADate), MonthOf(ADate), Error) then
    Exit(False);
  FOnChanged.Notify;
  FOnPackagesChanged.Notify(ADate);
  Result := True;
end;

function TJournalStore.PausesForDate(const ADate: TDate): TArray<TPauseInterval>;
var
  Covered: TArray<Boolean>;
  First, Last, I, Run, Count: Integer;
begin
  SetLength(Result, 0);
  Covered := FullDayCoverage(ADate);
  First := -1;
  Last := -1;
  for I := 0 to High(Covered) do
    if Covered[I] then
    begin
      if First < 0 then
        First := I;
      Last := I;
    end;
  if First < 0 then
    Exit;
  Run := -1;
  Count := 0;
  for I := First to Last do
  begin
    if not Covered[I] then
    begin
      if Run < 0 then
        Run := I;
    end
    else if Run >= 0 then
    begin
      SetLength(Result, Count + 1);
      Result[Count].StartMinute := Run;
      Result[Count].EndMinute := I;
      Inc(Count);
      Run := -1;
    end;
  end;
end;

function TJournalStore.SuggestPause(const ADate: TDate; AtMinute: Integer;
  out StartMinute, EndMinute: Integer; out ExistingGap: Boolean): Boolean;

  procedure SetRange(AStart, AEnd: Integer; Existing: Boolean);
  begin
    StartMinute := AStart;
    EndMinute := AEnd;
    ExistingGap := Existing;
  end;

var
  Pause: TPauseInterval;
  Bounds, Window: TDayBounds;
  Breaks: TBreakAdjustment;
  Idx, FromIdx, ToIdx: Integer;
  Pkg: TWorkPackage;
  PkgStart, PkgEnd: Integer;
begin
  AtMinute := ClampInt(AtMinute, 0, 24 * 60 - 1);
  for Pause in PausesForDate(ADate) do
    if (AtMinute >= Pause.StartMinute) and (AtMinute < Pause.EndMinute) then
    begin
      SetRange(Pause.StartMinute, Pause.EndMinute, True);
      Exit(Pause.EndMinute > Pause.StartMinute);
    end;

  Bounds := BoundsForDate(ADate);
  Breaks := BreakAdjustmentForDate(ADate);
  Idx := AtMinute - Bounds.StartMinute;
  if (Idx >= 0) and (Idx <= High(Breaks.AutoPause)) and Breaks.AutoPause[Idx] then
  begin
    FromIdx := Idx;
    ToIdx := Idx + 1;
    while (FromIdx > 0) and Breaks.AutoPause[FromIdx - 1] do
      Dec(FromIdx);
    while (ToIdx <= High(Breaks.AutoPause)) and Breaks.AutoPause[ToIdx] do
      Inc(ToIdx);
    SetRange(Bounds.StartMinute + FromIdx, Bounds.StartMinute + ToIdx, False);
    Exit(True);
  end;

  Window := TAppSettings.Instance.UsualPauseWindow;
  if (AtMinute >= Window.StartMinute) and (AtMinute < Window.EndMinute) then
  begin
    SetRange(Window.StartMinute, Window.EndMinute, False);
    Exit(True);
  end;

    StartMinute := AtMinute;
    EndMinute := Min(AtMinute + PauseAfterSixHoursMinutes, 24 * 60);
    for Pkg in PackagesForDate(ADate) do
    begin
      PkgStart := Pkg.StartMinute;
      PkgEnd := Pkg.EndMinute(ADate);
      if (AtMinute >= PkgStart) and (AtMinute < PkgEnd) then
      begin
        if PkgEnd - PkgStart >= 2 then
        begin
          StartMinute := ClampInt(AtMinute, PkgStart + 1, PkgEnd - 1);
          EndMinute := Min(PkgEnd - 1, StartMinute + PauseAfterSixHoursMinutes);
          if EndMinute <= StartMinute then
            EndMinute := Min(PkgEnd, StartMinute + 1);
        end
        else
        begin
          StartMinute := PkgStart;
          EndMinute := Min(24 * 60, PkgStart + PauseAfterSixHoursMinutes);
        end;
        Break;
      end;
    end;
  ExistingGap := False;
  Result := EndMinute > StartMinute;
end;

function TJournalStore.ApplyPause(const ADate: TDate; StartMinute, EndMinute: Integer;
  out Error: string): Boolean;
var
  Data: TMonthData;
  List: TPackageList;
  Next: TArray<TWorkPackage>;
  Pkg, Left, Right: TWorkPackage;
  CutAny: Boolean;
  Starts: TDictionary<Integer, Boolean>;
  Start, Count: Integer;
begin
  Error := '';
  if not DateValid(ADate) then
  begin
    Error := 'Ungültiges Datum.';
    Exit(False);
  end;
  StartMinute := ClampInt(StartMinute, 0, 23 * 60 + 58);
  EndMinute := ClampInt(EndMinute, StartMinute + 1, 24 * 60);
  if EndMinute <= StartMinute then
  begin
    Error := 'Das Pausenende muss nach dem Beginn liegen.';
    Exit(False);
  end;

  Data := MonthData(YearOf(ADate), MonthOf(ADate));
  if not Data.Days.TryGetValue(DayOf(ADate), List) or (List = nil) then
  begin
    Error := 'In diesem Zeitraum liegt kein Arbeitspaket.';
    Exit(False);
  end;

  SetLength(Next, 0);
  Count := 0;
  CutAny := False;
  for Pkg in List do
  begin
    if (Pkg.EndMinute(ADate) <= StartMinute) or (Pkg.StartMinute >= EndMinute) then
    begin
      SetLength(Next, Count + 1);
      Next[Count] := Pkg;
      Inc(Count);
      Continue;
    end;
    CutAny := True;
    if Pkg.StartMinute < StartMinute then
    begin
      Left := Pkg;
      Left.EndMinuteStored := StartMinute;
      Left.Active := False;
      SetLength(Next, Count + 1);
      Next[Count] := Left;
      Inc(Count);
    end;
    if Pkg.EndMinute(ADate) > EndMinute then
    begin
      Right := Pkg;
      if Pkg.StartMinute < StartMinute then
        Right.Id := NewPackageId;
      Right.StartMinute := EndMinute;
      SetLength(Next, Count + 1);
      Next[Count] := Right;
      Inc(Count);
    end;
  end;

  if not CutAny then
  begin
    Error := 'In diesem Zeitraum liegt kein Arbeitspaket.';
    Exit(False);
  end;

  Starts := TDictionary<Integer, Boolean>.Create;
  try
    for Count := 0 to High(Next) do
    begin
      Pkg := Next[Count];
      Start := Pkg.StartMinute;
      while Starts.ContainsKey(Start) and (Start < 23 * 60 + 58) do
        Inc(Start);
      if Starts.ContainsKey(Start) then
      begin
        Error := 'Ein anderes Arbeitspaket beginnt bereits in derselben Minute.';
        Exit(False);
      end;
      if Start <> Pkg.StartMinute then
      begin
        Pkg.StartMinute := Start;
        Next[Count] := Pkg;
      end;
      Starts.Add(Start, True);
    end;
  finally
    Starts.Free;
  end;

  SortByStart(Next);
  List.Clear;
  for Pkg in Next do
    List.Add(Pkg);
  if List.Count = 0 then
    Data.Days.Remove(DayOf(ADate));
  if not SaveMonth(YearOf(ADate), MonthOf(ADate), Error) then
    Exit(False);
  FOnChanged.Notify;
  FOnPackagesChanged.Notify(ADate);
  Result := True;
end;

function TJournalStore.ClosePause(const ADate: TDate; StartMinute, EndMinute: Integer;
  out Error: string): Boolean;
var
  Data: TMonthData;
  List: TPackageList;
  Packages: TArray<TWorkPackage>;
  I, LeftIdx, RightIdx: Integer;
  Left, Right: TWorkPackage;
begin
  Error := '';
  if (not DateValid(ADate)) or (EndMinute <= StartMinute) then
  begin
    Error := 'Ungültige Pause.';
    Exit(False);
  end;
  Data := MonthData(YearOf(ADate), MonthOf(ADate));
  if not Data.Days.TryGetValue(DayOf(ADate), List) or (List = nil) then
  begin
    Error := 'Keine angrenzenden Arbeitspakete für diese Pause.';
    Exit(False);
  end;
  SetLength(Packages, List.Count);
  for I := 0 to List.Count - 1 do
    Packages[I] := List[I];

  LeftIdx := -1;
  RightIdx := -1;
  for I := 0 to High(Packages) do
  begin
    if Packages[I].EndMinute(ADate) = StartMinute then
      if (LeftIdx < 0) or (Packages[I].StartMinute > Packages[LeftIdx].StartMinute) then
        LeftIdx := I;
    if Packages[I].StartMinute = EndMinute then
      if (RightIdx < 0) or (Packages[I].StartMinute < Packages[RightIdx].StartMinute) then
        RightIdx := I;
  end;

  if (LeftIdx < 0) and (RightIdx < 0) then
  begin
    Error := 'Keine angrenzenden Arbeitspakete für diese Pause.';
    Exit(False);
  end;

  if (LeftIdx >= 0) and (RightIdx >= 0) and
     AnsiSameText(Packages[LeftIdx].Title, Packages[RightIdx].Title) then
  begin
    Left := Packages[LeftIdx];
    Right := Packages[RightIdx];
    Left.EndMinuteStored := Right.EndMinute(ADate);
    Left.Active := Left.Active or Right.Active;
    if Trim(Left.Details) = '' then
      Left.Details := Right.Details
    else if (Trim(Right.Details) <> '') and (Left.Details <> Right.Details) then
      Left.Details := Left.Details + sLineBreak + Right.Details;
    Packages[LeftIdx] := Left;
    for I := RightIdx to High(Packages) - 1 do
      Packages[I] := Packages[I + 1];
    SetLength(Packages, Length(Packages) - 1);
  end
  else if LeftIdx >= 0 then
  begin
    Left := Packages[LeftIdx];
    Left.EndMinuteStored := EndMinute;
    Left.Active := False;
    Packages[LeftIdx] := Left;
  end
  else if StartMinuteTaken(ADate, StartMinute, Packages[RightIdx].Id) then
  begin
    Error := 'Ein anderes Arbeitspaket beginnt bereits in derselben Minute.';
    Exit(False);
  end
  else
  begin
    Right := Packages[RightIdx];
    Right.StartMinute := StartMinute;
    Packages[RightIdx] := Right;
  end;

  SortByStart(Packages);
  List.Clear;
  for I := 0 to High(Packages) do
    List.Add(Packages[I]);
  if not SaveMonth(YearOf(ADate), MonthOf(ADate), Error) then
    Exit(False);
  FOnChanged.Notify;
  FOnPackagesChanged.Notify(ADate);
  Result := True;
end;

function TJournalStore.PersistActivePackagesToday: Boolean;
var
  Today: TDate;
  Data: TMonthData;
  List: TPackageList;
  I: Integer;
  Pkg: TWorkPackage;
  NowMin: Integer;
  Dummy: string;
begin
  Result := False;
  if not HasActivePackagesToday then
    Exit;
  Today := Date;
  Data := MonthData(YearOf(Today), MonthOf(Today));
  if not Data.Days.TryGetValue(DayOf(Today), List) or (List = nil) then
    Exit;
  NowMin := TimeToMinute(Time);
  for I := 0 to List.Count - 1 do
  begin
    Pkg := List[I];
    if Pkg.Active then
    begin
      Pkg.EndMinuteStored := NowMin;
      List[I] := Pkg;
    end;
  end;
  if not SaveMonth(YearOf(Today), MonthOf(Today), Dummy) then
    Exit(False);
  FOnChanged.Notify;
  FOnActiveDayTicked.Notify;
  Result := True;
end;

function TJournalStore.LastCountableMinute(const ADate: TDate): Integer;
var
  Today: TDate;
begin
  Today := Date;
  if not DateValid(ADate) or (ADate > Today) then
    Exit(-1);
  if ADate < Today then
    Exit(24 * 60);
  Result := TimeToMinute(Time);
end;

function TJournalStore.CoverageForDate(const ADate: TDate): TArray<Boolean>;
var
  Bounds: TDayBounds;
  Last, StartM, EndM, Minute: Integer;
  Pkg: TWorkPackage;
begin
  Bounds := BoundsForDate(ADate);
  SetLength(Result, Bounds.Span);
  Last := LastCountableMinute(ADate);
  if Last < 0 then
    Exit;
  for Pkg in PackagesForDate(ADate) do
  begin
    StartM := Max(Pkg.StartMinute, Bounds.StartMinute);
    EndM := Min(Pkg.EndMinute(ADate), Min(Bounds.EndMinute, Last));
    for Minute := StartM to EndM - 1 do
      Result[Minute - Bounds.StartMinute] := True;
  end;
end;

function TJournalStore.FullDayCoverage(const ADate: TDate): TArray<Boolean>;
var
  Last, StartM, EndM, Minute: Integer;
  Pkg: TWorkPackage;
begin
  SetLength(Result, 24 * 60);
  Last := LastCountableMinute(ADate);
  if Last < 0 then
    Exit;
  for Pkg in PackagesForDate(ADate) do
  begin
    StartM := Max(0, Min(Pkg.StartMinute, 24 * 60));
    EndM := Max(StartM, Min(Pkg.EndMinute(ADate), Min(Last, 24 * 60)));
    for Minute := StartM to EndM - 1 do
      Result[Minute] := True;
  end;
end;

function TJournalStore.BreakAdjustmentForDate(const ADate: TDate): TBreakAdjustment;
begin
  Result := ApplyAutomaticBreaks(CoverageForDate(ADate));
end;

function TJournalStore.ActualHoursForDate(const ADate: TDate): Double;
begin
  Result := BreakAdjustmentForDate(ADate).CreditedMinutes / 60.0;
end;

function TJournalStore.ActualHoursForMonth(AYear, AMonth: Integer): Double;
var
  First: TDateTime;
  Days, Day: Integer;
begin
  Result := 0;
  if not TryEncodeDate(AYear, AMonth, 1, First) then
    Exit;
  Days := DaysInAMonth(AYear, AMonth);
  for Day := 1 to Days do
    Result := Result + ActualHoursForDate(EncodeDate(AYear, AMonth, Day));
end;

function TJournalStore.TitleHoursForMonth(AYear, AMonth: Integer): TArray<TTitleHours>;
var
  MinutesByTitle: TDictionary<string, Integer>;
  Days, Day, Last, Minute, Index, TopStart, I, J: Integer;
  DateVal: TDateTime;
  Packages: TArray<TWorkPackage>;
  Breaks: TBreakAdjustment;
  Bounds: TDayBounds;
  Top: Integer;
  Pair: TPair<string, Integer>;
  Item: TTitleHours;
begin
  SetLength(Result, 0);
  if not TryEncodeDate(AYear, AMonth, 1, DateVal) then
    Exit;
  MinutesByTitle := TDictionary<string, Integer>.Create;
  try
    Days := DaysInAMonth(AYear, AMonth);
    for Day := 1 to Days do
    begin
      DateVal := EncodeDate(AYear, AMonth, Day);
      Last := LastCountableMinute(DateVal);
      if Last < 0 then
        Continue;
      Packages := PackagesForDate(DateVal);
      Breaks := BreakAdjustmentForDate(DateVal);
      Bounds := BoundsForDate(DateVal);
      Minute := Bounds.StartMinute;
      while (Minute < Bounds.EndMinute) and (Minute < Last) do
      begin
        Index := Minute - Bounds.StartMinute;
        if (Index >= 0) and (Index < Length(Breaks.Credited)) and Breaks.Credited[Index] then
        begin
          Top := -1;
          TopStart := -1;
          for I := 0 to High(Packages) do
            if (Minute >= Packages[I].StartMinute) and (Minute < Packages[I].EndMinute(DateVal))
               and ((Top < 0) or (Packages[I].StartMinute > TopStart)) then
            begin
              Top := I;
              TopStart := Packages[I].StartMinute;
            end;
          if Top >= 0 then
          begin
            if not MinutesByTitle.TryGetValue(Packages[Top].Title, J) then
              J := 0;
            MinutesByTitle.AddOrSetValue(Packages[Top].Title, J + 1);
          end;
        end;
        Inc(Minute);
      end;
    end;
    SetLength(Result, MinutesByTitle.Count);
    I := 0;
    for Pair in MinutesByTitle do
    begin
      Item.Title := Pair.Key;
      Item.Hours := Pair.Value / 60.0;
      Result[I] := Item;
      Inc(I);
    end;
    for I := 0 to High(Result) - 1 do
      for J := I + 1 to High(Result) do
        if (Result[J].Hours > Result[I].Hours) or
           ((Result[J].Hours = Result[I].Hours) and
            (AnsiCompareText(Result[J].Title, Result[I].Title) < 0)) then
        begin
          Item := Result[I];
          Result[I] := Result[J];
          Result[J] := Item;
        end;
  finally
    MinutesByTitle.Free;
  end;
end;

function TJournalStore.AbsenceForDate(const ADate: TDate): TAbsence;
var
  Data: TMonthData;
begin
  Result := Default(TAbsence);
  if not DateValid(ADate) then
    Exit;
  Data := MonthData(YearOf(ADate), MonthOf(ADate));
  if not Data.Absences.TryGetValue(DayOf(ADate), Result) then
    Result := Default(TAbsence);
end;

function TJournalStore.SetAbsences(const Dates: TArray<TDate>; const Absence: TAbsence;
  out Error: string): Boolean;
var
  MonthKeys: TDictionary<string, Boolean>;
  FromDate, ToDate, ADate: TDate;
  Data: TMonthData;
  Key: string;
  Parts: TArray<string>;
begin
  Error := '';
  Result := True;
  if Length(Dates) = 0 then
    Exit;
  MonthKeys := TDictionary<string, Boolean>.Create;
  try
    FromDate := 0;
    ToDate := 0;
    for ADate in Dates do
    begin
      if not DateValid(ADate) then
        Continue;
      Data := MonthData(YearOf(ADate), MonthOf(ADate));
      if Absence.IsSet then
        Data.Absences.AddOrSetValue(DayOf(ADate), Absence)
      else
        Data.Absences.Remove(DayOf(ADate));
      MonthKeys.AddOrSetValue(MonthKey(YearOf(ADate), MonthOf(ADate)), True);
      if (FromDate = 0) or (ADate < FromDate) then
        FromDate := ADate;
      if (ToDate = 0) or (ADate > ToDate) then
        ToDate := ADate;
    end;
    if MonthKeys.Count = 0 then
      Exit(True);
    for Key in MonthKeys.Keys do
    begin
      Parts := Key.Split(['-']);
      if Length(Parts) <> 2 then
        Continue;
      if not SaveMonth(StrToInt(Parts[0]), StrToInt(Parts[1]), Error) then
        Exit(False);
    end;
    FOnChanged.Notify;
    FOnAbsencesChanged.Notify(FromDate, ToDate);
    Result := True;
  finally
    MonthKeys.Free;
  end;
end;

function TJournalStore.BoundsForDate(const ADate: TDate): TDayBounds;
var
  Global, OverrideB: TDayBounds;
  Data: TMonthData;
begin
  Global := SanitizeDayBounds(TAppSettings.Instance.DayStartMinute,
    TAppSettings.Instance.DayEndMinute);
  if not DateValid(ADate) then
    Exit(Global);
  Data := MonthData(YearOf(ADate), MonthOf(ADate));
  if Data.DayBounds.TryGetValue(DayOf(ADate), OverrideB) and OverrideB.Custom then
    Result := SanitizeDayBounds(OverrideB.StartMinute, OverrideB.EndMinute, True)
  else
    Result := Global;
end;

function TJournalStore.SetBoundsForDate(const ADate: TDate; const Bounds: TDayBounds;
  out Error: string): Boolean;
var
  Data: TMonthData;
begin
  Error := '';
  if not DateValid(ADate) then
    Exit(False);
  Data := MonthData(YearOf(ADate), MonthOf(ADate));
  if Bounds.Custom then
  begin
    if Bounds.StartMinute >= Bounds.EndMinute then
    begin
      Error := 'Die Tagesgrenze ' + DQuoteOpen + 'Von' + DQuoteClose +
        ' muss vor ' + DQuoteOpen + 'Bis' + DQuoteClose + ' liegen.';
      Exit(False);
    end;
    Data.DayBounds.AddOrSetValue(DayOf(ADate),
      SanitizeDayBounds(Bounds.StartMinute, Bounds.EndMinute, True));
  end
  else
    Data.DayBounds.Remove(DayOf(ADate));
  if not SaveMonth(YearOf(ADate), MonthOf(ADate), Error) then
    Exit(False);
  FOnChanged.Notify;
  FOnDayBoundsChanged.Notify(ADate);
  Result := True;
end;

function TJournalStore.HasActivePackagesToday: Boolean;
var
  Today: TDate;
  Data: TMonthData;
  List: TPackageList;
  Pkg: TWorkPackage;
begin
  Result := False;
  Today := Date;
  Data := MonthDataIfLoaded(YearOf(Today), MonthOf(Today));
  if Data = nil then
    Exit;
  if not Data.Days.TryGetValue(DayOf(Today), List) or (List = nil) then
    Exit;
  for Pkg in List do
    if Pkg.Active then
      Exit(True);
end;

initialization
finalization
  FreeAndNil(GStore);

end.
