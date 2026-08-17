unit Journal.Calendar;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Classes, Journal.Events;

type
  TYearCache = class
  public
    PublicHolidays: TDictionary<TDate, string>;
    SchoolHolidays: TDictionary<TDate, string>;
    PublicTried: Boolean;
    SchoolTried: Boolean;
    constructor Create;
    destructor Destroy; override;
  end;

  THttpDone = reference to procedure(Ok: Boolean; const Body, Err: string);

  TCalendarService = class
  private
    FOnYearDataChanged: TIntHub;
    FOnDownloadFinished: TDownloadHub;
    FOnDownloadProgress: TProgressHub;
    FYears: TObjectDictionary<Integer, TYearCache>;
    FLoadedState: string;
    FHolidayYearQueue: TList<Integer>;
    FHolidayYearTotal: Integer;
    FHolidayYearOk: Integer;
    FHolidayYearErrors: TStringList;
    FHolidayYearBatch: Boolean;
    constructor Create;
    function StateCode: string;
    function CalendarDir: string;
    function EnsureCalendarDir: Boolean;
    function YearCache(AYear: Integer): TYearCache;
    function LoadPublicHolidaysFromDisk(AYear: Integer): Boolean;
    function LoadSchoolHolidaysFromDisk(AYear: Integer): Boolean;
    procedure ApplyPublicHolidaysJson(AYear: Integer; const Json: string);
    procedure ApplySchoolHolidaysJson(AYear: Integer; const Json: string);
    function SaveJsonText(const Path, Json: string; out Error: string): Boolean;
    procedure StartPublicHolidayDownload(AYear: Integer; Batch: Boolean);
    procedure StartNextHolidayYearDownload;
    procedure FinishHolidayYearBatch;
    procedure OnSettingsChanged;
    procedure DownloadAsync(const Url: string; const Headers: TArray<TPair<string, string>>;
      const OnDone: THttpDone);
  public
    destructor Destroy; override;
    class function Instance: TCalendarService; static;
    property OnYearDataChanged: TIntHub read FOnYearDataChanged;
    property OnDownloadFinished: TDownloadHub read FOnDownloadFinished;
    property OnDownloadProgress: TProgressHub read FOnDownloadProgress;

    procedure EnsureYearLoaded(AYear: Integer);
    procedure ReloadYear(AYear: Integer);
    procedure DownloadPublicHolidays(AYear: Integer);
    procedure DownloadPublicHolidayYears(const Years: TArray<Integer>);
    procedure DownloadSchoolHolidays(AYear: Integer);
    function PublicHolidayFilePath(AYear: Integer): string;
    function SchoolHolidayFilePath(AYear: Integer): string;
    function PublicHolidaysFileExists(AYear: Integer): Boolean;
    function HasPublicHolidays(AYear: Integer): Boolean;
    function IsPublicHoliday(const ADate: TDate): Boolean;
    function PublicHolidayName(const ADate: TDate): string;
    function IsSchoolHoliday(const ADate: TDate): Boolean;
    function SchoolHolidayName(const ADate: TDate): string;
  end;

implementation

uses
  System.JSON, System.IOUtils, System.Net.HttpClient, System.Net.URLClient,
  System.Threading, System.DateUtils, System.StrUtils,
  Journal.Settings, Journal.JsonUtil, Journal.Types;

var
  GCalendar: TCalendarService;

constructor TYearCache.Create;
begin
  inherited Create;
  PublicHolidays := TDictionary<TDate, string>.Create;
  SchoolHolidays := TDictionary<TDate, string>.Create;
end;

destructor TYearCache.Destroy;
begin
  PublicHolidays.Free;
  SchoolHolidays.Free;
  inherited;
end;

constructor TCalendarService.Create;
begin
  inherited Create;
  FOnYearDataChanged := TIntHub.Create;
  FOnDownloadFinished := TDownloadHub.Create;
  FOnDownloadProgress := TProgressHub.Create;
  FYears := TObjectDictionary<Integer, TYearCache>.Create([doOwnsValues]);
  FHolidayYearQueue := TList<Integer>.Create;
  FHolidayYearErrors := TStringList.Create;
  FLoadedState := StateCode;
  TAppSettings.Instance.OnChanged.Add(OnSettingsChanged);
end;

