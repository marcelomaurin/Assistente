unit presentation_package;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, fpjson, jsonparser, zipper, presentation_paths, professor_commands, presentation_tags;
const PVAMaxFile = 64*1024*1024; PVAMaxTotal = 256*1024*1024; PVAMaxEntries = 256;
type
  TPVAPackage = class
  private
    FFiles: TStringList;
    FTotal: Int64;
    procedure CreateStream(Sender: TObject; var AStream: TStream; Item: TFullZipFileEntry);
    procedure DoneStream(Sender: TObject; var AStream: TStream; Item: TFullZipFileEntry);
    function Data(const Name: string): TMemoryStream;
    procedure CheckManifest;
  public
    Script: string;
    constructor Create;
    destructor Destroy; override;
    procedure Load(const FileName: string);
    procedure ExportFile(const FileName, Source, AssetRoot: string);
    procedure ExtractTo(const NewDirectory: string);
    function Count: Integer;
    function NameAt(Index: Integer): string;
  end;
function PresentationSHA256(Stream: TMemoryStream): string;
procedure WriteUTF8(const FileName, Text: string);
function ReadUTF8(const FileName: string): string;
implementation
uses Windows, presentation_document;
type
  TBoundedStream = class(TMemoryStream)
    function Write(const Buffer; N: LongInt): LongInt; override;
  end;
function BCryptOpenAlgorithmProvider(out Handle: Pointer; Alg, Impl: PWideChar; Flags: LongWord): LongInt; stdcall; external 'bcrypt.dll';
function BCryptHash(Handle: Pointer; Secret: Pointer; SecretSize: LongWord; Input: Pointer; InputSize: LongWord; Output: Pointer; OutputSize: LongWord): LongInt; stdcall; external 'bcrypt.dll';
function BCryptCloseAlgorithmProvider(Handle: Pointer; Flags: LongWord): LongInt; stdcall; external 'bcrypt.dll';
function TBoundedStream.Write(const Buffer; N: LongInt): LongInt;
begin
  if (N<0) or (Position+N>PVAMaxFile) then raise Exception.Create('Recurso excede 64 MiB');
  Result:=inherited Write(Buffer,N);
end;
function PresentationSHA256(Stream: TMemoryStream): string;
var H: Pointer; Digest: array[0..31] of Byte; I: Integer;
begin
  if BCryptOpenAlgorithmProvider(H,'SHA256',nil,0)<>0 then raise Exception.Create('SHA256 indisponivel');
  try
    if BCryptHash(H,nil,0,Stream.Memory,Stream.Size,@Digest,32)<>0 then raise Exception.Create('Falha SHA256');
    Result:='';for I:=0 to 31 do Result:=Result+LowerCase(IntToHex(Digest[I],2));
  finally BCryptCloseAlgorithmProvider(H,0);end;
end;
procedure WriteUTF8(const FileName, Text: string);
var F: TFileStream;
begin
  F:=TFileStream.Create(FileName,fmCreate);
  try if Text<>'' then F.WriteBuffer(Text[1],Length(Text));finally F.Free;end;
end;
function ReadUTF8(const FileName: string): string;
var F: TFileStream;
begin
  F:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  try
    if F.Size>1024*1024 then raise Exception.Create('Roteiro excede 1 MiB');
    SetLength(Result,F.Size);if F.Size>0 then F.ReadBuffer(Result[1],F.Size);
  finally F.Free;end;
end;
constructor TPVAPackage.Create;
begin
  inherited Create;FFiles:=TStringList.Create;FFiles.CaseSensitive:=False;
end;
destructor TPVAPackage.Destroy;
var I: Integer;
begin
  for I:=0 to FFiles.Count-1 do FFiles.Objects[I].Free;
  FFiles.Free;inherited Destroy;
end;
function TPVAPackage.Count: Integer;
begin Result:=FFiles.Count;end;
function TPVAPackage.NameAt(Index: Integer): string;
begin Result:=FFiles[Index];end;
function TPVAPackage.Data(const Name: string): TMemoryStream;
var I: Integer;
begin
  I:=FFiles.IndexOf(Name);
  if (I<0) or (FFiles[I]<>Name) then raise Exception.Create('Recurso ausente: '+Name);
  Result:=TMemoryStream(FFiles.Objects[I]);
