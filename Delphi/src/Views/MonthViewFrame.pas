unit MonthViewFrame;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.Grids, Vcl.Menus, Vcl.ExtCtrls, Journal.Types;

type
  TMonthActivated = procedure(const ADate: TDate) of object;

  TMonthViewFrame = class(TFrame)
    pnlHeader: TPanel;
    lblSummary: TLabel;
    btnAbsence: TButton;
    grdDays: TStringGrid;
  private
    FMonth: TDate;
    FOnDayActivated: TMonthActivated;
    FContextDate: TDate;
    FDayMenu: TPopupMenu;
    procedure CalendarYearChanged(AYear: Integer);
    procedure SettingsChanged;
    procedure DataReloaded;
    procedure DayRecalculated(const ADate: TDate);
    procedure MonthRecalculated(AYear, AMonth: Integer);
    procedure AppointmentsChanged;
    procedure FillDayRow(Day: Integer);
    procedure UpdateSummary;
    procedure RefreshView;
    procedure GridClick(Sender: TObject);
    procedure GridDblClick(Sender: TObject);
    procedure GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
      State: TGridDrawState);
    procedure GridResized(Sender: TObject);
    procedure DayMenuPopup(Sender: TObject);
    procedure RebuildDayMenu;
    procedure ApplyAbsence(const Dates: TArray<TDate>; const Absence: TAbsence);
    procedure OpenRangeDialog(const FromDate: TDate);
    procedure OpenDayPackages(const ADate: TDate);
    function DateFromRow(Row: Integer): TDate;
    function RowBackground(const ADate: TDate): TColor;
    procedure CtxPackages(Sender: TObject);
    procedure CtxVacFull(Sender: TObject);
    procedure CtxVacHalf(Sender: TObject);
    procedure CtxSickFull(Sender: TObject);
    procedure CtxSickHalf(Sender: TObject);
    procedure CtxPaidFull(Sender: TObject);
    procedure CtxPaidHalf(Sender: TObject);
    procedure CtxCompFull(Sender: TObject);
    procedure CtxCompHalf(Sender: TObject);
    procedure CtxBounds(Sender: TObject);
    procedure CtxRange(Sender: TObject);
    procedure CtxClear(Sender: TObject);
    procedure AbsenceClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DisplayedMonth: TDate;
    procedure SetMonth(AYear, AMonth: Integer);
    procedure SelectDate(const ADate: TDate);
    procedure OpenAbsenceDialog;
    property OnDayActivated: TMonthActivated read FOnDayActivated write FOnDayActivated;
  end;

implementation

{$R *.dfm}

uses
  System.DateUtils, System.Types, Vcl.Dialogs, Journal.Settings, Journal.Calendar,
  Journal.Store, Journal.TimeTotals, Journal.Arbzg, Journal.UiUtil, Journal.Appointments,
  AbsenceForm, DayBoundsForm, DayPackagesForm;

const
  ColDay = 0;
  ColStart = 1;
  ColEnd = 2;
  ColActual = 3;
  ColTarget = 4;
  ColSaldo = 5;
  ColHint = 6;
  ColCount = 7;

procedure WorkSpan(const ADate: TDate; out StartMinute, EndMinute: Integer);
var
  Pkg: TWorkPackage;
begin
  StartMinute := -1;
  EndMinute := -1;
  for Pkg in TJournalStore.Instance.PackagesForDate(ADate) do
  begin
    if (StartMinute < 0) or (Pkg.StartMinute < StartMinute) then
      StartMinute := Pkg.StartMinute;
    if (EndMinute < 0) or (Pkg.EndMinute(ADate) > EndMinute) then
      EndMinute := Pkg.EndMinute(ADate);
  end;
end;

function IsCountableAbsenceDay(const ADate: TDate): Boolean;
begin
  if (not DateValid(ADate)) or TCalendarService.Instance.IsPublicHoliday(ADate) then
    Exit(False);
  Result := TAppSettings.Instance.TargetHoursForDate(ADate) > 0;
