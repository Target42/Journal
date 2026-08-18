unit SettingsForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.NumberBox, Vcl.ComCtrls, Vcl.ExtCtrls,
  Journal.Types;

type
  TSettingsForm = class(TForm)
    pages: TPageControl;
    tabWork: TTabSheet;
    tabVacation: TTabSheet;
    tabOvertime: TTabSheet;
    tabDay: TTabSheet;
    grpBundesland: TGroupBox;
    lblArbeitsort: TLabel;
    cbState: TComboBox;
    lblStateHint: TLabel;
    grpArbeitstage: TGroupBox;
    chkMo: TCheckBox;
    chkDi: TCheckBox;
    chkMi: TCheckBox;
    chkDo: TCheckBox;
    chkFr: TCheckBox;
    chkSa: TCheckBox;
    chkSo: TCheckBox;
    grpSoll: TGroupBox;
    rbEven: TRadioButton;
    rbIndividual: TRadioButton;
    lblWeekly: TLabel;
    nbWeekly: TNumberBox;
    lblEvenPreview: TLabel;
    nbMo: TNumberBox;
    nbDi: TNumberBox;
    nbMi: TNumberBox;
    nbDo: TNumberBox;
    nbFr: TNumberBox;
    nbSa: TNumberBox;
    nbSo: TNumberBox;
    lblMo: TLabel;
    lblDi: TLabel;
    lblMi: TLabel;
    lblDo: TLabel;
    lblFr: TLabel;
    lblSa: TLabel;
    lblSo: TLabel;
    grpUrlaub: TGroupBox;
    lblUrlaub: TLabel;
    nbVacation: TNumberBox;
    grpEve: TGroupBox;
    lblEve: TLabel;
    cbEve: TComboBox;
    lblEveHint: TLabel;
    grpOvertime: TGroupBox;
    chkOvertimeLimits: TCheckBox;
    lblGeltung: TLabel;
    cbPeriod: TComboBox;
    lblMin: TLabel;
    nbMin: TNumberBox;
    lblMax: TLabel;
    nbMax: TNumberBox;
    lblOvertimeHint: TLabel;
    grpBounds: TGroupBox;
    lblVon: TLabel;
    dtpStart: TDateTimePicker;
    lblBis: TLabel;
    dtpEnd: TDateTimePicker;
    lblBoundsHint: TLabel;
    grpPause: TGroupBox;
    lblPauseVon: TLabel;
    dtpPauseStart: TDateTimePicker;
    lblPauseBis: TLabel;
    dtpPauseEnd: TDateTimePicker;
    lblPauseHint: TLabel;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  private
    FWorkDays: array[0..6] of TCheckBox;
    FDayHours: array[0..6] of TNumberBox;
    procedure LoadFromSettings;
    procedure SaveToSettings;
    procedure UpdateModeUi(Sender: TObject);
    procedure UpdateEvenPreview(Sender: TObject);
    procedure UpdateOvertimeUi(Sender: TObject);
    procedure ApplyEvenHoursToWorkDays;
    procedure WorkDayToggled(Sender: TObject);
    function SelectedWorkDayCount: Integer;
    function EvenHoursPerDay: Double;
    procedure OkClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
  end;

implementation

{$R *.dfm}

uses
  Vcl.Dialogs, Journal.Settings;

procedure TSettingsForm.FormCreate(Sender: TObject);
var
  State: TGermanState;
  I: Integer;
