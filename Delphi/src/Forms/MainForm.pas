unit MainForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.Dialogs, Vcl.Menus, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.StdCtrls,
  MonthViewFrame, YearViewFrame, DayViewFrame, PackageChartFrame, AccountTrendFrame;

type
  TMainForm = class(TForm)
    MainMenu: TMainMenu;
    miDatei: TMenuItem;
    miDatenordner: TMenuItem;
    miEinstellungen: TMenuItem;
    miTitel: TMenuItem;
    miAbsence: TMenuItem;
    N1: TMenuItem;
    miRente: TMenuItem;
    miArbZG: TMenuItem;
    N2: TMenuItem;
    miFeiertage: TMenuItem;
    miFerien: TMenuItem;
    N3: TMenuItem;
    miBeenden: TMenuItem;
    miHilfe: TMenuItem;
    miUeber: TMenuItem;
    StatusBar: TStatusBar;
    pnlDay: TPanel;
    grpDay: TGroupBox;
    splDay: TSplitter;
    pnlTop: TPanel;
    pnlLeft: TPanel;
    grpMonth: TGroupBox;
    splVert: TSplitter;
    pnlRight: TPanel;
    pnlYear: TPanel;
    grpYear: TGroupBox;
    splYear: TSplitter;
    pnlChart: TPanel;
    grpChart: TGroupBox;
    splChart: TSplitter;
    pnlTrend: TPanel;
    grpTrend: TGroupBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FMonthView: TMonthViewFrame;
    FYearView: TYearViewFrame;
    FDayView: TDayViewFrame;
    FPackageChart: TPackageChartFrame;
    FAccountTrend: TAccountTrendFrame;
    procedure ChooseDataPath(Sender: TObject);
    procedure OpenSettings(Sender: TObject);
    procedure OpenTitles(Sender: TObject);
    procedure OpenAbsence(Sender: TObject);
    procedure OpenRetirement(Sender: TObject);
    procedure OpenArbzg(Sender: TObject);
    procedure DownloadPublicHolidays(Sender: TObject);
    procedure DownloadSchoolHolidays(Sender: TObject);
    procedure ShowAbout(Sender: TObject);
    procedure QuitClick(Sender: TObject);
    procedure OnCalendarDownloadFinished(const AKind: string; AYear: Integer;
      AOk: Boolean; const AMessage: string);
    procedure SettingsChanged;
    procedure StoreChanged;
    procedure UpdateStatusBar;
    function ActiveYear: Integer;
    function AskDownloadYear(const Title: string): Integer;
    procedure YearMonthActivated(AYear, AMonth: Integer);
    procedure YearChanged(AYear: Integer);
    procedure DayActivated(const ADate: TDate);
    procedure DayDateChanged(const ADate: TDate);
    procedure UpdateGroupTitles;
  end;

var
  frmMain: TMainForm;

implementation

{$R *.dfm}

