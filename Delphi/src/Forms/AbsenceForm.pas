unit AbsenceForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Journal.Types;

type
  TAbsenceForm = class(TForm)
    lblVon: TLabel;
    lblBis: TLabel;
    dtpFrom: TDateTimePicker;
    dtpTo: TDateTimePicker;
    grpArt: TGroupBox;
    rbVacation: TRadioButton;
    rbSick: TRadioButton;
    rbPaid: TRadioButton;
    rbCompensatory: TRadioButton;
    rbClear: TRadioButton;
    grpUmfang: TGroupBox;
    rbFull: TRadioButton;
    rbHalf: TRadioButton;
    lblHint: TLabel;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  private
    procedure ClearToggled(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
  public
    procedure InitRange(const AFrom, ATo: TDate);
    function FromDate: TDate;
    function ToDate: TDate;
    function Absence: TAbsence;
    function IsClear: Boolean;
  end;

implementation

{$R *.dfm}

uses
  Vcl.Dialogs;

procedure TAbsenceForm.FormCreate(Sender: TObject);
begin
  rbClear.OnClick := ClearToggled;
  btnOk.OnClick := OkClick;
  btnCancel.OnClick := CancelClick;
end;

procedure TAbsenceForm.InitRange(const AFrom, ATo: TDate);
begin
  if DateValid(AFrom) then
    dtpFrom.Date := AFrom
  else
    dtpFrom.Date := Date;
  if DateValid(ATo) then
    dtpTo.Date := ATo
  else
    dtpTo.Date := dtpFrom.Date;
end;

procedure TAbsenceForm.ClearToggled(Sender: TObject);
begin
  rbFull.Enabled := not rbClear.Checked;
  rbHalf.Enabled := not rbClear.Checked;
end;

procedure TAbsenceForm.OkClick(Sender: TObject);
begin
  if (dtpFrom.Date <= 0) or (dtpTo.Date <= 0) then
  begin
    MessageDlg('Bitte einen gültigen Zeitraum angeben.', mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOk;
end;

procedure TAbsenceForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

function TAbsenceForm.FromDate: TDate;
begin
  Result := Trunc(dtpFrom.Date);
end;

function TAbsenceForm.ToDate: TDate;
begin
  Result := Trunc(dtpTo.Date);
end;

function TAbsenceForm.Absence: TAbsence;
begin
  Result := Default(TAbsence);
  if IsClear then
    Exit;
  if rbSick.Checked then
    Result.AbsenceType := atSick
  else if rbPaid.Checked then
    Result.AbsenceType := atPaidLeave
  else if rbCompensatory.Checked then
    Result.AbsenceType := atCompensatory
  else
    Result.AbsenceType := atVacation;
  if rbHalf.Checked then
    Result.Fraction := 0.5
  else
    Result.Fraction := 1.0;
end;

function TAbsenceForm.IsClear: Boolean;
begin
  Result := rbClear.Checked;
end;

end.
