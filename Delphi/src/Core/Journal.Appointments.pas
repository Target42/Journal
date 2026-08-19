unit Journal.Appointments;

interface

uses
  System.SysUtils, System.Generics.Collections, Journal.Types, Journal.Events;

type
  TAppointmentKind = (akOnce, akWeekly);

  TAppointment = record
    Id: string;
    Title: string;
    StartMinute: Integer;
    EndMinute: Integer;
    Kind: TAppointmentKind;
    Date: TDate;
    Weekdays: TArray<Integer>;
    function OccursOn(const ADate: TDate): Boolean;
    function Summary: string;
    function HasWeekday(ADay: Integer): Boolean;
  end;

  TAppointmentCatalog = class
  private
    FOnChanged: TNotifyHub;
    FDataPath: string;
    FItems: TList<TAppointment>;
    constructor Create;
    function FilePath: string;
    procedure ReloadIfPathChanged;
    procedure LoadFromDisk;
    procedure SaveToDisk;
    procedure SortItems;
    function IndexOf(const Id: string): Integer;
    procedure OnSettingsChanged;
    function Sanitize(var Apt: TAppointment; out Error: string): Boolean;
  public
    destructor Destroy; override;
    class function Instance: TAppointmentCatalog; static;
    property OnChanged: TNotifyHub read FOnChanged;
    function All: TArray<TAppointment>;
    function ForDate(const ADate: TDate): TArray<TAppointment>;
    function TitlesForDate(const ADate: TDate): TArray<string>;
    function ById(const Id: string): TAppointment;
    function Contains(const Id: string): Boolean;
    function Upsert(Apt: TAppointment; out Error: string): Boolean;
    function Remove(const Id: string): Boolean;
  end;

implementation

uses
  System.JSON, System.IOUtils, System.DateUtils, System.Generics.Defaults,
  Journal.Settings, Journal.JsonUtil;

var
  GCatalog: TAppointmentCatalog;

const
  DayNames: array[1..7] of string = ('Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So');

function NewAppointmentId: string;
begin
  Result := TGUID.NewGuid.ToString;
  Result := Result.Trim(['{', '}']);
end;

function HasDay(const Days: TArray<Integer>; ADay: Integer): Boolean;
var
  D: Integer;
begin
  for D in Days do
    if D = ADay then
      Exit(True);
  Result := False;
end;

function NormalizeWeekdays(const Days: TArray<Integer>): TArray<Integer>;
var
  Day: Integer;
begin
  Result := nil;
  for Day := 1 to 7 do
    if HasDay(Days, Day) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Day;
    end;
end;

function WeekdayList(const Days: TArray<Integer>): string;
var
  Norm: TArray<Integer>;
  Day: Integer;
begin
  Result := '';
  Norm := NormalizeWeekdays(Days);
  for Day in Norm do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + DayNames[Day];
  end;
end;

function TAppointment.HasWeekday(ADay: Integer): Boolean;
begin
  Result := HasDay(Weekdays, ADay);
end;

function TAppointment.OccursOn(const ADate: TDate): Boolean;
begin
  if Kind = akOnce then
    Result := DateValid(Date) and SameDate(Date, ADate)
  else
    Result := HasWeekday(IsoWeekDay(ADate));
end;

function TAppointment.Summary: string;
var
  Span, When: string;
begin
  Span := MinuteToText(StartMinute) + EnDash + MinuteToText(EndMinute);
  if Kind = akWeekly then
    When := 'w' + #$00F6 + 'chentlich ' + WeekdayList(Weekdays)
  else if DateValid(Date) then
    When := FormatDateTime('dd.mm.yyyy', Date)
  else
    When := '';
  if When = '' then
    Result := Span + '  ' + Title
  else
    Result := Span + '  ' + Title + '  ' + MiddleDot + '  ' + When;
end;

constructor TAppointmentCatalog.Create;
begin
  inherited Create;
  FOnChanged := TNotifyHub.Create;
  FItems := TList<TAppointment>.Create;
  TAppSettings.Instance.OnChanged.Add(OnSettingsChanged);
  ReloadIfPathChanged;
end;

destructor TAppointmentCatalog.Destroy;
begin
  TAppSettings.Instance.OnChanged.Remove(OnSettingsChanged);
  FItems.Free;
  FOnChanged.Free;
  inherited;
end;

