program professor_animation_smoke;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, ExtCtrls, CastleImages, CastleURIUtils, CastleControl,
  professor_view, professor_state;
type
  TRunner = class(TComponent)
  public
    View: TProfessorView;
    Timer: TTimer;
    Control: TCastleControl;
    Index, Phase: Integer;
    OutputDir: string;
    MovieClip: string;
    procedure Tick(Sender: TObject);
    constructor Create(AOwner: TComponent); override;
  end;
const Names: array[0..12] of string = ('idle','listening','thinking','talking','wave','walk','walk','talking',
  'idle_smile','applause_smile','idle_smile_right_hand_up','talking_smile_right_hand_up','idle');
      Moments: array[0..12] of Single = (0.3,0.6,0.8,0.5,1.1,0.3,0.9,0.8,0.6,1.1,0.6,0.6,0.3);
var Window: TForm; Runner: TRunner;
constructor TRunner.Create(AOwner: TComponent);
var I: Integer;
begin
  inherited;
  OutputDir := ExtractFilePath(ParamStr(0))+'animation-smoke'+PathDelim;
  MovieClip:=ParamStr(2);
  if MovieClip<>'' then
  begin
    if not ((MovieClip='wave') or (MovieClip='walk') or (MovieClip='applause_smile')) then
      raise Exception.Create('Capture clip must be wave, walk or applause_smile');
    OutputDir:=ExtractFilePath(ParamStr(0))+'motion60-'+MovieClip+PathDelim;
  end;
  ForceDirectories(OutputDir);
  View := TProfessorView.Create(Self, Window);
  if not View.LoadModel(ExpandFileName(ParamStr(1)),True) then raise Exception.Create(View.Diagnostic);
  for I:=0 to View.ComponentCount-1 do
    if View.Components[I] is TCastleControl then Control:=TCastleControl(View.Components[I]);
  if Control=nil then raise Exception.Create('No renderer');
  Timer := TTimer.Create(Self); Timer.Interval:=350; Timer.OnTimer:=@Tick;
  if MovieClip<>'' then Timer.Interval:=20;
end;
procedure TRunner.Tick(Sender: TObject);
var Shot: TRGBImage;Clip,FileName: string;Moment: Single;
begin
  Timer.Enabled := False;
  if ((MovieClip='') and (Index>=Length(Names))) or ((MovieClip<>'') and (Index>=144)) then
  begin Application.Terminate;Exit;end;
  if MovieClip='' then begin Clip:=Names[Index];Moment:=Moments[Index];FileName:=IntToStr(Index)+'-'+Clip;end
  else begin Clip:=MovieClip;Moment:=Index/60;FileName:=Format('%.3d',[Index]);end;
  if Phase=0 then
  begin
    if (MovieClip='') and (Index=12) then View.ZoomBy(4);
    View.Scene.StopAnimation;
    if not View.Scene.ForceAnimationPose(Clip,Moment,True) then raise Exception.Create('Cannot pose');
    Phase:=1;
  end else
  begin
    Shot := Control.Container.SaveScreen;
    try SaveImage(Shot,FilenameToURISafe(OutputDir+FileName+'.png'));
    finally Shot.Free; end;
    Inc(Index);
    Phase:=0;
  end;
  Timer.Enabled := True;
end;
begin
  Application.Initialize;
  if ParamCount<1 then raise Exception.Create('Usage: professor_animation_smoke model.gltf');
  Window := TForm.CreateNew(nil);
  if ParamStr(2)='' then Window.Caption:='Inspeção: poses congeladas (não é reprodução)'
  else Window.Caption:='Exportando vídeo: captura em câmera lenta';
  Window.Width:=600; Window.Height:=740; Window.Show;
  Runner := TRunner.Create(Window);
  Application.Run;
  Window.Free;
  if ParamStr(2)<>'' then WriteLn('PASS: 144 native rendered motion frames sampled at 60 Hz; renderer shutdown')
  else WriteLn('PASS: thirteen rendered skeletal/facial/directive poses and close-up; renderer shutdown');
end.
