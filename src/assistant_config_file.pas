unit assistant_config_file;
{ Portable configuration file of the Assistente (*.assistente-config.json).

  Generated from Configurações > Exportar and applied with Configurações >
  Importar, or at start-up with:  assistente.exe --importar-config=<arquivo>

  Format (UTF-8 JSON):
    {"format":"assistente-config","version":1,"exported_at":"...",
     "contains_secrets":false,"settings":{"CHATGPTPROVIDER":"1",...}}

  "settings" uses the same keys as Setmain.cfg. Settings tied to one
  computer (window position, device indexes, script paths) are never
  exported nor imported. Keys absent from the file keep their value. }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, setmain;
const
  AssistantConfigFormat = 'assistente-config';
  AssistantConfigExtension = '.assistente-config.json';
  AssistantConfigFilter = 'Configuração do Assistente (*.assistente-config.json)|*.assistente-config.json;*.json|Todos os arquivos (*.*)|*.*';
procedure ExportAssistantConfig(Settings: TSetMain; const FileName: string; IncludeSecrets: Boolean);
{ Returns the number of settings applied. Raises on an invalid file. }
function ImportAssistantConfig(Settings: TSetMain; const FileName: string): Integer;
{ Value of --importar-config=<file> (or "--importar-config <file>"), a single
  *.assistente-config.json argument, or ''. }
function ConfigFileFromCommandLine: string;
implementation
uses fpjson, jsonparser, jsonscanner;
const MaxConfigSize = 1024*1024;

procedure ExportAssistantConfig(Settings: TSetMain; const FileName: string; IncludeSecrets: Boolean);
var Lines: TStringList; Root, Values: TJSONObject; I, P: Integer; Text, Temp: string;
  Mode: TSettingsWriteMode; Stream: TFileStream;
begin
  Lines:=TStringList.Create;Root:=TJSONObject.Create;
  try
    if IncludeSecrets then Mode:=swExportWithSecrets else Mode:=swExportWithoutSecrets;
    Settings.WriteLines(Lines,Mode);
    Values:=TJSONObject.Create;
    for I:=0 to Lines.Count-1 do begin
      P:=Pos(':',Lines[I]);
      if P>1 then Values.Add(Copy(Lines[I],1,P-1),Copy(Lines[I],P+1,MaxInt));
    end;
    Root.Add('format',AssistantConfigFormat);Root.Add('version',1);
    Root.Add('exported_at',FormatDateTime('yyyy-mm-dd"T"hh:nn:ss',Now));
    Root.Add('contains_secrets',IncludeSecrets);
    Root.Add('settings',Values);
    Text:=Root.FormatJSON([],2)+LineEnding;
    Temp:=FileName+'.tmp';
    Stream:=TFileStream.Create(Temp,fmCreate);
    try Stream.WriteBuffer(Text[1],Length(Text));finally Stream.Free;end;
    if FileExists(FileName) and not DeleteFile(FileName) then begin
      DeleteFile(Temp);raise Exception.Create('Não foi possível substituir '+FileName);
    end;
    if not RenameFile(Temp,FileName) then begin
      DeleteFile(Temp);raise Exception.Create('Não foi possível gravar '+FileName);
    end;
  finally Lines.Free;Root.Free;end;
end;

function ReadConfigText(const FileName: string): string;
var Stream: TFileStream;
begin
  Stream:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size>MaxConfigSize then raise Exception.Create('Arquivo de configuração muito grande');
    SetLength(Result,Stream.Size);
    if Stream.Size>0 then Stream.ReadBuffer(Result[1],Stream.Size);
  finally Stream.Free;end;
  if Copy(Result,1,3)=#$EF#$BB#$BF then Delete(Result,1,3);
end;

function ImportAssistantConfig(Settings: TSetMain; const FileName: string): Integer;
var Parser: TJSONParser; Data, Item: TJSONData; Values: TJSONObject; Lines: TStringList;
  I: Integer; Key, Value: string;
begin
  Result:=0;
  Parser:=TJSONParser.Create(ReadConfigText(FileName),[joUTF8,joStrict]);
  try
    try Data:=Parser.Parse;
    except on E: Exception do raise Exception.Create('Arquivo de configuração inválido: '+E.Message);end;
  finally Parser.Free;end;
  Lines:=TStringList.Create;
  try
    if not (Data is TJSONObject) or (TJSONObject(Data).Get('format','')<>AssistantConfigFormat) then
      raise Exception.Create('O arquivo não é uma configuração do Assistente');
    if TJSONObject(Data).Get('version',0)<>1 then
      raise Exception.Create('Versão do arquivo de configuração não suportada');
    Item:=TJSONObject(Data).Find('settings');
    if not (Item is TJSONObject) then raise Exception.Create('Configuração sem a seção "settings"');
    Values:=TJSONObject(Item);
    for I:=0 to Values.Count-1 do begin
      Key:=UpperCase(Trim(Values.Names[I]));
      if (Key='') or (Pos(':',Key)>0) or (Length(Key)>64) then
        raise Exception.Create('Chave inválida na configuração: '+Values.Names[I]);
      if Values.Items[I].JSONType in [jtObject,jtArray,jtNull] then
        raise Exception.Create('Valor inválido para '+Key);
      Value:=Values.Items[I].AsString;
      if (Pos(#10,Value)>0) or (Pos(#13,Value)>0) then
        raise Exception.Create('Valor com quebra de linha em '+Key);
      if IsMachineSettingKey(Key) then Continue;
      Lines.Append(Key+':'+Value);
    end;
    if Lines.Count=0 then raise Exception.Create('Nenhuma configuração aplicável no arquivo');
    Settings.ImportLines(Lines);
    Result:=Lines.Count;
  finally Lines.Free;Data.Free;end;
end;

function ConfigFileFromCommandLine: string;
const Option = '--importar-config';
var I: Integer; A: string;
begin
  Result:='';
  for I:=1 to ParamCount do begin
    A:=ParamStr(I);
    if SameText(Copy(A,1,Length(Option)+1),Option+'=') then Exit(Copy(A,Length(Option)+2,MaxInt));
    if SameText(A,Option) and (I<ParamCount) then Exit(ParamStr(I+1));
  end;
  { Opening a configuration file with the Assistente (double click). }
  if (ParamCount=1) and SameText(Copy(LowerCase(ParamStr(1)),Length(ParamStr(1))-Length(AssistantConfigExtension)+1,MaxInt),
    AssistantConfigExtension) then Result:=ParamStr(1);
end;
end.
