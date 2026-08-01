unit aivoicesynthesizer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  {$IFDEF MSWINDOWS}
  ComObj, ActiveX, Variants,
  {$ENDIF}
  DynLibs, aibase, LResources,
  fphttpclient, opensslsockets, fpjson, jsonparser;

type
  TSpeechEngine = (seSystemDefault, seSAPI, seEspeak, seOpenAI);

  Pespeak_VOICE = ^Tespeak_VOICE;
  Tespeak_VOICE = record
    name       : PAnsiChar;
    languages  : PAnsiChar;
    identifier : PAnsiChar;
    gender     : Byte;
    age        : Byte;
    variant    : Byte;
    xx1        : Byte;
    score      : Integer;
    spare      : Pointer;
  end;
  PPespeak_VOICE = ^Pespeak_VOICE;

  { eSpeak C API function pointer signatures }
  Tespeak_Initialize = function(output: Integer; buf_length: Integer; path: PAnsiChar; options: Integer): Integer; cdecl;
  Tespeak_SetVoiceByName = function(name: PAnsiChar): Integer; cdecl;
  Tespeak_SetVolume = function(volume: Integer): Integer; cdecl;
  Tespeak_SetRate = function(rate: Integer): Integer; cdecl;
  Tespeak_Synth = function(text: PAnsiChar; size: SizeInt; position: Cardinal; position_type: Integer; end_position: Cardinal; flags: Cardinal; unique_identifier: PCardinal; user_data: Pointer): Integer; cdecl;
  Tespeak_Terminate = function: Integer; cdecl;
  Tespeak_ListVoices = function(voice_selector: Pointer): PPespeak_VOICE; cdecl;

  { TAIVoiceSynthesizer }

  TAIVoiceSynthesizer = class(TAIBaseComponent)
  private
    FText         : string;
    FVolume       : Integer;
    FRate         : Integer;
    FVoiceName    : string;
    FAsynchronous : Boolean;
    FEngine       : TSpeechEngine;

    // OpenAI fields
    FOpenAIToken       : string;
    FOpenAIModel       : string;
    FOpenAIVoice       : string;
    FOpenAIInstructions: string;
    FOpenAIOutputFormat: string;
    FOpenAIOutputFile  : string;
    FLanguage          : string;
    FOpenAIEndpoint    : string;
    FSpeed             : Double;

    {$IFDEF MSWINDOWS}
    FSpVoice      : OleVariant;
    FSpVoiceCreated: Boolean;
    {$ENDIF}

    // eSpeak dynamically loaded fields (both Windows and Linux)
    FLibHandle    : TLibHandle;
    FInitialized  : Boolean;

    espeak_Initialize     : Tespeak_Initialize;
    espeak_SetVoiceByName : Tespeak_SetVoiceByName;
    espeak_SetVolume      : Tespeak_SetVolume;
    espeak_SetRate        : Tespeak_SetRate;
    espeak_Synth          : Tespeak_Synth;
    espeak_Terminate      : Tespeak_Terminate;
    espeak_ListVoices     : Tespeak_ListVoices;

    function InitEspeak: Boolean;
    procedure UnloadEspeak;
    function SayOpenAI(const AText: string): Boolean;
    function BuildOpenAIInstructions: string;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Say(const AText: string = '');
    procedure GetAvailableVoices(AList: TStrings);
    function ValidateOpenAIConfig(const AText: string): Boolean;
    function JSONEscape(const S: string): string;

  published
    property Text: string read FText write FText;
    property Volume: Integer read FVolume write FVolume default 100;
    property Rate: Integer read FRate write FRate default 0;
    property VoiceName: string read FVoiceName write FVoiceName;
    property Asynchronous: Boolean read FAsynchronous write FAsynchronous default True;
    property Engine: TSpeechEngine read FEngine write FEngine default seSystemDefault;
    property OpenAIToken: string read FOpenAIToken write FOpenAIToken;
    property OpenAIModel: string read FOpenAIModel write FOpenAIModel;
    property OpenAIVoice: string read FOpenAIVoice write FOpenAIVoice;
    property OpenAIInstructions: string read FOpenAIInstructions write FOpenAIInstructions;
    property OpenAIOutputFormat: string read FOpenAIOutputFormat write FOpenAIOutputFormat;
    property OpenAIOutputFile: string read FOpenAIOutputFile write FOpenAIOutputFile;
    property Language: string read FLanguage write FLanguage;
    property OpenAIEndpoint: string read FOpenAIEndpoint write FOpenAIEndpoint;
    property Speed: Double read FSpeed write FSpeed;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('AI Voice', [TAIVoiceSynthesizer]);
