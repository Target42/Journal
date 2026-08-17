unit Journal.Events;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Classes;

type
  TNotifyProc = procedure of object;
  TIntNotifyProc = procedure(AValue: Integer) of object;
  TDateNotifyProc = procedure(const ADate: TDate) of object;
  TDateRangeNotifyProc = procedure(const AFrom, ATo: TDate) of object;
  TYearMonthNotifyProc = procedure(AYear, AMonth: Integer) of object;
  TDownloadNotifyProc = procedure(const AKind: string; AYear: Integer; AOk: Boolean;
    const AMessage: string) of object;
  TDownloadProgressProc = procedure(const AKind: string; AYear, ACurrent, ATotal: Integer) of object;

  TNotifyHub = class
  private
    FItems: TList<TNotifyProc>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Handler: TNotifyProc);
    procedure Remove(const Handler: TNotifyProc);
    procedure Notify;
  end;

  TIntHub = class
  private
    FItems: TList<TIntNotifyProc>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Handler: TIntNotifyProc);
    procedure Remove(const Handler: TIntNotifyProc);
    procedure Notify(AValue: Integer);
  end;

  TDateHub = class
  private
    FItems: TList<TDateNotifyProc>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Handler: TDateNotifyProc);
    procedure Remove(const Handler: TDateNotifyProc);
    procedure Notify(const ADate: TDate);
  end;

  TDateRangeHub = class
  private
    FItems: TList<TDateRangeNotifyProc>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Handler: TDateRangeNotifyProc);
    procedure Remove(const Handler: TDateRangeNotifyProc);
    procedure Notify(const AFrom, ATo: TDate);
  end;

  TYearMonthHub = class
  private
    FItems: TList<TYearMonthNotifyProc>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Handler: TYearMonthNotifyProc);
    procedure Remove(const Handler: TYearMonthNotifyProc);
    procedure Notify(AYear, AMonth: Integer);
  end;

  TDownloadHub = class
  private
    FItems: TList<TDownloadNotifyProc>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Handler: TDownloadNotifyProc);
    procedure Remove(const Handler: TDownloadNotifyProc);
    procedure Notify(const AKind: string; AYear: Integer; AOk: Boolean; const AMessage: string);
  end;

  TProgressHub = class
  private
    FItems: TList<TDownloadProgressProc>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Handler: TDownloadProgressProc);
    procedure Remove(const Handler: TDownloadProgressProc);
    procedure Notify(const AKind: string; AYear, ACurrent, ATotal: Integer);
  end;

implementation

{ TNotifyHub }

constructor TNotifyHub.Create;
begin
  inherited Create;
  FItems := TList<TNotifyProc>.Create;
end;

destructor TNotifyHub.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TNotifyHub.Add(const Handler: TNotifyProc);
begin
  if Assigned(Handler) and (FItems.IndexOf(Handler) < 0) then
    FItems.Add(Handler);
end;

procedure TNotifyHub.Remove(const Handler: TNotifyProc);
begin
  FItems.Remove(Handler);
end;

procedure TNotifyHub.Notify;
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    if Assigned(FItems[I]) then
      FItems[I]();
end;

{ TIntHub }

constructor TIntHub.Create;
begin
  inherited Create;
  FItems := TList<TIntNotifyProc>.Create;
end;

destructor TIntHub.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TIntHub.Add(const Handler: TIntNotifyProc);
begin
  if Assigned(Handler) and (FItems.IndexOf(Handler) < 0) then
    FItems.Add(Handler);
end;

procedure TIntHub.Remove(const Handler: TIntNotifyProc);
begin
  FItems.Remove(Handler);
end;

procedure TIntHub.Notify(AValue: Integer);
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    if Assigned(FItems[I]) then
      FItems[I](AValue);
end;

{ TDateHub }

constructor TDateHub.Create;
begin
  inherited Create;
  FItems := TList<TDateNotifyProc>.Create;
end;

destructor TDateHub.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TDateHub.Add(const Handler: TDateNotifyProc);
begin
  if Assigned(Handler) and (FItems.IndexOf(Handler) < 0) then
    FItems.Add(Handler);
end;

procedure TDateHub.Remove(const Handler: TDateNotifyProc);
begin
  FItems.Remove(Handler);
end;

procedure TDateHub.Notify(const ADate: TDate);
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    if Assigned(FItems[I]) then
      FItems[I](ADate);
end;

{ TDateRangeHub }

constructor TDateRangeHub.Create;
begin
  inherited Create;
  FItems := TList<TDateRangeNotifyProc>.Create;
end;

destructor TDateRangeHub.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TDateRangeHub.Add(const Handler: TDateRangeNotifyProc);
begin
  if Assigned(Handler) and (FItems.IndexOf(Handler) < 0) then
    FItems.Add(Handler);
end;

procedure TDateRangeHub.Remove(const Handler: TDateRangeNotifyProc);
begin
  FItems.Remove(Handler);
end;

procedure TDateRangeHub.Notify(const AFrom, ATo: TDate);
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    if Assigned(FItems[I]) then
      FItems[I](AFrom, ATo);
end;

{ TYearMonthHub }

constructor TYearMonthHub.Create;
begin
  inherited Create;
  FItems := TList<TYearMonthNotifyProc>.Create;
end;

destructor TYearMonthHub.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TYearMonthHub.Add(const Handler: TYearMonthNotifyProc);
begin
  if Assigned(Handler) and (FItems.IndexOf(Handler) < 0) then
    FItems.Add(Handler);
end;

procedure TYearMonthHub.Remove(const Handler: TYearMonthNotifyProc);
begin
  FItems.Remove(Handler);
end;

procedure TYearMonthHub.Notify(AYear, AMonth: Integer);
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    if Assigned(FItems[I]) then
      FItems[I](AYear, AMonth);
end;

{ TDownloadHub }

constructor TDownloadHub.Create;
begin
  inherited Create;
  FItems := TList<TDownloadNotifyProc>.Create;
end;

destructor TDownloadHub.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TDownloadHub.Add(const Handler: TDownloadNotifyProc);
begin
  if Assigned(Handler) and (FItems.IndexOf(Handler) < 0) then
    FItems.Add(Handler);
end;

procedure TDownloadHub.Remove(const Handler: TDownloadNotifyProc);
begin
  FItems.Remove(Handler);
end;

procedure TDownloadHub.Notify(const AKind: string; AYear: Integer; AOk: Boolean;
  const AMessage: string);
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    if Assigned(FItems[I]) then
      FItems[I](AKind, AYear, AOk, AMessage);
end;

{ TProgressHub }

constructor TProgressHub.Create;
begin
  inherited Create;
  FItems := TList<TDownloadProgressProc>.Create;
end;

destructor TProgressHub.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TProgressHub.Add(const Handler: TDownloadProgressProc);
begin
  if Assigned(Handler) and (FItems.IndexOf(Handler) < 0) then
    FItems.Add(Handler);
end;

procedure TProgressHub.Remove(const Handler: TDownloadProgressProc);
begin
  FItems.Remove(Handler);
end;

procedure TProgressHub.Notify(const AKind: string; AYear, ACurrent, ATotal: Integer);
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    if Assigned(FItems[I]) then
      FItems[I](AKind, AYear, ACurrent, ATotal);
end;

end.