destructor TCalendarService.Destroy;
begin
  TAppSettings.Instance.OnChanged.Remove(OnSettingsChanged);
  FHolidayYearQueue.Free;
  FHolidayYearErrors.Free;
  FYears.Free;
  FOnYearDataChanged.Free;
  FOnDownloadFinished.Free;
  FOnDownloadProgress.Free;
  inherited;
end;

class function TCalendarService.Instance: TCalendarService;
begin
  if GCalendar = nil then
    GCalendar := TCalendarService.Create;
  Result := GCalendar;
end;

procedure TCalendarService.OnSettingsChanged;
var
  State: string;
  Year: Integer;
begin
  State := StateCode;
  if State = FLoadedState then
    Exit;
  FLoadedState := State;
  for Year in FYears.Keys do
    ReloadYear(Year);
end;

function TCalendarService.StateCode: string;
begin
  Result := UpperCase(TAppSettings.Instance.StateCode);
end;

function TCalendarService.CalendarDir: string;
begin
  Result := TPath.Combine(TAppSettings.Instance.DataPath, 'kalender');
end;

function TCalendarService.EnsureCalendarDir: Boolean;
begin
  Result := True;
  if not TDirectory.Exists(CalendarDir) then
    Result := ForceDirectories(CalendarDir);
end;

function TCalendarService.YearCache(AYear: Integer): TYearCache;
begin
  if not FYears.TryGetValue(AYear, Result) then
  begin
    Result := TYearCache.Create;
    FYears.Add(AYear, Result);
  end;
end;

function TCalendarService.PublicHolidayFilePath(AYear: Integer): string;
begin
  Result := TPath.Combine(CalendarDir, Format('feiertage_%s_%d.json', [StateCode, AYear]));
end;

function TCalendarService.SchoolHolidayFilePath(AYear: Integer): string;
begin
  Result := TPath.Combine(CalendarDir, Format('ferien_%s_%d.json', [StateCode, AYear]));
end;

function TCalendarService.PublicHolidaysFileExists(AYear: Integer): Boolean;
begin
  Result := TFile.Exists(PublicHolidayFilePath(AYear));
end;

function TCalendarService.HasPublicHolidays(AYear: Integer): Boolean;
var
  Cache: TYearCache;
begin
  if FYears.TryGetValue(AYear, Cache) and (Cache.PublicHolidays.Count > 0) then
    Exit(True);
  Result := PublicHolidaysFileExists(AYear);
end;

procedure TCalendarService.EnsureYearLoaded(AYear: Integer);
var
  Cache: TYearCache;
  Changed: Boolean;
begin
  Cache := YearCache(AYear);
  Changed := False;
  if not Cache.PublicTried then
  begin
    Cache.PublicTried := True;
    Changed := LoadPublicHolidaysFromDisk(AYear) or Changed;
  end;
  if not Cache.SchoolTried then
  begin
    Cache.SchoolTried := True;
    Changed := LoadSchoolHolidaysFromDisk(AYear) or Changed;
  end;
  if Changed then
    FOnYearDataChanged.Notify(AYear);
end;

procedure TCalendarService.ReloadYear(AYear: Integer);
var
  Cache: TYearCache;
begin
  Cache := YearCache(AYear);
  Cache.PublicHolidays.Clear;
  Cache.SchoolHolidays.Clear;
  Cache.PublicTried := False;
  Cache.SchoolTried := False;
  EnsureYearLoaded(AYear);
  FOnYearDataChanged.Notify(AYear);
end;

function TCalendarService.LoadPublicHolidaysFromDisk(AYear: Integer): Boolean;
var
  Path: string;
begin
  Path := PublicHolidayFilePath(AYear);
  if not TFile.Exists(Path) then
    Exit(False);
  ApplyPublicHolidaysJson(AYear, ReadUtf8File(Path));
  Result := True;
end;

function TCalendarService.LoadSchoolHolidaysFromDisk(AYear: Integer): Boolean;
var
  Path: string;
begin
  Path := SchoolHolidayFilePath(AYear);
  if not TFile.Exists(Path) then
    Exit(False);
  ApplySchoolHolidaysJson(AYear, ReadUtf8File(Path));
  Result := True;
end;

procedure TCalendarService.ApplyPublicHolidaysJson(AYear: Integer; const Json: string);
var
  Cache: TYearCache;
  Root: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  D: TDate;
  Name: string;