uses
  System.DateUtils, System.Math, Vcl.FileCtrl, Journal.Types, Journal.Settings, Journal.Calendar, Journal.TimeTotals,
  Journal.Store, Journal.Arbzg, SettingsForm, TitlesForm, RetirementForm, ArbzgForm, YearSelectForm;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Caption := 'Journal ' + EnDash + ' Arbeitszeiterfassung';
  TTimeTotals.Instance;
  FMonthView := TMonthViewFrame.Create(Self);
  FMonthView.Parent := grpMonth;
  FMonthView.Align := alClient;
  FYearView := TYearViewFrame.Create(Self);
  FYearView.Parent := grpYear;
  FYearView.Align := alClient;
  FPackageChart := TPackageChartFrame.Create(Self);
  FPackageChart.Parent := grpChart;
  FPackageChart.Align := alClient;
  FAccountTrend := TAccountTrendFrame.Create(Self);
  FAccountTrend.Parent := grpTrend;
  FAccountTrend.Align := alClient;
  FDayView := TDayViewFrame.Create(Self);
  FDayView.Parent := grpDay;
  FDayView.Align := alClient;

  miDatenordner.OnClick := ChooseDataPath;
  miEinstellungen.OnClick := OpenSettings;
  miTitel.OnClick := OpenTitles;
  miAbsence.OnClick := OpenAbsence;
  miRente.OnClick := OpenRetirement;
  miArbZG.OnClick := OpenArbzg;
  miFeiertage.OnClick := DownloadPublicHolidays;
  miFerien.OnClick := DownloadSchoolHolidays;
  miBeenden.OnClick := QuitClick;
  miUeber.OnClick := ShowAbout;

  FYearView.OnMonthActivated := YearMonthActivated;
  FYearView.OnYearChanged := YearChanged;
  FMonthView.OnDayActivated := DayActivated;
  FDayView.OnDateChanged := DayDateChanged;

  TCalendarService.Instance.OnDownloadFinished.Add(OnCalendarDownloadFinished);
  TAppSettings.Instance.OnChanged.Add(SettingsChanged);
  TJournalStore.Instance.OnChanged.Add(StoreChanged);
  TJournalStore.Instance.OnActiveDayTicked.Add(StoreChanged);

  FYearView.SelectMonth(MonthOf(FMonthView.DisplayedMonth));
  FPackageChart.SetMonth(YearOf(FMonthView.DisplayedMonth), MonthOf(FMonthView.DisplayedMonth));
  FMonthView.SelectDate(FDayView.DateValue);
  UpdateGroupTitles;
  UpdateStatusBar;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  TCalendarService.Instance.OnDownloadFinished.Remove(OnCalendarDownloadFinished);
  TAppSettings.Instance.OnChanged.Remove(SettingsChanged);
  TJournalStore.Instance.OnChanged.Remove(StoreChanged);
  TJournalStore.Instance.OnActiveDayTicked.Remove(StoreChanged);
end;

procedure TMainForm.YearMonthActivated(AYear, AMonth: Integer);
var
  Current, Today: TDate;
begin
  FMonthView.SetMonth(AYear, AMonth);
  FPackageChart.SetMonth(AYear, AMonth);
  Current := FDayView.DateValue;
  Today := Date;
  if (YearOf(Current) <> AYear) or (MonthOf(Current) <> AMonth) then
  begin
    if (YearOf(Today) = AYear) and (MonthOf(Today) = AMonth) then
      FDayView.SetDate(Today)
    else
      FDayView.SetDate(EncodeDate(AYear, AMonth, 1));
  end;
  FMonthView.SelectDate(FDayView.DateValue);
  UpdateGroupTitles;
end;

procedure TMainForm.YearChanged(AYear: Integer);
var
  Month: Integer;
  Today: TDate;
begin
  Month := MonthOf(FMonthView.DisplayedMonth);
  TCalendarService.Instance.EnsureYearLoaded(AYear);
  FMonthView.SetMonth(AYear, Month);
  FYearView.SelectMonth(Month);
  FPackageChart.SetMonth(AYear, Month);
  Today := Date;
  if (YearOf(Today) = AYear) and (MonthOf(Today) = Month) then
    FDayView.SetDate(Today)
  else
    FDayView.SetDate(EncodeDate(AYear, Month, 1));
  FMonthView.SelectDate(FDayView.DateValue);
  UpdateGroupTitles;
end;

procedure TMainForm.DayActivated(const ADate: TDate);
begin
  FDayView.SetDate(ADate);
end;

procedure TMainForm.DayDateChanged(const ADate: TDate);
begin
  FMonthView.SelectDate(ADate);
end;

function TMainForm.ActiveYear: Integer;
begin
  if FYearView <> nil then
    Result := FYearView.DisplayedYear
  else if FMonthView <> nil then
    Result := YearOf(FMonthView.DisplayedMonth)
  else
    Result := YearOf(Date);
end;

function TMainForm.AskDownloadYear(const Title: string): Integer;
var
  Dlg: TYearSelectForm;
begin
  Result := 0;
  Dlg := TYearSelectForm.Create(Self);
  try
    Dlg.Caption := Title;
    Dlg.nbYear.Value := Max(ActiveYear, YearOf(Date) + 1);
    if Dlg.ShowModal = mrOk then
      Result := Dlg.SelectedYear;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.DownloadPublicHolidays(Sender: TObject);
