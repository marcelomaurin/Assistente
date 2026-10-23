program presentation_native_smoke;
{$mode objfpc}{$H+}
uses Interfaces, Controls, Forms, Classes, SysUtils, Windows, ExtCtrls, LCLType, Graphics, StdCtrls, Types,
  main, presentation_media, presentation_tags, presentation_package, presentation_editor_ui, SynEdit,
  CastleControl, CastleImages, CastleURIUtils, professor_view, presentation_joints, presentation_joint_tags, X3DNodes, CastleVectors;
type
  TRunner = class(TComponent)
  public
    Timer: TTimer;
    Started, PausedAt: QWord;
    PauseSent, ResumeSent, CancelSent: Boolean;
    Images,SecondImage,Slides,ClosedMedia,SawJoint,SawAvatar,SawSound: Boolean;
    SoundStarted: QWord;
    Report: TStringList;
    View: TProfessorView;
    procedure Tick(Sender: TObject);
    procedure CaptureLayout;
  end;
var Root,Mode,ConfigDir: string; Media: TPresentationMedia; Tag: TPresentationTag;
  Config,Report: TStringList; Runner: TRunner; Editor: TPresentationEditor;
  I: Integer; Edit: TSynEdit; B: TButton; Bone: TX3DNode;
procedure Check(OK: Boolean; const Error: string);
begin if not OK then raise Exception.Create(Error);end;
procedure TRunner.CaptureLayout;
var C: TCastleControl; I: Integer; Shot: TRGBImage; Image: TBitmap;
  Avatar: TPicture; Origin: TPoint;
begin
  C:=nil;
  for I:=0 to View.ComponentCount-1 do
    if View.Components[I] is TCastleControl then C:=TCastleControl(View.Components[I]);
  Check(C<>nil,'avatar renderer missing');
  Shot:=C.Container.SaveScreen;
  try SaveImage(Shot,FilenameToURISafe(Root+PathDelim+'embedded-avatar.png'));finally Shot.Free;end;
  Image:=frmmain.GetFormImage;Avatar:=TPicture.Create;
  try
    Avatar.LoadFromFile(Root+PathDelim+'embedded-avatar.png');
    Origin:=frmmain.ScreenToClient(C.ClientToScreen(Point(0,0)));
    Image.Canvas.Draw(Origin.X,Origin.Y,Avatar.Graphic);
    Image.SaveToFile(Root+PathDelim+'embedded-layout.bmp');
  finally Avatar.Free;Image.Free;end;
