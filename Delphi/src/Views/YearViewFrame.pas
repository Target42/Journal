unit YearViewFrame;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.Grids, Vcl.ExtCtrls;

type
  TYearMonthEvent = procedure(AYear, AMonth: Integer) of object;
  TYearEvent = procedure(AYear: Integer) of object;

  TYearViewFrame = class(TFrame)
    pnlNav: TPanel;
    btnPrev: TButton;
    lblHeader: TLabel;
    btnNext: TButton;
    lblVacation: TLabel;
    grdMonths: TStringGrid;
  private
    FYear: Integer;
    FSelectedMonth: Integer;
    FOnMonthActivated: TYearMonthEvent;
    FOnYearChanged: TYearEvent;
    procedure CalendarYearChanged(AYear: Integer);
    procedure SettingsChanged;
    procedure DataReloaded;
    procedure MonthRecalculated(AYear, AMonth: Integer);
    procedure YearRecalculated(AYear: Integer);
    procedure RefreshView;
    procedure FillMonthRow(AMonth: Integer);
    procedure UpdateYearHeader;
    procedure PrevClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure GridClick(Sender: TObject);
    procedure GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
      State: TGridDrawState);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DisplayedYear: Integer;
    procedure SetYear(AYear: Integer);
    procedure SelectMonth(AMonth: Integer);
    property OnMonthActivated: TYearMonthEvent read FOnMonthActivated write FOnMonthActivated;
    property OnYearChanged: TYearEvent read FOnYearChanged write FOnYearChanged;
  end;

implementation

{$R *.dfm}

uses
  System.DateUtils, Journal.Settings, Journal.Calendar, Journal.Store,
  Journal.TimeTotals, Journal.Types, Journal.UiUtil;

constructor TYearViewFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FYear := YearOf(Date);
  FSelectedMonth := MonthOf(Date);
  grdMonths.ColCount := 7;
  grdMonths.RowCount := 13;
  grdMonths.FixedRows := 1;
  grdMonths.FixedCols := 0;
  grdMonths.DefaultRowHeight := 20;
  EnableGridColumnResize(grdMonths);
  grdMonths.Cells[0, 0] := 'Monat';
  grdMonths.Cells[1, 0] := 'Soll (h)';
  grdMonths.Cells[2, 0] := 'Ist (h)';
  grdMonths.Cells[3, 0] := 'Saldo (h)';
  grdMonths.Cells[4, 0] := 'Konto (h)';
  grdMonths.Cells[5, 0] := 'genommen';
  grdMonths.Cells[6, 0] := 'geplant';
  ApplyMonoFont(grdMonths);
  btnPrev.OnClick := PrevClick;
  btnNext.OnClick := NextClick;
  grdMonths.OnClick := GridClick;
  grdMonths.OnDrawCell := GridDrawCell;
  TCalendarService.Instance.OnYearDataChanged.Add(CalendarYearChanged);
  TAppSettings.Instance.OnChanged.Add(SettingsChanged);
  TJournalStore.Instance.OnDataReloaded.Add(DataReloaded);
  TTimeTotals.Instance.OnMonthRecalculated.Add(MonthRecalculated);
  TTimeTotals.Instance.OnYearRecalculated.Add(YearRecalculated);
  TCalendarService.Instance.EnsureYearLoaded(FYear);
  RefreshView;
end;

destructor TYearViewFrame.Destroy;
begin
  TCalendarService.Instance.OnYearDataChanged.Remove(CalendarYearChanged);
  TAppSettings.Instance.OnChanged.Remove(SettingsChanged);
  TJournalStore.Instance.OnDataReloaded.Remove(DataReloaded);
  TTimeTotals.Instance.OnMonthRecalculated.Remove(MonthRecalculated);
  TTimeTotals.Instance.OnYearRecalculated.Remove(YearRecalculated);
  inherited Destroy;
end;

function TYearViewFrame.DisplayedYear: Integer;
begin
  Result := FYear;
end;

procedure TYearViewFrame.CalendarYearChanged(AYear: Integer);
begin
  if AYear = FYear then
    RefreshView;
end;

procedure TYearViewFrame.SettingsChanged;
begin
  RefreshView;
end;

procedure TYearViewFrame.DataReloaded;
begin
  RefreshView;
end;

procedure TYearViewFrame.MonthRecalculated(AYear, AMonth: Integer);
begin
  if AYear = FYear then
  begin
    FillMonthRow(AMonth);
    grdMonths.Invalidate;
  end;
end;

procedure TYearViewFrame.YearRecalculated(AYear: Integer);
begin
  if AYear = FYear then
    UpdateYearHeader;
end;

procedure TYearViewFrame.SetYear(AYear: Integer);
begin
  if (AYear < 1970) or (AYear > 2100) or (AYear = FYear) then
    Exit;
  FYear := AYear;
  TCalendarService.Instance.EnsureYearLoaded(FYear);
  RefreshView;
  if Assigned(FOnYearChanged) then
    FOnYearChanged(FYear);
end;

procedure TYearViewFrame.SelectMonth(AMonth: Integer);
begin
  if (AMonth < 1) or (AMonth > 12) then
    Exit;
  FSelectedMonth := AMonth;
  grdMonths.Row := AMonth;
end;

procedure TYearViewFrame.PrevClick(Sender: TObject);
begin
  SetYear(FYear - 1);
