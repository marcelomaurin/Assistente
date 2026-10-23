program presentation_ai_tests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, presentation_ai, presentation_document;
var C: TPresentationAIConfig; J: TPresentationAIJob; Started: QWord; Original: string;
procedure Check(B: Boolean; const E: string);
begin if not B then raise Exception.Create(E);end;
begin
  try
    C:=Default(TPresentationAIConfig);C.Token:='local-test-only';C.URL:=ParamStr(1);C.Model:='local-test';
    Original:='Olá [abrir arquivo=assets/one.png]mundo.'+#10;
    J:=TPresentationAIJob.Create(C,Original);
    try
      Started:=GetTickCount64;
      while not J.Finished do begin Check(GetTickCount64-Started<10000,'AI timeout');Sleep(10);end;
      if ParamStr(2)='reject' then Check(J.ErrorText<>'','AI rewrite was accepted')
      else begin
        Check(J.ErrorText='',J.ErrorText);Check(J.Output='[sorriso]'+Original,'AI output or UTF8 changed');
      end;
    finally J.Free;end;
    WriteLn('PASS: configured TCHATGPT request and ',ParamStr(2));
  except on E: Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