end;

{ TAIVoiceSynthesizer }

constructor TAIVoiceSynthesizer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCategory := ccOutput;
  FText := '';
  FVolume := 100;
  FRate := 0;
  FVoiceName := '';
  FAsynchronous := True;
  FEngine := seSystemDefault;

  FOpenAIToken := GetEnvironmentVariable('OPENAI_API_KEY');
  FOpenAIModel := 'tts-1';
  FOpenAIVoice := 'alloy';
  FOpenAIInstructions := '';
  FOpenAIOutputFormat := 'mp3';
  FOpenAIOutputFile := '';
  FLanguage := 'pt';
  FOpenAIEndpoint := 'https://api.openai.com/v1/audio/speech';
  FSpeed := 1.0;

  FInitialized := False;
  FLibHandle := NilHandle;
  {$IFDEF MSWINDOWS}
  FSpVoiceCreated := False;
  {$ENDIF}
  FPrompt := 'TAIVoiceSynthesizer realiza síntese de voz (TTS) nativa usando SAPI, eSpeak ou OpenAI TTS.';
  ClearError;
end;

destructor TAIVoiceSynthesizer.Destroy;
begin
  UnloadEspeak;
  {$IFDEF MSWINDOWS}
  if FSpVoiceCreated then
  begin
    FSpVoice := Unassigned;
    FSpVoiceCreated := False;
  end;
  {$ENDIF}
  inherited Destroy;
end;

function TAIVoiceSynthesizer.InitEspeak: Boolean;
var
  LibName: string;
  SampleRate: Integer;
begin
  if FInitialized then Exit(True);

  {$IFDEF MSWINDOWS}
  LibName := 'libespeak-ng.dll';
  if not FileExists(LibName) then
    LibName := 'espeak.dll';
  {$ELSE}
  LibName := 'libespeak-ng.so.1';
  if not FileExists(LibName) then
    LibName := 'libespeak.so.1';
  {$ENDIF}

  FLibHandle := LoadLibrary(LibName);
  if FLibHandle = NilHandle then
  begin
    SetError('Não foi possível carregar a biblioteca eSpeak (' + LibName + ').');
    Exit(False);
  end;

  Pointer(espeak_Initialize) := GetProcedureAddress(FLibHandle, 'espeak_Initialize');
  Pointer(espeak_SetVoiceByName) := GetProcedureAddress(FLibHandle, 'espeak_SetVoiceByName');
  Pointer(espeak_SetVolume) := GetProcedureAddress(FLibHandle, 'espeak_SetVolume');
  Pointer(espeak_SetRate) := GetProcedureAddress(FLibHandle, 'espeak_SetRate');
  Pointer(espeak_Synth) := GetProcedureAddress(FLibHandle, 'espeak_Synth');
  Pointer(espeak_Terminate) := GetProcedureAddress(FLibHandle, 'espeak_Terminate');
  Pointer(espeak_ListVoices) := GetProcedureAddress(FLibHandle, 'espeak_ListVoices');

  if not Assigned(espeak_Initialize) or not Assigned(espeak_Synth) then
  begin
    SetError('Funções fundamentais do eSpeak não foram encontradas na biblioteca.');
    UnloadEspeak;
    Exit(False);
  end;

  SampleRate := espeak_Initialize(0, 500, nil, 0);
  if SampleRate < 0 then
  begin
    SetError('Falha ao inicializar o motor eSpeak.');
    UnloadEspeak;
    Exit(False);
  end;

  FInitialized := True;
  Result := True;
end;

procedure TAIVoiceSynthesizer.UnloadEspeak;
begin
  if FInitialized then
  begin
    if Assigned(espeak_Terminate) then
      espeak_Terminate;
    FInitialized := False;
  end;

  if FLibHandle <> NilHandle then
  begin
    FreeLibrary(FLibHandle);
    FLibHandle := NilHandle;
  end;
