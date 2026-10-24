program professor_remote_speech_tests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, reception_core, professor_commands;
var Config: TReceptionConfig; Job: TReceptionJob; Command: TAvatarCommand;
  Started, PlayingSince,LongestPlayback: QWord; Count, Iteration: Integer; SawPlayback: Boolean;
procedure Check(B: Boolean; const Msg: string);
begin if not B then raise Exception.Create(Msg); end;
procedure StartJob(const Text: string);
begin
  Job:=TReceptionJob.Create(rjSpeak,Config,Text,'','remote-test');
  Started:=GetTickCount64;PlayingSince:=0;LongestPlayback:=0;Count:=0;SawPlayback:=False;
end;
procedure Poll;
begin
  Check(GetTickCount64-Started<10000,'Remote speech stalled');
  if Job.TakeAvatarCommand(Command) then
  begin
    Check(not Job.PlaybackActive,'Playback began before command acknowledgment');
    Inc(Count);Job.ConfirmAvatarCommand;
  end;
  if Job.PlaybackActive then
  begin
    SawPlayback:=True;
    if PlayingSince=0 then PlayingSince:=GetTickCount64;
  end;
  if not Job.PlaybackActive and (PlayingSince<>0) then begin
    if GetTickCount64-PlayingSince>LongestPlayback then LongestPlayback:=GetTickCount64-PlayingSince;
    PlayingSince:=0;
  end;
  Sleep(5);
end;
begin
  Check(ParamCount=1,'Pass local mock endpoint');
  Config:=Default(TReceptionConfig);Config.EnableAvatarCommands:=True;
  Config.SynthEngine:=3;Config.AudioToken:='local-test-only';
  Config.URL:=ParamStr(1);Config.Model:='test-tts';Config.Voice:='alloy';Config.Volume:=100;
  { Run twice: the synthesizer's default cache must not redirect the job file. }
  for Iteration:=1 to 2 do
  begin
    StartJob('[sorriso] primeira [aplausos] segunda [abaixar mao direita]');
    try
      while not Job.Done do Poll;
      Check(Job.Success,Job.ErrorText);Check(Count=3,'Lost speech-boundary command');
      Check(SawPlayback,'No actual remote playback');
      Check(not Job.PlaybackActive,'Completed job still reports playback');
      Check(GetTickCount64-Started>=1400,'Playback returned before both segments completed');
      if (PlayingSince<>0) and (GetTickCount64-PlayingSince>LongestPlayback) then LongestPlayback:=GetTickCount64-PlayingSince;
      // Fixture PCM is 500 ms; gesture waits are separate from audio completion.
      Check(LongestPlayback<1500,'Metadata inflated individual WAV playback duration');
    finally Job.Free;end;
  end;
  WriteLn('PASS: repeated remote WAV, actual completion, metadata chunks, commands before playback');
  StartJob('[sorriso] streaming-wav');
  try
    while not Job.Done do Poll;
    Check(Job.Success,Job.ErrorText);Check(SawPlayback and (Count=1),'Streaming WAV was not finalized before playback');
  finally Job.Free;end;
  WriteLn('PASS: OpenAI streaming WAV header finalized and played with gesture synchronization');
  StartJob('[sorriso] cancel');
  try
    while not Job.PlaybackActive and not Job.Done do Poll;
    Check(Job.PlaybackActive,'No playback to cancel');
    Job.Cancel;Started:=GetTickCount64;Job.WaitFor;
    Check(GetTickCount64-Started<1000,'Cancel did not stop playback promptly');
    Check(Job.Done and not Job.Success and Job.Cancelled,'Cancellation outcome');
    Check(not Job.PlaybackActive,'Cancelled job still playing');
  finally Job.Free;end;
  WriteLn('PASS: cancellation during actual playback');
  StartJob('[sorriso] fail');
  try
    while not Job.Done do Poll;
    Check(not Job.Success and (Job.ErrorText<>''),'HTTP failure not reported');
    Check(not SawPlayback and (Count=0),'Failed synthesis applied gesture or played audio');
  finally Job.Free;end;
  StartJob('invalid-audio');
  try
    while not Job.Done do Poll;
    Check(not Job.Success and (Job.ErrorText<>''),'Invalid audio accepted');
    Check(not SawPlayback,'Invalid audio started playback');
  finally Job.Free;end;
  WriteLn('PASS: HTTP and invalid audio failures without playback');
end.
