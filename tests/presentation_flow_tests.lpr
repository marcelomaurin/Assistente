program presentation_flow_tests;
{$mode objfpc}{$H+}
uses Classes,SysUtils,presentation_flow,presentation_document,presentation_package;
procedure Check(B: Boolean; const E: string);
begin if not B then raise Exception.Create(E);end;
procedure Rejected(const Source: string);
var P: TFlowProgram;
begin
  try P:=TFlowProgram.Create(Source);P.Free;raise Exception.Create('invalid flow accepted');
  except on E: Exception do Check(E.Message<>'invalid flow accepted',Source);end;
end;
var P: TFlowProgram; Source,Compiled: string; I,J: Integer;
begin
  try
    Source:='Principal [{A}] retorno.[FIM]inacessivel[BLOCO:{A}]A[{B}]C[BLOCO:{B}]B';
    P:=TFlowProgram.Create(Source);
    try
      Check(P.Compile='Principal ABC retorno.[FIM]','call did not return');
      Check(P.Compile('b')='B[FIM]','named entry crossed block boundary');
      Check(P.BlockCount=2,'block inventory');
    finally P.Free;end;
    P:=TFlowProgram.Create('Antes[GOTO:{A}]nao ler[BLOCO:{A}]Destino[BLOCO:{B}]nao ler');
    try Check(P.Compile='AntesDestino[FIM]','GOTO boundary');finally P.Free;end;
    P:=TFlowProgram.Create('[{A}]nao ler[BLOCO:{A}]Dentro[FIM]fora[BLOCO:{B}]fora');
    try Check(P.Compile='Dentro[FIM]','FIM did not terminate caller');finally P.Free;end;
    P:=TFlowProgram.Create('[A]fim[BLOCO:A]texto');
    try Check(P.Compile='textofim[FIM]','shorthand');finally P.Free;end;
    P:=TFlowProgram.Create('[BLOCO:Introdução]Somente por chamada[BLOCO:outro]Nao executar');
    try
      Check(P.Compile='[FIM]','declarations executed automatically');
      Check(P.Compile('INTRODUCAO')='Somente por chamada[FIM]','accent/case block lookup');
    finally P.Free;end;
    P:=TFlowProgram.Create('[EVENT={Detecção de voz}:{A}][EVENT=Detecção de rosto:A]'+
      '[EVENT=Detecção de mão levantada:A][EVENT=Reconhecimento de pessoa:A]Principal[BLOCO:A]Evento');
    try
      Check((P.EventCount=4) and (P.EventBinding(2).EventName='MAO_LEVANTADA'),'event inventory');
      Check(P.Compile='Principal[FIM]','event executed a block');
      Check(Pos('EVENT',P.WithoutFlowTags)=0,'event leaked into text projection');
    finally P.Free;end;
    P:=TFlowProgram.Create('`[BLOCO:A]` \[FIM] [GOTO:A](link) [{A}](link)');
    try Check(not P.HasFlow,'literal code, escape or link became executable');finally P.Free;end;
    Rejected('[GOTO:missing]');Rejected('[{missing}]');Rejected('[BLOCO:A]1[BLOCO:a]2');
    Rejected('[BLOCO:Introdução]1[BLOCO:introducao]2');Rejected('[BLOCO:sorriso]x');
    Rejected('[BLOCO:A][A]');Rejected('[BLOCO:A][B][BLOCO:B][GOTO:A]');
    Rejected('[EVENT=evento falso:A][BLOCO:A]x');Rejected('[EVENT=DETECCAO_VOZ:missing]');
    Rejected('[EVENT=DETECCAO_VOZ:A][EVENT=Detecção de voz:A][BLOCO:A]x');
    Rejected('[BLOCO=foo]');Rejected('[BLOCO:{A]');Rejected('[GOTO:A');
    Source:='[{A}][BLOCO:A]Texto [sorriso]';
    Check(AcceptGeneratedMovements(Source,'[aceno]'+Source)='[aceno]'+Source,'AI preservation');
    try AcceptGeneratedMovements(Source,'[{A}][BLOCO:A]Alterado');raise Exception.Create('AI rewrote block');
    except on E: Exception do Check(Pos('IA alterou',E.Message)>0,'AI preservation error');end;
    ValidatePresentationScript('[GOTO:A][BLOCO:A]ok[FIM]');
    ValidatePresentationScript('`[BLOCO:arquivo]` [GOTO:arquivo](link)');
    Source:='';for I:=1 to 100 do Source:=Source+'[{A}]';Source:=Source+'[BLOCO:A]';
    for J:=1 to 50 do Source:=Source+'[sorriso]';
    try ValidatePresentationScript(Source);raise Exception.Create('expanded event limit ignored');
    except on E:Exception do Check(Pos('4096',E.Message)>0,'expanded event limit');end;
    P:=TFlowProgram.Create('[EVENT=DETECCAO_VOZ:A][EVENT=DETECCAO_VOZ:B][BLOCO:A]A[BLOCO:B]B');
    try Check(P.EventCount=2,'different event bindings rejected');finally P.Free;end;
    WriteLn('PASS: blocks, GOTO, nested returning calls, global FIM, literal syntax, reserved names, dormant events, cycles and AI preservation');
  except on E: Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
