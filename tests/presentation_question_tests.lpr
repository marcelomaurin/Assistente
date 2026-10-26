program presentation_question_tests;
{$mode objfpc}{$H+}{$codepage utf8}
uses Interfaces,Forms,Classes,SysUtils,Windows,ExtCtrls,StdCtrls,Controls,Types,Graphics,main,professor_view,CastleControl,CastleImages,CastleURIUtils,
 presentation_package,presentation_tags,presentation_document,presentation_flow,presentation_questions;
type TRunner=class
 Timer:TTimer;Phase,LastTrace:Integer;Started,HoverStarted,OffAt:QWord;HoverReset,HoverReentered:Boolean;Root:string;Button:TButton;
 procedure Tick(Sender:TObject);
 procedure Submit(const Text:string;Voice:Boolean=False);
 procedure CheckLayout;
 procedure Capture;
end;
var Runner:TRunner;Settings:TStringList;Root,Config:string;Tag:TPresentationTag;OldCursor:TPoint;
procedure Check(B:Boolean;const Msg:string);
begin if not B then raise Exception.Create(Msg);end;
procedure TRunner.Submit(const Text:string;Voice:Boolean);
begin if Voice then frmmain.VoiceInput.OnText(nil,Text) else begin frmmain.edPergunta.Text:=Text;frmmain.btEnviarClick(nil);end;end;
procedure TRunner.CheckLayout;
var Media:TControl;Composer:TControl;
begin
 Media:=TControl(frmmain.FindComponent('PresentationMediaPanel'));Composer:=frmmain.edPergunta.Parent;
 Check(Composer.Visible and frmmain.edPergunta.Enabled,'Input hidden/disabled while waiting');
 Check(Media.Top+Media.Height<Composer.Top,'Media covers composer');
 Check(frmmain.QuestionAnswer.Top+frmmain.QuestionAnswer.Height<Composer.Top,'Answer covers composer');
 Check(frmmain.btConfig.Visible,'Settings hidden by presentation');
end;
procedure TRunner.Capture;
var I,J:Integer;View:TProfessorView;Control:TCastleControl;Shot:TRGBImage;Frame:TBitmap;Picture:TPicture;Origin:TPoint;
begin
 Control:=nil;
 for I:=0 to frmmain.ComponentCount-1 do if frmmain.Components[I] is TProfessorView then begin
  View:=TProfessorView(frmmain.Components[I]);
  for J:=0 to View.ComponentCount-1 do if View.Components[J] is TCastleControl then Control:=TCastleControl(View.Components[J]);
 end;
 if Control=nil then Exit;
 Shot:=Control.Container.SaveScreen;try SaveImage(Shot,FilenameToURISafe(Root+PathDelim+'avatar.png'));finally Shot.Free;end;
 Frame:=frmmain.GetFormImage;Picture:=TPicture.Create;
 try Picture.LoadFromFile(Root+PathDelim+'avatar.png');Origin:=frmmain.ScreenToClient(Control.ClientToScreen(Point(0,0)));
  Frame.Canvas.Draw(Origin.X,Origin.Y,Picture.Graphic);Frame.SaveToFile(Root+PathDelim+'perguntas-menu.bmp');
 finally Picture.Free;Frame.Free;end;
