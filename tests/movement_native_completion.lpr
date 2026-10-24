program movement_native_completion;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Classes,SysUtils,ExtCtrls,professor_view,presentation_joints,
  movement_catalog,movement_timeline;
type TRunner=class(TComponent)
public
  View:TProfessorView;Timer:TTimer;Started:QWord;Index,Total:Integer;Active:Boolean;
  procedure Tick(Sender:TObject);
end;
const IDs:array[0..9] of string=('levantar_mao_esquerda','concordar','gesticular_ok','bocejar','fechar_mao_direita','abrir_olhos','cruzar_bracos','neutro','sentar','levantar');
var Window:TForm;Runner:TRunner;
procedure TRunner.Tick(Sender:TObject);
var S:TPresentationScene;M:TMovementDefinition;T:TMovementTimeline;
begin
  try
    S:=TPresentationScene(View.Scene);
    if not Active then begin
      if Index>High(IDs) then begin Timer.Enabled:=False;WriteLn('PASS: native rendered update loop completed all movements');Application.Terminate;Exit;end;
      if not FindMovement(IDs[Index],M) then raise Exception.Create('Missing movement');
      T:=MovementTimelineFor(M,ExtractFileName(ExtractFileDir(View.ModelFile)));Total:=T.DurationMS+T.TransitionMS;
      if T.ReturnToStart then Inc(Total,T.ReturnMS);
      if not View.ExecuteMovement(M.ID) then raise Exception.Create('Execution rejected');
      Started:=GetTickCount64;Active:=True;Exit;
    end;
    if S.MovementBlocked<>'' then raise Exception.Create(IDs[Index]+' stopped: '+S.MovementBlocked+' at '+FloatToStr(S.MovementElapsed));
    if S.MovementElapsed>=Total-0.01 then begin WriteLn('COMPLETED ',IDs[Index],' ',S.MovementElapsed:0:2);Inc(Index);Active:=False;end
    else if GetTickCount64-Started>Total+5000 then raise Exception.Create('Native update stalled: '+IDs[Index]+' elapsed '+FloatToStr(S.MovementElapsed));
  except on E:Exception do begin WriteLn('FAIL: '+E.Message);ExitCode:=1;Timer.Enabled:=False;Application.Terminate;end;end;
end;
begin
 Application.Initialize;Application.ShowMainForm:=False;Window:=TForm.CreateNew(nil);
 Window.Caption:='Verificação automática de movimentos';Window.SetBounds(30,30,320,480);Runner:=TRunner.Create(Window);
 Runner.View:=TProfessorView.Create(Runner,Window);
 if not Runner.View.LoadModel(ExpandFileName(ParamStr(1)),True) then Halt(1);
 WriteLn('SCENE HEIGHT ',Runner.View.Scene.BoundingBox.Size.Y:0:9,' TimePlaying ',Runner.View.Scene.TimePlaying);
 Runner.Timer:=TTimer.Create(Runner);Runner.Timer.Interval:=50;Runner.Timer.OnTimer:=@Runner.Tick;
 Window.Show;Application.Run;Window.Free;
end.
