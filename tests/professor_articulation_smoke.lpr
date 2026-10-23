program professor_articulation_smoke;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, ExtCtrls, CastleImages, CastleURIUtils,
  CastleControl, CastleViewport, CastleVectors, CastleSceneCore, professor_view, professor_state, professor_commands;
type TRunner=class(TComponent)
public
  View:TProfessorView; Control:TCastleControl; Viewport:TCastleViewport;
  Timer:TTimer; Index,Phase:Integer; OutputDir,Clip:string;
  constructor Create(AOwner:TComponent);override;
  procedure Tick(Sender:TObject);
end;
var Window:TForm; Runner:TRunner;
constructor TRunner.Create(AOwner:TComponent);
var I:Integer;
begin
  inherited;
  OutputDir:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(10)));
  ForceDirectories(OutputDir);Clip:=ParamStr(2);
  View:=TProfessorView.Create(Self,Window);
  if not View.LoadModel(ExpandFileName(ParamStr(1)),True) then raise Exception.Create(View.Diagnostic);
  if Clip='bocejar' then View.ExecuteCommand(acYawn);
  for I:=0 to View.ComponentCount-1 do begin
    if View.Components[I] is TCastleControl then Control:=TCastleControl(View.Components[I]);
    if View.Components[I] is TCastleViewport then Viewport:=TCastleViewport(View.Components[I]);
  end;
  Viewport.AutoCamera:=False;
  Viewport.Camera.SetWorldView(Vector3(StrToFloat(ParamStr(5)),StrToFloat(ParamStr(6)),StrToFloat(ParamStr(7))+StrToFloat(ParamStr(8))),
    Vector3(0,0,-1),Vector3(0,1,0));
  Timer:=TTimer.Create(Self);Timer.Interval:=180;Timer.OnTimer:=@Tick;
end;
procedure TRunner.Tick(Sender:TObject);
var Shot:TRGBImage;Moment:Single;Params:TPlayAnimationParameters;
begin
  Timer.Enabled:=False;
  if Index=10 then begin Application.Terminate;Exit;end;
  if Phase=0 then begin
    if Index<2 then begin
      Moment:=StrToFloat(ParamStr(3+Index));View.Scene.StopAnimation;
      if not View.Scene.ForceAnimationPose(Clip,Moment,True) then raise Exception.Create('Cannot pose');
    end else if Index=2 then begin
      // Exercise the same speaking-state selection as the application, then
      // sample real progressing playback as well as the two controlled poses.
      if Clip='talking' then View.SetActivity(psSpeaking)
      else begin
        Params:=TPlayAnimationParameters.Create;
        try Params.Name:=Clip;Params.Loop:=True;Params.InitialTime:=StrToFloat(ParamStr(9));Params.TransitionDuration:=0;
          if not View.Scene.PlayAnimation(Params) then raise Exception.Create('Cannot play');
        finally Params.Free;end;
      end;
      Timer.Interval:=60;
    end;
    Phase:=1;
  end else begin
    Shot:=Control.Container.SaveScreen;
    try SaveImage(Shot,FilenameToURISafe(OutputDir+Format('%.2d.png',[Index])));
    finally Shot.Free;end;
    Inc(Index);Phase:=0;
  end;
  Timer.Enabled:=True;
end;
begin
  DefaultFormatSettings.DecimalSeparator:='.';
  Application.Initialize;
  if ParamCount<>10 then raise Exception.Create('Usage: model clip time0 time1 focusX focusY focusZ distance initialTime output');
  Window:=TForm.CreateNew(nil);Window.Caption:='Validando boca, pálpebras, olhar e dedos';
  Window.Width:=640;Window.Height:=640;Window.Show;
  Runner:=TRunner.Create(Window);Application.Run;Window.Free;
  WriteLn('PASS: two native controlled poses, eight playback captures, renderer shutdown');
end.