begin
  Cache := YearCache(AYear);
  Cache.PublicHolidays.Clear;
  Root := TJSONObject.ParseJSONValue(Json);
  if Root = nil then
    Exit;
  try
    if not (Root is TJSONObject) then
      Exit;
    Arr := JsonArr(TJSONObject(Root), 'feiertage');
    if Arr = nil then
      Exit;
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      Item := TJSONObject(Arr.Items[I]);
      D := ParseIsoDate(JsonStr(Item, 'date'));
      Name := JsonStr(Item, 'fname');
      if DateValid(D) then
        Cache.PublicHolidays.AddOrSetValue(D, Name);
    end;
  finally
    Root.Free;
  end;
end;

function SchoolHolidayNameFromObject(Obj: TJSONObject): string;
var
  Names: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  NameObj: TJSONObject;
    Lang, NameText: string;
  Space: Integer;
begin
  Result := '';
  if Obj = nil then
    Exit;
  Names := Obj.Values['name'];
  if Names is TJSONArray then
  begin
    Arr := TJSONArray(Names);
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      NameObj := TJSONObject(Arr.Items[I]);
      Lang := JsonStr(NameObj, 'language');
      if SameText(Lang, 'DE') then
        Exit(JsonStr(NameObj, 'text'));
    end;
    if Arr.Count > 0 then
    begin
      if Arr.Items[0] is TJSONObject then
        Exit(JsonStr(TJSONObject(Arr.Items[0]), 'text'));
    end;
  end
  else if Names <> nil then
  begin
    Result := Names.Value;
    Space := Pos(' ', Result);
    if Space > 0 then
      Result := Copy(Result, 1, Space - 1);
    if Result <> '' then
      Result[1] := UpCase(Result[1]);
  end;
end;

procedure TCalendarService.ApplySchoolHolidaysJson(AYear: Integer; const Json: string);
var
  Cache: TYearCache;
  Root: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  StartD, EndD, Day: TDate;
  Name: string;
begin
  Cache := YearCache(AYear);
  Cache.SchoolHolidays.Clear;
  Root := TJSONObject.ParseJSONValue(Json);
  if Root = nil then
    Exit;
  try
    if Root is TJSONArray then
      Arr := TJSONArray(Root)
    else
      Exit;
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      Item := TJSONObject(Arr.Items[I]);
      StartD := ParseIsoDate(JsonStr(Item, 'startDate'));
      EndD := ParseIsoDate(JsonStr(Item, 'endDate'));
      if not DateValid(StartD) then
        StartD := ParseIsoDate(JsonStr(Item, 'start'));
      if not DateValid(EndD) then
        EndD := ParseIsoDate(JsonStr(Item, 'end'));
      Name := SchoolHolidayNameFromObject(Item);
      if (not DateValid(StartD)) or (not DateValid(EndD)) or (Name = '') then
        Continue;
      Day := StartD;
      while Day <= EndD do
      begin
        if YearOf(Day) = AYear then
          if not Cache.SchoolHolidays.ContainsKey(Day) then
            Cache.SchoolHolidays.Add(Day, Name);
        Day := IncDay(Day);
      end;
    end;
  finally
    Root.Free;
  end;
end;

function TCalendarService.SaveJsonText(const Path, Json: string; out Error: string): Boolean;
begin
  Error := '';
  if not EnsureCalendarDir then
  begin
    Error := 'Kalender-Ordner konnte nicht angelegt werden.';
    Exit(False);
  end;
  try
    WriteUtf8File(Path, Json);
    Result := True;
  except
    Error := 'Datei konnte nicht geschrieben werden:' + sLineBreak + Path;
    Result := False;
  end;
end;

procedure TCalendarService.DownloadAsync(const Url: string;
  const Headers: TArray<TPair<string, string>>; const OnDone: THttpDone);
begin
  TTask.Run(
    procedure
    var
      Client: THTTPClient;
      Response: IHTTPResponse;
      Ok: Boolean;
      Body, Err: string;
      H: TPair<string, string>;
    begin
      Ok := False;
      Body := '';
      Err := '';
      Client := THTTPClient.Create;
      try
        Client.ConnectionTimeout := 30000;
        Client.ResponseTimeout := 30000;
        for H in Headers do
          Client.CustomHeaders[H.Key] := H.Value;
        try
          Response := Client.Get(Url);
          if Response.StatusCode = 200 then
          begin
            Ok := True;
            Body := Response.ContentAsString(TEncoding.UTF8);
          end
          else
            Err := Format('HTTP %d', [Response.StatusCode]);
        except
          on E: Exception do
            Err := E.Message;
        end;
      finally
        Client.Free;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(OnDone) then
            OnDone(Ok, Body, Err);
        end);
    end);