end;
procedure TRunner.Tick(Sender: TObject);
var Elapsed: QWord; Key: Word; Active: string; Panel: TPanel; AvatarRight: Integer;
begin
  try
    Elapsed:=GetTickCount64-Started;Check(Elapsed<40000,'main presentation stalled');
    Active:=frmmain.ActivePresentationMedia;
    Panel:=TPanel(frmmain.FindComponent('PresentationMediaPanel'));
    Check(Panel<>nil,'missing embedded media panel');
    if Active<>'' then begin
      Check(Panel.Visible and Panel.IsVisible,'visual panel hidden');
      Check(frmmain.pnlAvatar.IsVisible,'media hides avatar');
      Check(not frmmain.edPergunta.IsVisible,'typed text remains over visual');
      AvatarRight:=frmmain.pnlAvatar.ClientToScreen(Point(frmmain.pnlAvatar.Width,0)).X;
      Check(Panel.ClientToScreen(Point(0,0)).X>=AvatarRight,'media overlaps avatar');
    end else begin
      Check(not Panel.Visible,'closed media panel remains visible');
      Check(frmmain.edPergunta.IsVisible,'text panel not restored');
      Check(frmmain.edPergunta.Text='Rascunho preservado','typed draft was changed');
    end;
    SawAvatar:=SawAvatar or (frmmain.ActivePresentationAvatar='engenheiro');
    if frmmain.ActivePresentationSound<>'' then begin
      SawSound:=True;if SoundStarted=0 then SoundStarted:=GetTickCount64;
    end;
    Images:=Images or (Active='assets/one.png');
    SecondImage:=SecondImage or (Active='assets/two.png');
    if (View<>nil) and (View.Scene.RootNode<>nil) then begin
      Bone:=View.Scene.RootNode.FindNodeByName(TTransformNode,'head',False);
      if Bone is TTransformNode then SawJoint:=SawJoint or (Abs(TTransformNode(Bone).Rotation.W)>0.1);
      Bone:=View.Scene.RootNode.FindNodeByName(TTransformNode,'jaw',False);
      if Bone is TTransformNode then Check(Abs(TTransformNode(Bone).Rotation.W)<0.001,'silent gesture moved the mouth');
    end;
    Slides:=Slides or (Active='assets/slides.pptx');
    if SecondImage and (Active='') and frmmain.ApresentandoResposta then ClosedMedia:=True;
    if not PauseSent and Images then begin
      Key:=Ord('P');frmmain.OnKeyDown(frmmain,Key,[]);Check(Key=0,'pause key not consumed');
      PausedAt:=GetTickCount64;PauseSent:=True;
      frmmain.Width:=frmmain.Width+110;frmmain.Height:=frmmain.Height+60;
      Report.Add('PASS: embedded visual beside visible avatar; text hidden; resize and text restoration checked');
    end;
    if PauseSent and not ResumeSent then begin
      Check(frmmain.ApresentandoResposta,'paused job finished');
      Check(frmmain.ActivePresentationMedia='assets/one.png','media advanced during pause');
      if GetTickCount64-PausedAt>650 then begin
        CaptureLayout;Key:=Ord('P');frmmain.OnKeyDown(frmmain,Key,[]);ResumeSent:=True;
      end;
    end;
    if not frmmain.ApresentandoResposta then begin
      if not CancelSent then begin
        Check(Pos('Pronto',frmmain.lblStatus.Caption)=1,'main execution error: '+frmmain.lblStatus.Caption);
        Check(SawAvatar and SawSound,'avatar/sound tags did not execute');
        Check(frmmain.ActivePresentationAvatar='custom','original avatar not restored');
        Check(GetTickCount64-SoundStarted>=1800,'trailing sound cut off');
        Check(SawJoint,'parametric head motion did not render');
        Check(Images and SecondImage and (Slides or (ParamStr(4)='without-office')) and ClosedMedia,'missing media execution');
        Check(frmmain.ActivePresentationMedia='','completed presentation left media open');
        Report.Add('PASS: main loaded PVA; image/close tags, pause/resume and completion cleanup; Office mode='+ParamStr(4));
        Started:=GetTickCount64;
        frmmain.StartPresentation(Root+PathDelim+'cancel.pva');
        CancelSent:=True;PausedAt:=GetTickCount64;
      end else begin
        Check(frmmain.ActivePresentationMedia='','cancel left media open');
        Check((frmmain.ActivePresentationSound='') and (frmmain.ActivePresentationAvatar='custom'),'cancel failed to restore avatar/close sound');
        Report.Add('PASS: avatar tag/restoration, trailing audio completion, cancellation, joint interpolation and silent mouth');
        Report.SaveToFile(Root+PathDelim+'main-result.txt');Timer.Enabled:=False;Application.Terminate;
      end;
    end else if CancelSent and (GetTickCount64-PausedAt>300) then begin
      Key:=VK_ESCAPE;frmmain.OnKeyDown(frmmain,Key,[]);
    end;
  except on E: Exception do begin
    Report.Add('FAIL: '+E.Message);Report.SaveToFile(Root+PathDelim+'main-result.txt');
    ExitCode:=1;Timer.Enabled:=False;Application.Terminate;
  end;end;
