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
    {$IFDEF MSWINDOWS}FDeviceID: MCIDEVICEID;FPlaybackCopy:UnicodeString;{$ENDIF}
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
    procedure SetPaused(Value: Boolean);
  published
    property LastError: string read FLastError;
    property Playing: Boolean read GetPlaying;
    property OnPlaybackBuffer: TAIPlaybackBufferEvent read FOnPlaybackBuffer write FOnPlaybackBuffer;
    property OnPlaybackStart: TAIPlaybackFileEvent read FOnPlaybackStart write FOnPlaybackStart;
    property OnPlaybackStop: TNotifyEvent read FOnPlaybackStop write FOnPlaybackStop;
  end;

function FinalizeStreamingWaveFile(const FileName:string;out Error:string):Boolean;
procedure Register;

implementation

{ A completed streaming WAV can still declare RIFF/data sizes as $FFFFFFFF.
  MCI waveaudio rejects that header although the PCM payload is complete.
  Inspect without write access first: ordinary/read-only WAVs stay untouched. }
function FinalizeStreamingWaveFile(const FileName: string; out Error: string): Boolean;
var Stream:TFileStream; Header:array[0..11] of AnsiChar; Chunk:array[0..3] of AnsiChar;
  RiffSize,ChunkSize,DataSize:Cardinal; Position,DataOffset,Available,FileSize:Int64;
  FoundFormat,FoundData,PatchRiff,PatchData:Boolean;
  function IsChunk(const Name:AnsiString):Boolean;
  begin Result:=(Chunk[0]=Name[1]) and (Chunk[1]=Name[2]) and (Chunk[2]=Name[3]) and (Chunk[3]=Name[4]);end;
  function ReadSize:Cardinal;
  var B:array[0..3] of Byte;
  begin
    Stream.ReadBuffer(B,4);
    Result:=Cardinal(B[0]) or (Cardinal(B[1]) shl 8) or (Cardinal(B[2]) shl 16) or (Cardinal(B[3]) shl 24);
  end;
  procedure WriteSize(Offset:Int64;Value:Cardinal);
  var B:array[0..3] of Byte;
  begin
    B[0]:=Byte(Value);B[1]:=Byte(Value shr 8);B[2]:=Byte(Value shr 16);B[3]:=Byte(Value shr 24);
    Stream.Position:=Offset;Stream.WriteBuffer(B,4);
  end;
begin
  Result:=False;Error:='';Stream:=nil;
  FoundFormat:=False;FoundData:=False;PatchData:=False;DataOffset:=0;DataSize:=0;
  try
    try
      Stream:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyNone);FileSize:=Stream.Size;
      if (FileSize<44) or (FileSize-8>High(Cardinal)) then raise Exception.Create('Tamanho WAV invalido');
      Stream.ReadBuffer(Header,12);
      if (Header[0]<>'R') or (Header[1]<>'I') or (Header[2]<>'F') or (Header[3]<>'F') or
         (Header[8]<>'W') or (Header[9]<>'A') or (Header[10]<>'V') or (Header[11]<>'E') then
        raise Exception.Create('Arquivo recebido nao e um WAV RIFF');
      Stream.Position:=4;RiffSize:=ReadSize;
      PatchRiff:=(RiffSize=High(Cardinal)) or (RiffSize=0);
      if not PatchRiff and (Int64(RiffSize)>FileSize-8) then raise Exception.Create('Arquivo WAV truncado');
      Position:=12;
      while Position+8<=FileSize do begin
        Stream.Position:=Position;Stream.ReadBuffer(Chunk,4);ChunkSize:=ReadSize;
        Available:=FileSize-Position-8;
        if IsChunk('data') then begin
          FoundData:=True;DataOffset:=Position+4;
          PatchData:=(ChunkSize=High(Cardinal)) or ((ChunkSize=0) and PatchRiff);
          if PatchData then DataSize:=Cardinal(Available) else DataSize:=ChunkSize;
          if (DataSize=0) or (Int64(DataSize)>Available) then raise Exception.Create('Dados WAV vazios ou truncados');
          Break;
        end;
        if Int64(ChunkSize)>Available then raise Exception.Create('Chunk WAV truncado');
        if IsChunk('fmt ') then begin
          if ChunkSize<16 then raise Exception.Create('Formato WAV invalido');FoundFormat:=True;
        end;
        Position:=Position+8+Int64(ChunkSize)+(ChunkSize and 1);
      end;
      if not FoundFormat or not FoundData then raise Exception.Create('WAV sem formato ou dados de audio');
      if PatchRiff or PatchData then begin
        FreeAndNil(Stream);Stream:=TFileStream.Create(FileName,fmOpenReadWrite or fmShareDenyWrite);
        if Stream.Size<>FileSize then raise Exception.Create('Arquivo WAV mudou durante a validacao');
        if PatchRiff then WriteSize(4,Cardinal(FileSize-8));
        if PatchData then WriteSize(DataOffset,DataSize);
      end;
      Result:=True;
    except on E:Exception do Error:='Falha ao preparar audio WAV: '+E.Message;end;
  finally Stream.Free;end;
end;


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
  ShortName:UnicodeString;N:DWORD;TempPath,TempName:array[0..MAX_PATH] of WideChar;
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
  if (Ext='.wav') and not FinalizeStreamingWaveFile(AFileName,FLastError) then Exit;

  {$IFDEF MSWINDOWS}
  { Each player owns its device. No shared alias or process-wide
    sndPlaySound: status queries observe actual completion of this file. }
  FileNameW := UTF8Decode(ExpandFileName(AFileName));
  // MCI drivers can reject paths longer than 127 characters with error 304.
  SetLength(ShortName,32768);N:=GetShortPathNameW(PWideChar(FileNameW),PWideChar(ShortName),Length(ShortName));
  if (N>0) and (N<DWORD(Length(ShortName))) then begin SetLength(ShortName,N);FileNameW:=ShortName;end;
  if Length(FileNameW)>127 then begin
    if (GetTempPathW(MAX_PATH,@TempPath[0])=0) or (GetTempFileNameW(@TempPath[0],'asp',0,@TempName[0])=0) then begin
      FLastError:='Falha ao criar copia temporaria para audio: '+SysErrorMessage(GetLastError);Exit;
    end;
    FPlaybackCopy:=PWideChar(@TempName[0]);
    if not CopyFileW(PWideChar(FileNameW),PWideChar(FPlaybackCopy),False) then begin
      FLastError:='Falha ao preparar audio: '+SysErrorMessage(GetLastError);Stop;Exit;
    end;
    FileNameW:=FPlaybackCopy;
  end;
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
  if not Result then begin
    Stop;FLastError := Format('Falha ao reproduzir audio via MCI (Erro %d)', [Ret]);
  end;
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

procedure TAIAudioPlayer.SetPaused(Value: Boolean);
var R: MCIERROR;
begin
  {$IFDEF MSWINDOWS}
  if FDeviceID=0 then Exit;
  if Value then R:=mciSendCommandW(FDeviceID,MCI_PAUSE,MCI_WAIT,0)
  else R:=mciSendCommandW(FDeviceID,MCI_RESUME,MCI_WAIT,0);
  if R<>0 then begin FLastError:='Falha ao pausar/retomar audio';Stop;end;
  {$ENDIF}
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
  if FPlaybackCopy<>'' then begin DeleteFileW(PWideChar(FPlaybackCopy));FPlaybackCopy:='';end;
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