end;
procedure TRunner.Tick(Sender:TObject);
var K:Word;P:TPoint;UpButton,DownButton:TButton;Character:Char;
begin
 try
  if Phase<>LastTrace then begin LastTrace:=Phase;WriteLn('PHASE ',Phase);Flush(Output);end;
  Check(GetTickCount64-Started<60000,'Timed out in phase '+IntToStr(Phase)+': '+frmmain.lblStatus.Caption);
  case Phase of
   0:if frmmain.WaitingForQuestion then begin
    Check(frmmain.ActivePresentationMedia='assets/one.png','PERGUNTAR lost image');CheckLayout;
    Check(Button.Parent=frmmain.pnlHeader,'Perguntar is not in header');
    Check(Button.Left>frmmain.btConfig.Left,'Header controls order');
    Button.Click;Check(frmmain.WaitingForQuestion,'Perguntar resumed instead of accepting questions');
    Submit('Qual e o codigo da aula?');Phase:=1;
   end;
   1:if frmmain.WaitingForQuestion and (Pos('CODIGO_AULA_927',frmmain.QuestionAnswer.Text)>0) then begin
    Check(frmmain.ActivePresentationMedia='assets/one.png','AI answer resumed or changed presentation');
    Submit('IR Detalhes',True);Phase:=2;
   end;
   2:if frmmain.WaitingForQuestion and frmmain.BlockMenu.Visible then begin
    Check(frmmain.ActivePresentationMedia='','MENU did not close previous visual');
    Check(frmmain.ActivePresentationSound='','MENU did not close previous sound');
    Check(not TControl(frmmain.FindComponent('PresentationMediaPanel')).Visible,'MENU still shows media');
    Check(frmmain.BlockMenu.Items.Count=43,'MENU missing blocks');
    Button.Click;Check(not frmmain.BlockMenu.Visible and frmmain.WaitingForQuestion,'Header Perguntar should accept questions');
    TButton(frmmain.FindComponent('PresentationMenuButton')).Click;
    Check(frmmain.BlockMenu.Visible,'Header Menu should reopen block list');CheckLayout;Capture;
    DownButton:=TButton(frmmain.FindComponent('MenuScrollDown'));UpButton:=TButton(frmmain.FindComponent('MenuScrollUp'));
    DownButton.Click;Check(frmmain.BlockMenu.TopIndex>0,'Bottom button does not scroll');
    UpButton.OnClick(UpButton);Check(frmmain.BlockMenu.TopIndex=0,'Top button does not scroll');
    K:=VK_END;frmmain.BlockMenu.OnKeyDown(frmmain.BlockMenu,K,[]);
    Check((frmmain.BlockMenu.ItemIndex=42) and (frmmain.BlockMenu.TopIndex>0),'Keyboard cannot reach offscreen blocks');
    Check(frmmain.WaitingForQuestion,'Arrow key executed a block');
    K:=VK_HOME;frmmain.BlockMenu.OnKeyDown(frmmain.BlockMenu,K,[]);
    Character:='I';frmmain.BlockMenu.OnKeyPress(frmmain.BlockMenu,Character);
    Check(frmmain.edPergunta.Text='I','Cannot start typing IR while menu has focus');frmmain.edPergunta.Clear;
    frmmain.BlockMenu.OnMouseUp(frmmain.BlockMenu,mbLeft,[],10,frmmain.BlockMenu.ItemHeight+frmmain.BlockMenu.ItemHeight div 2);Phase:=3;
   end;
   3:if frmmain.WaitingForQuestion and not frmmain.BlockMenu.Visible and (frmmain.ActivePresentationMedia='assets/detail.png') then begin
    Submit('[CONTINUAR]');Phase:=4;
   end;
   4:if frmmain.WaitingForQuestion and (frmmain.ActivePresentationMedia='assets/three.png') then begin
    Submit('IR {Referencia}');Phase:=20;
   end;
   20:if frmmain.WaitingForQuestion and (frmmain.ActivePresentationMedia='assets/three.png') then begin
    Submit('IR {Nao existe}');Check(frmmain.WaitingForQuestion,'Invalid block left question mode');
    Check(Pos('Bloco nao encontrado',frmmain.lblStatus.Caption)>0,'Missing invalid block error');
    TButton(frmmain.FindComponent('PresentationMenuButton')).Click;
    K:=VK_HOME;frmmain.BlockMenu.OnKeyDown(frmmain.BlockMenu,K,[]);
    K:=VK_DOWN;frmmain.BlockMenu.OnKeyDown(frmmain.BlockMenu,K,[]);
    K:=VK_DOWN;frmmain.BlockMenu.OnKeyDown(frmmain.BlockMenu,K,[]);
    Check(frmmain.BlockMenu.Visible and (frmmain.BlockMenu.ItemIndex=2),'Keyboard navigation executed early');
    K:=VK_RETURN;frmmain.BlockMenu.OnKeyDown(frmmain.BlockMenu,K,[]);Phase:=21;
   end;
   21:if frmmain.WaitingForQuestion and not frmmain.BlockMenu.Visible then begin
    Check(frmmain.ActivePresentationMedia='','Menu did not replace media');Submit('MENU');
    P:=frmmain.BlockMenu.ClientToScreen(Types.Point(10,frmmain.BlockMenu.ItemHeight div 2));
    Windows.SetCursorPos(P.X,P.Y);HoverStarted:=GetTickCount64;Phase:=22;
   end;
   22:begin
    if not HoverReset and (GetTickCount64-HoverStarted>2500) then begin
      Check(frmmain.BlockMenu.Visible,'Hover activated before five seconds');Windows.SetCursorPos(0,0);OffAt:=GetTickCount64;HoverReset:=True;
    end;
    if HoverReset and not HoverReentered and (GetTickCount64-OffAt>250) then begin
      P:=frmmain.BlockMenu.ClientToScreen(Types.Point(10,frmmain.BlockMenu.ItemHeight div 2));Windows.SetCursorPos(P.X,P.Y);
      HoverStarted:=GetTickCount64;HoverReentered:=True;
    end;
    if HoverReentered then begin
      if GetTickCount64-HoverStarted<4900 then Check(frmmain.BlockMenu.Visible,'Leaving item did not reset hover countdown');
      if not frmmain.BlockMenu.Visible then begin Check(GetTickCount64-HoverStarted>=5000,'Hover activated too early');Phase:=5;end;
    end;
   end;
   5:if not frmmain.ApresentandoResposta then begin
    Check(frmmain.ActivePresentationMedia='','FIM did not close image');
    frmmain.StartPresentation(Root+PathDelim+'manual.pva');Phase:=6;
   end;
   6:if frmmain.ActivePresentationMedia='assets/one.png' then begin
    Check(Button.Caption='Perguntar','Missing manual question button');Button.Click;
    Check(frmmain.WaitingForQuestion,'Manual pause failed');CheckLayout;
    Submit('Qual e o codigo da aula?',True);Phase:=7;
   end;
   7:if frmmain.WaitingForQuestion and not frmmain.AskingPresentation then begin
    Submit('[CONTINUAR]');Check(not frmmain.WaitingForQuestion,'Manual resume failed');
    K:=VK_ESCAPE;frmmain.OnKeyDown(frmmain,K,[]);Phase:=8;
   end;
   8:if not frmmain.ApresentandoResposta then begin
    Check(not frmmain.WaitingForQuestion and (frmmain.ActivePresentationMedia=''),'Cancel left paused jobs/media');
    frmmain.StartPresentation(Root+PathDelim+'video.pva');Phase:=9;
   end;
   9:if TButton(frmmain.FindComponent('StopPresentationVideoButton')).Visible then begin
    TButton(frmmain.FindComponent('StopPresentationVideoButton')).Click;
    Check(frmmain.ActivePresentationMedia='','Video dismissal did not close media');
    Check(frmmain.WaitingForQuestion,'Video dismissal did not preserve presentation pause');
    Check(not TButton(frmmain.FindComponent('StopPresentationVideoButton')).Visible,'Stop video button remains after close');
    Submit('CONTINUAR');Phase:=10;
   end;
   10:if frmmain.WaitingForQuestion and (frmmain.ActivePresentationMedia='assets/two.png') then begin
    K:=VK_ESCAPE;frmmain.OnKeyDown(frmmain,K,[]);
    frmmain.StartPresentation(Root+PathDelim+'local-video.pva');Phase:=11;
   end;
   11:if TButton(frmmain.FindComponent('StopPresentationVideoButton')).Visible then begin
    TButton(frmmain.FindComponent('StopPresentationVideoButton')).Click;
    Check(frmmain.ActivePresentationMedia='','Local video remains open');
    Check(frmmain.WaitingForQuestion,'Local video close did not pause');
    K:=VK_ESCAPE;frmmain.OnKeyDown(frmmain,K,[]);
    Timer.Enabled:=False;WriteLn('PASS: local video and header Menu/Perguntar, video dismissal and resume, PERGUNTAR, contextual AI without playback commands, voice IR, MENU replaces media, 43 blocks, scroll buttons, arrows/Enter, click, five-second dwell/reset, nested CONTINUAR, invalid target, manual pause, resume, cancel and separate input/media');Application.Terminate;
   end;
  end;
 except on E:Exception do begin WriteLn('FAIL: phase ',Phase,': ',E.Message);ExitCode:=1;Timer.Enabled:=False;Application.Terminate;end;end;
