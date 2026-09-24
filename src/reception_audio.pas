unit reception_audio;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, aiaudio;
type
  TReceptionMicrophone = class
  private
    FInput: TAIAudioInput;
    FPCM: TMemoryStream;
    FRoot, FChunk: string;
    FStarted: QWord;
    FVoiced, FSilence: Integer;
    FWasSpeech: Boolean;
  public
    Threshold: Integer;
    constructor Create(const ARoot: string);
    destructor Destroy; override;
    function Start: Boolean;
    procedure Stop;
    function Poll(out AFile: string; out ASpeechStarted: Boolean): Boolean;
    function LastError: string;
    property Input: TAIAudioInput read FInput;
  end;
function ReadPCM16(const AFile: string; AData: TStream; out ARMS: Double): Boolean;
procedure WritePCM16(const AFile: string; AData: TStream);
implementation
uses Math;

function ReadPCM16(const AFile: string; AData: TStream; out ARMS: Double): Boolean;
var S: TFileStream; ID: array[0..3] of Char; Size, Rate: LongWord;
    FormatCode, Channels, Bits: Word; NextPos: Int64; Sample: SmallInt;
    Count, I: Integer; Sum: Double; Valid: Boolean;
begin
  Result := False; ARMS := 0; Valid := False;
  S := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
  try
    if S.Size < 44 then Exit;
    S.ReadBuffer(ID, 4); if string(ID) <> 'RIFF' then Exit;
    S.Position := 8; S.ReadBuffer(ID, 4); if string(ID) <> 'WAVE' then Exit;
    while S.Position + 8 <= S.Size do
    begin
      S.ReadBuffer(ID, 4); S.ReadBuffer(Size, 4);
      NextPos := S.Position + Size + (Size mod 2);
      if S.Position + Size > S.Size then Exit;
      if (string(ID) = 'fmt ') and (Size >= 16) then
      begin
        S.ReadBuffer(FormatCode, 2); S.ReadBuffer(Channels, 2); S.ReadBuffer(Rate, 4);
        S.Position := S.Position + 6; S.ReadBuffer(Bits, 2);
        Valid := (FormatCode = 1) and (Channels = 1) and (Rate = 16000) and (Bits = 16);
      end
      else if (string(ID) = 'data') and Valid then
      begin
        Count := Size div 2;
        if Count = 0 then Exit;
        Sum := 0;
        for I := 1 to Count do
        begin
          S.ReadBuffer(Sample, 2); Sum := Sum + Sqr(Double(Sample));
          AData.WriteBuffer(Sample, 2);
        end;
        ARMS := Sqrt(Sum / Count);
        Exit(True);
      end;
      S.Position := NextPos;
    end;
  finally S.Free; end;
end;

procedure WritePCM16(const AFile: string; AData: TStream);
var S: TFileStream; N: LongWord; W: Word;
begin
  S := TFileStream.Create(AFile, fmCreate);
  try
    S.WriteBuffer('RIFF', 4); N := AData.Size + 36; S.WriteBuffer(N, 4);
    S.WriteBuffer('WAVEfmt ', 8); N := 16; S.WriteBuffer(N, 4);
    W := 1; S.WriteBuffer(W, 2); S.WriteBuffer(W, 2);
    N := 16000; S.WriteBuffer(N, 4); N := 32000; S.WriteBuffer(N, 4);
    W := 2; S.WriteBuffer(W, 2); W := 16; S.WriteBuffer(W, 2);
    S.WriteBuffer('data', 4); N := AData.Size; S.WriteBuffer(N, 4);
    AData.Position := 0; S.CopyFrom(AData, AData.Size);
  finally S.Free; end;
end;

constructor TReceptionMicrophone.Create(const ARoot: string);
begin
  inherited Create;
  FRoot := IncludeTrailingPathDelimiter(ARoot);
  ForceDirectories(FRoot);
  FChunk := FRoot + 'capture.wav';
  FInput := TAIAudioInput.Create(nil);
  FInput.SampleRate := 16000; FInput.Channels := 1;
  FPCM := TMemoryStream.Create;
  Threshold := 450;
end;
destructor TReceptionMicrophone.Destroy;
begin Stop; FPCM.Free; FInput.Free; inherited Destroy; end;
function TReceptionMicrophone.Start: Boolean;
begin
  if FInput.Recording then Exit(True);
  Result := FInput.StartRecord(FChunk); FStarted := GetTickCount64;
end;
procedure TReceptionMicrophone.Stop;
begin
  FInput.StopRecord; DeleteFile(FChunk); FPCM.Clear;
  FVoiced := 0; FSilence := 0; FWasSpeech := False;
end;
function TReceptionMicrophone.LastError: string;
begin Result := FInput.LastError; end;
function TReceptionMicrophone.Poll(out AFile: string; out ASpeechStarted: Boolean): Boolean;
var Chunk: TMemoryStream; RMS: Double; Voice: Boolean;
begin
  Result := False; AFile := ''; ASpeechStarted := False;
  if not FInput.Recording or (GetTickCount64 - FStarted < 700) then Exit;
  FInput.StopRecord;
  Chunk := TMemoryStream.Create;
  try
    if FileExists(FChunk) and ReadPCM16(FChunk, Chunk, RMS) then
    begin
      Voice := RMS >= Threshold;
      ASpeechStarted := Voice and not FWasSpeech;
      if Voice then begin Inc(FVoiced); FSilence := 0; end
      else if FVoiced > 0 then Inc(FSilence);
      if Voice or (FVoiced > 0) then
      begin Chunk.Position := 0; FPCM.CopyFrom(Chunk, Chunk.Size); end;
      FWasSpeech := Voice;
      if (FVoiced > 0) and ((FSilence >= 2) or (FPCM.Size >= 32000 * 20)) then
      begin
        AFile := FRoot + 'utterance-' + IntToStr(GetTickCount64) + '.wav';
        WritePCM16(AFile, FPCM);
        FPCM.Clear; FVoiced := 0; FSilence := 0;
        Result := True;
      end;
    end;
  finally Chunk.Free; DeleteFile(FChunk); end;
  Start;
end;
end.
