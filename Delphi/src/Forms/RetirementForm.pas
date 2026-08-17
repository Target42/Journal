unit RetirementForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Grids, Vcl.ExtCtrls,
  Journal.Types;

type
  TRetirementForm = class(TForm)
    grpZeitraum: TGroupBox;
    lblFrom: TLabel;
    dtpFrom: TDateTimePicker;
    lblRetirement: TLabel;
    dtpRetirement: TDateTimePicker;
    lblLastWork: TLabel;
    chkProrate: TCheckBox;
    lblMeta: TLabel;
    btnCalculate: TButton;
    btnDownload: TButton;
    lblSummary: TLabel;
    grdYears: TStringGrid;
    lblStatus: TLabel;
    lblHint: TLabel;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FBusy: Boolean;
    procedure Recalculate(Sender: TObject);
    procedure DownloadMissing(Sender: TObject);
    procedure PersistInputs(Sender: TObject);
    procedure OnDownloadProgress(const AKind: string; AYear, ACurrent, ATotal: Integer);
    procedure OnDownloadFinished(const AKind: string; AYear: Integer; AOk: Boolean;
      const AMessage: string);
    procedure OnSettingsChanged;
    procedure LoadFromSettings;
    procedure SetBusy(Busy: Boolean);
    procedure FillTable;
    procedure CloseClick(Sender: TObject);
    procedure GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
      State: TGridDrawState);
  end;

implementation

{$R *.dfm}

uses
  System.DateUtils, Vcl.Dialogs, Journal.Settings, Journal.Calendar,
  Journal.Retirement, Journal.UiUtil;

function WorkDaysLabel: string;
var
  WS: TWorkSettings;
  I: Integer;
  Names: TArray<string>;
const
  DayNames: array[0..6] of string = ('Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So');
begin
  WS := TAppSettings.Instance.WorkSettings;
  SetLength(Names, 0);
  for I := 0 to 6 do
    if WS.WorkDays[I] then
    begin
      SetLength(Names, Length(Names) + 1);
      Names[High(Names)] := DayNames[I];
    end;
  if Length(Names) = 0 then
    Result := 'keine'
  else
    Result := string.Join(', ', Names);
end;

procedure TRetirementForm.FormCreate(Sender: TObject);
begin
  grdYears.ColCount := 7;
  grdYears.FixedRows := 1;
  grdYears.FixedCols := 0;
  grdYears.DefaultRowHeight := 22;
  EnableGridColumnResize(grdYears);
  grdYears.Cells[0, 0] := 'Jahr';
  grdYears.Cells[1, 0] := 'Zeitraum';
  grdYears.Cells[2, 0] := 'Arbeitstage';
  grdYears.Cells[3, 0] := 'Feiertage';
  grdYears.Cells[4, 0] := 'Urlaub';
  grdYears.Cells[5, 0] := 'Resttage';
  grdYears.Cells[6, 0] := 'Stunden';
  ApplyMonoFont(grdYears);
  grdYears.OnDrawCell := GridDrawCell;
  dtpFrom.OnChange := Recalculate;
  dtpRetirement.OnChange := PersistInputs;
  chkProrate.OnClick := PersistInputs;
  btnCalculate.OnClick := Recalculate;
  btnDownload.OnClick := DownloadMissing;
  btnClose.OnClick := CloseClick;
  TCalendarService.Instance.OnDownloadProgress.Add(OnDownloadProgress);
  TCalendarService.Instance.OnDownloadFinished.Add(OnDownloadFinished);
  TAppSettings.Instance.OnChanged.Add(OnSettingsChanged);
  LoadFromSettings;
  Recalculate(nil);
end;

procedure TRetirementForm.FormDestroy(Sender: TObject);
begin
  TCalendarService.Instance.OnDownloadProgress.Remove(OnDownloadProgress);
  TCalendarService.Instance.OnDownloadFinished.Remove(OnDownloadFinished);
  TAppSettings.Instance.OnChanged.Remove(OnSettingsChanged);
end;

procedure TRetirementForm.OnSettingsChanged;
begin
  if not FBusy then
    Recalculate(nil);
