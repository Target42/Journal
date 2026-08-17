unit TitlesForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.Dialogs;

type
  TTitlesForm = class(TForm)
    lstTitles: TListBox;
    btnAdd: TButton;
    btnReplace: TButton;
    lblHint: TLabel;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    procedure CatalogChanged;
    procedure RefreshList;
    procedure UpdateButtons;
    function SelectedTitle: string;
    procedure AddTitle(Sender: TObject);
    procedure ReplaceTitle(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure ListClick(Sender: TObject);
    procedure ListDblClick(Sender: TObject);
    procedure ListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
      State: TOwnerDrawState);
  end;

implementation

{$R *.dfm}

uses
  Journal.TitleCatalog, Journal.Store, Journal.Types, Journal.UiUtil;

procedure TTitlesForm.FormCreate(Sender: TObject);
begin
  lstTitles.Style := lbOwnerDrawFixed;
  lstTitles.ItemHeight := 22;
  lstTitles.OnDrawItem := ListDrawItem;
  lstTitles.OnClick := ListClick;
  lstTitles.OnDblClick := ListDblClick;
  btnAdd.OnClick := AddTitle;
  btnReplace.OnClick := ReplaceTitle;
  btnClose.OnClick := CloseClick;
  TTitleCatalog.Instance.OnChanged.Add(CatalogChanged);
  RefreshList;
end;

procedure TTitlesForm.FormDestroy(Sender: TObject);
begin
  TTitleCatalog.Instance.OnChanged.Remove(CatalogChanged);
end;

procedure TTitlesForm.CatalogChanged;
begin
  RefreshList;
end;

procedure TTitlesForm.RefreshList;
var
  Current: string;
  Titles: TArray<TPackageTitle>;
  I, Select: Integer;
begin
  Current := SelectedTitle;
  lstTitles.Items.BeginUpdate;
  try
    lstTitles.Items.Clear;
    Titles := TTitleCatalog.Instance.Titles;
    Select := -1;
    for I := 0 to High(Titles) do
    begin
      lstTitles.Items.Add(Titles[I].Title);
      if (Current <> '') and AnsiSameText(Titles[I].Title, Current) then
        Select := I;
    end;
    if Select >= 0 then
      lstTitles.ItemIndex := Select;
  finally
    lstTitles.Items.EndUpdate;
  end;
  UpdateButtons;
end;

procedure TTitlesForm.UpdateButtons;
begin
  btnReplace.Enabled := SelectedTitle <> '';
end;

function TTitlesForm.SelectedTitle: string;
begin
  Result := '';
  if lstTitles.ItemIndex >= 0 then
    Result := lstTitles.Items[lstTitles.ItemIndex];
end;

procedure TTitlesForm.AddTitle(Sender: TObject);
var
  Title: string;
  Color: TColor;
  CD: TColorDialog;
