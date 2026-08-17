unit PauseForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Journal.Types;

type
  TPauseForm = class(TForm)
    lblVon: TLabel;
    dtpStart: TDateTimePicker;
    lblBis: TLabel;
    dtpEnd: TDateTimePicker;
    lblDuration: TLabel;
    lblHint: TLabel;
    btnOk: TButton;
    btnCancel: TButton;
    btnDelete: TButton;
    procedure FormCreate(Sender: TObject);
  private
    FDate: TDate;
    FExisting: Boolean;
    FDeleted: Boolean;
    function StartMinute: Integer;
    function EndMinute: Integer;
    procedure UpdateDuration(Sender: TObject);
    procedure ConfirmDelete(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
  public
    procedure Init(const ADate: TDate; AStart, AEnd: Integer; Existing: Boolean);
    function WasDeleted: Boolean;
    class function RunAt(AOwner: TComponent; const ADate: TDate; AtMinute: Integer): Boolean;
    class function RunRange(AOwner: TComponent; const ADate: TDate; AStart, AEnd: Integer;
      Existing: Boolean): Boolean;
  end;

implementation

{$R *.dfm}

uses
  Vcl.Dialogs, Journal.Store, Journal.UiUtil;

procedure TPauseForm.FormCreate(Sender: TObject);
begin
  dtpStart.OnChange := UpdateDuration;
  dtpEnd.OnChange := UpdateDuration;
  btnOk.OnClick := OkClick;
  btnCancel.OnClick := CancelClick;
  btnDelete.OnClick := ConfirmDelete;
end;

procedure TPauseForm.Init(const ADate: TDate; AStart, AEnd: Integer; Existing: Boolean);
begin
  FDate := ADate;
  FExisting := Existing;
  FDeleted := False;
  if Existing then
    Caption := 'Pause bearbeiten ' + EnDash + ' ' + GermanDateLong(ADate)
  else
    Caption := 'Pause einfügen ' + EnDash + ' ' + GermanDateLong(ADate);
  btnDelete.Visible := Existing;
  dtpStart.Time := MinuteToTime(AStart);
  dtpEnd.Time := MinuteToTime(AEnd);
  UpdateDuration(nil);
end;

function TPauseForm.WasDeleted: Boolean;
begin
  Result := FDeleted;
end;

function TPauseForm.StartMinute: Integer;
begin
  Result := TimeToMinute(dtpStart.Time);
end;

function TPauseForm.EndMinute: Integer;
begin
  Result := TimeToMinute(dtpEnd.Time);
end;

procedure TPauseForm.UpdateDuration(Sender: TObject);
var
  Minutes: Integer;
begin
  Minutes := EndMinute - StartMinute;
  if Minutes <= 0 then
    lblDuration.Caption := 'Dauer: ' + EnDash
  else
    lblDuration.Caption := 'Dauer: ' + FormatHours(Minutes / 60.0) + ' h';
end;

procedure TPauseForm.ConfirmDelete(Sender: TObject);
begin
  if MessageDlg('Die Pause schließen und die Arbeitszeit wieder verbinden?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FDeleted := True;
  ModalResult := mrOk;
end;

procedure TPauseForm.OkClick(Sender: TObject);
begin
  if FDeleted then
  begin
    ModalResult := mrOk;
    Exit;
  end;
  if EndMinute <= StartMinute then
  begin
    MessageDlg('Das Ende muss nach dem Beginn liegen.', mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOk;
end;

procedure TPauseForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

class function TPauseForm.RunRange(AOwner: TComponent; const ADate: TDate;
  AStart, AEnd: Integer; Existing: Boolean): Boolean;
var
  Dlg: TPauseForm;
  Store: TJournalStore;
  Error: string;
  NextStart, NextEnd: Integer;
begin
  Result := False;
  Dlg := TPauseForm.Create(AOwner);
  try
    Dlg.Init(ADate, AStart, AEnd, Existing);
    if Dlg.ShowModal <> mrOk then
      Exit;
    Store := TJournalStore.Instance;
    if Dlg.WasDeleted then
    begin
      if not Store.ClosePause(ADate, AStart, AEnd, Error) then
      begin
        MessageDlg(Error, mtWarning, [mbOK], 0);
        Exit;
      end;
      Exit(True);
    end;
    NextStart := Dlg.StartMinute;
    NextEnd := Dlg.EndMinute;
    if Existing and ((NextStart <> AStart) or (NextEnd <> AEnd)) then
    begin
      if not Store.ClosePause(ADate, AStart, AEnd, Error) then
      begin
        MessageDlg(Error, mtWarning, [mbOK], 0);
        Exit;
      end;
    end;
    if Existing and (NextStart = AStart) and (NextEnd = AEnd) then
      Exit(True);
    if not Store.ApplyPause(ADate, NextStart, NextEnd, Error) then
    begin
      MessageDlg(Error, mtWarning, [mbOK], 0);
      Exit;
    end;
    Result := True;
  finally
    Dlg.Free;
  end;
end;

class function TPauseForm.RunAt(AOwner: TComponent; const ADate: TDate;
  AtMinute: Integer): Boolean;
var
  StartM, EndM: Integer;
  Existing: Boolean;
begin
  StartM := AtMinute;
  EndM := AtMinute + 30;
  Existing := False;
  TJournalStore.Instance.SuggestPause(ADate, AtMinute, StartM, EndM, Existing);
  Result := RunRange(AOwner, ADate, StartM, EndM, Existing);
end;

end.