end;
procedure MediaTest;
var Position: Integer; HostForm: TForm; Host: TPanel; SlideWindow: HWND; Bounds: TRect;
begin
  HostForm:=TForm.CreateNew(nil);HostForm.SetBounds(50,50,800,600);
  Host:=TPanel.Create(HostForm);Host.Parent:=HostForm;Host.Align:=alClient;
  HostForm.Show;Application.ProcessMessages;
  Media:=TPresentationMedia.Create(Root,Host);
  try
    TryParsePresentationTag('[abrir arquivo=assets/one.png]',Tag);Media.Execute(Tag);
    Check(Media.Active='assets/one.png','image not open');
    Check(TryParsePresentationTag('[abrir arquivo=assets/sound.wav|inicio=00:00:01]',Tag),'sound tag');Media.Execute(Tag);
    Check((Media.Active='assets/one.png') and (Media.ActiveSound='assets/sound.wav'),'sound replaced visual');
    Check((Media.SoundPositionMS>=1000) and (Media.SoundPositionMS<1300),'sound offset not applied');
    Media.SetPaused(True);Position:=Media.SoundPositionMS;Sleep(120);
    Check(Abs(Media.SoundPositionMS-Position)<30,'sound advanced while paused');Media.SetPaused(False);
    TryParsePresentationTag('[fechar som]',Tag);Media.Execute(Tag);
    Check((Media.ActiveSound='') and (Media.Active='assets/one.png'),'close sound disturbed visual');
    TryParsePresentationTag('[abrir arquivo=assets/sound.wav|inicio=00:00:10]',Tag);
    try Media.Execute(Tag);raise Exception.Create('invalid sound position accepted');
    except on E: Exception do Check(Pos('Inicio fora',E.Message)>0,'wrong sound offset error');end;
    TryParsePresentationTag('[abrir arquivo=assets/two.png]',Tag);Media.Execute(Tag);
    Check(Media.Active='assets/two.png','image replacement failed');Report.Add('PASS: real PNG single-media replacement');Report.SaveToFile(Root+PathDelim+'media-result.txt');
    TryParsePresentationTag('[abrir arquivo=assets/movie.avi|inicio=00:00:01]',Tag);Media.Execute(Tag);
    Check(Media.Active='assets/movie.avi','video not open');
    Check((Media.VideoPositionMS>=1000) and (Media.VideoPositionMS<1300),'video offset not applied');
    Media.SetPaused(True);Sleep(100);Media.SetPaused(False);Report.Add('PASS: real AVI/WAV offsets, independent image+sound, sound close, duration bounds, pause/resume');Report.SaveToFile(Root+PathDelim+'media-result.txt');
    if ParamStr(4)<>'without-office' then begin
    TryParsePresentationTag('[abrir arquivo=assets/slides.pptx]',Tag);Media.Execute(Tag);
    Check(Media.Active='assets/slides.pptx','PowerPoint replacement failed');Check(Media.CurrentSlide=1,'initial slide');
    SlideWindow:=FindWindowEx(Host.Handle,0,'screenClass',nil);
    Check(SlideWindow<>0,'PowerPoint is not embedded in media panel');
    HostForm.SetBounds(50,50,650,450);Application.ProcessMessages;
    Check(Windows.GetParent(SlideWindow)=Host.Handle,'slide lost embedded parent after resize');
    Windows.GetClientRect(SlideWindow,Bounds);
    Check((Bounds.Right=Host.ClientWidth) and (Bounds.Bottom=Host.ClientHeight),'slides not resized to host');
    Report.Add('PASS: real PowerPoint slideshow embedded as child of media panel');
    TryParsePresentationTag('[proximo slide]',Tag);Media.Execute(Tag);Check(Media.CurrentSlide=2,'next slide');
    TryParsePresentationTag('[slide anterior]',Tag);Media.Execute(Tag);Check(Media.CurrentSlide=1,'previous slide');
    TryParsePresentationTag('[ir para slide=3]',Tag);Media.Execute(Tag);Check(Media.CurrentSlide=3,'specific slide');
    TryParsePresentationTag('[ir para slide=4]',Tag);
    try Media.Execute(Tag);raise Exception.Create('slide range not checked');
    except on E: Exception do Check(Pos('Slide fora',E.Message)=1,'wrong out-of-range error: '+E.Message);end;
    Media.SetPaused(True);Media.SetPaused(False);
    end;
    TryParsePresentationTag('[fechar arquivo]',Tag);Media.Execute(Tag);Check(Media.Active='','close failed');
    Media.Execute(Tag);
    Report.Add('PASS: single-media close and real slide navigation/bounds; Office mode='+ParamStr(4));
  finally Media.Free;HostForm.Free;end;