end;

function DatesInRange(const AFrom, ATo: TDate; OnlyCountable: Boolean): TArray<TDate>;
var
  StartD, EndD, D: TDate;
begin
  SetLength(Result, 0);
  if (not DateValid(AFrom)) or (not DateValid(ATo)) then
    Exit;
  if AFrom <= ATo then
  begin
    StartD := AFrom;
    EndD := ATo;
  end
  else
  begin
    StartD := ATo;
    EndD := AFrom;
  end;
  D := StartD;
  while D <= EndD do
  begin
    if (not OnlyCountable) or IsCountableAbsenceDay(D) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := D;
    end;
    D := IncDay(D);
  end;
end;

constructor TMonthViewFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMonth := EncodeDate(YearOf(Date), MonthOf(Date), 1);
  grdDays.ColCount := ColCount;
  grdDays.FixedRows := 1;
  grdDays.FixedCols := 0;
  grdDays.DefaultRowHeight := 20;
  EnableGridColumnResize(grdDays);
  grdDays.Cells[ColDay, 0] := 'Tag';
  grdDays.Cells[ColStart, 0] := 'Anfang';
  grdDays.Cells[ColEnd, 0] := 'Ende';
  grdDays.Cells[ColActual, 0] := 'Ist';
  grdDays.Cells[ColTarget, 0] := 'Soll';
  grdDays.Cells[ColSaldo, 0] := 'Saldo';
  grdDays.Cells[ColHint, 0] := 'Titel';
  ApplyMonoFont(grdDays);
  grdDays.OnClick := GridClick;
  grdDays.OnDblClick := GridDblClick;
  grdDays.OnDrawCell := GridDrawCell;
  FDayMenu := TPopupMenu.Create(Self);
  FDayMenu.OnPopup := DayMenuPopup;
  grdDays.PopupMenu := FDayMenu;
  btnAbsence.OnClick := AbsenceClick;
  OnResize := GridResized;
  TCalendarService.Instance.OnYearDataChanged.Add(CalendarYearChanged);
  TAppSettings.Instance.OnChanged.Add(SettingsChanged);
  TJournalStore.Instance.OnDataReloaded.Add(DataReloaded);
  TTimeTotals.Instance.OnDayRecalculated.Add(DayRecalculated);
  TTimeTotals.Instance.OnMonthRecalculated.Add(MonthRecalculated);
  TAppointmentCatalog.Instance.OnChanged.Add(AppointmentsChanged);
  TCalendarService.Instance.EnsureYearLoaded(YearOf(FMonth));
  RefreshView;
end;

destructor TMonthViewFrame.Destroy;
begin
  TCalendarService.Instance.OnYearDataChanged.Remove(CalendarYearChanged);
  TAppSettings.Instance.OnChanged.Remove(SettingsChanged);
  TJournalStore.Instance.OnDataReloaded.Remove(DataReloaded);
  TTimeTotals.Instance.OnDayRecalculated.Remove(DayRecalculated);
  TTimeTotals.Instance.OnMonthRecalculated.Remove(MonthRecalculated);
  TAppointmentCatalog.Instance.OnChanged.Remove(AppointmentsChanged);
  inherited Destroy;
end;

function TMonthViewFrame.DisplayedMonth: TDate;
begin
  Result := FMonth;
end;

procedure TMonthViewFrame.CalendarYearChanged(AYear: Integer);
begin
  if AYear = YearOf(FMonth) then
    RefreshView;
end;

procedure TMonthViewFrame.SettingsChanged;
begin
  RefreshView;
end;

procedure TMonthViewFrame.DataReloaded;
begin
  RefreshView;
end;

procedure TMonthViewFrame.AppointmentsChanged;
begin
  RefreshView;
end;

procedure TMonthViewFrame.DayRecalculated(const ADate: TDate);
begin
  if (YearOf(ADate) = YearOf(FMonth)) and (MonthOf(ADate) = MonthOf(FMonth)) then
  begin
    FillDayRow(DayOf(ADate));
    UpdateSummary;
    grdDays.Invalidate;
  end;