end;
procedure TPVAPackage.CreateStream(Sender: TObject; var AStream: TStream; Item: TFullZipFileEntry);
var Name: string;
begin
  Name:=Item.ArchiveFileName;
  if not SafePresentationPath(Name) or Item.IsDirectory or Item.IsLink or
    ((Item.BitFlags and 1)<>0) or not (Item.CompressMethod in [0,8]) then
    raise Exception.Create('Entrada ZIP proibida: '+Name);
  if (Item.Size<0) or (Item.Size>PVAMaxFile) or (FTotal+Item.Size>PVAMaxTotal) or
    (FFiles.Count>=PVAMaxEntries) or (FFiles.IndexOf(Name)>=0) then
    raise Exception.Create('ZIP excede limites ou tem nomes duplicados');
  AStream:=TBoundedStream.Create;
  FFiles.AddObject(Name,AStream);
end;
procedure TPVAPackage.DoneStream(Sender: TObject; var AStream: TStream; Item: TFullZipFileEntry);
begin
  if AStream=nil then Exit;
  if AStream.Size<>Item.Size then raise Exception.Create('Tamanho ZIP incorreto');
  Inc(FTotal,AStream.Size);
  AStream:=nil; // package owns the bounded stream, including error cleanup
end;
procedure TPVAPackage.CheckManifest;
var J: TJSONData; O,F: TJSONObject; A: TJSONArray; I,K: Integer; M: TMemoryStream;
  S,N: string; Seen: TStringList; Steps: TAvatarScript;
begin
  M:=Data('manifest.json');
  if M.Size>1024*1024 then raise Exception.Create('Manifesto grande demais');
  SetLength(S,M.Size);if M.Size>0 then Move(M.Memory^,S[1],M.Size);
  J:=GetJSON(S);
  Seen:=TStringList.Create;
  try
    if not (J is TJSONObject) then raise Exception.Create('Manifesto invalido');
    O:=TJSONObject(J);
    if (O.Get('format','')<>'pva') or (O.Get('version',0)<>1) or
      (O.Get('script','')<>'script.txt') or (O.Get('hash','')<>'sha256') then
      raise Exception.Create('Formato ou versao PVA nao suportada');
    A:=O.Arrays['files'];
    if A.Count<>FFiles.Count-1 then raise Exception.Create('Inventario divergente');
    Seen.CaseSensitive:=False;
    for I:=0 to A.Count-1 do begin
      if not (A[I] is TJSONObject) then raise Exception.Create('Inventario invalido');
      F:=TJSONObject(A[I]);N:=F.Get('path','');
      if (N='manifest.json') or not SafePresentationPath(N) or (Seen.IndexOf(N)>=0) then raise Exception.Create('Inventario duplicado/invalido');
      Seen.Add(N);M:=Data(N);
      if (F.Get('size',Int64(-1))<>M.Size) or (F.Get('sha256','')<>PresentationSHA256(M)) then
        raise Exception.Create('Integridade invalida: '+N);
      if (N<>'script.txt') and ((Copy(N,1,7)<>'assets/') or not SupportedPresentationMedia(N)) then
        raise Exception.Create('Recurso nao suportado: '+N);
    end;
    M:=Data('script.txt');if M.Size>1024*1024 then raise Exception.Create('Roteiro grande demais');
    SetLength(Script,M.Size);if M.Size>0 then Move(M.Memory^,Script[1],M.Size);
    if not ValidPresentationUTF8(Script) then raise Exception.Create('Roteiro nao e UTF-8');
    ValidatePresentationScript(Script);
    Steps:=ParseAvatarScript(Script,4096);
    for K:=0 to High(Steps.Steps) do
      if Steps.Steps[K].Presentation.Action=paOpenFile then begin
        N:=Steps.Steps[K].Presentation.Argument;
        if Copy(N,1,7)<>'assets/' then raise Exception.Create('Midia fora de assets/');
        Data(N);
      end;
  finally Seen.Free;J.Free;end;
end;
procedure TPVAPackage.Load(const FileName: string);
var U: TUnZipper; F: TFileStream; I: Integer; Sum: Int64; E: TFullZipFileEntry; Names: TStringList;
begin
  if FFiles.Count<>0 then raise Exception.Create('Pacote ja carregado');
  F:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  try if F.Size>PVAMaxTotal then raise Exception.Create('ZIP grande demais');finally F.Free;end;
  U:=TUnZipper.Create;Names:=TStringList.Create;
  try
    U.FileName:=FileName;U.UseUTF8:=True;U.Examine;Sum:=0;Names.CaseSensitive:=False;
    if (U.Entries.Count<2) or (U.Entries.Count>PVAMaxEntries) then raise Exception.Create('Quantidade de entradas invalida');
    for I:=0 to U.Entries.Count-1 do begin
      E:=U.Entries[I];
      if not SafePresentationPath(E.ArchiveFileName) or E.IsLink or E.IsDirectory or
        (E.Size<0) or (E.Size>PVAMaxFile) or (Names.IndexOf(E.ArchiveFileName)>=0) then raise Exception.Create('Diretorio ZIP invalido');
      Inc(Sum,E.Size);if Sum>PVAMaxTotal then raise Exception.Create('ZIP expandido excede 256 MiB');
      Names.Add(E.ArchiveFileName);
    end;
    U.OnCreateStream:=@CreateStream;U.OnDoneStream:=@DoneStream;U.UnZipAllFiles;
    CheckManifest;
  finally Names.Free;U.Free;end;