class function TAppointmentCatalog.Instance: TAppointmentCatalog;
begin
  if GCatalog = nil then
    GCatalog := TAppointmentCatalog.Create;
  Result := GCatalog;
end;

procedure TAppointmentCatalog.OnSettingsChanged;
begin
  ReloadIfPathChanged;
end;

function TAppointmentCatalog.All: TArray<TAppointment>;
begin
  Result := FItems.ToArray;
end;

function TAppointmentCatalog.ForDate(const ADate: TDate): TArray<TAppointment>;
var
  Apt: TAppointment;
  Items: TList<TAppointment>;
begin
  Items := TList<TAppointment>.Create;
  try
    for Apt in FItems do
      if Apt.OccursOn(ADate) then
        Items.Add(Apt);
    Items.Sort(TComparer<TAppointment>.Construct(
      function(const A, B: TAppointment): Integer
      begin
        Result := A.StartMinute - B.StartMinute;
        if Result = 0 then
          Result := AnsiCompareText(A.Title, B.Title);
      end));
    Result := Items.ToArray;
  finally
    Items.Free;
  end;
end;

function TAppointmentCatalog.TitlesForDate(const ADate: TDate): TArray<string>;
var
  Items: TArray<TAppointment>;
  I: Integer;
begin
  Items := ForDate(ADate);
  SetLength(Result, Length(Items));
  for I := 0 to High(Items) do
    Result[I] := Items[I].Title;
end;

function TAppointmentCatalog.ById(const Id: string): TAppointment;
var
  Idx: Integer;
begin
  Result := Default(TAppointment);
  Idx := IndexOf(Id);
  if Idx >= 0 then
    Result := FItems[Idx];
end;

function TAppointmentCatalog.Contains(const Id: string): Boolean;
begin
  Result := IndexOf(Id) >= 0;
end;

function TAppointmentCatalog.Sanitize(var Apt: TAppointment; out Error: string): Boolean;
begin
  Error := '';
  Apt.Title := Trim(Apt.Title);
  if Apt.Title = '' then
  begin
    Error := 'Bitte einen Titel eingeben.';
    Exit(False);
  end;
  Apt.StartMinute := ClampInt(Apt.StartMinute, 0, 23 * 60 + 58);
  Apt.EndMinute := ClampInt(Apt.EndMinute, Apt.StartMinute + 1, 24 * 60);
  if Apt.EndMinute <= Apt.StartMinute then
  begin
    Error := 'Das Ende muss nach dem Beginn liegen.';
    Exit(False);
  end;
  if Apt.Kind = akWeekly then
  begin
    Apt.Weekdays := NormalizeWeekdays(Apt.Weekdays);
    Apt.Date := 0;
    if Length(Apt.Weekdays) = 0 then
    begin
      Error := 'Bitte mindestens einen Wochentag w' + #$00E4 + 'hlen.';
      Exit(False);
    end;
  end
  else
  begin
    Apt.Kind := akOnce;
    Apt.Weekdays := nil;
    if not DateValid(Apt.Date) then
    begin
      Error := 'Bitte ein Datum w' + #$00E4 + 'hlen.';
      Exit(False);
    end;
  end;
  if Trim(Apt.Id) = '' then
    Apt.Id := NewAppointmentId;
  Result := True;
end;

function TAppointmentCatalog.Upsert(Apt: TAppointment; out Error: string): Boolean;
var
  Idx: Integer;
begin
  ReloadIfPathChanged;
  if not Sanitize(Apt, Error) then
    Exit(False);
  Idx := IndexOf(Apt.Id);
  if Idx >= 0 then
    FItems[Idx] := Apt
  else
    FItems.Add(Apt);
  SortItems;
  SaveToDisk;
  FOnChanged.Notify;
  Result := True;
end;

function TAppointmentCatalog.Remove(const Id: string): Boolean;
var
  Idx: Integer;
begin
  ReloadIfPathChanged;
  Idx := IndexOf(Id);
  if Idx < 0 then
    Exit(False);
  FItems.Delete(Idx);
  SaveToDisk;
  FOnChanged.Notify;
  Result := True;
end;

function TAppointmentCatalog.FilePath: string;
begin
  Result := TPath.Combine(TAppSettings.Instance.DataPath, 'termine.json');
end;

procedure TAppointmentCatalog.ReloadIfPathChanged;
var
  Path: string;
begin
  Path := TAppSettings.Instance.DataPath;
  if (Path = FDataPath) and (FDataPath <> '') then
    Exit;
  FDataPath := Path;
  LoadFromDisk;
  FOnChanged.Notify;