end;

procedure TMonthViewFrame.MonthRecalculated(AYear, AMonth: Integer);
var
  Day: Integer;
begin
  if (AYear = YearOf(FMonth)) and (AMonth = MonthOf(FMonth)) then
  begin
    for Day := 1 to DaysInAMonth(AYear, AMonth) do
      FillDayRow(Day);
    UpdateSummary;
    grdDays.Invalidate;
  end;
end;

procedure TMonthViewFrame.SetMonth(AYear, AMonth: Integer);
var
  Next: TDateTime;
begin
  if (AMonth < 1) or (AMonth > 12) then
    Exit;
  if not TryEncodeDate(AYear, AMonth, 1, Next) then
    Exit;
  FMonth := Next;
  TCalendarService.Instance.EnsureYearLoaded(YearOf(FMonth));
  RefreshView;
end;

procedure TMonthViewFrame.SelectDate(const ADate: TDate);
begin
  if (not DateValid(ADate)) or (YearOf(ADate) <> YearOf(FMonth)) or
     (MonthOf(ADate) <> MonthOf(FMonth)) then
    Exit;
  grdDays.Row := DayOf(ADate);
end;

procedure TMonthViewFrame.GridClick(Sender: TObject);
var
  D: TDate;
begin
  D := DateFromRow(grdDays.Row);
  if DateValid(D) and Assigned(FOnDayActivated) then
    FOnDayActivated(D);
end;

procedure TMonthViewFrame.GridDblClick(Sender: TObject);
begin
  OpenDayPackages(DateFromRow(grdDays.Row));
end;

procedure TMonthViewFrame.OpenDayPackages(const ADate: TDate);
var
  Dlg: TDayPackagesForm;
begin
  if not DateValid(ADate) then
    Exit;
  if Assigned(FOnDayActivated) then
    FOnDayActivated(ADate);
  Dlg := TDayPackagesForm.Create(Self);
  try
    Dlg.InitDate(ADate);
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TMonthViewFrame.FillDayRow(Day: Integer);
var
  Days: Integer;
  ADate: TDate;
  Row: Integer;
  Hints, Eve, Title: string;
  Target, Actual, Saldo: Double;
  Absence: TAbsence;
  Arbzg: TArbzgDay;
  StartMinute, EndMinute: Integer;