end;

procedure TRetirementForm.LoadFromSettings;
begin
  dtpFrom.OnChange := nil;
  dtpRetirement.OnChange := nil;
  try
    dtpFrom.Date := Date;
    dtpRetirement.Date := TAppSettings.Instance.RetirementDate;
    chkProrate.Checked := TAppSettings.Instance.ProrateVacationInExitYear;
  finally
    dtpFrom.OnChange := Recalculate;
    dtpRetirement.OnChange := PersistInputs;
  end;
end;

procedure TRetirementForm.PersistInputs(Sender: TObject);
begin
  TAppSettings.Instance.SetRetirementDate(Trunc(dtpRetirement.Date));
  TAppSettings.Instance.SetProrateVacationInExitYear(chkProrate.Checked);
  Recalculate(Sender);
end;

procedure TRetirementForm.SetBusy(Busy: Boolean);
begin
  FBusy := Busy;
  dtpFrom.Enabled := not Busy;
  dtpRetirement.Enabled := not Busy;
  chkProrate.Enabled := not Busy;
  btnCalculate.Enabled := not Busy;
  btnDownload.Enabled := not Busy;
end;

procedure TRetirementForm.Recalculate(Sender: TObject);
var
  LastWork: TDate;
  WS: TWorkSettings;
begin
  if FBusy then
    Exit;
  LastWork := IncDay(Trunc(dtpRetirement.Date), -1);
  if LastWork > 0 then
    lblLastWork.Caption := 'Letzter Arbeitstag: ' + FormatDateTime('dd.mm.yyyy', LastWork)
  else
    lblLastWork.Caption := '';
  WS := TAppSettings.Instance.WorkSettings;
  lblMeta.Caption := Format('Bundesland: %s  |  Jahresurlaub: %s Tage  |  Arbeitstage: %s',
    [TAppSettings.Instance.StateDisplayName, FormatHours(WS.AnnualVacationDays, 1), WorkDaysLabel]);
  FillTable;
end;

procedure TRetirementForm.FillTable;
var
  Plan: TRetirementPlan;
  Row, I: Integer;
  Year: Integer;
  Years: string;
begin
  Plan := TRetirementCalculator.Compute(Trunc(dtpFrom.Date), Trunc(dtpRetirement.Date),
    chkProrate.Checked);
  if Plan.Error <> '' then
  begin
    grdYears.RowCount := 2;
    grdYears.Rows[1].Clear;
    lblSummary.Caption := Plan.Error;
    lblStatus.Caption := '';
    btnDownload.Enabled := False;
    Exit;
  end;
  grdYears.RowCount := Length(Plan.Years) + 2;
  for I := 0 to High(Plan.Years) do
  begin
    Row := I + 1;
    grdYears.Cells[0, Row] := IntToStr(Plan.Years[I].Year);
    grdYears.Cells[1, Row] := FormatDateTime('dd.mm.', Plan.Years[I].FromDate) + ' ' + EnDash + ' ' +
      FormatDateTime('dd.mm.yyyy', Plan.Years[I].ToDate);
    grdYears.Cells[2, Row] := IntToStr(Plan.Years[I].WorkDays);
    if Plan.Years[I].HolidaysAvailable then
      grdYears.Cells[3, Row] := IntToStr(Plan.Years[I].HolidaysOnWorkDays)
    else
      grdYears.Cells[3, Row] := EnDash;
    grdYears.Cells[4, Row] := FormatHours(Plan.Years[I].VacationDays, 1);
    grdYears.Cells[5, Row] := FormatHours(Plan.Years[I].RemainingDays, 1);
    grdYears.Cells[6, Row] := FormatHours(Plan.Years[I].RemainingHours, 2);
  end;
  Row := Length(Plan.Years) + 1;
  grdYears.Cells[0, Row] := 'Summe';
  grdYears.Cells[1, Row] := '';
  grdYears.Cells[2, Row] := IntToStr(Plan.TotalWorkDays);
  grdYears.Cells[3, Row] := IntToStr(Plan.TotalHolidays);
  grdYears.Cells[4, Row] := FormatHours(Plan.TotalVacation, 1);
  grdYears.Cells[5, Row] := FormatHours(Plan.TotalRemainingDays, 1);
  grdYears.Cells[6, Row] := FormatHours(Plan.TotalRemainingHours, 2);
  lblSummary.Caption := Format('Noch %s Arbeitstage (%s h) bis zur Rente.',
    [FormatHours(Plan.TotalRemainingDays, 1), FormatHours(Plan.TotalRemainingHours, 2)]);
  btnDownload.Enabled := Length(Plan.MissingHolidayYears) > 0;
  if Length(Plan.MissingHolidayYears) = 0 then
    lblStatus.Caption := Format('Feiertage für %s liegen lokal vor.',
      [TAppSettings.Instance.StateDisplayName])
  else
  begin
    Years := '';
    for Year in Plan.MissingHolidayYears do
    begin
      if Years <> '' then
        Years := Years + ', ';
      Years := Years + IntToStr(Year);
    end;
    lblStatus.Caption := Format('Feiertage fehlen für: %s. Bitte herunterladen, sonst werden in diesen Jahren keine Feiertage abgezogen.',
      [Years]);
  end;
  SizeGridColumnsToContent(grdYears, [0, 1, 2, 3, 4, 5, 6]);
  grdYears.Invalidate;
