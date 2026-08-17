unit DayPackagesForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.Grids, Journal.Types;

type
  TDayPackagesForm = class(TForm)
    lblSummary: TLabel;
    grdPackages: TStringGrid;
    btnAdd: TButton;
    btnPause: TButton;
    btnEdit: TButton;
    btnDelete: TButton;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    type
      TDayRow = record
        IsPause: Boolean;
        Id: string;
        PauseStart: Integer;
        PauseEnd: Integer;
      end;
    var
    FDate: TDate;
    FRows: TArray<TDayRow>;
    procedure StoreChanged;
    procedure TitlesChanged;
    procedure RefreshGrid;
    procedure UpdateButtons;
    function SelectedId: string;
    function SelectedPause(out StartMinute, EndMinute: Integer): Boolean;
    procedure AddPackage(Sender: TObject);
    procedure AddPause(Sender: TObject);
    procedure EditSelected(Sender: TObject);
    procedure DeleteSelected(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure GridDblClick(Sender: TObject);
    procedure GridClick(Sender: TObject);
    procedure GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
      State: TGridDrawState);
    procedure GridResized(Sender: TObject);
    procedure OpenEditor(const Package: TWorkPackage);
  public
    procedure InitDate(const ADate: TDate);
  end;

implementation

{$R *.dfm}

uses
  System.DateUtils, System.Math, Vcl.Dialogs,   Journal.Store, Journal.TitleCatalog,
  Journal.UiUtil, WorkPackageForm, PauseForm;

procedure TDayPackagesForm.FormCreate(Sender: TObject);
begin
  KeyPreview := True;
  grdPackages.ColCount := 5;
  grdPackages.FixedRows := 1;
  grdPackages.FixedCols := 0;
  grdPackages.DefaultRowHeight := 22;
  EnableGridColumnResize(grdPackages);
  grdPackages.Cells[0, 0] := 'Titel';
  grdPackages.Cells[1, 0] := 'Von';
  grdPackages.Cells[2, 0] := 'Bis';
  grdPackages.Cells[3, 0] := 'Dauer';
  grdPackages.Cells[4, 0] := 'Details';
  ApplyMonoFont(grdPackages);
  btnAdd.OnClick := AddPackage;
  btnPause.OnClick := AddPause;
  btnEdit.OnClick := EditSelected;
  btnDelete.OnClick := DeleteSelected;
  btnClose.OnClick := CloseClick;
  grdPackages.OnDblClick := GridDblClick;
  grdPackages.OnClick := GridClick;
  grdPackages.OnDrawCell := GridDrawCell;
  OnResize := GridResized;
  TJournalStore.Instance.OnChanged.Add(StoreChanged);
  TTitleCatalog.Instance.OnChanged.Add(TitlesChanged);
end;

procedure TDayPackagesForm.FormDestroy(Sender: TObject);
begin
  TJournalStore.Instance.OnChanged.Remove(StoreChanged);
  TTitleCatalog.Instance.OnChanged.Remove(TitlesChanged);
end;

procedure TDayPackagesForm.InitDate(const ADate: TDate);
begin
  FDate := ADate;
  Caption := 'Arbeitspakete ' + EnDash + ' ' + GermanDateLong(ADate);
  RefreshGrid;
end;

procedure TDayPackagesForm.StoreChanged;
begin
  RefreshGrid;
end;

procedure TDayPackagesForm.TitlesChanged;
begin
  RefreshGrid;
end;

procedure TDayPackagesForm.RefreshGrid;
var
  Packages: TArray<TWorkPackage>;
  Pauses: TArray<TPauseInterval>;
  Prev: string;
  PrevPauseStart, PrevPauseEnd: Integer;
  Row, I, J, SelectRow, Count: Integer;
  Pkg: TWorkPackage;
  Pause: TPauseInterval;
  Hours: Double;
  EndText, Summary: string;
  Entry: TDayRow;
