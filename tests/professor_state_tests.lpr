program professor_state_tests;
{$mode objfpc}{$H+}
uses SysUtils, professor_state;
var M: TProfessorStateMachine;
procedure Check(B: Boolean; const Msg: string);
begin if not B then raise Exception.Create(Msg); end;
begin
  M := TProfessorStateMachine.Create;
  try
    Check(M.State = psIdle, 'initial idle');
    M.SetActivity(psListening);
    M.Gesture(psWave, 100);
    M.Tick(2499);
    Check(M.State = psWave, 'wave duration');
    M.Tick(2500);
    Check(M.State = psListening, 'return to latest activity');
    M.Gesture(psWalk, 3000);
    M.SetActivity(psThinking);
    M.Tick(9000);
    Check(M.State = psThinking, 'new question preempts walk');
    M.Gesture(psWave, 10000);
    Check(M.State = psThinking, 'gesture cannot override thinking');
    M.SetActivity(psSpeaking);
    M.Gesture(psWalk, 12000);
    Check(M.State = psSpeaking, 'gesture cannot override speech');
    M.SetActivity(psIdle);
    M.Gesture(psWalk, 15000);
    M.Tick(17400);
    Check(M.State = psIdle, 'walk expiry');
    Check(AnimationName(psSpeaking) = 'talking', 'speech clip contract');
    WriteLn('PASS: professor state transitions and priorities');
  finally M.Free; end;
end.
