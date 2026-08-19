unit TermineForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls;

type
  TTermineForm = class(TForm)
    lstTermine: TListBox;
    btnAdd: TButton;
    btnEdit: TButton;
    btnDelete: TButton;
    lblHint: TLabel;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FIds: TStringList;
    procedure CatalogChanged;
    procedure RefreshList;
    procedure UpdateButtons;
    function SelectedId: string;
    procedure AddAppointment(Sender: TObject);
    procedure EditAppointment(Sender: TObject);
    procedure DeleteAppointment(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure ListClick(Sender: TObject);
    procedure ListDblClick(Sender: TObject);
  end;

implementation

{$R *.dfm}

uses
  Vcl.Dialogs, Journal.Appointments, Journal.Types, TerminEditForm;

procedure TTermineForm.FormCreate(Sender: TObject);
begin
  FIds := TStringList.Create;
  lstTermine.OnClick := ListClick;
  lstTermine.OnDblClick := ListDblClick;
  btnAdd.OnClick := AddAppointment;
  btnEdit.OnClick := EditAppointment;
  btnDelete.OnClick := DeleteAppointment;
  btnClose.OnClick := CloseClick;
  TAppointmentCatalog.Instance.OnChanged.Add(CatalogChanged);
  RefreshList;
end;

procedure TTermineForm.FormDestroy(Sender: TObject);
begin
  TAppointmentCatalog.Instance.OnChanged.Remove(CatalogChanged);
  FIds.Free;
end;

procedure TTermineForm.CatalogChanged;
begin
  RefreshList;
end;

procedure TTermineForm.RefreshList;
var
  Current: string;
  Items: TArray<TAppointment>;
  I, Select: Integer;
begin
  Current := SelectedId;
  lstTermine.Items.BeginUpdate;
  try
    lstTermine.Items.Clear;
    FIds.Clear;
    Items := TAppointmentCatalog.Instance.All;
    Select := -1;
    for I := 0 to High(Items) do
    begin
      lstTermine.Items.Add(Items[I].Summary);
      FIds.Add(Items[I].Id);
      if (Current <> '') and (Items[I].Id = Current) then
        Select := I;
    end;
    if Select >= 0 then
      lstTermine.ItemIndex := Select;
  finally
    lstTermine.Items.EndUpdate;
  end;
  UpdateButtons;
end;

procedure TTermineForm.UpdateButtons;
begin
  btnEdit.Enabled := SelectedId <> '';
  btnDelete.Enabled := SelectedId <> '';
end;

function TTermineForm.SelectedId: string;
begin
  Result := '';
  if (lstTermine.ItemIndex >= 0) and (lstTermine.ItemIndex < FIds.Count) then
    Result := FIds[lstTermine.ItemIndex];
end;

procedure TTermineForm.AddAppointment(Sender: TObject);
begin
  TTerminEditForm.RunNew(Self);
end;

procedure TTermineForm.EditAppointment(Sender: TObject);
var
  Id: string;
  Apt: TAppointment;
begin
  Id := SelectedId;
  if Id = '' then
    Exit;
  Apt := TAppointmentCatalog.Instance.ById(Id);
  if Apt.Id = '' then
    Exit;
  TTerminEditForm.RunEdit(Self, Apt);
end;

procedure TTermineForm.DeleteAppointment(Sender: TObject);
var
  Id: string;
  Apt: TAppointment;
begin
  Id := SelectedId;
  if Id = '' then
    Exit;
  Apt := TAppointmentCatalog.Instance.ById(Id);
  if MessageDlg('Den Termin ' + DQuoteOpen + Apt.Title + DQuoteClose + ' l' +
    #$00F6 + 'schen?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  TAppointmentCatalog.Instance.Remove(Id);
end;

procedure TTermineForm.CloseClick(Sender: TObject);
begin
  ModalResult := mrClose;
end;

procedure TTermineForm.ListClick(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TTermineForm.ListDblClick(Sender: TObject);
begin
  EditAppointment(Sender);
end;

end.