begin
  Prev := SelectedId;
  SelectedPause(PrevPauseStart, PrevPauseEnd);
  Packages := TJournalStore.Instance.PackagesForDate(FDate);
  Pauses := TJournalStore.Instance.PausesForDate(FDate);
  Count := Length(Packages) + Length(Pauses);
  SetLength(FRows, Count);
  J := 0;
  for Pkg in Packages do
  begin
    FRows[J].IsPause := False;
    FRows[J].Id := Pkg.Id;
    FRows[J].PauseStart := Pkg.StartMinute;
    FRows[J].PauseEnd := Pkg.EndMinute(FDate);
    Inc(J);
  end;
  for Pause in Pauses do
  begin
    FRows[J].IsPause := True;
    FRows[J].Id := '';
    FRows[J].PauseStart := Pause.StartMinute;
    FRows[J].PauseEnd := Pause.EndMinute;
    Inc(J);
  end;
  for I := 0 to High(FRows) - 1 do
    for J := I + 1 to High(FRows) do
      if FRows[J].PauseStart < FRows[I].PauseStart then
      begin
        Entry := FRows[I];
        FRows[I] := FRows[J];
        FRows[J] := Entry;
      end;

  if Count = 0 then
  begin
    grdPackages.RowCount := 2;
    grdPackages.Rows[1].Clear;
    lblSummary.Caption := 'Keine Arbeitspakete an diesem Tag.';
  end
  else
  begin
    grdPackages.RowCount := Count + 1;
    for I := 0 to High(FRows) do
    begin
      Row := I + 1;
      if FRows[I].IsPause then
      begin
        grdPackages.Cells[0, Row] := 'Pause';
        grdPackages.Cells[1, Row] := MinuteToText(FRows[I].PauseStart);
        grdPackages.Cells[2, Row] := MinuteToText(FRows[I].PauseEnd);
        Hours := Max(0, FRows[I].PauseEnd - FRows[I].PauseStart) / 60.0;
        grdPackages.Cells[3, Row] := FormatHours(Hours);
        grdPackages.Cells[4, Row] := '';
      end
      else
      begin
        Pkg := TJournalStore.Instance.PackageById(FDate, FRows[I].Id);
        if Pkg.Active then
          grdPackages.Cells[0, Row] := '▶ ' + Pkg.Title
        else
          grdPackages.Cells[0, Row] := Pkg.Title;
        grdPackages.Cells[1, Row] := MinuteToText(Pkg.StartMinute);
        EndText := MinuteToText(Pkg.EndMinute(FDate));
        if Pkg.Active then
          EndText := EndText + '  Aktiv';
        grdPackages.Cells[2, Row] := EndText;
        Hours := Max(0, Pkg.EndMinute(FDate) - Pkg.StartMinute) / 60.0;
        grdPackages.Cells[3, Row] := FormatHours(Hours);
        grdPackages.Cells[4, Row] := Pkg.Details;
      end;
    end;
    if Length(Packages) = 1 then
      Summary := '1 Arbeitspaket'
    else
      Summary := Format('%d Arbeitspakete', [Length(Packages)]);
    if Length(Pauses) = 1 then
      Summary := Summary + '  ' + MiddleDot + '  1 Pause'
    else if Length(Pauses) > 1 then
      Summary := Summary + Format('  ' + MiddleDot + '  %d Pausen', [Length(Pauses)]);
    lblSummary.Caption := Summary;
  end;
  SelectRow := -1;
  for I := 0 to High(FRows) do
  begin
    if (Prev <> '') and (not FRows[I].IsPause) and (FRows[I].Id = Prev) then
    begin
      SelectRow := I + 1;
      Break;
    end;
    if (PrevPauseStart >= 0) and FRows[I].IsPause and
       (FRows[I].PauseStart = PrevPauseStart) and (FRows[I].PauseEnd = PrevPauseEnd) then
    begin
      SelectRow := I + 1;
      Break;
    end;
  end;
  if (SelectRow < 0) and (Count > 0) then
    SelectRow := 1;
  if SelectRow >= 1 then
    grdPackages.Row := SelectRow;
  SizeGridColumnsToContent(grdPackages, [0, 1, 2, 3]);
  grdPackages.ColWidths[0] := grdPackages.ColWidths[0] + 16;
  if grdPackages.ColWidths[0] < 120 then
    grdPackages.ColWidths[0] := 120;
  if grdPackages.ColWidths[0] > 240 then
    grdPackages.ColWidths[0] := 240;
  FitGridStretchColumn(grdPackages, 4);
  UpdateButtons;
  grdPackages.Invalidate;
