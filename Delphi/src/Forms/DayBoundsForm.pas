unit DayBoundsForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Journal.Types;

type
  TDayBoundsForm = class(TForm)
    rbGlobal: TRadioButton;
    lblGlobal: TLabel;
    rbCustom: TRadioButton;
    lblVon: TLabel;
    dtpStart: TDateTimePicker;
    lblBis: TLabel;
    dtpEnd: TDateTimePicker;
    lblHint: TLabel;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  private
    FDate: TDate;
    procedure UpdateUi(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure LoadValues;
  public
    procedure InitDate(const ADate: TDate);
  end;

implementation

{$R *.dfm}

uses
  Vcl.Dialogs, Journal.Settings, Journal.Store, Journal.UiUtil;

procedure TDayBoundsForm.FormCreate(Sender: TObject);
begin
  rbGlobal.OnClick := UpdateUi;
  rbCustom.OnClick := UpdateUi;
  btnOk.OnClick := OkClick;
  btnCancel.OnClick := CancelClick;
end;

procedure TDayBoundsForm.InitDate(const ADate: TDate);
begin
  FDate := ADate;
  Caption := 'Tagesgrenzen ' + EnDash + ' ' + GermanDateLong(ADate);
  LoadValues;
end;

procedure TDayBoundsForm.LoadValues;
var
  Global, Current: TDayBounds;
begin
  Global := SanitizeDayBounds(TAppSettings.Instance.DayStartMinute,
    TAppSettings.Instance.DayEndMinute);
  lblGlobal.Caption := 'Aktuell ' + Global.LabelText;
  Current := TJournalStore.Instance.BoundsForDate(FDate);
  dtpStart.Time := MinuteToTime(Current.StartMinute);
  dtpEnd.Time := MinuteToTime(Current.EndMinute);
  if Current.Custom then
    rbCustom.Checked := True
  else
    rbGlobal.Checked := True;
  UpdateUi(nil);
end;

procedure TDayBoundsForm.UpdateUi(Sender: TObject);
begin
  dtpStart.Enabled := rbCustom.Checked;
  dtpEnd.Enabled := rbCustom.Checked;
  lblVon.Enabled := rbCustom.Checked;
  lblBis.Enabled := rbCustom.Checked;
end;

procedure TDayBoundsForm.OkClick(Sender: TObject);
var
  Bounds: TDayBounds;
  Error: string;
begin
  Bounds := Default(TDayBounds);
  if rbCustom.Checked then
  begin
    Bounds.Custom := True;
    Bounds.StartMinute := TimeToMinute(dtpStart.Time);
    Bounds.EndMinute := TimeToMinute(dtpEnd.Time);
    if Bounds.StartMinute >= Bounds.EndMinute then
    begin
      MessageDlg('Die Tagesgrenze ' + DQuoteOpen + 'Von' + DQuoteClose +
        ' muss vor ' + DQuoteOpen + 'Bis' + DQuoteClose + ' liegen.', mtWarning, [mbOK], 0);
      Exit;
    end;
  end;
  if not TJournalStore.Instance.SetBoundsForDate(FDate, Bounds, Error) then
  begin
    if Error = '' then
      Error := 'Die Tagesgrenzen konnten nicht gespeichert werden.';
    MessageDlg(Error, mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOk;
end;

procedure TDayBoundsForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
