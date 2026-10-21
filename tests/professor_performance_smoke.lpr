program professor_performance_smoke;
{$mode objfpc}{$H+}
{$apptype GUI}
uses Interfaces, Forms, Classes, SysUtils, ExtCtrls, Windows,
  CastleUIControls, CastleControl, professor_view;
type
  TFrameProbe=class(TCastleUserInterface)
  public
    Capture: Boolean;
    Last,Frequency: Int64;
    Count: Integer;
    Intervals: array[0..4095] of Double;
    procedure Render;override;
  end;
  TRunner=class(TComponent)
  public
    View: TProfessorView;
    Probe: TFrameProbe;
    Control: TCastleControl;
    Timer: TTimer;
    Seconds: Integer;
    constructor Create(AOwner: TComponent);override;
    procedure Tick(Sender: TObject);
  end;
var Window: TForm;Runner: TRunner;
procedure TFrameProbe.Render;
var Now: Int64;
begin
  QueryPerformanceCounter(Now);
  if Capture and (Last<>0) and (Count<Length(Intervals)) then
  begin Intervals[Count]:=(Now-Last)*1000/Frequency;Inc(Count);end;
  Last:=Now;
end;
constructor TRunner.Create(AOwner: TComponent);
var I: Integer;
begin
  inherited;
  View:=TProfessorView.Create(Self,Window);
  if not View.LoadModel(ExpandFileName(ParamStr(1)),True) then raise Exception.Create(View.Diagnostic);
  for I:=0 to View.ComponentCount-1 do
    if View.Components[I] is TCastleControl then Control:=TCastleControl(View.Components[I]);
  Probe:=TFrameProbe.Create(Self);Probe.FullSize:=True;QueryPerformanceFrequency(Probe.Frequency);
  Control.Container.Controls.InsertFront(Probe);
  View.Scene.PlayAnimation('applause_smile',True);
  Timer:=TTimer.Create(Self);Timer.Interval:=1000;Timer.OnTimer:=@Tick;
end;
procedure TRunner.Tick(Sender: TObject);
var I,J: Integer;Value,Sum: Double;Report: TStringList;
begin
  Inc(Seconds);
  if Seconds=2 then Probe.Capture:=True;
  if Seconds<12 then Exit;
  Timer.Enabled:=False;Probe.Capture:=False;Report:=TStringList.Create;
  try
    Sum:=0;for I:=0 to Probe.Count-1 do Sum:=Sum+Probe.Intervals[I];
    for I:=1 to Probe.Count-1 do
    begin
      Value:=Probe.Intervals[I];J:=I-1;
      while (J>=0) and (Probe.Intervals[J]>Value) do
      begin Probe.Intervals[J+1]:=Probe.Intervals[J];Dec(J);end;
      Probe.Intervals[J+1]:=Value;
    end;
    if (Probe.Count=0) or (Sum<=0) then begin ExitCode:=1;Report.Add('FAIL: no rendered frames');end
    else
    begin
      Report.Add('Continuous live playback; no screenshots, pose forcing, audio or network.');
      Report.Add('Measured frames: '+IntToStr(Probe.Count));
      Report.Add(Format('Average FPS: %.2f',[1000*Probe.Count/Sum]));
      Report.Add(Format('95th percentile frame ms: %.2f',[Probe.Intervals[(Probe.Count-1)*95 div 100]]));
      Report.Add(Format('Maximum frame ms: %.2f',[Probe.Intervals[Probe.Count-1]]));
      Report.Add(Format('CGE real FPS: %.2f',[Control.Container.Fps.RealFps]));
    end;
    Report.SaveToFile(ExtractFilePath(ParamStr(0))+'performance-smoke.txt');
  finally Report.Free;end;
  Application.Terminate;
end;
begin
  Application.Initialize;Window:=TForm.CreateNew(nil);
  Window.Caption:='Reprodução contínua — aplausos (sem áudio)';Window.Width:=600;Window.Height:=740;Window.Show;
  Runner:=TRunner.Create(Window);Application.Run;Window.Free;
end.
