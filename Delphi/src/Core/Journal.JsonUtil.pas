unit Journal.JsonUtil;

interface

uses
  System.SysUtils, System.JSON, System.Classes;

function JsonStr(Obj: TJSONObject; const Name: string; const Default: string = ''): string;
function JsonInt(Obj: TJSONObject; const Name: string; Default: Integer = 0): Integer;
function JsonFloat(Obj: TJSONObject; const Name: string; Default: Double = 0): Double;
function JsonBool(Obj: TJSONObject; const Name: string; Default: Boolean = False): Boolean;
function JsonObj(Obj: TJSONObject; const Name: string): TJSONObject;
function JsonArr(Obj: TJSONObject; const Name: string): TJSONArray;
function LoadJsonFile(const Path: string): TJSONValue;
procedure SaveJsonFile(const Path: string; Value: TJSONValue);
procedure WriteUtf8File(const Path, Text: string);
function ReadUtf8File(const Path: string): string;

implementation

uses
  System.IOUtils;

function JsonStr(Obj: TJSONObject; const Name: string; const Default: string): string;
var
  V: TJSONValue;
begin
  Result := Default;
  if Obj = nil then
    Exit;
  V := Obj.Values[Name];
  if V <> nil then
    Result := V.Value;
end;

function JsonInt(Obj: TJSONObject; const Name: string; Default: Integer): Integer;
var
  V: TJSONValue;
begin
  Result := Default;
  if Obj = nil then
    Exit;
  V := Obj.Values[Name];
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsInt;
end;

function JsonFloat(Obj: TJSONObject; const Name: string; Default: Double): Double;
var
  V: TJSONValue;
begin
  Result := Default;
  if Obj = nil then
    Exit;
  V := Obj.Values[Name];
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsDouble;
end;

function JsonBool(Obj: TJSONObject; const Name: string; Default: Boolean): Boolean;
var
  V: TJSONValue;
begin
  Result := Default;
  if Obj = nil then
    Exit;
  V := Obj.Values[Name];
  if V is TJSONBool then
    Result := TJSONBool(V).AsBoolean
  else if V is TJSONTrue then
    Result := True
  else if V is TJSONFalse then
    Result := False;
end;

function JsonObj(Obj: TJSONObject; const Name: string): TJSONObject;
var
  V: TJSONValue;
begin
  Result := nil;
  if Obj = nil then
    Exit;
  V := Obj.Values[Name];
  if V is TJSONObject then
    Result := TJSONObject(V);
end;

function JsonArr(Obj: TJSONObject; const Name: string): TJSONArray;
var
  V: TJSONValue;
begin
  Result := nil;
  if Obj = nil then
    Exit;
  V := Obj.Values[Name];
  if V is TJSONArray then
    Result := TJSONArray(V);
end;

function ReadUtf8File(const Path: string): string;
var
  Bytes: TBytes;
begin
  Bytes := TFile.ReadAllBytes(Path);
  Result := TEncoding.UTF8.GetString(Bytes);
end;

procedure WriteUtf8File(const Path, Text: string);
var
  Bytes: TBytes;
begin
  ForceDirectories(ExtractFileDir(Path));
  Bytes := TEncoding.UTF8.GetBytes(Text);
  TFile.WriteAllBytes(Path, Bytes);
end;

function LoadJsonFile(const Path: string): TJSONValue;
begin
  Result := nil;
  if not TFile.Exists(Path) then
    Exit;
  Result := TJSONObject.ParseJSONValue(ReadUtf8File(Path));
end;

procedure SaveJsonFile(const Path: string; Value: TJSONValue);
begin
  if Value = nil then
    Exit;
  WriteUtf8File(Path, Value.Format(2));
end;

end.
