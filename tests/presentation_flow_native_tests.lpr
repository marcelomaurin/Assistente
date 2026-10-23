program presentation_flow_native_tests;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Classes,SysUtils,Windows,ExtCtrls,main,agent_manager,
  presentation_package,presentation_rag,presentation_flow,voice_input_bridge;
type
  TRunner = class
    Timer: TTimer;
    Phase: Integer;
    Started,PhaseStarted: QWord;
    SawOne,SawTwo,SawSound,SawReturn: Boolean;
    Report: TStringList;
    procedure Tick(Sender: TObject);
    procedure Submit(const Text: string; Voice: Boolean=False);
  end;
var Root,Config: string; Runner: TRunner; Settings: TStringList;
procedure Check(B: Boolean; const E: string);
begin if not B then raise Exception.Create(E);end;
procedure TRunner.Submit(const Text: string; Voice: Boolean);
begin
  PhaseStarted:=GetTickCount64;SawOne:=False;SawTwo:=False;SawSound:=False;SawReturn:=False;
  if Voice then frmmain.VoiceInput.OnText(nil,Text)
  else begin frmmain.edPergunta.Text:=Text;frmmain.btEnviarClick(nil);end;
end;
procedure TRunner.Tick(Sender: TObject);
var Active: string;
begin
  try
    Check(GetTickCount64-Started<30000,'native flow timeout');
    Active:=frmmain.ActivePresentationMedia;
    Check(Active<>'assets/forbidden.png','uninvoked/event block executed');
    SawReturn:=SawReturn or (SawTwo and (Active='assets/one.png'));
    SawOne:=SawOne or (Active='assets/one.png');SawTwo:=SawTwo or (Active='assets/two.png');
    SawSound:=SawSound or (frmmain.ActivePresentationSound<>'');
    if frmmain.ApresentandoResposta then Exit;
    if GetTickCount64-PhaseStarted<=50 then Exit;
    case Phase of
      0: begin
        Check(SawOne and SawTwo and SawReturn,'GOTO / nested return path missing images');
        Check(frmmain.LoadedFlow.EventCount=4,'loaded event bindings missing');
        Check(ExtractFileName(frmmain.LoadedDocument)='Demonstracao.pva','loaded source not retained');
        Report.Add('PASS: typed fuzzy load; GOTO, returning calls, block boundaries, four dormant events; source retained');
        Inc(Phase);Submit('chamar bloco {Rapido}.',True);
      end;
      1: begin
        Check(SawOne and SawSound,'transcribed call did not execute block: '+frmmain.lblStatus.Caption);
        Check(GetTickCount64-PhaseStarted<2200,'FIM waited for trailing sound instead of ending');
        Check((frmmain.ActivePresentationSound='') and (Active=''),'FIM left media open');
        Report.Add('PASS: transcribed voice command calls loaded block; FIM stops audio/media and ignores remaining block text');
        Inc(Phase);Submit('chamar bloco Outro');
      end;
      2: begin
        Check(SawTwo and not SawOne,'typed direct block call failed');
        Inc(Phase);Submit('carregar arquivo Conhecimento');
      end;
      3: begin
        Check((frmmain.LoadedFlow=nil) and (ExtractFileName(frmmain.LoadedDocument)='Conhecimento.rag'),'traditional document did not replace loaded script');
        Check(not SawOne and not SawTwo,'RAG executed control tags');
        Submit('chamar bloco Rapido');Check(not frmmain.ApresentandoResposta,'RAG allowed old script block');
        Check(Pos('Carregue primeiro',frmmain.lblStatus.Caption)>0,'missing RAG/block error');
        Inc(Phase);Submit('carregar arquivo roteiro');
      end;
      4: begin
        Check(SawTwo,'raw text script did not run');
        Check(ExtractFileName(frmmain.LoadedDocument)='roteiro.script','raw script not retained');
        Report.Add('PASS: typed direct call; traditional RAG stays data, clears old blocks; raw .script executes');
        Inc(Phase);Submit('carregar arquivo Conhecimento');
      end;
      5: begin Inc(Phase);Submit('Qual e o marcador do documento carregado?');end;
      6: begin
        Check(frmmain.AssistantManager.State<>asError,'knowledge question failed');
        if Pos('Resposta baseada no documento',frmmain.memResposta.Lines.Text)=0 then Exit;
        Check(frmmain.AssistantManager.SelectedPresentation='','knowledge question selected a presentation');
        Report.Add('PASS: loaded traditional RAG supplies knowledge to real agent, without running control tags or selecting a script');
        Report.SaveToFile(Root+PathDelim+'flow-native-result.txt');Timer.Enabled:=False;Application.Terminate;
      end;
    end;
  except on E: Exception do begin
    Report.Add('FAIL: '+E.Message);Report.SaveToFile(Root+PathDelim+'flow-native-result.txt');
    ExitCode:=1;Timer.Enabled:=False;Application.Terminate;
  end;end;
end;
begin
  Root:=ExpandFileName(ParamStr(1));Config:=Root+PathDelim+'config';ForceDirectories(Config);
  SetEnvironmentVariableW('ASSISTENTE_CONFIG_DIR',PWideChar(UTF8Decode(Config)));
  Settings:=TStringList.Create;
  try
    Settings.Add('CONTINUOUS_LISTENING:0');Settings.Add('AUTOSPEAK:0');Settings.Add('VISION_SOURCE:none');
    Settings.Add('AVATAR3D_PROFILE:custom');Settings.Add('AVATAR3D_MODEL:'+ParamStr(2));
    Settings.SaveToFile(Config+PathDelim+'Setmain.cfg');
  finally Settings.Free;end;
  RequireDerivedFormResource:=True;Application.Initialize;Application.CreateForm(Tfrmmain,frmmain);frmmain.Show;
  frmmain.AssistantManager.ChatGPT.TOKEN:='local-test';frmmain.AssistantManager.ChatGPT.CustomModel:='local-test';
  frmmain.AssistantManager.ChatGPT.URL:=UTF8Decode(ParamStr(3));frmmain.AssistantManager.ChatGPT.Timeout:=5000;
  Runner:=TRunner.Create;Runner.Report:=TStringList.Create;
  try
    Runner.Started:=GetTickCount64;Runner.Timer:=TTimer.Create(nil);Runner.Timer.Interval:=25;Runner.Timer.OnTimer:=@Runner.Tick;
    Runner.Submit('carregar arquivo demonstracaoo');Application.Run;
  finally Runner.Timer.Free;Runner.Report.Free;Runner.Free;frmmain.Free;end;
end.