end;

function TAIVoiceSynthesizer.JSONEscape(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #8:   Result := Result + '\b';
      #12:  Result := Result + '\f';
      #10:  Result := Result + '\n';
      #13:  Result := Result + '\r';
      #9:   Result := Result + '\t';
    else
      if Ord(C) < 32 then
        Result := Result + '\u' + IntToHex(Ord(C), 4)
      else
        Result := Result + C;
    end;
  end;
end;

function TAIVoiceSynthesizer.BuildOpenAIInstructions: string;
begin
  Result := FOpenAIInstructions;
end;

function TAIVoiceSynthesizer.ValidateOpenAIConfig(const AText: string): Boolean;
var
  Token: string;
begin
  ClearError;
  Token := Trim(FOpenAIToken);
  if Token = '' then
    Token := GetEnvironmentVariable('OPENAI_API_KEY');

  if Token = '' then
  begin
    SetError('OpenAI API Token não configurado para síntese de voz.');
    Exit(False);
  end;

  if Trim(AText) = '' then
  begin
    SetError('Texto para síntese OpenAI não pode ser vazio.');
    Exit(False);
  end;

  Result := True;
end;

function TAIVoiceSynthesizer.SayOpenAI(const AText: string): Boolean;
var
  Client: TFPHTTPClient;
  JSONPayload, ResponseText, Token, TargetFile: string;
  OutStream: TFileStream;
begin
  Result := False;
  if not ValidateOpenAIConfig(AText) then Exit(False);

  Token := Trim(FOpenAIToken);
  if Token = '' then
    Token := GetEnvironmentVariable('OPENAI_API_KEY');

  JSONPayload := '{"model":"' + JSONEscape(FOpenAIModel) + '",' +
                 '"input":"' + JSONEscape(AText) + '",' +
                 '"voice":"' + JSONEscape(FOpenAIVoice) + '",' +
                 '"response_format":"' + JSONEscape(FOpenAIOutputFormat) + '",' +
                 '"speed":' + StringReplace(FloatToStr(FSpeed), ',', '.', [rfReplaceAll]) + '}';

  if Trim(FOpenAIOutputFile) <> '' then
    TargetFile := FOpenAIOutputFile
  else
    TargetFile := IncludeTrailingPathDelimiter(GetTempDir) + 'speech_output.' + FOpenAIOutputFormat;

  Client := TFPHTTPClient.Create(nil);
  try
    try
      Client.AddHeader('Authorization', 'Bearer ' + Token);
      Client.AddHeader('Content-Type', 'application/json');
      Client.RequestBody := TStringStream.Create(JSONPayload);

      OutStream := TFileStream.Create(TargetFile, fmCreate);
      try
        Client.Post(FOpenAIEndpoint, OutStream);
        Result := FileExists(TargetFile) and (OutStream.Size > 0);
        if Result then
        begin
          FLastResult := TargetFile;
          FLastSuccess := True;
          Log(llInfo, 'Síntese de voz OpenAI concluída com sucesso: ' + TargetFile);
        end
        else
          SetError('Resposta vazia da API OpenAI TTS.');
      finally
        OutStream.Free;
        Client.RequestBody.Free;
      end;
    except
      on E: Exception do
      begin
        SetError('Erro na chamada da API OpenAI TTS: ' + E.Message);
        Result := False;
      end;
    end;
  finally
    Client.Free;
  end;
end;

procedure TAIVoiceSynthesizer.Say(const AText: string);
var
  SpeakText: string;
  {$IFDEF MSWINDOWS}
  Flags: Integer;
  {$ENDIF}
begin
  ClearError;
  if AText <> '' then
    SpeakText := AText
  else
    SpeakText := FText;

  if Trim(SpeakText) = '' then
  begin
    SetError('Texto para síntese de voz está vazio.');
    Exit;
  end;

  if FEngine = seOpenAI then
  begin
    SayOpenAI(SpeakText);
    Exit;
  end;

  if (FEngine = seSAPI) or ((FEngine = seSystemDefault) and
     {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}) then
  begin
    {$IFDEF MSWINDOWS}
    try
      if not FSpVoiceCreated then
      begin
        ActiveX.CoInitialize(nil);
        FSpVoice := CreateOleObject('SAPI.SpVoice');
        FSpVoiceCreated := True;
      end;

      if FVolume >= 0 then
        FSpVoice.Volume := FVolume;

      if (FRate >= -10) and (FRate <= 10) then
        FSpVoice.Rate := FRate;

      if FAsynchronous then
        Flags := 1 // SPF_ASYNC
      else
        Flags := 0;

      FSpVoice.Speak(SpeakText, Flags);
      FLastResult := 'Speech synthesis completed (SAPI)';
      FLastSuccess := True;
    except
      on E: Exception do
        SetError('Exceção ao sintetizar voz via SAPI: ' + E.Message);
    end;
    {$ELSE}
    SetError('SAPI é suportado apenas no sistema operacional Windows.');
    {$ENDIF}
  end
  else
  begin
    if not FInitialized then
    begin
      if not InitEspeak then Exit;
    end;

    if FInitialized and Assigned(espeak_Synth) then
    begin
      try
        if FVolume < 0 then FVolume := 0;
        if FVolume > 100 then FVolume := 100;
        if Assigned(espeak_SetVolume) then
          espeak_SetVolume(FVolume);

        if FRate < -10 then FRate := -10;
        if FRate > 10 then FRate := 10;
        if Assigned(espeak_SetRate) then
          espeak_SetRate(175 + (FRate * 12));

        if (FVoiceName <> '') and Assigned(espeak_SetVoiceByName) then
          espeak_SetVoiceByName(PAnsiChar(AnsiString(FVoiceName)));

        espeak_Synth(PAnsiChar(AnsiString(SpeakText)), Length(SpeakText) + 1, 0, 0, 0, 1, nil, nil);
        FLastResult := 'Speech synthesis completed (eSpeak)';
        FLastSuccess := True;
      except
        on E: Exception do
          SetError('Exceção ao sintetizar voz via eSpeak: ' + E.Message);
      end;
    end;
  end;
end;

procedure TAIVoiceSynthesizer.GetAvailableVoices(AList: TStrings);
var
  {$IFDEF MSWINDOWS}
  Voices: OleVariant;
  I: Integer;
  {$ENDIF}
  VoiceList: PPespeak_VOICE;
  VoicePtr: Pespeak_VOICE;
  Idx: Integer;
begin
  AList.Clear;
  ClearError;

  if (FEngine = seSAPI) or ((FEngine = seSystemDefault) and
     {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}) then
  begin
    {$IFDEF MSWINDOWS}
    try
      if not FSpVoiceCreated then
      begin
        ActiveX.CoInitialize(nil);
        FSpVoice := CreateOleObject('SAPI.SpVoice');
        FSpVoiceCreated := True;
      end;
      Voices := FSpVoice.GetVoices;
      for I := 0 to Voices.Count - 1 do
      begin
        try
          AList.Add(Voices.Item(I).GetAttribute('Name'));
        except
          try
            AList.Add(Voices.Item(I).GetDescription);
          except
          end;
        end;
      end;
      FLastResult := 'SAPI voices retrieved successfully';
      FLastSuccess := True;
    except
      on E: Exception do
        SetError('Exceção ao listar vozes via SAPI: ' + E.Message);
    end;
    {$ELSE}
    SetError('SAPI é suportado apenas no sistema operacional Windows.');
    {$ENDIF}
  end
  else
  begin
    if not FInitialized then
    begin
      if not InitEspeak then Exit;
    end;

    if FInitialized and Assigned(espeak_ListVoices) then
    begin
      try
        VoiceList := espeak_ListVoices(nil);
        if Assigned(VoiceList) then
        begin
          Idx := 0;
          while Assigned(VoiceList[Idx]) do
          begin
            VoicePtr := VoiceList[Idx];
            if Assigned(VoicePtr^.name) then
            begin
              AList.Add(string(VoicePtr^.name));
            end;
            Inc(Idx);
          end;
        end;
        FLastResult := 'eSpeak voices retrieved successfully';
        FLastSuccess := True;
      except
        on E: Exception do
          SetError('Exceção ao listar vozes via eSpeak: ' + E.Message);
      end;
    end;
  end;
end;

initialization
  {$I aivoicesynthesizer_icon.lrs}

end.