end;
procedure TPVAPackage.ExportFile(const FileName, Source, AssetRoot: string);
var Z: TZipper; O,F: TJSONObject; A: TJSONArray; Steps: TAvatarScript;
  I: Integer; N,P: string; M: TMemoryStream; Manifest: TStringStream; SourceFile: TFileStream;
  procedure AddMemory(const Name, Text: string);
  var S: TMemoryStream;
  begin
    S:=TMemoryStream.Create;if Text<>'' then S.WriteBuffer(Text[1],Length(Text));
    S.Position:=0;FFiles.AddObject(Name,S);
  end;
begin
  if FFiles.Count<>0 then raise Exception.Create('Use um pacote novo');
  if Length(Source)>1024*1024 then raise Exception.Create('Roteiro excede limite');
  ValidatePresentationScript(Source);
  Script:=Source;AddMemory('script.txt',Source);
  Steps:=ParseAvatarScript(Source,4096);
  for I:=0 to High(Steps.Steps) do if Steps.Steps[I].Presentation.Action=paOpenFile then begin
    N:=Steps.Steps[I].Presentation.Argument;
    if not SafePresentationPath(N) or (Copy(N,1,7)<>'assets/') then raise Exception.Create('Caminho invalido: '+N);
    if FFiles.IndexOf(N)>=0 then begin
      if FFiles[FFiles.IndexOf(N)]<>N then raise Exception.Create('Referencia com maiusculas divergentes: '+N);
      Continue;
    end;
    P:=IncludeTrailingPathDelimiter(AssetRoot)+StringReplace(N,'/',PathDelim,[rfReplaceAll]);
    SourceFile:=TFileStream.Create(P,fmOpenRead or fmShareDenyWrite);
    try
      if SourceFile.Size>PVAMaxFile then raise Exception.Create('Recurso excede 64 MiB');
      Inc(FTotal,SourceFile.Size);
      if (FTotal+Length(Source)>PVAMaxTotal) or (FFiles.Count>=PVAMaxEntries-1) then raise Exception.Create('Pacote excede limites');
      M:=TMemoryStream.Create;FFiles.AddObject(N,M);M.CopyFrom(SourceFile,0);M.Position:=0;
    finally SourceFile.Free;end;
  end;
  O:=TJSONObject.Create(['format','pva','version',1,'script','script.txt','hash','sha256']);
  Z:=TZipper.Create;Manifest:=nil;
  try
    A:=TJSONArray.Create;O.Add('files',A);
    for I:=0 to FFiles.Count-1 do begin
      M:=TMemoryStream(FFiles.Objects[I]);M.Position:=0;
      F:=TJSONObject.Create(['path',FFiles[I],'size',M.Size,'sha256',PresentationSHA256(M)]);
      A.Add(F);Z.Entries.AddFileEntry(M,FFiles[I]);
    end;
    Manifest:=TStringStream.Create(O.AsJSON);Z.Entries.AddFileEntry(Manifest,'manifest.json');
    Z.UseLanguageEncoding:=True;Z.FileName:=FileName+'.tmp';Z.ZipAllFiles;
    if not MoveFileExW(PWideChar(UTF8Decode(FileName+'.tmp')),PWideChar(UTF8Decode(FileName)),MOVEFILE_REPLACE_EXISTING or $00000008) then
      raise Exception.Create('Nao foi possivel salvar pacote');
  finally
    SysUtils.DeleteFile(FileName+'.tmp');Z.Free;Manifest.Free;O.Free;
  end;
end;
procedure TPVAPackage.ExtractTo(const NewDirectory: string);
var I: Integer; P: string;
begin
  // Only a newly created private directory may receive verified resources.
  if DirectoryExists(NewDirectory) or FileExists(NewDirectory) then raise Exception.Create('Diretorio de destino deve ser novo');
  if not ForceDirectories(NewDirectory) then raise Exception.Create('Nao foi possivel criar diretorio');
  for I:=0 to FFiles.Count-1 do begin
    P:=IncludeTrailingPathDelimiter(NewDirectory)+StringReplace(FFiles[I],'/',PathDelim,[rfReplaceAll]);
    ForceDirectories(ExtractFileDir(P));TMemoryStream(FFiles.Objects[I]).SaveToFile(P);
  end;
end;
end.
