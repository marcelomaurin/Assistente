unit professor_catalog;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, fpjson, jsonparser, LazFileUtils;
type
  TAvatarEntry = class
    ID, Name, ModelFile: string;
  end;
  TAvatarCatalog = class
  private
    FItems: TList;
    FRoot, FDiagnostic: string;
    procedure Scan(const Folder: string; Depth: Integer);
    procedure AddModel(const ModelFile, ID, DisplayName: string);
    function GetCount: Integer;
    function GetItem(Index: Integer): TAvatarEntry;
  public
    constructor Create(const Root: string = '');
    destructor Destroy; override;
    procedure Refresh;
    function IndexOfID(const ID: string): Integer;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TAvatarEntry read GetItem; default;
    property Root: string read FRoot;
    property Diagnostic: string read FDiagnostic;
  end;
function AvatarRoot: string;
implementation
function AvatarRoot: string;
var Base: string;
begin
  Base := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Result := Base + 'AVATARES';
  if not DirectoryExists(Result) and DirectoryExists(Base + '..' + PathDelim + 'AVATARES') then
    Result := ExpandFileName(Base + '..' + PathDelim + 'AVATARES');
end;
constructor TAvatarCatalog.Create(const Root: string);
begin
  inherited Create;
  FItems := TList.Create;
  if Root = '' then FRoot := AvatarRoot else FRoot := ExpandFileName(Root);
  Refresh;
end;
destructor TAvatarCatalog.Destroy;
var I: Integer;
begin
  for I := 0 to FItems.Count-1 do TObject(FItems[I]).Free;
  FItems.Free;
  inherited Destroy;
end;
function TAvatarCatalog.GetCount: Integer;
begin Result := FItems.Count; end;
function TAvatarCatalog.GetItem(Index: Integer): TAvatarEntry;
begin Result := TAvatarEntry(FItems[Index]); end;
function TAvatarCatalog.IndexOfID(const ID: string): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to Count-1 do if SameText(Items[I].ID, ID) then Exit(I);
end;
procedure TAvatarCatalog.AddModel(const ModelFile, ID, DisplayName: string);
var I: Integer; E: TAvatarEntry; Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(ModelFile));
  if not (Ext = '.glb') and not (Ext = '.gltf') then Exit;
  if not FileExists(ModelFile) then
  begin FDiagnostic := FDiagnostic + 'Modelo ausente: ' + ModelFile + LineEnding; Exit; end;
  for I := 0 to Count-1 do if SameFileName(Items[I].ModelFile, ModelFile) then Exit;
  if IndexOfID(ID) >= 0 then
  begin FDiagnostic := FDiagnostic + 'ID repetido: ' + ID + LineEnding; Exit; end;
  E := TAvatarEntry.Create;
  E.ModelFile := ExpandFileName(ModelFile);
  E.ID := ID;
  E.Name := DisplayName;
  FItems.Add(E);
end;
procedure TAvatarCatalog.Scan(const Folder: string; Depth: Integer);
var R: TSearchRec; Files, Dirs, Text: TStringList; J: TJSONData;
  I: Integer; FileName, ID, LabelText, Model: string;
begin
  if Depth > 6 then Exit;
  FileName := IncludeTrailingPathDelimiter(Folder) + 'avatar.json';
  if FileExists(FileName) then
  begin
    Text := TStringList.Create;
    try
      try
        Text.LoadFromFile(FileName);
        J := GetJSON(Text.Text);
        try
          if not (J is TJSONObject) then raise Exception.Create('Manifesto deve ser um objeto JSON');
          Model := TJSONObject(J).Get('model', 'modelo.gltf');
          if FilenameIsAbsolute(Model) then raise Exception.Create('Use caminho relativo no manifesto');
          ID := TJSONObject(J).Get('id', ExtractFileName(ExcludeTrailingPathDelimiter(Folder)));
          LabelText := TJSONObject(J).Get('name', ID);
          AddModel(ExpandFileName(IncludeTrailingPathDelimiter(Folder)+Model), ID, LabelText);
        finally J.Free; end;
      except on E: Exception do FDiagnostic := FDiagnostic + FileName + ': ' + E.Message + LineEnding; end;
    finally Text.Free; end;
  end;
  Files := TStringList.Create;
  Dirs := TStringList.Create;
  try
    Files.Sorted := True; Dirs.Sorted := True;
    if FindFirst(IncludeTrailingPathDelimiter(Folder) + '*', faAnyFile, R) = 0 then
    begin
      try repeat
        if (R.Name <> '') and (R.Name[1] <> '.') then
          if (R.Attr and faDirectory) <> 0 then Dirs.Add(R.Name)
          else if SameText(ExtractFileExt(R.Name), '.glb') or SameText(ExtractFileExt(R.Name), '.gltf') then Files.Add(R.Name);
      until FindNext(R) <> 0;
      finally FindClose(R); end;
    end;
    for I := 0 to Files.Count-1 do
    begin
      FileName := IncludeTrailingPathDelimiter(Folder)+Files[I];
      ID := StringReplace(ExtractRelativePath(IncludeTrailingPathDelimiter(FRoot), ChangeFileExt(FileName,'')), PathDelim, '/', [rfReplaceAll]);
      AddModel(FileName, ID, ChangeFileExt(Files[I], ''));
    end;
    for I := 0 to Dirs.Count-1 do Scan(IncludeTrailingPathDelimiter(Folder)+Dirs[I], Depth+1);
  finally Files.Free; Dirs.Free; end;
end;
procedure TAvatarCatalog.Refresh;
var I, P: Integer;
begin
  for I := 0 to Count-1 do TObject(FItems[I]).Free;
  FItems.Clear;
  FDiagnostic := '';
  if DirectoryExists(FRoot) then Scan(FRoot,0)
  else FDiagnostic := 'Pasta AVATARES ausente: ' + FRoot;
  P := IndexOfID('professor');
  if P > 0 then FItems.Exchange(0,P);
end;
end.