end;

procedure TRetirementForm.DownloadMissing(Sender: TObject);
var
  Plan: TRetirementPlan;
begin
  Plan := TRetirementCalculator.Compute(Trunc(dtpFrom.Date), Trunc(dtpRetirement.Date),
    chkProrate.Checked);
  if Plan.Error <> '' then
  begin
    MessageDlg(Plan.Error, mtWarning, [mbOK], 0);
    Exit;
  end;
  if Length(Plan.MissingHolidayYears) = 0 then
  begin
    lblStatus.Caption := 'Feiertage liegen bereits vor.';
    Exit;
  end;
  SetBusy(True);
  lblStatus.Caption := 'Lade Feiertage' + Ellipsis;
  TCalendarService.Instance.DownloadPublicHolidayYears(Plan.MissingHolidayYears);
end;

procedure TRetirementForm.OnDownloadProgress(const AKind: string; AYear, ACurrent, ATotal: Integer);
begin
  if (AKind <> 'feiertage') or not FBusy then
    Exit;
    lblStatus.Caption := Format('Lade Feiertage %d (%d von %d)' + Ellipsis, [AYear, ACurrent, ATotal]);
end;

procedure TRetirementForm.OnDownloadFinished(const AKind: string; AYear: Integer; AOk: Boolean;
  const AMessage: string);
begin
  if AKind <> 'feiertage-jahre' then
    Exit;
  SetBusy(False);
  FillTable;
  if AOk then
    lblStatus.Caption := AMessage
  else
  begin
    MessageDlg(AMessage, mtWarning, [mbOK], 0);
    lblStatus.Caption := AMessage;
  end;
end;

procedure TRetirementForm.CloseClick(Sender: TObject);
begin
  ModalResult := mrClose;
end;

procedure TRetirementForm.GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
  State: TGridDrawState);
begin
  UseGridFont(grdYears);
  if ARow = 0 then
    grdYears.Canvas.Brush.Color := clBtnFace
  else if gdSelected in State then
    grdYears.Canvas.Brush.Color := clHighlight
  else if ARow = grdYears.RowCount - 1 then
    grdYears.Canvas.Brush.Color := clBtnFace
  else
    grdYears.Canvas.Brush.Color := clWindow;
  if (gdSelected in State) and (ARow > 0) then
    grdYears.Canvas.Font.Color := clHighlightText
  else
    grdYears.Canvas.Font.Color := clWindowText;
  if ARow = grdYears.RowCount - 1 then
    grdYears.Canvas.Font.Style := [fsBold];
  grdYears.Canvas.FillRect(Rect);
  DrawPlainText(grdYears.Canvas, Rect, grdYears.Cells[ACol, ARow], ACol <> 1);
end;

end.