begin
  Days := DaysInAMonth(YearOf(FMonth), MonthOf(FMonth));
  if (Day < 1) or (Day > Days) then
    Exit;
  ADate := EncodeDate(YearOf(FMonth), MonthOf(FMonth), Day);
  Row := Day;
  Hints := '';
  if TCalendarService.Instance.IsPublicHoliday(ADate) then
    Hints := TCalendarService.Instance.PublicHolidayName(ADate)
  else
  begin
    Eve := EveDayName(ADate);
    if Eve <> '' then
    begin
      if TAppSettings.Instance.IsCompanyFreeEveDate(ADate) then
        Hints := Eve + ' (frei)'
      else
        Hints := Eve;
    end;
  end;
  if TCalendarService.Instance.IsSchoolHoliday(ADate) then
  begin
    if Hints <> '' then
      Hints := Hints + ' ' + MiddleDot + ' ';
    Hints := Hints + TCalendarService.Instance.SchoolHolidayName(ADate);
  end;
  Absence := TTimeTotals.Instance.EffectiveAbsenceForDate(ADate);
  if Absence.IsSet then
  begin
    if Hints <> '' then
      Hints := Hints + ' ' + MiddleDot + ' ';
    Hints := Hints + Absence.LabelText;
  end;
  for Title in TAppointmentCatalog.Instance.TitlesForDate(ADate) do
  begin
    if Title = '' then
      Continue;
    if Hints <> '' then
      Hints := Hints + ' ' + MiddleDot + ' ';
    Hints := Hints + Title;
  end;
  if ADate <= Date then
  begin
    Arbzg := AssessArbzgDay(ADate);
    if Arbzg.HasIssue or (Length(Arbzg.Notes) > 0) then
    begin
      if Hints <> '' then
        Hints := Hints + ' ' + MiddleDot + ' ';
      if Arbzg.HasIssue then
        Hints := Hints + 'ArbZG!'
      else
        Hints := Hints + 'ArbZG';
    end;
  end;
  if TCalendarService.Instance.IsPublicHoliday(ADate) then
    Target := 0
  else
    Target := TAppSettings.Instance.TargetHoursForDate(ADate);
  Actual := TTimeTotals.Instance.CreditedHoursForDate(ADate);
  Saldo := Actual - Target;
  WorkSpan(ADate, StartMinute, EndMinute);
  grdDays.Cells[ColDay, Row] := Format('%s  %.2d', [GermanDayShort(ADate), Day]);
  if StartMinute >= 0 then
    grdDays.Cells[ColStart, Row] := MinuteToText(StartMinute)
  else
    grdDays.Cells[ColStart, Row] := '';
  if EndMinute >= 0 then
    grdDays.Cells[ColEnd, Row] := MinuteToText(EndMinute)
  else
    grdDays.Cells[ColEnd, Row] := '';
  grdDays.Cells[ColActual, Row] := FormatHours(Actual);
  grdDays.Cells[ColTarget, Row] := FormatHours(Target);
  if ADate > Date then
    grdDays.Cells[ColSaldo, Row] := ''
  else if Saldo > 0.005 then
    grdDays.Cells[ColSaldo, Row] := '+' + FormatHoursAbs(Saldo)
  else if Saldo < -0.005 then
    grdDays.Cells[ColSaldo, Row] := '-' + FormatHoursAbs(Saldo)
  else
    grdDays.Cells[ColSaldo, Row] := FormatHours(0);
  grdDays.Cells[ColHint, Row] := Hints;
end;

procedure TMonthViewFrame.UpdateSummary;
var
  Totals: TMonthTotals;
  Text: string;
begin
  Totals := TTimeTotals.Instance.MonthTotals(YearOf(FMonth), MonthOf(FMonth));
  Text := Format('Monat %s %d ' + EnDash + ' Soll: %s  |  Ist: %s  |  Vormonat: %s  |  Saldo: %s  |  Konto: %s',
    [GermanMonthName(MonthOf(FMonth)), YearOf(FMonth),
     FormatHours(Totals.TargetHours), FormatHours(Totals.ActualHours),
     FormatHours(Totals.CarryIn), FormatHours(Totals.MonthSaldo),
     FormatHours(Totals.ClosingSaldo)]);
  if Abs(Totals.ClippedHours) > 0.005 then
    Text := Text + '  |  Abgeschnitten: ' + FormatHoursAbs(Totals.ClippedHours);
  Text := Text + Format('  |  Urlaub genommen: %s  |  geplant: %s',
    [FormatHours(Totals.VacationTaken, 1), FormatHours(Totals.VacationPlanned, 1)]);
  lblSummary.Caption := Text;
end;

procedure TMonthViewFrame.RefreshView;
var
  Days, Day, Selected: Integer;
begin
  Days := DaysInAMonth(YearOf(FMonth), MonthOf(FMonth));
  Selected := grdDays.Row;
  grdDays.RowCount := Days + 1;
  TTimeTotals.Instance.EnsureYear(YearOf(FMonth));
  TCalendarService.Instance.EnsureYearLoaded(YearOf(FMonth));
  for Day := 1 to Days do
    FillDayRow(Day);
  UpdateSummary;
  if (Selected >= 1) and (Selected <= Days) then
    grdDays.Row := Selected;
  SizeGridColumnsToContent(grdDays, [ColDay, ColStart, ColEnd, ColActual, ColTarget, ColSaldo]);
  FitGridStretchColumn(grdDays, ColHint);
  grdDays.Invalidate;
end;

function TMonthViewFrame.RowBackground(const ADate: TDate): TColor;
var
  Weekend, Holiday, School, CompanyFree: Boolean;
  Absence: TAbsence;
