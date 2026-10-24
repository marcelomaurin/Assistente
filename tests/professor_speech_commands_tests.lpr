program professor_speech_commands_tests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, reception_core, professor_commands, movement_catalog;
const Expected: array[0..3] of TAvatarCommand = (acSmile,acApplause,acRaiseRightHand,acLowerRightHand);
var Config: TReceptionConfig; Job: TReceptionJob; Command: TAvatarCommand;
  StartTime,LastTime,Budget: QWord; Count,I: Integer;M:TMovementDefinition;
procedure Check(Condition: Boolean; const Message: string);
begin if not Condition then raise Exception.Create(Message);end;
begin
  Budget:=5000; // Silent text segments and scheduler overhead, plus actual catalog movements below.
  for I:=Low(Expected) to High(Expected) do begin
    Check(FindMovement(AvatarCommandName(Expected[I]),M),'Missing command movement');
    if Length(M.Timeline.Tracks)>0 then begin
      Inc(Budget,M.Timeline.DurationMS+M.Timeline.TransitionMS);
      if M.Timeline.ReturnToStart then Inc(Budget,M.Timeline.ReturnMS);
    end else if M.Mode='gesture' then Inc(Budget,M.Duration) else Inc(Budget,M.Transition);
  end;
  Config:=Default(TReceptionConfig);Config.EnableAvatarCommands:=True;Config.SilentPresentation:=True;
  Job:=TReceptionJob.Create(rjSpeak,Config,'[sorriso] Oi [aplausos] Obrigado '+
    '[levantar mão direita] Pergunte [abaixe mao direita]','','test');
  StartTime:=GetTickCount64;LastTime:=StartTime;Count:=0;
  try
    while not Job.Done do
    begin
      Check(GetTickCount64-StartTime<Budget,'Script stalled');
      Check(not Job.PlaybackActive,'Silent test attempted audio');
      if Job.TakeAvatarCommand(Command) then
      begin
        Check((Count<Length(Expected)) and (Command=Expected[Count]),'Mailbox order');
        if Count>0 then Check(GetTickCount64-LastTime>=250,'Tag fired ahead of prior segment');
        Inc(Count);LastTime:=GetTickCount64;Job.ConfirmAvatarCommand;
      end;
      Sleep(5);
    end;
    Check(Job.Success,Job.ErrorText);Check(Count=4,'Missing command');
    Check(Pos('[',Job.Text)=0,'Speech contains tags');
  finally Job.Free;end;
  Job:=TReceptionJob.Create(rjSpeak,Config,'[aplausos] text','','cancel-test');
  try
    StartTime:=GetTickCount64;
    while not Job.TakeAvatarCommand(Command) do
    begin Check(GetTickCount64-StartTime<2000,'No pending directive');Sleep(5);end;
    { Cancel while worker awaits acknowledgment, simulating a closing form. }
    Job.Cancel;StartTime:=GetTickCount64;Job.WaitFor;
    Check(GetTickCount64-StartTime<500,'Cancel blocked on UI acknowledgment');
    Check(not Job.Success,'Cancelled presentation succeeded');
  finally Job.Free;end;
  for Count:=1 to 20 do
  begin
    Job:=TReceptionJob.Create(rjSpeak,Config,'[sorriso] Oi','','immediate-cancel');
    try
      Job.Cancel;Job.WaitFor;
      Check(Job.Done,'Cancelled-before-entry worker never became done');
      Check(not Job.Success,'Immediate cancellation succeeded');
    finally Job.Free;end;
  end;
  WriteLn('PASS: ordered speech boundaries, trailing command, no audio/network in silent mode, cancellation while awaiting UI');
  WriteLn('PASS: immediate cancellation before thread entry (20 iterations)');
end.
