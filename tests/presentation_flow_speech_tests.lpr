program presentation_flow_speech_tests;
{$mode objfpc}{$H+}
uses Classes,SysUtils,reception_core,presentation_flow,professor_commands,presentation_tags;
var C: TReceptionConfig; J: TReceptionJob; P: TFlowProgram; Step: TAvatarScriptStep;
  Compiled: string; Started: QWord; Ends: Integer;
procedure Check(B: Boolean; const E: string);
begin if not B then raise Exception.Create(E);end;
begin
  try
    P:=TFlowProgram.Create('[EVENT=DETECCAO_VOZ:A]Inicio [{A}] Retorno.[FIM]Nao falar[BLOCO:A]Dentro');
    try Compiled:=P.Compile;finally P.Free;end;
    C:=Default(TReceptionConfig);C.EnableAvatarCommands:=True;C.EnablePresentationCommands:=True;
    C.SynthEngine:=3;C.AudioToken:='local-test';C.URL:=ParamStr(1);C.Model:='local-test';C.Voice:='alloy';C.Volume:=100;
    J:=TReceptionJob.Create(rjSpeak,C,Compiled,'','flow-tts');Started:=GetTickCount64;Ends:=0;
    try
      repeat
        Check(GetTickCount64-Started<10000,'flow speech stalled');
        while J.TakeScriptCommand(Step) do begin
          Check(Step.Presentation.Action=paEndTask,'unexpected flow speech event');Inc(Ends);J.ConfirmAvatarCommand;
        end;
        if J.Done then Break;Sleep(5);
      until False;
      Check(J.Success,J.ErrorText);Check(Ends=1,'FIM not delivered to interface');
      Check(J.Text='Inicio Dentro Retorno.','block metadata or unreachable text reached TTS');
    finally J.Free;end;
    WriteLn('PASS: compiled flow speaks only executable text; FIM dispatched after speech without reading tags or dormant events');
  except on E: Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