begin
  Weekend := IsoWeekDay(ADate) >= 6;
  Holiday := TCalendarService.Instance.IsPublicHoliday(ADate);
  School := TCalendarService.Instance.IsSchoolHoliday(ADate);
  CompanyFree := TAppSettings.Instance.IsCompanyFreeEveDate(ADate);
  Absence := TTimeTotals.Instance.EffectiveAbsenceForDate(ADate);
  if Holiday or CompanyFree then
    Result := RGB(250, 212, 212)
  else if Weekend and School then
    Result := RGB(232, 228, 200)
  else if Weekend then
    Result := RGB(232, 232, 240)
  else if School then
    Result := RGB(255, 243, 196)
  else if Absence.AbsenceType = atVacation then
    Result := RGB(210, 232, 255)
  else if Absence.AbsenceType = atSick then
    Result := RGB(255, 228, 196)
  else if Absence.AbsenceType = atPaidLeave then
    Result := RGB(232, 214, 245)
  else if Absence.AbsenceType = atCompensatory then
    Result := RGB(210, 240, 220)
  else
    Result := clWindow;
end;

procedure TMonthViewFrame.GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
  State: TGridDrawState);
var
  D: TDate;
  Bg: TColor;
  S: string;
begin
  UseGridFont(grdDays);
  if ARow = 0 then
  begin
    grdDays.Canvas.Brush.Color := clBtnFace;
    grdDays.Canvas.Font.Color := clWindowText;
    grdDays.Canvas.FillRect(Rect);
    DrawPlainText(grdDays.Canvas, Rect, grdDays.Cells[ACol, ARow],
      ACol in [ColStart, ColEnd, ColActual, ColTarget, ColSaldo]);
    Exit;
  end;
  D := DateFromRow(ARow);
  Bg := RowBackground(D);
  if gdSelected in State then
  begin
    grdDays.Canvas.Brush.Color := clHighlight;
    grdDays.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    grdDays.Canvas.Brush.Color := Bg;
    grdDays.Canvas.Font.Color := clWindowText;
  end;
  grdDays.Canvas.FillRect(Rect);
  if (ACol = ColSaldo) and (not (gdSelected in State)) then
  begin
    S := grdDays.Cells[ColSaldo, ARow];
    if S.StartsWith('+') then
    begin
      grdDays.Canvas.Font.Color := RGB(0, 128, 0);
      DrawPlainText(grdDays.Canvas, Rect, Copy(S, 2, MaxInt), True);
      Exit;
    end;
    if S.StartsWith('-') then
    begin
      grdDays.Canvas.Font.Color := RGB(180, 0, 0);
      DrawPlainText(grdDays.Canvas, Rect, Copy(S, 2, MaxInt), True);
      Exit;
    end;
  end;
  if (ACol = ColHint) and (not (gdSelected in State)) then
  begin
    if Pos('ArbZG!', grdDays.Cells[ColHint, ARow]) > 0 then
      grdDays.Canvas.Font.Color := RGB(180, 0, 0)
    else if Pos('ArbZG', grdDays.Cells[ColHint, ARow]) > 0 then
      grdDays.Canvas.Font.Color := RGB(179, 92, 0);
  end;
  DrawPlainText(grdDays.Canvas, Rect, grdDays.Cells[ACol, ARow],
    ACol in [ColStart, ColEnd, ColActual, ColTarget, ColSaldo]);
end;

function TMonthViewFrame.DateFromRow(Row: Integer): TDate;
begin
  Result := 0;
  if (Row < 1) or (Row > DaysInAMonth(YearOf(FMonth), MonthOf(FMonth))) then
    Exit;
  Result := EncodeDate(YearOf(FMonth), MonthOf(FMonth), Row);
end;

procedure TMonthViewFrame.DayMenuPopup(Sender: TObject);
var
  P: TPoint;
  Col, Row: Integer;
  D: TDate;