end;

procedure TYearViewFrame.NextClick(Sender: TObject);
begin
  SetYear(FYear + 1);
end;

procedure TYearViewFrame.GridClick(Sender: TObject);
begin
  if (grdMonths.Row < 1) or (grdMonths.Row > 12) then
    Exit;
  FSelectedMonth := grdMonths.Row;
  if Assigned(FOnMonthActivated) then
    FOnMonthActivated(FYear, FSelectedMonth);
end;

procedure TYearViewFrame.FillMonthRow(AMonth: Integer);
var
  Totals: TMonthTotals;
begin
  if (AMonth < 1) or (AMonth > 12) then
    Exit;
  Totals := TTimeTotals.Instance.MonthTotals(FYear, AMonth);
  grdMonths.Cells[0, AMonth] := GermanMonthName(AMonth);
  grdMonths.Cells[1, AMonth] := FormatHours(Totals.TargetHours);
  grdMonths.Cells[2, AMonth] := FormatHours(Totals.ActualHours);
  if Totals.MonthSaldo > 0.005 then
    grdMonths.Cells[3, AMonth] := '+' + FormatHoursAbs(Totals.MonthSaldo)
  else if Totals.MonthSaldo < -0.005 then
    grdMonths.Cells[3, AMonth] := '-' + FormatHoursAbs(Totals.MonthSaldo)
  else
    grdMonths.Cells[3, AMonth] := FormatHours(0);
  if Totals.ClosingSaldo > 0.005 then
    grdMonths.Cells[4, AMonth] := '+' + FormatHoursAbs(Totals.ClosingSaldo)
  else if Totals.ClosingSaldo < -0.005 then
    grdMonths.Cells[4, AMonth] := '-' + FormatHoursAbs(Totals.ClosingSaldo)
  else
    grdMonths.Cells[4, AMonth] := FormatHours(0);
  grdMonths.Cells[5, AMonth] := FormatHours(Totals.VacationTaken, 1);
  grdMonths.Cells[6, AMonth] := FormatHours(Totals.VacationPlanned, 1);
end;

procedure TYearViewFrame.UpdateYearHeader;
var
  Totals: TYearTotals;
  Entitlement, Remaining: Double;
  Header: string;
begin
  Totals := TTimeTotals.Instance.YearTotals(FYear);
  Header := Format('Jahr %d ' + EnDash + ' Soll: %s  |  Ist: %s  |  Saldo: %s  |  Konto: %s',
    [FYear, FormatHours(Totals.TargetHours), FormatHours(Totals.ActualHours),
     FormatHours(Totals.Saldo), FormatHours(Totals.ClosingSaldo)]);
  if Abs(Totals.ClippedHours) > 0.005 then
    Header := Header + '  |  Abgeschnitten: ' + FormatHoursAbs(Totals.ClippedHours);
  lblHeader.Caption := Header;
  Entitlement := TAppSettings.Instance.WorkSettings.AnnualVacationDays;
  Remaining := Entitlement - Totals.VacationTaken;
  lblVacation.Caption := Format('Urlaub: Anspruch %s  |  genommen %s  |  geplant %s  |  Rest %s',
    [FormatHours(Entitlement, 1), FormatHours(Totals.VacationTaken, 1),
     FormatHours(Totals.VacationPlanned, 1), FormatHours(Remaining, 1)]);
end;

procedure TYearViewFrame.RefreshView;
var
  Month: Integer;
begin
  TTimeTotals.Instance.EnsureYear(FYear);
  TCalendarService.Instance.EnsureYearLoaded(FYear);
  UpdateYearHeader;
  for Month := 1 to 12 do
    FillMonthRow(Month);
  if (FSelectedMonth >= 1) and (FSelectedMonth <= 12) then
    grdMonths.Row := FSelectedMonth;
  SizeGridColumnsToContent(grdMonths, [0, 1, 2, 3, 4, 5, 6]);
  grdMonths.Invalidate;
end;

procedure TYearViewFrame.GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
  State: TGridDrawState);
var
  S: string;
begin
  UseGridFont(grdMonths);
  if ARow = 0 then
    grdMonths.Canvas.Brush.Color := clBtnFace
  else if gdSelected in State then
    grdMonths.Canvas.Brush.Color := clHighlight
  else
    grdMonths.Canvas.Brush.Color := clWindow;
  if (gdSelected in State) and (ARow > 0) then
    grdMonths.Canvas.Font.Color := clHighlightText
  else
    grdMonths.Canvas.Font.Color := clWindowText;
  grdMonths.Canvas.FillRect(Rect);
  S := grdMonths.Cells[ACol, ARow];
  if (ACol in [3, 4]) and (ARow > 0) and not (gdSelected in State) then
  begin
    if S.StartsWith('+') then
    begin
      grdMonths.Canvas.Font.Color := RGB(0, 128, 0);
      DrawPlainText(grdMonths.Canvas, Rect, Copy(S, 2, MaxInt), True);
      Exit;
    end;
    if S.StartsWith('-') then
    begin
      grdMonths.Canvas.Font.Color := RGB(180, 0, 0);
      DrawPlainText(grdMonths.Canvas, Rect, Copy(S, 2, MaxInt), True);
      Exit;
    end;
  end;
  DrawPlainText(grdMonths.Canvas, Rect, S, ACol > 0);
end;

end.