var
  Year: Integer;
begin
  Year := AskDownloadYear('Feiertage herunterladen');
  if Year <= 0 then
    Exit;
  StatusBar.SimpleText := Format('Lade Feiertage f' + #$00FC + 'r %d' + Ellipsis, [Year]);
  TCalendarService.Instance.DownloadPublicHolidays(Year);
end;

procedure TMainForm.DownloadSchoolHolidays(Sender: TObject);
var
  Year: Integer;
begin
  Year := AskDownloadYear('Ferien herunterladen');
  if Year <= 0 then
    Exit;
  StatusBar.SimpleText := Format('Lade Ferien f' + #$00FC + 'r %d' + Ellipsis, [Year]);
  TCalendarService.Instance.DownloadSchoolHolidays(Year);
end;

procedure TMainForm.OnCalendarDownloadFinished(const AKind: string; AYear: Integer;
  AOk: Boolean; const AMessage: string);
begin
  if AKind = 'feiertage-jahre' then
    Exit;
  if AOk then
    MessageDlg(AMessage, mtInformation, [mbOK], 0)
  else
    MessageDlg(AMessage, mtWarning, [mbOK], 0);
  UpdateGroupTitles;
  UpdateStatusBar;
end;

procedure TMainForm.OpenSettings(Sender: TObject);
var
  Dlg: TSettingsForm;
begin
  Dlg := TSettingsForm.Create(Self);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.OpenTitles(Sender: TObject);
var
  Dlg: TTitlesForm;
begin
  Dlg := TTitlesForm.Create(Self);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.OpenAbsence(Sender: TObject);
begin
  FMonthView.OpenAbsenceDialog;
end;

procedure TMainForm.OpenRetirement(Sender: TObject);
var
  Dlg: TRetirementForm;
begin
  Dlg := TRetirementForm.Create(Self);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.OpenArbzg(Sender: TObject);
var
  Dlg: TArbzgForm;
  Month: TDate;
begin
  Month := FMonthView.DisplayedMonth;
  Dlg := TArbzgForm.Create(Self);
  try
    Dlg.Init(YearOf(Month), MonthOf(Month));
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.ChooseDataPath(Sender: TObject);
var
  Path: string;
begin
  Path := TAppSettings.Instance.DataPath;
  if SelectDirectory('Datenordner w' + #$00E4 + 'hlen', '', Path) then
  begin
    TAppSettings.Instance.SetDataPath(Path);
    UpdateStatusBar;
    TCalendarService.Instance.ReloadYear(ActiveYear);
  end;
end;

procedure TMainForm.ShowAbout(Sender: TObject);
begin
  MessageDlg('Journal' + sLineBreak + sLineBreak +
    'Persönliche Arbeitszeiterfassung nach deutschen Vorgaben (ArbZG).' + sLineBreak +
    'Version 0.1.0', mtInformation, [mbOK], 0);
end;

procedure TMainForm.QuitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.UpdateGroupTitles;
begin
  if FPackageChart <> nil then
    grpChart.Caption := FPackageChart.CaptionText;
  if FAccountTrend <> nil then
    grpTrend.Caption := FAccountTrend.CaptionText;
end;

procedure TMainForm.SettingsChanged;
begin
  UpdateGroupTitles;
  UpdateStatusBar;
end;

procedure TMainForm.StoreChanged;
begin
  UpdateGroupTitles;
  UpdateStatusBar;
end;

procedure TMainForm.UpdateStatusBar;
var
  Text: string;
  Today: TArbzgDay;
begin
  Text := Format('Datenordner: %s  |  Bundesland: %s',
    [TAppSettings.Instance.DataPath, TAppSettings.Instance.StateDisplayName]);
  Today := AssessArbzgDay(Date);
  if Today.HasIssue then
    Text := Text + '  |  ArbZG: ' + Today.Issues[0]
  else if Today.UsualPauseMissed then
    Text := Text + '  |  Übliche Pause noch nicht begonnen';
  StatusBar.SimpleText := Text;
end;

end.
