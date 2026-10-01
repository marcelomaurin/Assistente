unit voice_input_bridge;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, setmain, reception_core;

type
  TVoiceTextEvent = procedure(Sender: TObject; const AText: string) of object;
  TVoiceStateEvent = procedure(Sender: TObject; const AState: string) of object;

  { TVoiceInputBridge
    Ponte fina entre um capturador de audio e o fluxo principal do Assistente.
    Nesta etapa nao implementa VAD: recebe somente um WAV ja finalizado pelo
    capturador. O VAD/ruido sera responsabilidade do componente CHATGPT. }
  TVoiceInputBridge = class(TComponent)
  private
    FTimer: TTimer;
    FJob: TReceptionJob;
    FOnText: TVoiceTextEvent;
    FOnState: TVoiceStateEvent;
    FPaused: Boolean;
    FOnFinished: TNotifyEvent;
    procedure TimerTick(Sender: TObject);
    procedure SetState(const AState: string);
    function BuildConfig: TReceptionConfig;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function TranscribeWav(const AFileName: string): Boolean;
    procedure Pause;
    procedure Resume;
    procedure Cancel;
    function Busy: Boolean;
    property Paused: Boolean read FPaused;
    property OnText: TVoiceTextEvent read FOnText write FOnText;
    property OnState: TVoiceStateEvent read FOnState write FOnState;
    property OnFinished: TNotifyEvent read FOnFinished write FOnFinished;
  end;

implementation

constructor TVoiceInputBridge.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FJob := nil;
  FPaused := False;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 50;
  FTimer.OnTimer := @TimerTick;
end;

destructor TVoiceInputBridge.Destroy;
begin
  Cancel;
  inherited Destroy;
end;

function TVoiceInputBridge.BuildConfig: TReceptionConfig;
begin
  Result.Token := '';
  Result.AudioToken := '';
  Result.Model := '';
  Result.URL := '';
  Result.Language := '';
  Result.Voice := '';
  Result.Provider := 0;
  Result.RecogEngine := 0;
  Result.SynthEngine := 0;
  Result.Volume := 100;
  Result.Rate := 0;

  if FSetMain = nil then Exit;

  Result.Token := FSetMain.CHATGPT;
  Result.AudioToken := FSetMain.STTToken;
  if Result.AudioToken = '' then
    Result.AudioToken := FSetMain.VoiceAPIToken;
  if Result.AudioToken = '' then
    Result.AudioToken := FSetMain.CHATGPT;

  Result.Model := FSetMain.STTModel;
  Result.URL := FSetMain.STTEndpoint;
  Result.Language := FSetMain.RecogLanguage;
  Result.Provider := FSetMain.ChatGPTProvider;
  Result.RecogEngine := FSetMain.RecogEngine;
end;

procedure TVoiceInputBridge.SetState(const AState: string);
begin
  if Assigned(FOnState) then
    FOnState(Self, AState);
end;

function TVoiceInputBridge.Busy: Boolean;
begin
  Result := Assigned(FJob);
end;

function TVoiceInputBridge.TranscribeWav(const AFileName: string): Boolean;
var
  Cfg: TReceptionConfig;
begin
  Result := False;
  if FPaused or Busy then Exit;
  if (AFileName = '') or (not FileExists(AFileName)) then
  begin
    SetState('Arquivo de audio invalido');
    Exit;
  end;

  Cfg := BuildConfig;
  FJob := TReceptionJob.Create(rjTranscribe, Cfg, AFileName, '', 'voice');
  FTimer.Enabled := True;
  SetState('Transcrevendo fala...');
  Result := True;
end;

procedure TVoiceInputBridge.TimerTick(Sender: TObject);
var
  TextResult, ErrorResult: string;
  Ok: Boolean;
begin
  if not Assigned(FJob) then
  begin
    FTimer.Enabled := False;
    Exit;
  end;
  if not FJob.Done then Exit;

  FTimer.Enabled := False;
  Ok := FJob.Success;
  TextResult := Trim(FJob.Text);
  ErrorResult := Trim(FJob.ErrorText);
  FJob.Free;
  FJob := nil;

  try
  if Ok and (TextResult <> '') then
  begin
    SetState('Fala reconhecida');
    if Assigned(FOnText) then
      FOnText(Self, TextResult);
  end
  else if ErrorResult <> '' then
    SetState('Falha no reconhecimento: ' + ErrorResult)
  else
    SetState('Nenhuma fala reconhecida');
  finally
    if Assigned(FOnFinished) then FOnFinished(Self);
  end;
end;

procedure TVoiceInputBridge.Pause;
begin
  FPaused := True;
  SetState('Escuta pausada');
end;

procedure TVoiceInputBridge.Resume;
begin
  FPaused := False;
  SetState('Escuta disponivel');
end;

procedure TVoiceInputBridge.Cancel;
begin
  FTimer.Enabled := False;
  if Assigned(FJob) then
  begin
    FJob.Cancel;
    FJob.Free;
    FJob := nil;
  end;
end;

end.
