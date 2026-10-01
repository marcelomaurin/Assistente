unit reception_playback;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, {$IFDEF WINDOWS}Windows, MMSystem{$ELSE}Process{$ENDIF};

type
  { Owned and polled by the speech worker. Completion comes from the device,
    never from a duration guessed from a WAV header. }
  TReceptionPlayer = class
  private
    {$IFDEF WINDOWS}
    FAlias: string;
    FOpened: Boolean;
    procedure Command(const ACommand: string);
    {$ELSE}
    FProcess: TProcess;
    {$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;
    procedure Play(const AFileName: string);
    function Playing: Boolean;
    procedure Stop;
  end;

implementation

constructor TReceptionPlayer.Create;
begin
  inherited Create;
  {$IFDEF WINDOWS}
  FAlias := 'assistente_' + IntToHex(PtrUInt(Self), SizeOf(Pointer)*2);
  {$ENDIF}
end;

destructor TReceptionPlayer.Destroy;
begin
  Stop;
  inherited Destroy;
end;

{$IFDEF WINDOWS}
procedure TReceptionPlayer.Command(const ACommand: string);
var Code: MCIERROR;
begin
  Code := mciSendStringW(PWideChar(UTF8Decode(ACommand)), nil, 0, 0);
  if Code <> 0 then raise Exception.CreateFmt('Falha de reproducao de audio (%d)', [Code]);
end;
{$ENDIF}

procedure TReceptionPlayer.Play(const AFileName: string);
begin
  Stop;
  if not FileExists(AFileName) then raise Exception.Create('Audio nao encontrado');
  {$IFDEF WINDOWS}
  if Pos('"', AFileName)>0 then raise Exception.Create('Nome de audio invalido');
  Command('open "' + AFileName + '" alias ' + FAlias);
  FOpened := True;
  try Command('play ' + FAlias); except Stop; raise; end;
  {$ELSE}
  FProcess := TProcess.Create(nil);
  FProcess.Executable := 'aplay';
  FProcess.Parameters.Add(AFileName);
  FProcess.Execute;
  {$ENDIF}
end;

function TReceptionPlayer.Playing: Boolean;
{$IFDEF WINDOWS}
var Buffer: array[0..63] of WideChar; Code: MCIERROR; Mode: string;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  Result := False;
  if not FOpened then Exit;
  FillChar(Buffer, SizeOf(Buffer), 0);
  Code := mciSendStringW(PWideChar(UTF8Decode('status ' + FAlias + ' mode')),
    @Buffer[0], Length(Buffer), 0);
  if Code <> 0 then raise Exception.CreateFmt('Falha ao consultar audio (%d)', [Code]);
  Mode := UTF8Encode(UnicodeString(PWideChar(@Buffer[0])));
  if Mode = 'stopped' then Exit;
  if Mode <> 'playing' then raise Exception.Create('Estado de audio inesperado: ' + Mode);
  Result := True;
  {$ELSE}
  Result := Assigned(FProcess) and FProcess.Running;
  if Assigned(FProcess) and not Result and (FProcess.ExitStatus<>0) then
    raise Exception.Create('Falha no reprodutor de audio');
  {$ENDIF}
end;

procedure TReceptionPlayer.Stop;
begin
  {$IFDEF WINDOWS}
  if FOpened then
  begin
    mciSendStringW(PWideChar(UTF8Decode('close ' + FAlias)), nil, 0, 0);
    FOpened := False;
  end;
  {$ELSE}
  if Assigned(FProcess) then
  begin
    if FProcess.Running then FProcess.Terminate(0);
    FreeAndNil(FProcess);
  end;
  {$ENDIF}
end;
end.
