program external_movement_view_tests;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Classes,SysUtils,Math,FileUtil,CastleTransform,X3DNodes,
  professor_view,professor_state,movement_catalog,movement_animation,presentation_joints,movement_timeline;
var Root,Original:string;A:TMotionAnimation;L:TStringList;Window:TForm;View:TProfessorView;
  Scene:TPresentationScene;RemoveMe:TRemoveType;Before,D:Double;I,N:Integer;P,R:TMPoseArray;Q:TMQuaternion;
procedure Check(Value:Boolean;const Message:string);
begin if not Value then raise Exception.Create(Message);end;
begin
  Application.Initialize;Application.ShowMainForm:=False;
  Root:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));ForceDirectories(Root+'movimentos');Original:=MovementCatalogFile;
  L:=TStringList.Create;Window:=TForm.CreateNew(nil);
  try
    Check(CopyFile(ExtractFilePath(Original)+'colisoes.json',Root+'colisoes.json'),'Cannot copy collision profile');
    A:=Default(TMotionAnimation);A.Name:='Wrist validation';A.DurationMS:=1000;A.ReturnToBase:=True;A.Smooth:=True;
    SetLength(A.Tracks,1);A.Tracks[0].Bone:='wrist.R';A.Tracks[0].Axis:=#0;SetLength(A.Tracks[0].Keys,3);
    A.Tracks[0].Keys[1].TimeMS:=500;A.Tracks[0].Keys[1].Rotation:=MVector(3,5,2);A.Tracks[0].Keys[2].TimeMS:=1000;
    SaveMotionAnimation(Root+'movimentos/wrist.json',A);
    L.Text:='{"version":1,"movements":[{"id":"external_wrist","tag":"external wrist","duration_ms":50,"transition_ms":0,"animation_file":"wrist.json"}]}';L.SaveToFile(Root+'movimentos.json');
    ReloadMovementCatalog(Root+'movimentos.json');View:=TProfessorView.Create(Window,Window);
    Check(View.LoadModel(ExpandFileName(ParamStr(2)),True),View.Diagnostic);Scene:=TPresentationScene(View.Scene);RemoveMe:=rtNone;
    Check(View.ExecuteMovement('external wrist'),'External movement rejected');
    Check(View.CurrentAnimation='json:external_wrist','External file not using protected timeline');
    View.SetActivity(psSpeaking);View.SetActivity(psIdle);Check(View.CurrentAnimation='json:external_wrist','Activity replaced external file');
    Scene.TimePlayingSpeed:=0.5;Scene.Update(1,RemoveMe);Check(Abs(Scene.MovementElapsed-500)<0.1,'Playback speed ignored');
    P:=Scene.EditorPose;R:=Scene.EditorRig.RestPose;N:=Scene.EditorRig.NodeIndex('wrist.R');
    Q:=QMul(R[N].Rotation,MQuaternion(3,5,2));D:=0;for I:=0 to 3 do D:=D+Q[I]*P[N].Rotation[I];
    Check(Abs(Abs(D)-1)<1E-7,'XYZ external pose diverges in real view');
    Before:=Scene.MovementElapsed;Scene.PauseJoints(True);Scene.Update(1,RemoveMe);Check(Scene.MovementElapsed=Before,'Pause ignored');
    Scene.PauseJoints(False);Scene.TimePlayingSpeed:=1;Scene.Update(1,RemoveMe);
    Check(not Scene.MovementRunning and (Scene.MovementBlocked=''),'External file failed to finish');
    Check(Scene.MovementClearance>=0,'External file penetrated collision volumes');
    View.ResetCommands;Check(not Scene.TimelineHasPose,'Reset kept external pose');
    WriteLn('PASS: external XYZ v2 tag through real view, quaternion pose, collision protection, resource duration, idle/speech, half speed, pause, return and reset');
  finally Window.Free;L.Free;ReloadMovementCatalog(Original);end;
end.
