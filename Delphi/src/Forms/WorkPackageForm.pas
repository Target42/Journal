unit WorkPackageForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  Journal.Types;

type
  TWorkPackageForm = class(TForm)
    lblTitel: TLabel;
    cbTitle: TComboBox;
    btnColor: TButton;
    lblDetails: TLabel;
    memDetails: TMemo;
    lblVon: TLabel;
    dtpStart: TDateTimePicker;
    lblBis: TLabel;
    dtpEnd: TDateTimePicker;
    chkActive: TCheckBox;
    btnOk: TButton;
    btnCancel: TButton;
    btnDelete: TButton;
    dlgColor: TColorDialog;
    procedure FormCreate(Sender: TObject);
  private
    FDate: TDate;
    FPackage: TWorkPackage;
    FIsNew: Boolean;
    FDeleted: Boolean;
    FColor: TColor;
    procedure PopulateTitles;
    procedure ApplyTitleColor(Sender: TObject);
    procedure ChooseColor(Sender: TObject);
    procedure UpdateColorButton;
    procedure UpdateActiveUi(Sender: TObject);
    procedure ConfirmDelete(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
  public
    procedure Init(const ADate: TDate; const APackage: TWorkPackage);
    function Package: TWorkPackage;
    function WasDeleted: Boolean;
  end;

implementation

{$R *.dfm}

uses
  Journal.Store, Journal.TitleCatalog, Journal.UiUtil, System.DateUtils;

procedure TWorkPackageForm.FormCreate(Sender: TObject);
begin
  cbTitle.OnChange := ApplyTitleColor;
  btnColor.OnClick := ChooseColor;
  chkActive.OnClick := UpdateActiveUi;
  btnOk.OnClick := OkClick;
  btnCancel.OnClick := CancelClick;
  btnDelete.OnClick := ConfirmDelete;
end;

procedure TWorkPackageForm.Init(const ADate: TDate; const APackage: TWorkPackage);
begin
  FDate := ADate;
  FPackage := APackage;
  FIsNew := Trim(APackage.Title) = '';
  FDeleted := False;
  FColor := TTitleCatalog.Instance.NextUnusedColor;
  if FIsNew then
    Caption := 'Neues Arbeitspaket ' + EnDash + ' ' + GermanDateLong(ADate)
  else
  begin
    Caption := 'Arbeitspaket bearbeiten ' + EnDash + ' ' + GermanDateLong(ADate);
    FColor := TTitleCatalog.Instance.ColorFor(APackage.Title);
  end;
  btnDelete.Visible := not FIsNew;
  memDetails.Text := APackage.Details;
  if APackage.StartMinute > 0 then
    dtpStart.Time := MinuteToTime(APackage.StartMinute)
  else
    dtpStart.Time := EncodeTime(8, 0, 0, 0);
  if APackage.EndMinuteStored > 0 then
    dtpEnd.Time := MinuteToTime(APackage.EndMinuteStored)
  else
    dtpEnd.Time := EncodeTime(8, 30, 0, 0);
  chkActive.Enabled := SameDate(ADate, Date);
  chkActive.Checked := APackage.Active and SameDate(ADate, Date);
  if SameDate(ADate, Date) then
    chkActive.Hint := 'Solange das Paket aktiv ist, läuft das Ende mit der Uhrzeit mit.'
  else
    chkActive.Hint := 'Aktiv kann nur am heutigen Tag gesetzt werden.';
  PopulateTitles;
  UpdateColorButton;
  UpdateActiveUi(nil);
end;

procedure TWorkPackageForm.PopulateTitles;
var
  Current: string;
  Titles: TArray<TPackageTitle>;
  Entry: TPackageTitle;
  Idx: Integer;
begin
  Current := FPackage.Title;
  cbTitle.Items.BeginUpdate;
  try
    cbTitle.Items.Clear;
    Titles := TTitleCatalog.Instance.Titles;
    for Entry in Titles do
      cbTitle.Items.Add(Entry.Title);
  finally
    cbTitle.Items.EndUpdate;
  end;
  if Current <> '' then
  begin
    Idx := cbTitle.Items.IndexOf(Current);
    if Idx >= 0 then
      cbTitle.ItemIndex := Idx
    else
      cbTitle.Text := Current;
  end
  else
  begin
    cbTitle.ItemIndex := -1;
    cbTitle.Text := '';
  end;
end;

procedure TWorkPackageForm.ApplyTitleColor(Sender: TObject);
var
  Title: string;
begin
  Title := cbTitle.Text;
  if TTitleCatalog.Instance.Contains(Title) then
  begin
    FColor := TTitleCatalog.Instance.ColorFor(Title);
    UpdateColorButton;
  end;
end;

procedure TWorkPackageForm.ChooseColor(Sender: TObject);
begin
  dlgColor.Color := FColor;
  if dlgColor.Execute then
  begin
    FColor := dlgColor.Color;
    UpdateColorButton;
  end;
end;

procedure TWorkPackageForm.UpdateColorButton;
begin
  btnColor.Font.Color := FColor;
  btnColor.Font.Style := [fsBold];
  btnColor.Caption := 'Farbe';
end;

procedure TWorkPackageForm.UpdateActiveUi(Sender: TObject);
begin
  dtpEnd.Enabled := not chkActive.Checked;
  if chkActive.Checked then
    dtpEnd.Time := MinuteToTime(TimeToMinute(Time));
end;

procedure TWorkPackageForm.ConfirmDelete(Sender: TObject);
var
  Title: string;
begin
  Title := Trim(cbTitle.Text);
  if Title = '' then
    Title := '(ohne Titel)';
  if MessageDlg(Format('Arbeitspaket ' + DQuoteOpen + '%s' + DQuoteClose + ' wirklich l' + #$00F6 + 'schen?', [Title]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FDeleted := True;
  ModalResult := mrOk;
end;

procedure TWorkPackageForm.OkClick(Sender: TObject);
var
  Title: string;
  StartM, EndM: Integer;
  Active: Boolean;
begin
  if FDeleted then
  begin
    ModalResult := mrOk;
    Exit;
  end;
  Title := Trim(cbTitle.Text);
  if Title = '' then
  begin
    MessageDlg('Bitte einen Titel eingeben oder auswählen.', mtWarning, [mbOK], 0);
    Exit;
  end;
  StartM := TimeToMinute(dtpStart.Time);
  Active := chkActive.Checked;
  if Active then
    EndM := TimeToMinute(Time)
  else
    EndM := TimeToMinute(dtpEnd.Time);
  if (not Active) and (EndM <= StartM) then
  begin
    MessageDlg('Das Ende muss nach dem Start liegen.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if Active and (TimeToMinute(Time) < StartM) then
  begin
    MessageDlg('Ein aktives Arbeitspaket darf nicht in der Zukunft beginnen.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if TJournalStore.Instance.StartMinuteTaken(FDate, StartM, FPackage.Id) then
  begin
    MessageDlg('Ein anderes Arbeitspaket beginnt bereits in derselben Minute.', mtWarning, [mbOK], 0);
    Exit;
  end;
  TTitleCatalog.Instance.Upsert(Title, FColor);
  FPackage.Title := TTitleCatalog.Instance.CanonicalTitle(Title);
  FPackage.Details := Trim(memDetails.Text);
  FPackage.StartMinute := StartM;
  FPackage.EndMinuteStored := EndM;
  FPackage.Active := Active;
  ModalResult := mrOk;
end;

procedure TWorkPackageForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

function TWorkPackageForm.Package: TWorkPackage;
begin
  Result := FPackage;
end;

function TWorkPackageForm.WasDeleted: Boolean;
begin
  Result := FDeleted;
end;

end.