end;

procedure TDayPackagesForm.UpdateButtons;
var
  PauseStart, PauseEnd: Integer;
  HasSel: Boolean;
begin
  HasSel := (SelectedId <> '') or SelectedPause(PauseStart, PauseEnd);
  btnEdit.Enabled := HasSel;
  btnDelete.Enabled := HasSel;
end;

function TDayPackagesForm.SelectedId: string;
var
  Row: Integer;
begin
  Result := '';
  Row := grdPackages.Row;
  if (Row >= 1) and (Row - 1 <= High(FRows)) and (not FRows[Row - 1].IsPause) then
    Result := FRows[Row - 1].Id;
end;

function TDayPackagesForm.SelectedPause(out StartMinute, EndMinute: Integer): Boolean;
var
  Row: Integer;
begin
  Result := False;
  StartMinute := -1;
  EndMinute := -1;
  Row := grdPackages.Row;
  if (Row >= 1) and (Row - 1 <= High(FRows)) and FRows[Row - 1].IsPause then
  begin
    StartMinute := FRows[Row - 1].PauseStart;
    EndMinute := FRows[Row - 1].PauseEnd;
    Result := True;
  end;
end;

procedure TDayPackagesForm.AddPackage(Sender: TObject);
var
  StartM, EndM: Integer;
  Active: Boolean;
  Pkg: TWorkPackage;
begin
  StartM := 8 * 60;
  EndM := 8 * 60 + 30;
  Active := False;
  if SameDate(FDate, Date) then
  begin
    StartM := TimeToMinute(Time);
    EndM := StartM + 30;
    Active := True;
  end;
  StartM := ClampInt(StartM, 0, 23 * 60 + 58);
  EndM := ClampInt(EndM, StartM + 1, 23 * 60 + 59);
  while TJournalStore.Instance.StartMinuteTaken(FDate, StartM) and (StartM < 23 * 60 + 58) do
  begin
    Inc(StartM);
    if EndM <= StartM then
      EndM := StartM + 1;
  end;
  Pkg := Default(TWorkPackage);
  Pkg.Id := NewPackageId;
  Pkg.StartMinute := StartM;
  Pkg.EndMinuteStored := EndM;
  Pkg.Active := Active;
  OpenEditor(Pkg);
end;

procedure TDayPackagesForm.AddPause(Sender: TObject);
var
  AtMinute, PauseStart, PauseEnd: Integer;
  Id: string;
  Pkg: TWorkPackage;
begin
  AtMinute := 12 * 60;
  Id := SelectedId;
  if Id <> '' then
  begin
    Pkg := TJournalStore.Instance.PackageById(FDate, Id);
    if Pkg.Id <> '' then
      AtMinute := (Pkg.StartMinute + Pkg.EndMinute(FDate)) div 2;
  end
  else if SelectedPause(PauseStart, PauseEnd) then
  begin
    TPauseForm.RunRange(Self, FDate, PauseStart, PauseEnd, True);
    Exit;
  end;
  TPauseForm.RunAt(Self, FDate, AtMinute);
end;

procedure TDayPackagesForm.EditSelected(Sender: TObject);
var
  Id: string;
  Pkg: TWorkPackage;
  PauseStart, PauseEnd: Integer;
begin
  if SelectedPause(PauseStart, PauseEnd) then
  begin
    TPauseForm.RunRange(Self, FDate, PauseStart, PauseEnd, True);
    Exit;
  end;
  Id := SelectedId;
  if Id = '' then
    Exit;
  Pkg := TJournalStore.Instance.PackageById(FDate, Id);
  if Pkg.Id = '' then
    Exit;
  OpenEditor(Pkg);
end;

procedure TDayPackagesForm.DeleteSelected(Sender: TObject);
var
  Id, Error: string;
  Pkg: TWorkPackage;
  PauseStart, PauseEnd: Integer;
