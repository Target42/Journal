unit TerminEditForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Journal.Appointments;

type
  TTerminEditForm = class(TForm)
    lblTitel: TLabel;
    edtTitle: TEdit;
    lblVon: TLabel;
    dtpStart: TDateTimePicker;
    lblBis: TLabel;
    dtpEnd: TDateTimePicker;
    grpKind: TGroupBox;
    rbOnce: TRadioButton;
    lblDate: TLabel;
    dtpDate: TDateTimePicker;
    rbWeekly: TRadioButton;
    chkMo: TCheckBox;
    chkDi: TCheckBox;
    chkMi: TCheckBox;
    chkDo: TCheckBox;
    chkFr: TCheckBox;
    chkSa: TCheckBox;
    chkSo: TCheckBox;
    lblHint: TLabel;
    btnDelete: TButton;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  private
    FId: string;
    FExisting: Boolean;
    FDeleted: Boolean;
    procedure UpdateKindUi(Sender: TObject);
    procedure ConfirmDelete(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    function DayCheck(ADay: Integer): TCheckBox;
    function Collect: TAppointment;
  public
    procedure Init(const Apt: TAppointment; Existing: Boolean);
    function WasDeleted: Boolean;
    class function RunNew(AOwner: TComponent): Boolean;
    class function RunNewOnce(AOwner: TComponent; const ADate: TDate;
      StartMinute: Integer): Boolean;
    class function RunEdit(AOwner: TComponent; const Apt: TAppointment): Boolean;
  end;

implementation

{$R *.dfm}

uses
  System.DateUtils, Vcl.Dialogs, Journal.Types;

procedure TTerminEditForm.FormCreate(Sender: TObject);
begin
  rbOnce.OnClick := UpdateKindUi;
  rbWeekly.OnClick := UpdateKindUi;
  btnOk.OnClick := OkClick;
  btnCancel.OnClick := CancelClick;
  btnDelete.OnClick := ConfirmDelete;
end;

function TTerminEditForm.DayCheck(ADay: Integer): TCheckBox;
begin
  case ADay of
    1: Result := chkMo;
    2: Result := chkDi;
    3: Result := chkMi;
    4: Result := chkDo;
    5: Result := chkFr;
    6: Result := chkSa;
  else
    Result := chkSo;
  end;
end;

procedure TTerminEditForm.Init(const Apt: TAppointment; Existing: Boolean);
var
  Day: Integer;
begin
  FId := Apt.Id;
  FExisting := Existing;
  FDeleted := False;
  if Existing then
    Caption := 'Termin bearbeiten'
  else
    Caption := 'Termin anlegen';
  btnDelete.Visible := Existing;
  edtTitle.Text := Apt.Title;
  dtpStart.Time := MinuteToTime(Apt.StartMinute);
  dtpEnd.Time := MinuteToTime(Apt.EndMinute);
  if DateValid(Apt.Date) then
    dtpDate.Date := Apt.Date
  else
    dtpDate.Date := Date;
  for Day := 1 to 7 do
    DayCheck(Day).Checked := Apt.HasWeekday(Day);
  rbWeekly.Checked := Apt.Kind = akWeekly;
  rbOnce.Checked := Apt.Kind <> akWeekly;
  UpdateKindUi(nil);
end;

procedure TTerminEditForm.UpdateKindUi(Sender: TObject);
var
  Weekly: Boolean;
  Day: Integer;
begin
  Weekly := rbWeekly.Checked;
  lblDate.Enabled := not Weekly;
  dtpDate.Enabled := not Weekly;
  for Day := 1 to 7 do
    DayCheck(Day).Enabled := Weekly;
end;

function TTerminEditForm.Collect: TAppointment;
var
  Day: Integer;
begin
  Result := Default(TAppointment);
  Result.Id := FId;
  Result.Title := Trim(edtTitle.Text);
  Result.StartMinute := TimeToMinute(dtpStart.Time);
  Result.EndMinute := TimeToMinute(dtpEnd.Time);
  if rbWeekly.Checked then
  begin
    Result.Kind := akWeekly;
    for Day := 1 to 7 do
      if DayCheck(Day).Checked then
      begin
        SetLength(Result.Weekdays, Length(Result.Weekdays) + 1);
        Result.Weekdays[High(Result.Weekdays)] := Day;
      end;
  end
  else
  begin
    Result.Kind := akOnce;
    Result.Date := DateOf(dtpDate.Date);
  end;
end;

function TTerminEditForm.WasDeleted: Boolean;
begin
  Result := FDeleted;
end;

procedure TTerminEditForm.ConfirmDelete(Sender: TObject);
begin
  if MessageDlg('Den Termin ' + DQuoteOpen + Trim(edtTitle.Text) + DQuoteClose +
    ' l' + #$00F6 + 'schen?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FDeleted := True;
  ModalResult := mrOk;
end;

procedure TTerminEditForm.OkClick(Sender: TObject);
var
  Apt: TAppointment;
  Error: string;
begin
  if FDeleted then
  begin
    ModalResult := mrOk;
    Exit;
  end;
  Apt := Collect;
  if not TAppointmentCatalog.Instance.Upsert(Apt, Error) then
  begin
    MessageDlg(Error, mtWarning, [mbOK], 0);
    Exit;
  end;
  FId := Apt.Id;
  ModalResult := mrOk;
end;

procedure TTerminEditForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

class function TTerminEditForm.RunNew(AOwner: TComponent): Boolean;
var
  Apt: TAppointment;
  Dlg: TTerminEditForm;
begin
  Apt := Default(TAppointment);
  Apt.StartMinute := 9 * 60;
  Apt.EndMinute := 9 * 60 + 30;
  Apt.Kind := akOnce;
  Apt.Date := Date;
  Dlg := TTerminEditForm.Create(AOwner);
  try
    Dlg.Init(Apt, False);
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

class function TTerminEditForm.RunNewOnce(AOwner: TComponent; const ADate: TDate;
  StartMinute: Integer): Boolean;
var
  Apt: TAppointment;
  Dlg: TTerminEditForm;
begin
  Apt := Default(TAppointment);
  Apt.StartMinute := ClampInt(StartMinute, 0, 23 * 60 + 30);
  Apt.EndMinute := ClampInt(Apt.StartMinute + 30, Apt.StartMinute + 1, 24 * 60);
  Apt.Kind := akOnce;
  if DateValid(ADate) then
    Apt.Date := ADate
  else
    Apt.Date := Date;
  Dlg := TTerminEditForm.Create(AOwner);
  try
    Dlg.Init(Apt, False);
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

class function TTerminEditForm.RunEdit(AOwner: TComponent; const Apt: TAppointment): Boolean;
var
  Dlg: TTerminEditForm;
begin
  Dlg := TTerminEditForm.Create(AOwner);
  try
    Dlg.Init(Apt, True);
    Result := Dlg.ShowModal = mrOk;
    if Result and Dlg.WasDeleted then
      TAppointmentCatalog.Instance.Remove(Apt.Id);
  finally
    Dlg.Free;
  end;
end;

end.
