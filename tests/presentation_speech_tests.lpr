program presentation_speech_tests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, reception_core, professor_commands, presentation_tags;
var C: TReceptionConfig; J: TReceptionJob; Step: TAvatarScriptStep;
  Started,PauseAt: QWord; Count: Integer; PausedOnce,Resumed: Boolean;
procedure Check(B: Boolean; const E: string);
begin if not B then raise Exception.Create(E);end;
procedure Consume;
begin
  while J.TakeScriptCommand(Step) do begin
    case Count of
      0: Check(Step.Presentation.Action=paOpenFile,'open event order');
      1: Check(Step.Command=acSmile,'gesture event order');
      2: Check(Step.Presentation.Action=paCloseFile,'close event order');
      else Check(False,'extra directive');
    end;
    Inc(Count);J.ConfirmAvatarCommand;
  end;
end;
begin
  try
    PausedOnce:=False;Resumed:=False;Count:=0;
    C:=Default(TReceptionConfig);C.EnableAvatarCommands:=True;C.EnablePresentationCommands:=True;
    C.SynthEngine:=3;C.AudioToken:='local-test-only';C.URL:=ParamStr(1);
    C.Model:='local-test';C.Voice:='alloy';C.Volume:=100;
    J:=TReceptionJob.Create(rjSpeak,C,'[abrir arquivo=assets/one.png][sorriso]Primeiro trecho.[fechar arquivo]Segundo trecho.','','test');
    Started:=GetTickCount64;
    try
      while not J.Done do begin
        Check(GetTickCount64-Started<10000,'speech stalled');Consume;
        if J.PlaybackActive and not PausedOnce then begin J.SetPaused(True);PauseAt:=GetTickCount64;PausedOnce:=True;end;
        if PausedOnce and not Resumed and (GetTickCount64-PauseAt>100) then begin
          Check(J.Paused and not J.PlaybackActive,'audio pause not reflected');
          Check(Count=2,'timeline advanced while paused');
          if GetTickCount64-PauseAt>1100 then begin J.SetPaused(False);Resumed:=True;end;
        end;
        Sleep(5);
      end;
      Check(J.Success,J.ErrorText);Check(PausedOnce and Resumed and (Count=3),'missing playback events');
      Check(Pos('[',J.Text)=0,'TTS contains tags');
    finally J.Free;end;
    J:=TReceptionJob.Create(rjSpeak,C,'Cancelamento durante a pausa.','','cancel');
    Started:=GetTickCount64;
    try
      while not J.PlaybackActive and not J.Done do begin Check(GetTickCount64-Started<6000,'no playback');Sleep(5);end;
      Check(J.PlaybackActive,'cancel fixture failed');J.SetPaused(True);Sleep(50);J.Cancel;
      Started:=GetTickCount64;J.WaitFor;
      Check(GetTickCount64-Started<1000,'cancel while paused blocked');
      Check(J.Done and not J.Success and not J.PlaybackActive,'paused cancellation failed');
    finally J.Free;end;
    WriteLn('PASS: real WAV playback with synchronized media/gesture events, pause/resume, clean TTS, cancellation while paused');
  except on E: Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
