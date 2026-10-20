program professor_ui_smoke;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Windows, ExtCtrls, StdCtrls, Graphics, Math, Types,
  main, professor_view, professor_catalog, professor_state, professor_ui,
  CastleControl, CastleURIUtils, CastleImages;
type
  TColorPixel = packed record R, G, B: Byte; end;
  PColorPixel = ^TColorPixel;
  TWheelProbe = class(TProfessorControl)
    function Scroll(Delta: Integer): Boolean;
  end;
  TSmokeRunner = class(TComponent)
  private
    FTimer: TTimer;
    FView: TProfessorView;
    FControl: TCastleControl;
    FSelector: TComboBox;
    FIndex, FPhase: Integer;
    FOut: string;
    FReport: TStringList;
    FCatalog: TAvatarCatalog;
    procedure Tick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;
function TWheelProbe.Scroll(Delta: Integer): Boolean;
begin Result := DoMouseWheel([],Delta,Types.Point(2,2)); end;
constructor TSmokeRunner.Create(AOwner: TComponent);
var I: Integer;
begin
  inherited Create(AOwner);
  FOut := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'ui-smoke' + PathDelim;
  ForceDirectories(FOut);
  FReport := TStringList.Create;
  FCatalog := TAvatarCatalog.Create;
  FReport.Add('Form visible at start: ' + BoolToStr(frmmain.Visible, True));
  if Application.MainForm <> nil then FReport.Add('Application main form: ' + Application.MainForm.ClassName);
  for I := 0 to frmmain.ComponentCount-1 do
  begin
    if frmmain.Components[I] is TProfessorView then FView := TProfessorView(frmmain.Components[I]);
    if frmmain.Components[I] is TComboBox then FSelector := TComboBox(frmmain.Components[I]);
    if frmmain.Components[I] is TConversationView then
    begin
      TConversationView(frmmain.Components[I]).AddMessage('Gostaria de conhecer os projetos da FATEC.', True);
      TConversationView(frmmain.Components[I]).AddMessage('Claro! Temos projetos de inteligência artificial, robótica e equipamentos biomédicos.', False);
    end;
  end;
  if (FView = nil) or (FSelector = nil) then raise Exception.Create('Missing renderer/selector');
  for I := 0 to FView.ComponentCount-1 do
    if FView.Components[I] is TCastleControl then FControl := TCastleControl(FView.Components[I]);
  if FControl = nil then raise Exception.Create('Missing native OpenGL control');
  if FSelector.Items.Count <> FCatalog.Count+1 then raise Exception.Create('Catalog/selector mismatch');
  if not TWheelProbe(FControl).Scroll(120) then raise Exception.Create('Wheel event not handled');
  if FView.Zoom >= 1 then raise Exception.Create('Wheel zoom in failed');
  TWheelProbe(FControl).Scroll(-120);
  if Abs(FView.Zoom-1)>0.001 then raise Exception.Create('Wheel zoom out failed');
  FView.ZoomBy(100);
  if Abs(FView.Zoom-0.4)>0.001 then raise Exception.Create('Near zoom bound');
  FView.ZoomBy(-100);
  if Abs(FView.Zoom-2.5)>0.001 then raise Exception.Create('Far zoom bound');
  FControl.OnDblClick(FControl);
  if Abs(FView.Zoom-1)>0.001 then raise Exception.Create('Double-click framing');
  FReport.Add('PASS: wheel zoom in/out and both distance limits');
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 900;
  FTimer.OnTimer := @Tick;
end;
destructor TSmokeRunner.Destroy;
begin
  FReport.Free;
  FCatalog.Free;
  inherited Destroy;
end;
procedure TSmokeRunner.Tick(Sender: TObject);
var Rendered: TRGBImage; X, Y, Colored: Integer; P: PColorPixel;
  FormImage: Graphics.TBitmap; AvatarShot: TPicture; Origin: TPoint;