end;

procedure TAppointmentCatalog.LoadFromDisk;
var
  Root: TJSONValue;
  Obj: TJSONObject;
  Arr, Days: TJSONArray;
  I, D: Integer;
  Item: TJSONObject;
  Apt: TAppointment;
  Error: string;
  Kind: string;
begin
  FItems.Clear;
  Root := LoadJsonFile(FilePath);
  if Root = nil then
    Exit;
  try
    if not (Root is TJSONObject) then
      Exit;
    Obj := TJSONObject(Root);
    Arr := JsonArr(Obj, 'appointments');
    if Arr = nil then
      Exit;
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      Item := TJSONObject(Arr.Items[I]);
      Apt := Default(TAppointment);
      Apt.Id := Trim(JsonStr(Item, 'id'));
      Apt.Title := Trim(JsonStr(Item, 'title'));
      Apt.StartMinute := TextToMinute(JsonStr(Item, 'start'));
      Apt.EndMinute := TextToMinute(JsonStr(Item, 'end'));
      Kind := LowerCase(Trim(JsonStr(Item, 'kind')));
      if Kind = 'weekly' then
      begin
        Apt.Kind := akWeekly;
        Days := JsonArr(Item, 'weekdays');
        if Days <> nil then
          for D := 0 to Days.Count - 1 do
            if Days.Items[D] is TJSONNumber then
            begin
              SetLength(Apt.Weekdays, Length(Apt.Weekdays) + 1);
              Apt.Weekdays[High(Apt.Weekdays)] := TJSONNumber(Days.Items[D]).AsInt;
            end;
      end
      else
      begin
        Apt.Kind := akOnce;
        Apt.Date := ParseIsoDate(JsonStr(Item, 'date'));
      end;
      if Sanitize(Apt, Error) and (IndexOf(Apt.Id) < 0) then
        FItems.Add(Apt);
    end;
    SortItems;
  finally
    Root.Free;
  end;
end;

procedure TAppointmentCatalog.SortItems;
begin
  FItems.Sort(TComparer<TAppointment>.Construct(
    function(const A, B: TAppointment): Integer
    begin
      if A.Kind <> B.Kind then
      begin
        if A.Kind = akWeekly then
          Result := -1
        else
          Result := 1;
        Exit;
      end;
      if (A.Kind = akOnce) and not SameDate(A.Date, B.Date) then
      begin
        if A.Date < B.Date then
          Result := -1
        else
          Result := 1;
        Exit;
      end;
      Result := A.StartMinute - B.StartMinute;
      if Result = 0 then
        Result := AnsiCompareText(A.Title, B.Title);
    end));
end;

procedure TAppointmentCatalog.SaveToDisk;
var
  Root: TJSONObject;
  Arr, Days: TJSONArray;
  Item: TJSONObject;
  Apt: TAppointment;
  Day: Integer;
begin
  Root := TJSONObject.Create;
  try
    Arr := TJSONArray.Create;
    for Apt in FItems do
    begin
      Item := TJSONObject.Create;
      Item.AddPair('id', Apt.Id);
      Item.AddPair('title', Apt.Title);
      Item.AddPair('start', MinuteToText(Apt.StartMinute));
      Item.AddPair('end', MinuteToText(Apt.EndMinute));
      if Apt.Kind = akWeekly then
      begin
        Item.AddPair('kind', 'weekly');
        Days := TJSONArray.Create;
        for Day in NormalizeWeekdays(Apt.Weekdays) do
          Days.AddElement(TJSONNumber.Create(Day));
        Item.AddPair('weekdays', Days);
      end
      else
      begin
        Item.AddPair('kind', 'once');
        Item.AddPair('date', IsoDate(Apt.Date));
      end;
      Arr.AddElement(Item);
    end;
    Root.AddPair('appointments', Arr);
    SaveJsonFile(FilePath, Root);
  finally
    Root.Free;
  end;
end;

function TAppointmentCatalog.IndexOf(const Id: string): Integer;
var
  Trimmed: string;
  I: Integer;
begin
  Trimmed := Trim(Id);
  if Trimmed = '' then
    Exit(-1);
  for I := 0 to FItems.Count - 1 do
    if FItems[I].Id = Trimmed then
      Exit(I);
  Result := -1;
end;

initialization
finalization
  FreeAndNil(GCatalog);

end.