begin
  if SelectedPause(PauseStart, PauseEnd) then
  begin
    if MessageDlg('Die Pause schließen und die Arbeitszeit wieder verbinden?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
    if not TJournalStore.Instance.ClosePause(FDate, PauseStart, PauseEnd, Error) then
      MessageDlg(Error, mtWarning, [mbOK], 0);
    Exit;
  end;
  Id := SelectedId;
  if Id = '' then
    Exit;
  Pkg := TJournalStore.Instance.PackageById(FDate, Id);
  if Pkg.Id = '' then
    Exit;
  if MessageDlg(Format('Arbeitspaket ' + DQuoteOpen + '%s' + DQuoteClose + ' wirklich l' + #$00F6 + 'schen?', [Pkg.Title]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  TJournalStore.Instance.RemovePackage(FDate, Id, Error);
end;

procedure TDayPackagesForm.OpenEditor(const Package: TWorkPackage);
var
  Dlg: TWorkPackageForm;
  Error: string;
begin
  Dlg := TWorkPackageForm.Create(Self);
  try
    Dlg.Init(FDate, Package);
    if Dlg.ShowModal <> mrOk then
      Exit;
    if Dlg.WasDeleted then
    begin
      TJournalStore.Instance.RemovePackage(FDate, Package.Id, Error);
      Exit;
    end;
    if not TJournalStore.Instance.SavePackage(FDate, Dlg.Package, Error) then
      MessageDlg(Error, mtWarning, [mbOK], 0);
  finally
    Dlg.Free;
  end;
end;

procedure TDayPackagesForm.CloseClick(Sender: TObject);
begin
  ModalResult := mrClose;
end;

procedure TDayPackagesForm.GridDblClick(Sender: TObject);
begin
  EditSelected(Sender);
end;

procedure TDayPackagesForm.GridClick(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TDayPackagesForm.GridResized(Sender: TObject);
begin
  FitGridStretchColumn(grdPackages, 4);
end;

procedure TDayPackagesForm.GridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
  Grid: TStringGrid;
  Color: TColor;
begin
  Grid := grdPackages;
  UseGridFont(Grid);
  if ARow = 0 then
  begin
    Grid.Canvas.Brush.Color := clBtnFace;
    Grid.Canvas.FillRect(Rect);
    DrawPlainText(Grid.Canvas, Rect, Grid.Cells[ACol, ARow], False);
    Exit;
  end;
  if gdSelected in State then
    Grid.Canvas.Brush.Color := clHighlight
  else if (ARow >= 1) and (ARow - 1 <= High(FRows)) and FRows[ARow - 1].IsPause then
    Grid.Canvas.Brush.Color := RGB(236, 236, 228)
  else
    Grid.Canvas.Brush.Color := clWindow;
  Grid.Canvas.FillRect(Rect);
  if gdSelected in State then
    Grid.Canvas.Font.Color := clHighlightText
  else
  begin
    Grid.Canvas.Font.Color := clWindowText;
    if (ACol = 0) and (ARow - 1 <= High(FRows)) and (not FRows[ARow - 1].IsPause) then
    begin
      Color := TTitleCatalog.Instance.ColorFor(
        TJournalStore.Instance.PackageById(FDate, FRows[ARow - 1].Id).Title);
      Grid.Canvas.Brush.Color := Color;
      Grid.Canvas.FillRect(TRect.Create(Rect.Left + 2, Rect.Top + 6, Rect.Left + 14, Rect.Bottom - 6));
      Grid.Canvas.Brush.Color := clWindow;
      if gdSelected in State then
        Grid.Canvas.Brush.Color := clHighlight;
    end;
  end;
  DrawPlainText(Grid.Canvas, Rect, Grid.Cells[ACol, ARow], ACol in [1, 2, 3]);
end;

procedure TDayPackagesForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  PauseStart, PauseEnd: Integer;
begin
  if Key = VK_DELETE then
  begin
    DeleteSelected(Sender);
    Key := 0;
  end
  else if (Key = VK_RETURN) and grdPackages.Focused and
          ((SelectedId <> '') or SelectedPause(PauseStart, PauseEnd)) then
  begin
    EditSelected(Sender);
    Key := 0;
  end;
end;

end.