begin
  FWorkDays[0] := chkMo; FWorkDays[1] := chkDi; FWorkDays[2] := chkMi;
  FWorkDays[3] := chkDo; FWorkDays[4] := chkFr; FWorkDays[5] := chkSa;
  FWorkDays[6] := chkSo;
  FDayHours[0] := nbMo; FDayHours[1] := nbDi; FDayHours[2] := nbMi;
  FDayHours[3] := nbDo; FDayHours[4] := nbFr; FDayHours[5] := nbSa;
  FDayHours[6] := nbSo;
  cbState.Items.Clear;
  for State in TAppSettings.GermanStates do
    cbState.Items.Add(Format('%s (%s)', [State.Name, State.Code]));
  cbPeriod.Items.Clear;
  cbPeriod.Items.Add('Monatlich');
  cbPeriod.Items.Add('Quartalsweise');
  cbEve.Items.Clear;
  cbEve.Items.Add('Normaler Arbeitstag');
  cbEve.Items.Add('Jeweils ein Urlaubstag');
  cbEve.Items.Add('Jeweils ein halber Urlaubstag');
  cbEve.Items.Add('Vollst' + #$00E4 + 'ndig frei ohne Arbeitspflicht');
  for I := 0 to 6 do
    FWorkDays[I].OnClick := WorkDayToggled;
  rbEven.OnClick := UpdateModeUi;
  rbIndividual.OnClick := UpdateModeUi;
  nbWeekly.OnChangeValue := UpdateEvenPreview;
  chkOvertimeLimits.OnClick := UpdateOvertimeUi;
  btnOk.OnClick := OkClick;
  btnCancel.OnClick := CancelClick;
  LoadFromSettings;
end;

procedure TSettingsForm.LoadFromSettings;
var
  WS: TWorkSettings;
  Code: string;
  States: TArray<TGermanState>;
  I: Integer;
  Overtime: TOvertimeAccountSettings;
  Pause: TDayBounds;
begin
  WS := TAppSettings.Instance.WorkSettings;
  Code := TAppSettings.Instance.StateCode;
  States := TAppSettings.GermanStates;
  cbState.ItemIndex := 8;
  for I := 0 to High(States) do
    if States[I].Code = Code then
      cbState.ItemIndex := I;
  nbVacation.Value := WS.AnnualVacationDays;
  case WS.EveDayTreatment of
    edtFullVacation: cbEve.ItemIndex := 1;
    edtHalfVacation: cbEve.ItemIndex := 2;
    edtCompanyFree: cbEve.ItemIndex := 3;
  else
    cbEve.ItemIndex := 0;
  end;
  nbWeekly.Value := WS.WeeklyHours;
  for I := 0 to 6 do
  begin
    FWorkDays[I].Checked := WS.WorkDays[I];
    FDayHours[I].Value := WS.HoursPerDay[I];
  end;
  if WS.WorkTimeMode = wtmIndividual then
    rbIndividual.Checked := True
  else
    rbEven.Checked := True;
  UpdateModeUi(nil);
  UpdateEvenPreview(nil);
  if rbEven.Checked then
    ApplyEvenHoursToWorkDays;
  dtpStart.Time := MinuteToTime(TAppSettings.Instance.DayStartMinute);
  dtpEnd.Time := MinuteToTime(TAppSettings.Instance.DayEndMinute);
  Pause := TAppSettings.Instance.UsualPauseWindow;
  dtpPauseStart.Time := MinuteToTime(Pause.StartMinute);
  dtpPauseEnd.Time := MinuteToTime(Pause.EndMinute);
  Overtime := TAppSettings.Instance.OvertimeAccount;
  chkOvertimeLimits.Checked := Overtime.LimitsEnabled;
  if Overtime.Period = olpMonthly then
    cbPeriod.ItemIndex := 0
  else
    cbPeriod.ItemIndex := 1;
  nbMin.Value := Overtime.MinHours;
  nbMax.Value := Overtime.MaxHours;
  UpdateOvertimeUi(nil);
end;

procedure TSettingsForm.SaveToSettings;
var
  WS: TWorkSettings;
  States: TArray<TGermanState>;
  Overtime: TOvertimeAccountSettings;
  I: Integer;
begin
  WS := Default(TWorkSettings);
  WS.AnnualVacationDays := nbVacation.Value;
  case cbEve.ItemIndex of
    1: WS.EveDayTreatment := edtFullVacation;
    2: WS.EveDayTreatment := edtHalfVacation;
    3: WS.EveDayTreatment := edtCompanyFree;
  else
    WS.EveDayTreatment := edtNormal;
  end;
  if rbIndividual.Checked then
    WS.WorkTimeMode := wtmIndividual
  else
    WS.WorkTimeMode := wtmEven;
  WS.WeeklyHours := nbWeekly.Value;
  for I := 0 to 6 do
  begin
    WS.WorkDays[I] := FWorkDays[I].Checked;
    WS.HoursPerDay[I] := FDayHours[I].Value;
  end;
  TAppSettings.Instance.SetWorkSettings(WS);
  TAppSettings.Instance.SetDayWindow(TimeToMinute(dtpStart.Time), TimeToMinute(dtpEnd.Time));
  TAppSettings.Instance.SetUsualPauseWindow(TimeToMinute(dtpPauseStart.Time),
    TimeToMinute(dtpPauseEnd.Time));
  States := TAppSettings.GermanStates;
  if (cbState.ItemIndex >= 0) and (cbState.ItemIndex <= High(States)) then
    TAppSettings.Instance.SetStateCode(States[cbState.ItemIndex].Code);
  Overtime.LimitsEnabled := chkOvertimeLimits.Checked;
  if cbPeriod.ItemIndex = 0 then
    Overtime.Period := olpMonthly
  else
    Overtime.Period := olpQuarterly;
  Overtime.MinHours := nbMin.Value;
  Overtime.MaxHours := nbMax.Value;
  TAppSettings.Instance.SetOvertimeAccount(Overtime);
end;

procedure TSettingsForm.UpdateModeUi(Sender: TObject);
var
  Even: Boolean;
  I: Integer;
begin
  Even := rbEven.Checked;
  nbWeekly.Enabled := Even;
  lblWeekly.Enabled := Even;
  lblEvenPreview.Enabled := Even;
  for I := 0 to 6 do
  begin
    FDayHours[I].Enabled := FWorkDays[I].Checked;
    FDayHours[I].ReadOnly := Even;
  end;
  if Even then
    ApplyEvenHoursToWorkDays;
end;

procedure TSettingsForm.ApplyEvenHoursToWorkDays;
var
  Hours: Double;
  I: Integer;
begin
  if not rbEven.Checked then
    Exit;
  Hours := EvenHoursPerDay;
  for I := 0 to 6 do
    if FWorkDays[I].Checked then
      FDayHours[I].Value := Hours
    else
      FDayHours[I].Value := 0;
end;

procedure TSettingsForm.UpdateEvenPreview(Sender: TObject);
var
  Count: Integer;
begin
  Count := SelectedWorkDayCount;
  if Count = 0 then
    lblEvenPreview.Caption := 'Bitte mindestens einen Arbeitstag ausw' + #$00E4 + 'hlen.'
  else
    lblEvenPreview.Caption := Format('Entspricht %s h je Arbeitstag (%d Arbeitstage).',
      [FormatHours(EvenHoursPerDay), Count]);
  if rbEven.Checked then
    ApplyEvenHoursToWorkDays;
end;

procedure TSettingsForm.UpdateOvertimeUi(Sender: TObject);
begin
  cbPeriod.Enabled := chkOvertimeLimits.Checked;
  nbMin.Enabled := chkOvertimeLimits.Checked;
  nbMax.Enabled := chkOvertimeLimits.Checked;
  lblGeltung.Enabled := chkOvertimeLimits.Checked;
  lblMin.Enabled := chkOvertimeLimits.Checked;
  lblMax.Enabled := chkOvertimeLimits.Checked;
end;

procedure TSettingsForm.WorkDayToggled(Sender: TObject);
var
  I: Integer;
begin
  if rbEven.Checked then
    ApplyEvenHoursToWorkDays
  else
    for I := 0 to 6 do
      if (Sender = FWorkDays[I]) and FWorkDays[I].Checked and (FDayHours[I].Value <= 0) then
      begin
        if EvenHoursPerDay > 0 then
          FDayHours[I].Value := EvenHoursPerDay
        else
          FDayHours[I].Value := 8;
      end;
  UpdateModeUi(nil);
  UpdateEvenPreview(nil);
end;

function TSettingsForm.SelectedWorkDayCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to 6 do
    if FWorkDays[I].Checked then
      Inc(Result);
end;

function TSettingsForm.EvenHoursPerDay: Double;
var
  Count: Integer;
begin
  Count := SelectedWorkDayCount;
  if Count <= 0 then
    Result := 0
  else
    Result := nbWeekly.Value / Count;
end;

procedure TSettingsForm.OkClick(Sender: TObject);
begin
  if SelectedWorkDayCount = 0 then
  begin
    MessageDlg('Bitte mindestens einen Arbeitstag ausw' + #$00E4 + 'hlen.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if TimeToMinute(dtpStart.Time) >= TimeToMinute(dtpEnd.Time) then
  begin
    MessageDlg('Die Tagesgrenze ' + DQuoteOpen + 'Von' + DQuoteClose +
      ' muss vor ' + DQuoteOpen + 'Bis' + DQuoteClose + ' liegen.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if TimeToMinute(dtpPauseStart.Time) >= TimeToMinute(dtpPauseEnd.Time) then
  begin
    MessageDlg('Das Pausenfenster ' + DQuoteOpen + 'Von' + DQuoteClose +
      ' muss vor ' + DQuoteOpen + 'Bis' + DQuoteClose + ' liegen.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if chkOvertimeLimits.Checked and (nbMin.Value > nbMax.Value) then
  begin
    MessageDlg('Die Untergrenze des ' + #$00DC + 'berstundenkontos muss kleiner oder gleich der Obergrenze sein.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  SaveToSettings;
  ModalResult := mrOk;
end;

procedure TSettingsForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
