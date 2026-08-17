unit Journal.TitleCatalog;

interface

uses
  System.SysUtils, System.Generics.Collections, Vcl.Graphics, Journal.Types, Journal.Events;

type
  TTitleCatalog = class
  private
    FOnChanged: TNotifyHub;
    FDataPath: string;
    FTitles: TList<TPackageTitle>;
    constructor Create;
    function FilePath: string;
    procedure ReloadIfPathChanged;
    procedure LoadFromDisk;
    procedure SaveToDisk;
    procedure SortTitles;
    function IndexOf(const Title: string): Integer;
    procedure OnSettingsChanged;
  public
    destructor Destroy; override;
    class function Instance: TTitleCatalog; static;
    property OnChanged: TNotifyHub read FOnChanged;
    function Titles: TArray<TPackageTitle>;
    function Contains(const Title: string): Boolean;
    function CanonicalTitle(const Title: string): string;
    function ColorFor(const Title: string): TColor;
    function NextUnusedColor: TColor;
    procedure Upsert(const Title: string; Color: TColor);
    function Rename(const FromTitle, ToTitle: string): Boolean;
  end;

implementation

uses
  System.JSON, System.IOUtils, System.Generics.Defaults, Winapi.Windows,
  Journal.Settings, Journal.JsonUtil;

var
  GCatalog: TTitleCatalog;

function PaletteColor(Index: Integer): TColor;
begin
  case Index of
    0: Result := RGB(74, 144, 217);
    1: Result := RGB(124, 179, 66);
    2: Result := RGB(251, 140, 0);
    3: Result := RGB(171, 71, 188);
    4: Result := RGB(38, 166, 154);
    5: Result := RGB(239, 83, 80);
    6: Result := RGB(92, 107, 192);
    7: Result := RGB(141, 110, 99);
    8: Result := RGB(236, 64, 122);
    9: Result := RGB(120, 144, 156);
  else
    Result := RGB(120, 120, 120);
  end;
end;

constructor TTitleCatalog.Create;
begin
  inherited Create;
  FOnChanged := TNotifyHub.Create;
  FTitles := TList<TPackageTitle>.Create;
  TAppSettings.Instance.OnChanged.Add(OnSettingsChanged);
  ReloadIfPathChanged;
end;

destructor TTitleCatalog.Destroy;
begin
  TAppSettings.Instance.OnChanged.Remove(OnSettingsChanged);
  FTitles.Free;
  FOnChanged.Free;
  inherited;
end;

class function TTitleCatalog.Instance: TTitleCatalog;
begin
  if GCatalog = nil then
    GCatalog := TTitleCatalog.Create;
  Result := GCatalog;
end;

procedure TTitleCatalog.OnSettingsChanged;
begin
  ReloadIfPathChanged;
end;

function TTitleCatalog.Titles: TArray<TPackageTitle>;
begin
  Result := FTitles.ToArray;
end;

function TTitleCatalog.Contains(const Title: string): Boolean;
begin
  Result := IndexOf(Title) >= 0;
end;

function TTitleCatalog.CanonicalTitle(const Title: string): string;
var
  Idx: Integer;
begin
  Idx := IndexOf(Title);
  if Idx < 0 then
    Result := Trim(Title)
  else
    Result := FTitles[Idx].Title;
end;

function TTitleCatalog.ColorFor(const Title: string): TColor;
var
  Idx: Integer;
begin
  Idx := IndexOf(Title);
  if Idx < 0 then
    Result := RGB(120, 120, 120)
  else
    Result := FTitles[Idx].Color;
end;

function TTitleCatalog.NextUnusedColor: TColor;
var
  Used: TList<TColor>;
  Entry: TPackageTitle;
  I: Integer;
  C: TColor;
begin
  Used := TList<TColor>.Create;
  try
    for Entry in FTitles do
      Used.Add(ColorToRGB(Entry.Color));
    for I := 0 to 9 do
    begin
      C := ColorToRGB(PaletteColor(I));
      if Used.IndexOf(C) < 0 then
        Exit(PaletteColor(I));
    end;
    Result := PaletteColor(FTitles.Count mod 10);
  finally
    Used.Free;
  end;
end;

procedure TTitleCatalog.Upsert(const Title: string; Color: TColor);
var
  Trimmed: string;
  Idx: Integer;
  Entry: TPackageTitle;
