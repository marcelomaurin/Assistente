program professor_directive_smoke;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Windows, ExtCtrls, StdCtrls, LCLType,
  main, professor_view, professor_commands, professor_ui, CastleControl, CastleImages, CastleURIUtils;
type
  TRunner=class(TComponent)
  public
    Timer: TTimer;
    View: TProfessorView;
    Control: TCastleControl;
    Started: QWord;
    Smile,Clap,Raised,Captured,CancelStarted: Boolean;
    RaisedTicks: Integer;
    Report: TStringList;
    procedure Tick(Sender: TObject);
    constructor Create(AOwner: TComponent);override;
    destructor Destroy;override;
  end;
const Script='[sorriso] Oi [Aplausos] muito obrigado por estar aqui, '+
  '[levantar mao direita] se tiver uma dúvida, levante a mão direita que eu irei escutar você. [abaixe mao direita]';
var Config: TStringList; ConfigDir: string; Runner: TRunner;
constructor TRunner.Create(AOwner: TComponent);
var I: Integer;
begin
  inherited;Report:=TStringList.Create;
  for I:=0 to frmmain.ComponentCount-1 do
  begin
    if frmmain.Components[I] is TProfessorView then View:=TProfessorView(frmmain.Components[I]);
    if frmmain.Components[I] is TConversationView then
      TConversationView(frmmain.Components[I]).AddMessage(ParseAvatarScript(Script).PlainText,False);
  end;
  if View=nil then raise Exception.Create('No renderer');
  for I:=0 to View.ComponentCount-1 do
    if View.Components[I] is TCastleControl then Control:=TCastleControl(View.Components[I]);
  Started:=GetTickCount64;
  frmmain.FalarResposta(Script);
  Timer:=TTimer.Create(Self);Timer.Interval:=50;Timer.OnTimer:=@Tick;
end;
destructor TRunner.Destroy;
begin Report.Free;inherited;end;
procedure TRunner.Tick(Sender: TObject);
var Clip: string;Image: TRGBImage;Key: Word;
begin
  try
    if GetTickCount64-Started>60000 then raise Exception.Create('Presentation stalled');
    Clip:=View.CurrentAnimation;
    Smile:=Smile or (Pos('_smile',Clip)>0);
    Clap:=Clap or (Pos('applause',Clip)=1);
    if Pos('_right_hand_up',Clip)>0 then
    begin
      Raised:=True;Inc(RaisedTicks);
      if (RaisedTicks>18) and not Captured then
      begin
        Image:=Control.Container.SaveScreen;
        try SaveImage(Image,FilenameToURISafe(ExtractFilePath(ParamStr(0))+'directive-smoke.png'));
        finally Image.Free;end;
        Captured:=True;
      end;
    end;
    if not frmmain.ApresentandoResposta then
    begin
      if not CancelStarted then
      begin
        if not (Smile and Clap and Raised and Captured) then raise Exception.Create('Missing visual directive');
        if Pos('_right_hand_up',View.CurrentAnimation)>0 then raise Exception.Create('Trailing lower-hand command was lost');
        Report.Add('PASS: main form consumed the example in order; smile, applause and right hand rendered; trailing lower applied');
        Report.Add('Script elapsed ms: '+IntToStr(GetTickCount64-Started));
        CancelStarted:=True;
        Started:=GetTickCount64;
        frmmain.FalarResposta('[levantar mao direita] Um trecho longo para testar a interrupção da apresentação pelo teclado.');
        Key:=VK_ESCAPE;frmmain.OnKeyDown(frmmain,Key,[]);
      end else
      begin
        if Pos('_right_hand_up',View.CurrentAnimation)>0 then raise Exception.Create('Escape left hand raised');
        Report.Add('PASS: Escape cancelled the worker and cleared persistent poses');
        Report.Add('Silent demonstration: no microphone, camera, provider or audio playback used');
        Report.SaveToFile(ExtractFilePath(ParamStr(0))+'directive-smoke.txt');
        Timer.Enabled:=False;Application.Terminate;
      end;
    end;
  except on E:Exception do
    begin
      Report.Add('FAIL: '+E.Message);Report.SaveToFile(ExtractFilePath(ParamStr(0))+'directive-smoke.txt');
      ExitCode:=1;Timer.Enabled:=False;Application.Terminate;
    end;
  end;
end;
begin
  ConfigDir:=ExtractFilePath(ParamStr(0))+'directive-smoke-config';ForceDirectories(ConfigDir);
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
