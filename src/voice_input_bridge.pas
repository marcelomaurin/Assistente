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
  end;

function IsWhisperHallucination(const AText: string): Boolean;

implementation

function CleanTextForAnalysis(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      'a'..'z', '0'..'9', ' ':
        Result := Result + C;
      'A'..'Z':
        Result := Result + LowerCase(C);
      '_', '-', '.', ',', '!', '?', '~', '*', '#', '/', '\', ':', ';',
      '(', ')', '[', ']', '{', '}', '"', #39, '`', '^', '+':
        Result := Result + ' ';
    end;
  end;
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
  Result := Trim(Result);
end;

function IsWhisperHallucination(const AText: string): Boolean;
var
  Clean, Lower: string;
  AlphaCount, I: Integer;
begin
  Result := False;
  Lower := LowerCase(Trim(AText));
  if Lower = '' then
  begin
    Result := True;
    Exit;
  end;

  AlphaCount := 0;
  for I := 1 to Length(Lower) do
  begin
    if Lower[I] in ['a'..'z', '0'..'9', #128..#255] then
      Inc(AlphaCount);
  end;

  if AlphaCount < 2 then
  begin
    Result := True;
    Exit;
  end;

  Clean := CleanTextForAnalysis(Lower);

  if (Pos('thank you for watching', Clean) > 0) or
     (Pos('thanks for watching', Clean) > 0) or
     (Pos('please subscribe', Clean) > 0) or
     (Pos('subscribe to my channel', Clean) > 0) or
     (Pos('subscribe to our channel', Clean) > 0) or
     (Pos('like and subscribe', Clean) > 0) or
     (Pos('dont forget to subscribe', Clean) > 0) or
     (Pos('see you next time', Clean) > 0) or
     (Pos('see you in the next video', Clean) > 0) or
     (Pos('watch next video', Clean) > 0) or
     (Pos('subtitles by', Clean) > 0) or
     (Pos('subtitle by', Clean) > 0) or
     (Pos('transcribed by', Clean) > 0) or
     (Pos('captioned by', Clean) > 0) or
     (Pos('amara org', Clean) > 0) or
     (Pos('obrigado por assistir', Clean) > 0) or
     (Pos('obrigada por assistir', Clean) > 0) or
     (Pos('inscreva se no canal', Clean) > 0) or
     (Pos('inscreva se em nosso canal', Clean) > 0) or
     (Pos('deixe seu like', Clean) > 0) or
     (Pos('deixe o seu like', Clean) > 0) or
     (Pos('curta e compartilhe', Clean) > 0) or
     (Pos('ative o sininho', Clean) > 0) or
     (Pos('legendado por', Clean) > 0) or
     (Pos('legendas por', Clean) > 0) or
     (Pos('musica', Clean) = 1) or
     (Pos('silencio', Clean) = 1) or
     (Pos('barulho', Clean) = 1) or
     (Pos('ruido', Clean) = 1) then
  begin
    Result := True;
    Exit;
  end;
end;

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

  if Ok and (TextResult <> '') then
  begin
    if IsWhisperHallucination(TextResult) then
    begin
      SetState('Silêncio descartado');
      Exit;
    end;
    SetState('Fala reconhecida');
    if Assigned(FOnText) then
      FOnText(Self, TextResult);
  end
  else if ErrorResult <> '' then
    SetState('Falha no reconhecimento: ' + ErrorResult)
  else
    SetState('Nenhuma fala reconhecida');
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