end;

procedure TCalendarService.DownloadPublicHolidays(AYear: Integer);
begin
  StartPublicHolidayDownload(AYear, False);
end;

procedure TCalendarService.DownloadPublicHolidayYears(const Years: TArray<Integer>);
var
  Unique: TList<Integer>;
  Seen: TDictionary<Integer, Boolean>;
  Year, I, J: Integer;
  Tmp: Integer;
begin
  if FHolidayYearBatch then
  begin
    FOnDownloadFinished.Notify('feiertage-jahre', 0, False,
      'Es läuft bereits ein Feiertags-Download.');
    Exit;
  end;
  Unique := TList<Integer>.Create;
  Seen := TDictionary<Integer, Boolean>.Create;
  try
    for Year in Years do
    begin
      if (Year < 1970) or (Year > 2100) or Seen.ContainsKey(Year) then
        Continue;
      Seen.Add(Year, True);
      Unique.Add(Year);
    end;
    for I := 0 to Unique.Count - 2 do
      for J := I + 1 to Unique.Count - 1 do
        if Unique[J] < Unique[I] then
        begin
          Tmp := Unique[I];
          Unique[I] := Unique[J];
          Unique[J] := Tmp;
        end;
    if Unique.Count = 0 then
    begin
      FOnDownloadFinished.Notify('feiertage-jahre', 0, True,
        'Alle benötigten Feiertage liegen bereits vor.');
      Exit;
    end;
    FHolidayYearQueue.Clear;
    FHolidayYearQueue.AddRange(Unique);
    FHolidayYearTotal := Unique.Count;
    FHolidayYearOk := 0;
    FHolidayYearErrors.Clear;
    FHolidayYearBatch := True;
    StartNextHolidayYearDownload;
  finally
    Unique.Free;
    Seen.Free;
  end;
end;

procedure TCalendarService.StartNextHolidayYearDownload;
var
  Year, Current: Integer;
begin
  if FHolidayYearQueue.Count = 0 then
  begin
    FinishHolidayYearBatch;
    Exit;
  end;
  Year := FHolidayYearQueue[0];
  FHolidayYearQueue.Delete(0);
  Current := FHolidayYearTotal - FHolidayYearQueue.Count;
  FOnDownloadProgress.Notify('feiertage', Year, Current, FHolidayYearTotal);
  StartPublicHolidayDownload(Year, True);
end;

procedure TCalendarService.FinishHolidayYearBatch;
var
  Total, OkCount: Integer;
  Errors: string;
  Partial: Boolean;
begin
  FHolidayYearBatch := False;
  Total := FHolidayYearTotal;
  OkCount := FHolidayYearOk;
  Errors := FHolidayYearErrors.Text.Trim;
  FHolidayYearTotal := 0;
  FHolidayYearOk := 0;
  FHolidayYearErrors.Clear;
  if Errors = '' then
    FOnDownloadFinished.Notify('feiertage-jahre', 0, True,
      Format('Feiertage für %d %s gespeichert.',
        [Total, IfThen(Total = 1, 'Jahr', 'Jahre')]))
  else
  begin
    Partial := OkCount > 0;
    FOnDownloadFinished.Notify('feiertage-jahre', 0, Partial,
      Format('%d von %d Jahren gespeichert.' + sLineBreak + '%s',
        [OkCount, Total, Errors]));
  end;
end;

procedure TCalendarService.StartPublicHolidayDownload(AYear: Integer; Batch: Boolean);
var
  Url: string;
