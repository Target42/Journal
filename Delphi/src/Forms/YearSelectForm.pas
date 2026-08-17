unit YearSelectForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.NumberBox, Vcl.ExtCtrls;

type
  TYearSelectForm = class(TForm)
    lblJahr: TLabel;
    nbYear: TNumberBox;
    lblHint: TLabel;
    btnDownload: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  private
    procedure DownloadClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
  public
    function SelectedYear: Integer;
  end;

implementation

{$R *.dfm}

procedure TYearSelectForm.FormCreate(Sender: TObject);
begin
  btnDownload.OnClick := DownloadClick;
  btnCancel.OnClick := CancelClick;
  nbYear.SetFocus;
end;

procedure TYearSelectForm.DownloadClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TYearSelectForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

function TYearSelectForm.SelectedYear: Integer;
begin
  Result := Trunc(nbYear.Value);
end;

end.