end;
procedure EditorTest;
var Original,After: string;
begin
  Editor:=TPresentationEditor.Create(nil);
  try
    Editor.Show;Application.ProcessMessages;Edit:=nil;
    for I:=0 to Editor.ComponentCount-1 do if Editor.Components[I] is TSynEdit then Edit:=TSynEdit(Editor.Components[I]);
    Check(Edit<>nil,'editor missing');Edit.Text:='Ola mundo';Edit.CaretXY:=Point(5,1);
    Original:=Edit.Text;
    for I:=0 to Editor.ComponentCount-1 do if Editor.Components[I] is TButton then begin
      B:=TButton(Editor.Components[I]);if B.Tag=6 then B.Click;
    end;
    After:=Edit.Text;Check(Pos('[fechar arquivo]',After)>0,'cursor media insertion failed');
    Edit.Undo;Check(Edit.Text=Original,'undo insertion failed');Edit.Redo;Check(Edit.Text=After,'redo insertion failed');
    Editor.SavePackage(Root+PathDelim+'editor-roundtrip.pva');Edit.Text:='Descartar';
    Editor.LoadPackage(Root+PathDelim+'editor-roundtrip.pva');Check(Edit.Text=After,'editor save/open roundtrip');
    with Editor.GetFormImage do try SaveToFile(Root+PathDelim+'editor.bmp');finally Free;end;
    Edit.Modified:=False;
    Report.Add('PASS: native editor opened, cursor insertion, undo/redo, PVA save/open roundtrip; screenshot saved');
  finally Editor.Free;end;
end;
begin
  Root:=ExpandFileName(ParamStr(1));Mode:=ParamStr(2);Report:=TStringList.Create;
  try
    ConfigDir:=Root+PathDelim+'config';ForceDirectories(ConfigDir);
    SetEnvironmentVariableW('ASSISTENTE_CONFIG_DIR',PWideChar(UTF8Decode(ConfigDir)));
    Config:=TStringList.Create;
    try
      Config.Add('CONTINUOUS_LISTENING:0');Config.Add('AUTOSPEAK:0');Config.Add('VISION_SOURCE:none');
      Config.Add('AVATAR3D_PROFILE:custom');Config.Add('AVATAR3D_MODEL:'+ParamStr(3));
      Config.Add('AVATAR3D_AUTO_IDLE:1');Config.SaveToFile(ConfigDir+PathDelim+'Setmain.cfg');
    finally Config.Free;end;
    RequireDerivedFormResource:=True;Application.Initialize;
    if Mode='media' then begin MediaTest;Report.SaveToFile(Root+PathDelim+'media-result.txt');end
    else if Mode='editor' then begin EditorTest;Report.SaveToFile(Root+PathDelim+'editor-result.txt');end
    else begin
      Application.CreateForm(Tfrmmain,frmmain);frmmain.Show;
      Runner:=TRunner.Create(frmmain);
      for I:=0 to frmmain.ComponentCount-1 do if frmmain.Components[I] is TProfessorView then Runner.View:=TProfessorView(frmmain.Components[I]);
      Runner.Report:=Report;Runner.Started:=GetTickCount64;
      frmmain.edPergunta.Text:='Rascunho preservado';
      frmmain.StartPresentation(Root+PathDelim+'main.pva');
      Runner.Timer:=TTimer.Create(Runner);Runner.Timer.Interval:=50;Runner.Timer.OnTimer:=@Runner.Tick;
      Application.Run;frmmain.Free;
    end;
  except on E: Exception do begin
    Report.Add('FAIL: '+E.Message);Report.SaveToFile(Root+PathDelim+Mode+'-result.txt');ExitCode:=1;
  end;end;
  Report.Free;
end.