begin
  GetCursorPos(P);
  P := grdDays.ScreenToClient(P);
  if PtInRect(grdDays.ClientRect, P) then
  begin
    grdDays.MouseToCell(P.X, P.Y, Col, Row);
    if Row >= 1 then
    begin
      grdDays.Row := Row;
      D := DateFromRow(Row);
      if DateValid(D) and Assigned(FOnDayActivated) then
        FOnDayActivated(D);
    end;
  end;
  FContextDate := DateFromRow(grdDays.Row);
  RebuildDayMenu;
end;

procedure TMonthViewFrame.RebuildDayMenu;
var
  Current: TAbsence;
  Countable: Boolean;
  Vac, Sick, Paid, Comp, Item: TMenuItem;

  function Add(const Caption: string; Handler: TNotifyEvent; Parent: TMenuItem = nil): TMenuItem;
  begin
    Result := TMenuItem.Create(FDayMenu);
    Result.Caption := Caption;
    Result.OnClick := Handler;
    if Parent = nil then
      FDayMenu.Items.Add(Result)
    else
      Parent.Add(Result);
  end;

begin
  FDayMenu.Items.Clear;
  Current := TJournalStore.Instance.AbsenceForDate(FContextDate);
  Countable := DateValid(FContextDate) and IsCountableAbsenceDay(FContextDate);
  Add('Arbeitspakete' + Ellipsis, CtxPackages);
  Add('-', nil);
  Vac := Add('Urlaub', nil);
  Item := Add('Ganzer Tag', CtxVacFull, Vac);
  Item.Checked := (Current.AbsenceType = atVacation) and not Current.IsHalfDay;
  Item.Enabled := Countable;
  Item := Add('Halber Tag', CtxVacHalf, Vac);
  Item.Checked := (Current.AbsenceType = atVacation) and Current.IsHalfDay;
  Item.Enabled := Countable;
  Sick := Add('Krankheit', nil);
  Item := Add('Ganzer Tag', CtxSickFull, Sick);
  Item.Checked := (Current.AbsenceType = atSick) and not Current.IsHalfDay;
  Item.Enabled := Countable;
  Item := Add('Halber Tag', CtxSickHalf, Sick);
  Item.Checked := (Current.AbsenceType = atSick) and Current.IsHalfDay;
  Item.Enabled := Countable;
  Paid := Add('Bezahlt frei', nil);
  Item := Add('Ganzer Tag', CtxPaidFull, Paid);
  Item.Checked := (Current.AbsenceType = atPaidLeave) and not Current.IsHalfDay;
  Item.Enabled := Countable;
  Item := Add('Halber Tag', CtxPaidHalf, Paid);
  Item.Checked := (Current.AbsenceType = atPaidLeave) and Current.IsHalfDay;
  Item.Enabled := Countable;
  Comp := Add('Zeitausgleich', nil);
  Item := Add('Ganzer Tag', CtxCompFull, Comp);
  Item.Checked := (Current.AbsenceType = atCompensatory) and not Current.IsHalfDay;
  Item.Enabled := Countable;
  Item := Add('Halber Tag', CtxCompHalf, Comp);
  Item.Checked := (Current.AbsenceType = atCompensatory) and Current.IsHalfDay;
  Item.Enabled := Countable;
  Add('-', nil);
  Add('Tagesgrenzen' + Ellipsis, CtxBounds);
  Add('Zeitraum' + Ellipsis, CtxRange);
  Item := Add('Status entfernen', CtxClear);
  Item.Enabled := Current.IsSet;
end;

procedure TMonthViewFrame.GridResized(Sender: TObject);
begin
  FitGridStretchColumn(grdDays, ColHint);
end;

procedure TMonthViewFrame.CtxPackages(Sender: TObject);
begin
  OpenDayPackages(FContextDate);
end;

procedure TMonthViewFrame.CtxVacFull(Sender: TObject);
var
  A: TAbsence;
begin
  A.AbsenceType := atVacation;
  A.Fraction := 1;
  ApplyAbsence([FContextDate], A);
end;

