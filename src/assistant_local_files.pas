unit assistant_local_files;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

function AssistantConfigDirectory: string;
function AssistantHistoryReadPath(const ConfigDir, ExecutableDir: string;
  AllowLegacy: Boolean): string;
function CreateSiblingTempFile(const Destination: string): string;
procedure ReplaceLocalFile(const TempFile, Destination: string);
procedure WriteLocalText(const Destination, Text: string);

const AssistantHistoryName = 'conversation-history.json';

implementation

uses Classes, SysUtils, {$IFDEF MSWINDOWS}Windows{$ELSE}BaseUnix{$ENDIF};

function AssistantConfigDirectory: string;
begin
  Result := SysUtils.GetEnvironmentVariable('ASSISTENTE_CONFIG_DIR');
  if Result = '' then Result := GetAppConfigDir(False);
  Result := IncludeTrailingPathDelimiter(ExpandFileName(Result));
end;

function AssistantHistoryReadPath(const ConfigDir, ExecutableDir: string;
  AllowLegacy: Boolean): string;
var Candidate: string;
begin
  Result := IncludeTrailingPathDelimiter(ConfigDir) + AssistantHistoryName;
  if FileExists(Result) then Exit;
  if AllowLegacy then
  begin
    Candidate := IncludeTrailingPathDelimiter(ExecutableDir) + AssistantHistoryName;
    if FileExists(Candidate) then Exit(Candidate);
  end;
  Result := '';
end;

function CreateSiblingTempFile(const Destination: string): string;
var Directory: string;
{$IFDEF MSWINDOWS}
    Buffer: array[0..MAX_PATH] of WideChar;
{$ELSE}
    Attempt, Handle: Integer;
{$ENDIF}
begin
  Directory := ExtractFileDir(ExpandFileName(Destination));
  {$IFDEF MSWINDOWS}
  if GetTempFileNameW(PWideChar(UTF8Decode(Directory)), PWideChar(UnicodeString('ast')), 0, @Buffer[0]) = 0 then
    RaiseLastOSError;
  Result := UTF8Encode(WideString(PWideChar(@Buffer[0])));
  {$ELSE}
  for Attempt := 0 to 99 do
  begin
    Result := IncludeTrailingPathDelimiter(Directory) + '.assistente-' +
      IntToStr(fpGetPID) + '-' + IntToHex(GetTickCount64, 16) + '-' + IntToStr(Attempt) + '.tmp';
    Handle := fpOpen(PChar(Result), O_CREAT or O_EXCL or O_WRONLY, &600);
    if Handle >= 0 then
    begin
      fpClose(Handle);
      Exit;
    end;
    if fpGetErrNo <> ESysEEXIST then RaiseLastOSError;
  end;
  raise EInOutError.Create('Não foi possível reservar um arquivo temporário.');
  {$ENDIF}
end;

procedure ReplaceLocalFile(const TempFile, Destination: string);
begin
  {$IFDEF MSWINDOWS}
  if not MoveFileExW(PWideChar(UTF8Decode(ExpandFileName(TempFile))),
    PWideChar(UTF8Decode(ExpandFileName(Destination))),
    MOVEFILE_REPLACE_EXISTING) then RaiseLastOSError;
  {$ELSE}
  if fpRename(PChar(TempFile), PChar(Destination)) <> 0 then RaiseLastOSError;
  {$ENDIF}
end;

procedure WriteLocalText(const Destination, Text: string);
var TempFile: string; Stream: TFileStream;
begin
  TempFile := CreateSiblingTempFile(Destination);
  try
    Stream := TFileStream.Create(TempFile, fmCreate);
    try
      if Text <> '' then Stream.WriteBuffer(Text[1], Length(Text));
    finally
      Stream.Free;
    end;
    ReplaceLocalFile(TempFile, Destination);
  finally
    if FileExists(TempFile) then SysUtils.DeleteFile(TempFile);
  end;
end;

end.