begin
  Url := Format('https://get.api-feiertage.de?years=%d&states=%s',
    [AYear, LowerCase(StateCode)]);
  DownloadAsync(Url, [],
    procedure(Ok: Boolean; const Body, Err: string)
    var
      Message: string;
      Success: Boolean;
      Root: TJSONValue;
      Path, SaveErr: string;
    begin
      Success := False;
      Message := '';
      if not Ok then
        Message := Format('Download %d fehlgeschlagen:' + sLineBreak + '%s', [AYear, Err])
      else
      begin
        Root := TJSONObject.ParseJSONValue(Body);
        try
          if not (Root is TJSONObject) or
             (JsonStr(TJSONObject(Root), 'status') <> 'success') then
            Message := Format('Ungültige Antwort der Feiertags-API für %d.', [AYear])
          else
          begin
            Path := PublicHolidayFilePath(AYear);
            if not SaveJsonText(Path, Body, SaveErr) then
              Message := SaveErr
            else
            begin
              ApplyPublicHolidaysJson(AYear, Body);
              YearCache(AYear).PublicTried := True;
              FOnYearDataChanged.Notify(AYear);
              Success := True;
              Message := Format('Feiertage %d gespeichert:' + sLineBreak + '%s', [AYear, Path]);
            end;
          end;
        finally
          Root.Free;
        end;
      end;
      if Batch then
      begin
        if Success then
          Inc(FHolidayYearOk)
        else
          FHolidayYearErrors.Add(Message);
        StartNextHolidayYearDownload;
      end
      else
        FOnDownloadFinished.Notify('feiertage', AYear, Success, Message);
    end);
end;

procedure TCalendarService.DownloadSchoolHolidays(AYear: Integer);
var
  Url: string;
  Headers: TArray<TPair<string, string>>;
begin
  Url := Format(
    'https://openholidaysapi.org/SchoolHolidays?countryIsoCode=DE&subdivisionCode=DE-%s' +
    '&languageIsoCode=DE&validFrom=%d-01-01&validTo=%d-12-31',
    [StateCode, AYear, AYear]);
  SetLength(Headers, 1);
  Headers[0] := TPair<string, string>.Create('Accept', 'application/json');
  DownloadAsync(Url, Headers,
    procedure(Ok: Boolean; const Body, Err: string)
    var
      Root: TJSONValue;
      Path, SaveErr: string;
    begin
      if not Ok then
      begin
        FOnDownloadFinished.Notify('ferien', AYear, False,
          'Download fehlgeschlagen:' + sLineBreak + Err);
        Exit;
      end;
      Root := TJSONObject.ParseJSONValue(Body);
      try
        if not (Root is TJSONArray) then
        begin
          FOnDownloadFinished.Notify('ferien', AYear, False,
            'Ungültige Antwort der Ferien-API.');
          Exit;
        end;
        if TJSONArray(Root).Count = 0 then
        begin
          FOnDownloadFinished.Notify('ferien', AYear, False,
            Format('Für %d sind bei der Ferien-API keine Einträge vorhanden.', [AYear]));
          Exit;
        end;
        Path := SchoolHolidayFilePath(AYear);
        if not SaveJsonText(Path, Body, SaveErr) then
        begin
          FOnDownloadFinished.Notify('ferien', AYear, False, SaveErr);
          Exit;
        end;
        ApplySchoolHolidaysJson(AYear, Body);
        YearCache(AYear).SchoolTried := True;
        FOnYearDataChanged.Notify(AYear);
        FOnDownloadFinished.Notify('ferien', AYear, True,
          Format('Ferien %d gespeichert (%d Zeiträume):' + sLineBreak + '%s',
            [AYear, TJSONArray(Root).Count, Path]));
      finally
        Root.Free;
      end;
    end);
end;

function TCalendarService.IsPublicHoliday(const ADate: TDate): Boolean;
var
  Cache: TYearCache;
begin
  Result := False;
  if not FYears.TryGetValue(YearOf(ADate), Cache) then
    Exit;
  Result := Cache.PublicHolidays.ContainsKey(Trunc(ADate));
end;

function TCalendarService.PublicHolidayName(const ADate: TDate): string;
var
  Cache: TYearCache;
begin
  Result := '';
  if not FYears.TryGetValue(YearOf(ADate), Cache) then
    Exit;
  Cache.PublicHolidays.TryGetValue(Trunc(ADate), Result);
end;

function TCalendarService.IsSchoolHoliday(const ADate: TDate): Boolean;
var
  Cache: TYearCache;
begin
  Result := False;
  if not FYears.TryGetValue(YearOf(ADate), Cache) then
    Exit;
  Result := Cache.SchoolHolidays.ContainsKey(Trunc(ADate));
end;

function TCalendarService.SchoolHolidayName(const ADate: TDate): string;
var
  Cache: TYearCache;
begin
  Result := '';
  if not FYears.TryGetValue(YearOf(ADate), Cache) then
    Exit;
  Cache.SchoolHolidays.TryGetValue(Trunc(ADate), Result);
end;

initialization
finalization
  FreeAndNil(GCalendar);

end.