begin
  Trimmed := Trim(Title);
  if Trimmed = '' then
    Exit;
  ReloadIfPathChanged;
  Idx := IndexOf(Trimmed);
  if Idx >= 0 then
  begin
    if ColorToRGB(FTitles[Idx].Color) = ColorToRGB(Color) then
      Exit;
    Entry := FTitles[Idx];
    Entry.Color := Color;
    FTitles[Idx] := Entry;
  end
  else
  begin
    Entry.Title := Trimmed;
    Entry.Color := Color;
    FTitles.Add(Entry);
    SortTitles;
  end;
  SaveToDisk;
  FOnChanged.Notify;
end;

function TTitleCatalog.Rename(const FromTitle, ToTitle: string): Boolean;
var
  OldTitle, NewTitle: string;
  FromIndex, ToIndex: Integer;
  Entry: TPackageTitle;
begin
  OldTitle := Trim(FromTitle);
  NewTitle := Trim(ToTitle);
  if (OldTitle = '') or (NewTitle = '') then
    Exit(False);
  ReloadIfPathChanged;
  FromIndex := IndexOf(OldTitle);
  if FromIndex < 0 then
    Exit(False);
  ToIndex := IndexOf(NewTitle);
  if ToIndex = FromIndex then
  begin
    if FTitles[FromIndex].Title = NewTitle then
      Exit(True);
    Entry := FTitles[FromIndex];
    Entry.Title := NewTitle;
    FTitles[FromIndex] := Entry;
    SortTitles;
  end
  else if ToIndex >= 0 then
    FTitles.Delete(FromIndex)
  else
  begin
    Entry := FTitles[FromIndex];
    Entry.Title := NewTitle;
    FTitles[FromIndex] := Entry;
    SortTitles;
  end;
  SaveToDisk;
  FOnChanged.Notify;
  Result := True;
end;

function TTitleCatalog.FilePath: string;
begin
  Result := TPath.Combine(TAppSettings.Instance.DataPath, 'titel.json');
end;

procedure TTitleCatalog.ReloadIfPathChanged;
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

procedure TTitleCatalog.LoadFromDisk;
var
  Root: TJSONValue;
  Obj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  Entry: TPackageTitle;
begin
  FTitles.Clear;
  Root := LoadJsonFile(FilePath);
  if Root = nil then
    Exit;
  try
    if not (Root is TJSONObject) then
      Exit;
    Obj := TJSONObject(Root);
    Arr := JsonArr(Obj, 'titles');
    if Arr = nil then
      Exit;
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      Item := TJSONObject(Arr.Items[I]);
      Entry.Title := Trim(JsonStr(Item, 'title'));
      Entry.Color := HexToColor(JsonStr(Item, 'color'));
      if (Entry.Title = '') or (IndexOf(Entry.Title) >= 0) then
        Continue;
      FTitles.Add(Entry);
    end;
    SortTitles;
  finally
    Root.Free;
  end;
end;

procedure TTitleCatalog.SortTitles;
begin
  FTitles.Sort(TComparer<TPackageTitle>.Construct(
    function(const A, B: TPackageTitle): Integer
    begin
      Result := AnsiCompareText(A.Title, B.Title);
    end));
end;

procedure TTitleCatalog.SaveToDisk;
var
  Root: TJSONObject;
  Arr: TJSONArray;
  Item: TJSONObject;
  Entry: TPackageTitle;
begin
  Root := TJSONObject.Create;
  try
    Arr := TJSONArray.Create;
    for Entry in FTitles do
    begin
      Item := TJSONObject.Create;
      Item.AddPair('title', Entry.Title);
      Item.AddPair('color', ColorToHex(Entry.Color));
      Arr.AddElement(Item);
    end;
    Root.AddPair('titles', Arr);
    SaveJsonFile(FilePath, Root);
  finally
    Root.Free;
  end;
end;

function TTitleCatalog.IndexOf(const Title: string): Integer;
var
  Trimmed: string;
  I: Integer;
begin
  Trimmed := Trim(Title);
  for I := 0 to FTitles.Count - 1 do
    if AnsiSameText(FTitles[I].Title, Trimmed) then
      Exit(I);
  Result := -1;
end;

initialization
finalization
  FreeAndNil(GCatalog);

end.