end;
begin
 try
  Check(TryParsePresentationTag('[PERGUNTAR]',Tag) and (Tag.Action=paAsk),'PERGUNTAR parser');
  Check(TryParsePresentationTag('[CONTINUAR]',Tag) and (Tag.Action=paContinue),'CONTINUAR parser');
  Check(TryParsePresentationTag('[MENU]',Tag) and (Tag.Action=paMenu),'MENU parser');
  ValidatePresentationScript('Pergunta[PERGUNTAR][MENU][BLOCO:Detalhes]Resposta[CONTINUAR]');
  Root:=ExpandFileName(ParamStr(1));Config:=Root+PathDelim+'config';ForceDirectories(Config);
  SetEnvironmentVariableW('ASSISTENTE_CONFIG_DIR',PWideChar(UTF8Decode(Config)));Settings:=TStringList.Create;
  try Settings.Add('CONTINUOUS_LISTENING:0');if ParamStr(3)='speech' then begin Settings.Add('AUTOSPEAK:1');Settings.Add('SYNTHENGINE:3');Settings.Add('VOICEAPITOKEN:local-test');Settings.Add('VOICEENDPOINT:'+ParamStr(2));Settings.Add('SYNTHVOICE:alloy');end else Settings.Add('AUTOSPEAK:0');Settings.Add('VISION_SOURCE:none');Settings.Add('AVATAR3D_PROFILE:professor');Settings.SaveToFile(Config+PathDelim+'Setmain.cfg');finally Settings.Free;end;
  RequireDerivedFormResource:=True;Application.Initialize;Application.CreateForm(Tfrmmain,frmmain);frmmain.Show;
  frmmain.AssistantManager.ChatGPT.TOKEN:='local-test';frmmain.AssistantManager.ChatGPT.CustomModel:='local-test';
  frmmain.AssistantManager.ChatGPT.URL:=UTF8Decode(ParamStr(2));frmmain.AssistantManager.ChatGPT.Timeout:=5000;
  Windows.GetCursorPos(OldCursor);Windows.SetCursorPos(0,0);
  Runner:=TRunner.Create;
  try
   Runner.Root:=Root;Runner.Button:=TButton(frmmain.FindComponent('PresentationAskButton'));Check(Runner.Button<>nil,'Question button missing');
   Runner.Started:=GetTickCount64;Runner.Timer:=TTimer.Create(nil);Runner.Timer.Interval:=30;Runner.Timer.OnTimer:=@Runner.Tick;
   frmmain.StartPresentation(Root+PathDelim+'questions.pva');Application.Run;
  finally Windows.SetCursorPos(OldCursor.X,OldCursor.Y);Runner.Timer.Free;Runner.Free;frmmain.Free;end;
 except on E:Exception do begin WriteLn('FAIL: ',E.Message);Halt(1);end;end;
end.
