unit Journal.UiUtil;

interface

uses
  Winapi.Windows, System.SysUtils, System.Types, System.UITypes, Vcl.Graphics, Vcl.Controls,
  Vcl.Grids, Journal.Types;

procedure DrawHoursText(Canvas: TCanvas; const Rect: TRect; Hours: Double; Saldo: Boolean;
  RightAlign: Boolean = True);
procedure DrawPlainText(Canvas: TCanvas; const Rect: TRect; const Text: string;
  RightAlign: Boolean = False);
function ElideText(Canvas: TCanvas; const Text: string; MaxWidth: Integer): string;
function TextColorFor(Background: TColor): TColor;
function GermanMonthName(Month: Integer): string;
function GermanDayShort(const ADate: TDate): string;
function GermanDateLong(const ADate: TDate): string;
procedure ApplyMonoFont(Control: TControl);
procedure EnableGridColumnResize(Grid: TStringGrid);
procedure UseGridFont(Grid: TStringGrid);
procedure SizeGridColumnsToContent(Grid: TStringGrid; const Cols: array of Integer);
procedure FitGridStretchColumn(Grid: TStringGrid; StretchCol: Integer);
procedure FitLastGridColumn(Grid: TStringGrid);

implementation

uses
  System.DateUtils, Vcl.StdCtrls;

type
  TControlFont = class(TControl);

procedure DrawPlainText(Canvas: TCanvas; const Rect: TRect; const Text: string;
  RightAlign: Boolean);
var
  Flags: Cardinal;
  R: TRect;
begin
  R := Rect;
  InflateRect(R, -4, 0);
  Flags := DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX;
  if RightAlign then
    Flags := Flags or DT_RIGHT
  else
    Flags := Flags or DT_LEFT;
  DrawText(Canvas.Handle, PChar(Text), Length(Text), R, Flags);
end;

procedure DrawHoursText(Canvas: TCanvas; const Rect: TRect; Hours: Double; Saldo: Boolean;
  RightAlign: Boolean);
var
  Text: string;
  Saved: TColor;
begin
  Saved := Canvas.Font.Color;
  if Saldo then
  begin
    if Hours > 0.005 then
    begin
      Canvas.Font.Color := RGB(0, 128, 0);
      Text := FormatHoursAbs(Hours);
    end
    else if Hours < -0.005 then
    begin
      Canvas.Font.Color := RGB(180, 0, 0);
      Text := FormatHoursAbs(Hours);
    end
    else
      Text := FormatHours(0);
  end
  else
    Text := FormatHours(Hours);
  DrawPlainText(Canvas, Rect, Text, RightAlign);
  Canvas.Font.Color := Saved;
end;

function ElideText(Canvas: TCanvas; const Text: string; MaxWidth: Integer): string;
begin
  Result := Text;
  if Canvas.TextWidth(Result) <= MaxWidth then
    Exit;
  while (Length(Result) > 0) and (Canvas.TextWidth(Result + Ellipsis) > MaxWidth) do
    Delete(Result, Length(Result), 1);
  Result := Result + Ellipsis;
end;

function TextColorFor(Background: TColor): TColor;
var
  C: Longint;
  Lum: Double;
begin
  C := ColorToRGB(Background);
  Lum := (0.299 * GetRValue(C) + 0.587 * GetGValue(C) + 0.114 * GetBValue(C)) / 255.0;
  if Lum > 0.62 then
    Result := RGB(30, 30, 30)
  else
    Result := clWhite;
end;

function GermanMonthName(Month: Integer): string;
const
  Names: array[1..12] of string = (
    'Januar', 'Februar', 'M' + #$00E4 + 'rz', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember');
begin
  if (Month >= 1) and (Month <= 12) then
    Result := Names[Month]
  else
    Result := '';
end;

function GermanDayShort(const ADate: TDate): string;
const
  Names: array[1..7] of string = ('Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So');
begin
  Result := Names[IsoWeekDay(ADate)];
end;

function GermanDateLong(const ADate: TDate): string;
begin
  Result := Format('%s, %d. %s %d',
    [GermanDayShort(ADate), DayOf(ADate), GermanMonthName(MonthOf(ADate)), YearOf(ADate)]);
end;

procedure ApplyMonoFont(Control: TControl);
begin
  TControlFont(Control).Font.Name := 'Consolas';
  TControlFont(Control).Font.Size := 9;
end;

procedure UseGridFont(Grid: TStringGrid);
begin
  Grid.Canvas.Font := Grid.Font;
end;

procedure EnableGridColumnResize(Grid: TStringGrid);
begin
  Grid.Options := Grid.Options + [goColSizing, goRowSelect, goThumbTracking,
    goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine] - [goRangeSelect];
end;

procedure SizeGridColumnsToContent(Grid: TStringGrid; const Cols: array of Integer);
var
  C, Row, Col, W, MaxW: Integer;
begin
  if Grid = nil then
    Exit;
  UseGridFont(Grid);
  for C := 0 to High(Cols) do
  begin
    Col := Cols[C];
    if (Col < 0) or (Col >= Grid.ColCount) then
      Continue;
    MaxW := Grid.Canvas.TextWidth(Grid.Cells[Col, 0]);
    for Row := 1 to Grid.RowCount - 1 do
    begin
      W := Grid.Canvas.TextWidth(Grid.Cells[Col, Row]);
      if W > MaxW then
        MaxW := W;
    end;
    W := MaxW + 12;
    if W < 28 then
      W := 28;
    Grid.ColWidths[Col] := W;
  end;
end;

procedure FitGridStretchColumn(Grid: TStringGrid; StretchCol: Integer);
var
  I, Used, Avail, ContentH: Integer;
begin
  if (Grid = nil) or (StretchCol < 0) or (StretchCol >= Grid.ColCount) then
    Exit;
  Used := 0;
  for I := 0 to Grid.ColCount - 1 do
    if I <> StretchCol then
      Inc(Used, Grid.ColWidths[I] + Grid.GridLineWidth);
  ContentH := 0;
  for I := 0 to Grid.RowCount - 1 do
    Inc(ContentH, Grid.RowHeights[I] + Grid.GridLineWidth);
  Avail := Grid.ClientWidth - Used - Grid.GridLineWidth;
  if ContentH > Grid.ClientHeight then
    Dec(Avail, GetSystemMetrics(SM_CXVSCROLL));
  if Avail < 32 then
    Avail := 32;
  Grid.ColWidths[StretchCol] := Avail;
end;

procedure FitLastGridColumn(Grid: TStringGrid);
begin
  if Grid <> nil then
    FitGridStretchColumn(Grid, Grid.ColCount - 1);
end;

end.
