unit aiaudioplayback;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process,
  {$IFDEF MSWINDOWS}Windows, MMSystem,{$ENDIF}
  LResources;

type
  TAIPlaybackBufferEvent = procedure(
    Sender: TObject;
    const AData: TBytes;
    ASampleRate: Integer;
    AChannels: Integer
  ) of object;

  TAIPlaybackFileEvent = procedure(
    Sender: TObject;
    const AFileName: string
  ) of object;

  { TAIAudioPlayer: Audio playback component supporting WAV and MP3 }
  TAIAudioPlayer = class(TComponent)
  private
    FProcess: TProcess;
    FLastError: string;
    FPlaying: Boolean;
    {$IFDEF MSWINDOWS}FDeviceID: MCIDEVICEID;{$ENDIF}
    FOnPlaybackBuffer: TAIPlaybackBufferEvent;
    FOnPlaybackStart: TAIPlaybackFileEvent;
    FOnPlaybackStop: TNotifyEvent;

    function GetPlaying: Boolean;
    procedure DispatchWavBuffer(const AFileName: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Play(const AFileName: string): Boolean;
    procedure Stop;
  published
    property LastError: string read FLastError;
    property Playing: Boolean read GetPlaying;
    property OnPlaybackBuffer: TAIPlaybackBufferEvent read FOnPlaybackBuffer write FOnPlaybackBuffer;
    property OnPlaybackStart: TAIPlaybackFileEvent read FOnPlaybackStart write FOnPlaybackStart;
    property OnPlaybackStop: TNotifyEvent read FOnPlaybackStop write FOnPlaybackStop;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('AI Voice', [TAIAudioPlayer]);
end;

constructor TAIAudioPlayer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProcess := nil;
  FLastError := '';
  FPlaying := False;
  {$IFDEF MSWINDOWS}FDeviceID := 0;{$ENDIF}
end;

destructor TAIAudioPlayer.Destroy;
begin
  Stop;
  if Assigned(FProcess) then
    FreeAndNil(FProcess);
  inherited Destroy;
end;

procedure TAIAudioPlayer.DispatchWavBuffer(const AFileName: string);
var
  FS: TFileStream;
  Buffer: TBytes;
begin
  if not Assigned(FOnPlaybackBuffer) then Exit;
  if not FileExists(AFileName) then Exit;
  try
    FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      if FS.Size > 44 then
      begin
        SetLength(Buffer, FS.Size - 44);
        FS.Position := 44;
        FS.ReadBuffer(Buffer[0], Length(Buffer));
        FOnPlaybackBuffer(Self, Buffer, 16000, 1);
      end;
    finally
      FS.Free;
    end;
  except
  end;
end;

function TAIAudioPlayer.Play(const AFileName: string): Boolean;
var
  Ext: string;
  {$IFDEF MSWINDOWS}
  OpenParams: TMCI_WAVE_OPEN_PARMSW;
  PlayParams: TMCI_PLAY_PARMS;
  FileNameW, DeviceTypeW: UnicodeString;
  Ret: MCIERROR;
  {$ENDIF}
begin
  Result := False;
  FLastError := '';
  Stop;

  if not FileExists(AFileName) then
  begin
    FLastError := 'Arquivo de audio nao encontrado: ' + AFileName;
    Exit;
  end;

  Ext := LowerCase(ExtractFileExt(AFileName));

  {$IFDEF MSWINDOWS}
  { Each player owns its device. No shared alias or process-wide
    sndPlaySound: status queries observe actual completion of this file. }
  FileNameW := UTF8Decode(ExpandFileName(AFileName));
  if Ext = '.mp3' then DeviceTypeW := 'mpegvideo'
  else DeviceTypeW := 'waveaudio';
  FillChar(OpenParams, SizeOf(OpenParams), 0);
  OpenParams.lpstrDeviceType := PWideChar(DeviceTypeW);
  OpenParams.lpstrElementName := PWideChar(FileNameW);
  Ret := mciSendCommandW(0, MCI_OPEN,
    MCI_OPEN_TYPE or MCI_OPEN_ELEMENT or MCI_WAIT, PtrUInt(@OpenParams));
  if Ret = 0 then
  begin
    FDeviceID := OpenParams.wDeviceID;
    FillChar(PlayParams, SizeOf(PlayParams), 0);
    Ret := mciSendCommandW(FDeviceID, MCI_PLAY, 0, PtrUInt(@PlayParams));
    Result := Ret = 0;
    if not Result then Stop;
  end;
  if not Result then
    FLastError := Format('Falha ao reproduzir audio via MCI (Erro %d)', [Ret]);
  {$ELSE}
  FProcess := TProcess.Create(nil);
  if Ext = '.mp3' then
    FProcess.Executable := 'mpg123'
  else
    FProcess.Executable := 'aplay';

  FProcess.Parameters.Add(AFileName);
  FProcess.Options := [poNoConsole];
  try
    FProcess.Execute;
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Falha ao executar player Linux: ' + E.Message;
      FreeAndNil(FProcess);
    end;
  end;
  {$ENDIF}

  FPlaying := Result;
  if Result then
  begin
    DispatchWavBuffer(AFileName);
    if Assigned(FOnPlaybackStart) then
      FOnPlaybackStart(Self, AFileName);
  end;
end;

function TAIAudioPlayer.GetPlaying: Boolean;
{$IFDEF MSWINDOWS}
var Status: TMCI_STATUS_PARMS; Ret: MCIERROR;
{$ENDIF}
begin
  if FPlaying then
  begin
    {$IFDEF MSWINDOWS}
    FillChar(Status, SizeOf(Status), 0);
    Status.dwItem := MCI_STATUS_MODE;
    Ret := mciSendCommandW(FDeviceID, MCI_STATUS,
      MCI_STATUS_ITEM or MCI_WAIT, PtrUInt(@Status));
    if Ret <> 0 then
    begin
      FLastError := Format('Falha ao consultar reproducao MCI (Erro %d)', [Ret]);
      Stop;
    end
    else if Status.dwReturn = MCI_MODE_STOP then Stop;
    {$ELSE}
    if not Assigned(FProcess) or not FProcess.Running then Stop;
    {$ENDIF}
  end;
  Result := FPlaying;
end;

procedure TAIAudioPlayer.Stop;
var WasPlaying: Boolean;
begin
  WasPlaying := FPlaying;
  FPlaying := False;
  {$IFDEF MSWINDOWS}
  if FDeviceID <> 0 then
  begin
    mciSendCommandW(FDeviceID, MCI_STOP, MCI_WAIT, 0);
    mciSendCommandW(FDeviceID, MCI_CLOSE, MCI_WAIT, 0);
    FDeviceID := 0;
  end;
  {$ELSE}
  if Assigned(FProcess) then
  begin
    if FProcess.Running then FProcess.Terminate(0);
    FreeAndNil(FProcess);
  end;
  {$ENDIF}
  if WasPlaying and Assigned(FOnPlaybackStop) then FOnPlaybackStop(Self);
end;

initialization
  {$I aiaudioplayback_icon.lrs}

end.
