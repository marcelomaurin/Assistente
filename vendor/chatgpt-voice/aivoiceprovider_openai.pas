unit aivoiceprovider_openai;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  aivoiceprovider_types, aivoiceprovider_backend;

type
  { TAIOpenAIVoiceBackend: OpenAI official Speech API (/v1/audio/speech) backend }
  TAIOpenAIVoiceBackend = class(TAIVoiceProviderBackendBase)
  public
    function ValidateConfig(const AConfig: TAIVoiceConfig; const AText: string; out AErrorMsg: string): Boolean; override;
    function Synthesize(const AConfig: TAIVoiceConfig; const AText, AOutputFile: string; out AErrorMsg: string): Boolean; override;
  end;

implementation

function TAIOpenAIVoiceBackend.ValidateConfig(const AConfig: TAIVoiceConfig; const AText: string; out AErrorMsg: string): Boolean;
begin
  Result := False;
  AErrorMsg := '';

  if Trim(AConfig.APIToken) = '' then
  begin
    AErrorMsg := 'OpenAI API Token is required.';
    FLastError := AErrorMsg;
    Exit;
  end;

  if Trim(AText) = '' then
  begin
    AErrorMsg := 'Text to synthesize is empty.';
    FLastError := AErrorMsg;
    Exit;
  end;

  if Trim(AConfig.Endpoint) = '' then
  begin
    AErrorMsg := 'OpenAI Speech endpoint is required.';
    FLastError := AErrorMsg;
    Exit;
  end;

  if Trim(AConfig.Model) = '' then
  begin
    AErrorMsg := 'OpenAI Model is required (e.g. tts-1, tts-1-hd).';
    FLastError := AErrorMsg;
    Exit;
  end;

  if Trim(AConfig.RemoteVoice) = '' then
  begin
    AErrorMsg := 'OpenAI Voice is required (e.g. alloy, echo, fable, onyx, nova, shimmer).';
    FLastError := AErrorMsg;
    Exit;
  end;

  if (AConfig.Speed < 0.25) or (AConfig.Speed > 4.0) then
  begin
    AErrorMsg := Format('Speed %0.2f out of range (allowed: 0.25 to 4.0).', [AConfig.Speed]);
    FLastError := AErrorMsg;
    Exit;
  end;

  Result := True;
end;

function TAIOpenAIVoiceBackend.Synthesize(const AConfig: TAIVoiceConfig; const AText, AOutputFile: string; out AErrorMsg: string): Boolean;
var
  Payload: string;
  EscapedInput: string;
  SpeedStr: string;
  FormatStr: string;
  TargetFile: string;
begin
  Result := False;
  AErrorMsg := '';

  if not ValidateConfig(AConfig, AText, AErrorMsg) then
    Exit;

  TargetFile := AOutputFile;
  if Trim(TargetFile) = '' then
    TargetFile := AConfig.OutputFile;
  if Trim(TargetFile) = '' then
    TargetFile := IncludeTrailingPathDelimiter(GetTempDir) + 'assistente_speech.mp3';

  FormatStr := LowerCase(Trim(AConfig.OutputFormat));
  if FormatStr = '' then
    FormatStr := 'mp3';

  EscapedInput := JSONEscape(AText);
  SpeedStr := Format('%0.2f', [AConfig.Speed]);
  SpeedStr := StringReplace(SpeedStr, ',', '.', []);

  // OpenAI Speech API payload (/v1/audio/speech aceita apenas model, input, voice, response_format, speed)
  Payload := '{' +
    '"model": "' + JSONEscape(AConfig.Model) + '",' +
    '"input": "' + EscapedInput + '",' +
    '"voice": "' + JSONEscape(AConfig.RemoteVoice) + '",' +
    '"response_format": "' + JSONEscape(FormatStr) + '",' +
    '"speed": ' + SpeedStr +
    '}';

  Result := ExecuteHTTPRequest(
    AConfig.Endpoint,
    Payload,
    AConfig.APIToken,
    TargetFile,
    AConfig.TimeoutMS,
    AConfig.MaxRetries,
    AErrorMsg
  );
end;

end.