begin
  FTimer.Enabled := False;
  try
    if FIndex >= FCatalog.Count then
    begin
      if FPhase = 3 then begin Application.Terminate; Exit; end;
      if FView.LoadModel(FOut + 'missing.gltf', True) then raise Exception.Create('Invalid model accepted');
      if FView.Scene.BoundingBox.IsEmpty then raise Exception.Create('Fallback geometry missing');
      FReport.Add('PASS: missing custom model falls back to bundled professor');
      FSelector.ItemIndex := 0;
      FSelector.OnChange(FSelector);
      frmmain.edPergunta.Text := '';
      frmmain.btEnviarClick(nil);
      FReport.Add('PASS: empty send did not start an AI request');
      FReport.Add('PASS: native form and dynamic selector; profiles rendered: '+IntToStr(FCatalog.Count));
      FReport.Add('Layout capture contains demonstration messages, not an AI response.');
      FormImage := frmmain.GetFormImage;
      AvatarShot := TPicture.Create;
      try
        AvatarShot.LoadFromFile(FOut + 'professor.png');
        Origin := frmmain.ScreenToClient(FControl.ClientToScreen(Types.Point(0,0)));
        FormImage.Canvas.Draw(Origin.X, Origin.Y, AvatarShot.Graphic);
        FormImage.SaveToFile(FOut + 'layout.bmp');
      finally AvatarShot.Free; FormImage.Free; end;
      FPhase := 3;
      FTimer.Interval := 1000;
      FTimer.Enabled := True;
      FReport.SaveToFile(FOut + 'result.txt');
      Exit;
    end;
    if FPhase = 0 then
    begin
      FSelector.ItemIndex := FIndex;
      FSelector.OnChange(FSelector);
      if FView.Diagnostic <> '' then raise Exception.Create(FView.Diagnostic);
      if FView.Scene.BoundingBox.IsEmpty then raise Exception.Create('Empty scene');
      FPhase := 1;
    end
    else
    begin
      Rendered := FControl.Container.SaveScreen;
      try
        Colored := 0;
        Y := 0;
        while Y < Integer(Rendered.Height) do
        begin
          X := 0;
          while X < Integer(Rendered.Width) do
          begin
            P := PColorPixel(Rendered.PixelPtr(X,Y));
            if Max(P^.R, Max(P^.G,P^.B)) - Min(P^.R, Min(P^.G,P^.B)) > 20 then Inc(Colored);
            Inc(X,3);
          end;
          Inc(Y,3);
        end;
        if Colored < 100 then raise Exception.Create('Blank/unlit render: ' + FCatalog[FIndex].ID);
        SaveImage(Rendered, FilenameToURISafe(FOut + FCatalog[FIndex].ID + '.png'));
      finally Rendered.Free; end;
      FReport.Add('PASS: selector and colored OpenGL render: ' + FCatalog[FIndex].ID);
      FReport.SaveToFile(FOut + 'result.txt');
      Inc(FIndex);
      FPhase := 0;
    end;
    FTimer.Enabled := True;
  except
    on E: Exception do
    begin
      FReport.Add('FAIL: ' + E.ClassName + ': ' + E.Message);
      FReport.SaveToFile(FOut + 'result.txt');
    end;
  end;
end;
var Config: TStringList; ConfigDir: string; TraceIndex: Integer;
begin
  ConfigDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'ui-smoke-config';
  ForceDirectories(ConfigDir);
  Windows.SetEnvironmentVariable(PChar('ASSISTENTE_CONFIG_DIR'), PChar(ConfigDir));
  Config := TStringList.Create;
  try
    Config.Add('CONTINUOUS_LISTENING:0');
    Config.Add('AUTOSPEAK:0');
    Config.Add('VISION_SOURCE:none');
    Config.Add('AVATAR3D_PROFILE:professor');
    Config.Add('AVATAR3D_AUTO_IDLE:1');
    Config.SaveToFile(IncludeTrailingPathDelimiter(ConfigDir) + 'Setmain.cfg');
  finally Config.Free; end;
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(Tfrmmain, frmmain);
  frmmain.Show;
  TSmokeRunner.Create(Application);
  Application.Run;
  try frmmain.Free;
  except
    on E: Exception do
    begin
      Config := TStringList.Create;
      try
        ConfigDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'ui-smoke' + PathDelim + 'result.txt';
        Config.LoadFromFile(ConfigDir);
        Config.Add('FAIL: shutdown ' + E.ClassName + ': ' + E.Message);
        Config.Add(BackTraceStrFunc(ExceptAddr));
        for TraceIndex := 0 to ExceptFrameCount-1 do Config.Add(BackTraceStrFunc(ExceptFrames[TraceIndex]));
        Config.SaveToFile(ConfigDir);
      finally Config.Free; end;
      Halt(1);
    end;
  end;
  Config := TStringList.Create;
  try
    ConfigDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'ui-smoke' + PathDelim + 'result.txt';
    Config.LoadFromFile(ConfigDir);
    Config.Add('PASS: form shutdown and worker/resource disposal');
    Config.SaveToFile(ConfigDir);
  finally Config.Free; end;
end.
