program professor_gesture_tests;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Classes,SysUtils,professor_view,professor_commands,
  professor_state,presentation_joints,movement_catalog,movement_timeline,CastleTransform,X3DNodes;
const Commands:array[0..18] of TAvatarCommand=(acOK,acThumbsUp,acHeart,acNod,
  acShakeHead,acRaiseLeftHand,acRaiseBothHands,acLookBackRight,acLookBackLeft,
  acFingerNo,acRaiseRightFoot,acCloseLeftHand,acOpenLeftHand,
  acCloseRightHand,acOpenRightHand,acYawn,acOpenEyes,acCloseEyes,acBlink);
var Window:TForm;View:TProfessorView;Scene:TPresentationScene;C:TAvatarCommand;
  M:TMovementDefinition;Expected:string;RemoveMe:TRemoveType;I:Integer;
  Jaw:TTransformNode;Before:Single;
procedure Check(Value:Boolean;const Message:string);
begin if not Value then raise Exception.Create(Message);end;
begin
  try
    Application.Initialize;Application.ShowMainForm:=False;Window:=TForm.CreateNew(nil);
    try
      View:=TProfessorView.Create(Window,Window);
      Check(View.LoadModel(ExpandFileName(ParamStr(1)),False),View.Diagnostic);
      Scene:=TPresentationScene(View.Scene);RemoveMe:=rtNone;
      for C in Commands do begin
        View.ResetCommands;Check(FindMovement(AvatarCommandName(C),M),'Missing movement');
        Check(View.ExecuteCommand(C),'Missing members: '+M.ID);Expected:='json:'+M.ID;
        Check(View.CurrentAnimation=Expected,'Wrong JSON movement: '+M.ID);
        View.SetActivity(psSpeaking);Check(View.CurrentAnimation=Expected,'Speech replaced movement');
        View.SetActivity(psIdle);Check(View.CurrentAnimation=Expected,'Idle replaced movement');
        for I:=1 to 100 do begin Scene.Update(0.05,RemoveMe);Check(Scene.MovementClearance>=-1E-8,'Protected parts overlap');end;
        Check(Scene.MovementBlocked='','Gesture interrupted: '+M.ID+' / '+Scene.MovementBlocked);
        Check(not Scene.MovementRunning,'Gesture did not finish: '+M.ID);
      end;
      View.ResetCommands;View.ExecuteCommand(acYawn);View.SetActivity(psSpeaking);
      Scene.Update(1.6,RemoveMe);Jaw:=TTransformNode(Scene.RootNode.FindNodeByName(TTransformNode,'jaw',False));
      Check(Jaw.Rotation.W>0.2,'Speech overrode yawn jaw');Before:=Jaw.Rotation.W;
      Scene.PauseJoints(True);Scene.Update(0.5,RemoveMe);
      Check(Abs(Jaw.Rotation.W-Before)<1E-8,'Pause changed gesture');Scene.PauseJoints(False);
      Scene.Update(5,RemoveMe);Check(Scene.MovementClearance>=-1E-8,'Return penetrated protected parts');
      View.ResetCommands;Check(not Scene.TimelineHasPose,'Reset kept JSON pose');
      WriteLn('PASS: 19 JSON gestures through real view, speech/idle preservation, collision guard, yawn jaw, pause and reset');
    finally Window.Free;end;
  except on E:Exception do begin WriteLn(StdErr,'FAIL: '+E.Message);Halt(1);end;end;
end.