procedure TMonthViewFrame.CtxVacHalf(Sender: TObject);
var
  A: TAbsence;
begin
  A.AbsenceType := atVacation;
  A.Fraction := 0.5;
  ApplyAbsence([FContextDate], A);
end;

procedure TMonthViewFrame.CtxSickFull(Sender: TObject);
var
  A: TAbsence;
begin
  A.AbsenceType := atSick;
  A.Fraction := 1;
  ApplyAbsence([FContextDate], A);
end;

procedure TMonthViewFrame.CtxSickHalf(Sender: TObject);
var
  A: TAbsence;
begin
  A.AbsenceType := atSick;
  A.Fraction := 0.5;
  ApplyAbsence([FContextDate], A);
end;

procedure TMonthViewFrame.CtxPaidFull(Sender: TObject);
var
  A: TAbsence;
begin
  A.AbsenceType := atPaidLeave;
  A.Fraction := 1;
  ApplyAbsence([FContextDate], A);
end;

procedure TMonthViewFrame.CtxPaidHalf(Sender: TObject);
var
  A: TAbsence;
begin
  A.AbsenceType := atPaidLeave;
  A.Fraction := 0.5;
  ApplyAbsence([FContextDate], A);
end;

procedure TMonthViewFrame.CtxCompFull(Sender: TObject);
var
  A: TAbsence;
begin
  A.AbsenceType := atCompensatory;
  A.Fraction := 1;
  ApplyAbsence([FContextDate], A);
end;

procedure TMonthViewFrame.CtxCompHalf(Sender: TObject);
var
  A: TAbsence;
begin
  A.AbsenceType := atCompensatory;
  A.Fraction := 0.5;
  ApplyAbsence([FContextDate], A);
end;

procedure TMonthViewFrame.CtxBounds(Sender: TObject);
var
  Dlg: TDayBoundsForm;
begin
  Dlg := TDayBoundsForm.Create(Self);
  try
    Dlg.InitDate(FContextDate);
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TMonthViewFrame.CtxRange(Sender: TObject);
begin
  OpenRangeDialog(FContextDate);
end;

procedure TMonthViewFrame.CtxClear(Sender: TObject);
begin
  ApplyAbsence([FContextDate], Default(TAbsence));
end;

procedure TMonthViewFrame.OpenRangeDialog(const FromDate: TDate);
var
  Dlg: TAbsenceForm;
begin
  Dlg := TAbsenceForm.Create(Self);
  try
    Dlg.InitRange(FromDate, FromDate);
    if Dlg.ShowModal <> mrOk then
      Exit;
    if Dlg.IsClear then
      ApplyAbsence(DatesInRange(Dlg.FromDate, Dlg.ToDate, False), Default(TAbsence))
    else
      ApplyAbsence(DatesInRange(Dlg.FromDate, Dlg.ToDate, True), Dlg.Absence);
  finally
    Dlg.Free;
  end;
end;

procedure TMonthViewFrame.AbsenceClick(Sender: TObject);
begin
  OpenAbsenceDialog;
end;

procedure TMonthViewFrame.OpenAbsenceDialog;
var
  D: TDate;
begin
  D := DateFromRow(grdDays.Row);
  if not DateValid(D) then
  begin
    if (YearOf(Date) = YearOf(FMonth)) and (MonthOf(Date) = MonthOf(FMonth)) then
      D := Date
    else
      D := FMonth;
  end;
  OpenRangeDialog(D);
end;

procedure TMonthViewFrame.ApplyAbsence(const Dates: TArray<TDate>; const Absence: TAbsence);
var
  Error: string;
begin
  if Length(Dates) = 0 then
  begin
    MessageDlg('Im gewählten Zeitraum liegt kein Arbeitstag ohne Feiertag.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not TJournalStore.Instance.SetAbsences(Dates, Absence, Error) then
  begin
    if Error = '' then
      Error := 'Der Status konnte nicht gespeichert werden.';
    MessageDlg(Error, mtWarning, [mbOK], 0);
  end;
end;

end.