begin
  Title := '';
  if not InputQuery('Titel hinzufügen', 'Titel:', Title) then
    Exit;
  Title := Trim(Title);
  if Title = '' then
  begin
    MessageDlg('Bitte einen Titel eingeben.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if TTitleCatalog.Instance.Contains(Title) then
  begin
    MessageDlg(Format('Der Titel ' + DQuoteOpen + '%s' + DQuoteClose + ' ist bereits in der Liste.',
      [TTitleCatalog.Instance.CanonicalTitle(Title)]), mtWarning, [mbOK], 0);
    Exit;
  end;
  Color := TTitleCatalog.Instance.NextUnusedColor;
  CD := TColorDialog.Create(Self);
  try
    CD.Color := Color;
    if CD.Execute then
      Color := CD.Color;
  finally
    CD.Free;
  end;
  TTitleCatalog.Instance.Upsert(Title, Color);
  RefreshList;
  lstTitles.ItemIndex := lstTitles.Items.IndexOf(TTitleCatalog.Instance.CanonicalTitle(Title));
end;

procedure TTitlesForm.ReplaceTitle(Sender: TObject);
var
  FromTitle, Typed, CanonicalTo, Error: string;
  Merges: Boolean;
  KeepColor: TColor;
  Dlg: TForm;
  Lbl: TLabel;
  Combo: TComboBox;
  BtnOk, BtnCancel: TButton;
  Entry: TPackageTitle;
begin
  FromTitle := SelectedTitle;
  if FromTitle = '' then
    Exit;
  Dlg := TForm.Create(Self);
  try
    Dlg.Caption := 'Titel ersetzen';
    Dlg.BorderStyle := bsDialog;
    Dlg.Position := poOwnerFormCenter;
    Dlg.ClientWidth := 420;
    Dlg.ClientHeight := 160;
    Dlg.Font.Assign(Font);
    Lbl := TLabel.Create(Dlg);
    Lbl.Parent := Dlg;
    Lbl.Left := 16;
    Lbl.Top := 20;
    Lbl.Caption := 'Bisher: ' + FromTitle;
    Combo := TComboBox.Create(Dlg);
    Combo.Parent := Dlg;
    Combo.Left := 16;
    Combo.Top := 48;
    Combo.Width := 388;
    for Entry in TTitleCatalog.Instance.Titles do
      Combo.Items.Add(Entry.Title);
    Combo.ItemIndex := -1;
    Combo.Text := '';
    BtnOk := TButton.Create(Dlg);
    BtnOk.Parent := Dlg;
    BtnOk.Left := 228;
    BtnOk.Top := 116;
    BtnOk.Caption := 'Ersetzen';
    BtnOk.Default := True;
    BtnOk.ModalResult := mrOk;
    BtnCancel := TButton.Create(Dlg);
    BtnCancel.Parent := Dlg;
    BtnCancel.Left := 324;
    BtnCancel.Top := 116;
    BtnCancel.Caption := 'Abbrechen';
    BtnCancel.Cancel := True;
    BtnCancel.ModalResult := mrCancel;
    if Dlg.ShowModal <> mrOk then
      Exit;
    Typed := Trim(Combo.Text);
  finally
    Dlg.Free;
  end;
  if Typed = '' then
  begin
    MessageDlg('Bitte einen neuen Titel eingeben oder auswählen.', mtWarning, [mbOK], 0);
    Exit;
  end;
  Merges := TTitleCatalog.Instance.Contains(Typed) and
    (TTitleCatalog.Instance.CanonicalTitle(Typed) <> FromTitle);
  if Merges then
    CanonicalTo := TTitleCatalog.Instance.CanonicalTitle(Typed)
  else
    CanonicalTo := Typed;
  if CanonicalTo = FromTitle then
    Exit;
  if MessageDlg(Format('Alle Arbeitspakete mit dem Titel ' + DQuoteOpen + '%s' + DQuoteClose +
    ' in ' + DQuoteOpen + '%s' + DQuoteClose + ' umbenennen?' + sLineBreak +
    'Der bisherige Titel entfällt aus der Liste.', [FromTitle, CanonicalTo]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  if Merges then
    KeepColor := TTitleCatalog.Instance.ColorFor(CanonicalTo)
  else
    KeepColor := TTitleCatalog.Instance.ColorFor(FromTitle);
  if not TJournalStore.Instance.RenameTitle(FromTitle, CanonicalTo, Error) then
  begin
    if Error = '' then
      Error := 'Die Arbeitspakete konnten nicht umbenannt werden.';
    MessageDlg(Error, mtWarning, [mbOK], 0);
    Exit;
  end;
  if not TTitleCatalog.Instance.Rename(FromTitle, CanonicalTo) then
    TTitleCatalog.Instance.Upsert(CanonicalTo, KeepColor);
  RefreshList;
  lstTitles.ItemIndex := lstTitles.Items.IndexOf(CanonicalTo);
end;

procedure TTitlesForm.CloseClick(Sender: TObject);
begin
  ModalResult := mrClose;
end;

procedure TTitlesForm.ListClick(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TTitlesForm.ListDblClick(Sender: TObject);
begin
  ReplaceTitle(Sender);
end;

procedure TTitlesForm.ListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  Color: TColor;
begin
  if odSelected in State then
    lstTitles.Canvas.Brush.Color := clHighlight
  else
    lstTitles.Canvas.Brush.Color := clWindow;
  lstTitles.Canvas.FillRect(Rect);
  if Index < 0 then
    Exit;
  Color := TTitleCatalog.Instance.ColorFor(lstTitles.Items[Index]);
  lstTitles.Canvas.Brush.Color := Color;
  lstTitles.Canvas.FillRect(TRect.Create(Rect.Left + 4, Rect.Top + 5, Rect.Left + 16, Rect.Bottom - 5));
  if odSelected in State then
  begin
    lstTitles.Canvas.Brush.Color := clHighlight;
    lstTitles.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    lstTitles.Canvas.Brush.Color := clWindow;
    lstTitles.Canvas.Font.Color := clWindowText;
  end;
  lstTitles.Canvas.TextOut(Rect.Left + 22, Rect.Top + 3, lstTitles.Items[Index]);
end;

end.
