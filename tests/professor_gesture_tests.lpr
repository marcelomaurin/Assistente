program professor_gesture_tests;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, ExtCtrls, professor_view,
  professor_commands, professor_state, X3DNodes;
type TRunner=class(TComponent)
public
  View:TProfessorView;Timer:TTimer;Started:QWord;JawChecked,PoseHeld:Boolean;
  procedure Tick(Sender:TObject);
  constructor Create(AOwner:TComponent);override;
end;
const Commands:array[0..18] of TAvatarCommand=(acOK,acThumbsUp,acHeart,acNod,
  acShakeHead,acRaiseLeftHand,acRaiseBothHands,acLookBackRight,acLookBackLeft,
  acFingerNo,acRaiseRightFoot,acCloseLeftHand,acOpenLeftHand,
  acCloseRightHand,acOpenRightHand,acYawn,acOpenEyes,acCloseEyes,acBlink);
var Window:TForm;Runner:TRunner;
procedure Check(Value:Boolean;const Message:string);
begin if not Value then raise Exception.Create(Message);end;
constructor TRunner.Create(AOwner:TComponent);
var C:TAvatarCommand;Expected:string;
begin
  inherited;
  View:=TProfessorView.Create(Self,Window);
  Check(View.LoadModel(ExpandFileName(ParamStr(1)),False),View.Diagnostic);
  for C in Commands do begin
    View.ResetCommands;
    Check(View.ExecuteCommand(C),'Missing clip: '+AvatarCommandName(C));
    Expected:=StringReplace(AvatarCommandName(C),' ','_',[rfReplaceAll]);
    Check(View.CurrentAnimation=Expected,'Wrong selected clip: '+Expected);
    View.SetActivity(psSpeaking);
    Check(View.CurrentAnimation=Expected,'Speaking replaced gesture: '+Expected);
    View.SetActivity(psIdle);
    Check(View.CurrentAnimation=Expected,'Idle disabled persistent pose: '+Expected);
  end;
  View.ExecuteCommand(acRaiseLeftHand);View.ExecuteCommand(acRaiseRightHand);
  Check(View.CurrentAnimation='idle_right_hand_up','Right hand blocked by left pose');
  View.ExecuteCommand(acLowerBothHands);
  Check(View.CurrentAnimation='','Lower both left a raised hand');
  View.ExecuteCommand(acCloseEyes);View.ResetCommands;
  Check(View.CurrentAnimation='','Reset did not clear eyes');
  View.ExecuteCommand(acRaiseLeftHand);View.ExecuteCommand(acYawn);
  View.SetActivity(psSpeaking);
  Started:=GetTickCount64;
  Timer:=TTimer.Create(Self);Timer.Interval:=50;Timer.OnTimer:=@Tick;
end;
procedure TRunner.Tick(Sender:TObject);
begin
  try
    if (GetTickCount64-Started>600) and not PoseHeld then begin
      View.Scene.ForceAnimationPose('bocejar',1.6,True);
      View.Scene.TimePlaying:=False;PoseHeld:=True;
    end;
    if (GetTickCount64-Started>1200) and not JawChecked then begin
      Check(TTransformNode(View.Scene.RootNode.FindNodeByName(TTransformNode,'jaw',False)).Rotation.W>0.2, 'Speech overrode the yawn jaw: '+FloatToStr(TTransformNode(View.Scene.RootNode.FindNodeByName(TTransformNode,'jaw',False)).Rotation.W));
      JawChecked:=True;View.Scene.TimePlaying:=True;
    end;
    if GetTickCount64-Started<3000 then
      Check(View.CurrentAnimation='bocejar','Yawn expired before 4 seconds');
    if GetTickCount64-Started>4200 then begin
      Check(JawChecked,'Yawn jaw was not inspected');
      Check(View.CurrentAnimation='levantar_mao_esquerda','Transient did not return to persistent pose');
      View.ResetCommands;Timer.Enabled:=False;
      WriteLn('PASS: 19 real clips, speaking, disabled idle, hand switching, reset, 4-second yawn and pose restoration');
      Application.Terminate;
    end;
  except on E:Exception do begin
    WriteLn('FAIL: '+E.Message);ExitCode:=1;Timer.Enabled:=False;Application.Terminate;
  end;end;
end;
begin
  Application.Initialize;Window:=TForm.CreateNew(nil);Window.Width:=480;Window.Height:=640;
  Window.Show;Runner:=TRunner.Create(Window);Application.Run;Window.Free;
end.
