program professor_audio_smoke;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Windows, ExtCtrls, LCLType,
  main, setmain, professor_view, professor_state, presentation_joints;
type
  TRunner=class(TComponent)
  public
    Timer: TTimer;
    View: TProfessorView;
    Started: QWord;
    Stage: Integer;
    SawTalking, SawThinking: Boolean;
    procedure Tick(Sender: TObject);
    procedure BeginStage(AStage: Integer; const Text: string);
    constructor Create(AOwner: TComponent); override;
  end;
var Runner: TRunner; Config: TStringList; ConfigDir: string;
procedure Check(B: Boolean; const Msg: string);
begin if not B then raise Exception.Create(Msg);end;
constructor TRunner.Create(AOwner: TComponent);
var I: Integer;
begin
  inherited;
  for I:=0 to frmmain.ComponentCount-1 do
    if frmmain.Components[I] is TProfessorView then View:=TProfessorView(frmmain.Components[I]);
  Check(View<>nil,'No 3D renderer');
  FSetMain.AutoSpeak:=True;FSetMain.SynthEngine:=3;
  FSetMain.VoiceAPIToken:='local-test-only';FSetMain.VoiceEndpoint:=ParamStr(1);
  FSetMain.VoiceModel:='test-tts';FSetMain.SynthVoice:='alloy';
  Timer:=TTimer.Create(Self);Timer.Interval:=20;Timer.OnTimer:=@Tick;
  BeginStage(0,'[sorriso] primeira [abaixar mao direita]');
end;
procedure TRunner.BeginStage(AStage: Integer; const Text: string);
begin
  Stage:=AStage;Started:=GetTickCount64;SawTalking:=False;SawThinking:=False;
  frmmain.FalarResposta(Text);
end;
procedure TRunner.Tick(Sender: TObject);
var Key: Word;
begin
  try
    Check(GetTickCount64-Started<10000,'UI audio test stalled');
    SawTalking:=SawTalking or ((View.State=psSpeaking) and TPresentationScene(View.Scene).Speaking);
    SawThinking:=SawThinking or (View.State=psThinking);
    if frmmain.ApresentandoResposta then
    begin
      Check(not frmmain.edPergunta.Enabled,'Input enabled during speech');
      if (Stage=2) and SawTalking then
      begin
        Key:=VK_ESCAPE;frmmain.OnKeyDown(frmmain,Key,[]);
        Stage:=3;
      end;
      Exit;
    end;
    Check(frmmain.edPergunta.Enabled and frmmain.btConfig.Enabled,'Input did not recover');
    Check(not TPresentationScene(View.Scene).Speaking,'Avatar kept talking after job completion');
    case Stage of
      0: begin
        Check(SawTalking and SawThinking,'Missing preparation state or speech mouth activity');
        WriteLn('PASS: remote TTS drives preparation and speech mouth without replacing a JSON gesture; input recovers');
        BeginStage(1,'[sorriso] fail');
      end;
      1: begin
        Check(not SawTalking,'Failed synthesis animated speech');
        Check(Pos('Pronto',frmmain.lblStatus.Caption)<>1,'Voice failure hidden');
        WriteLn('PASS: synthesis error returns UI and avatar to ready');
        BeginStage(2,'[levantar mao direita] cancel');
      end;
      3: begin
        Check(not TPresentationScene(View.Scene).TimelineHasPose,'Cancel left a JSON pose active');
        WriteLn('PASS: Escape during remote playback clears pose and restores input');
        Timer.Enabled:=False;Application.Terminate;
      end;
    else raise Exception.Create('Playback ended before cancellation');end;
  except on E: Exception do
    begin WriteLn('FAIL: '+E.Message);ExitCode:=1;Timer.Enabled:=False;Application.Terminate;end;
  end;
end;
begin
  Check(ParamCount=1,'Pass local mock endpoint');
  ConfigDir:=SysUtils.GetEnvironmentVariable('ASSISTENTE_CONFIG_DIR');
  if ConfigDir='' then ConfigDir:=ExtractFilePath(ParamStr(0))+'audio-smoke-config';
  ForceDirectories(ConfigDir);
  Windows.SetEnvironmentVariable(PChar('ASSISTENTE_CONFIG_DIR'),PChar(ConfigDir));
  Config:=TStringList.Create;
  try
    Config.Add('CONTINUOUS_LISTENING:0');Config.Add('AUTOSPEAK:0');Config.Add('VISION_SOURCE:none');
    Config.Add('AVATAR3D_PROFILE:professor');Config.Add('AVATAR3D_AUTO_IDLE:1');
    Config.SaveToFile(IncludeTrailingPathDelimiter(ConfigDir)+'Setmain.cfg');
  finally Config.Free;end;
  RequireDerivedFormResource:=True;Application.Initialize;
  Application.CreateForm(Tfrmmain,frmmain);frmmain.Show;
  Runner:=TRunner.Create(frmmain);Application.Run;frmmain.Free;
end.
