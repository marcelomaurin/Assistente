unit presentation_questions;
{$mode objfpc}{$H+}
interface
uses SysUtils,presentation_flow,assistant_documents;
function QuestionBlock(Flow:TFlowProgram;const Input:string;out Name:string):Boolean;
function PresentationQuestionContext(Flow:TFlowProgram;const FileName,Question:string):string;
implementation
uses professor_commands;
function QuestionBlock(Flow:TFlowProgram;const Input:string;out Name:string):Boolean;
var S,Key,Argument:string;I,N:Integer;Command:TLocalDocumentCommand;Explicit:Boolean;
begin
 Result:=False;Name:='';if Flow=nil then Exit;
 S:=Trim(Input);Command:=ParseDocumentCommand(S,Argument);Explicit:=Command=dcCallBlock;
 if Command=dcLoadFile then raise Exception.Create('Encerre a apresentacao antes de carregar outro arquivo.');
 if Explicit then S:=Argument
 else if Copy(FlowNameKey(S),1,3)='ir ' then begin S:=Trim(Copy(S,4,MaxInt));Explicit:=True;end;
 while (Length(S)>0) and (S[1] in ['[','{']) do Delete(S,1,1);
 while (Length(S)>0) and (S[Length(S)] in [']','}','.','!','?']) do Delete(S,Length(S),1);
 Key:=FlowNameKey(S);
 if Copy(Key,1,6)='bloco ' then begin S:=Trim(Copy(S,7,MaxInt));Key:=FlowNameKey(S);Explicit:=True;end;
 I:=Flow.BlockIndex(S);if I>=0 then begin Name:=Flow.BlockName(I);Exit(True);end;
 if TryStrToInt(S,N) then begin
  if (N<1) or (N>Flow.BlockCount) then raise Exception.Create('Numero de bloco fora da apresentacao.');
  Name:=Flow.BlockName(N-1);Exit(True);
 end;
 if Explicit then raise Exception.Create('Bloco nao encontrado: '+S);
end;
function PresentationQuestionContext(Flow:TFlowProgram;const FileName,Question:string):string;
var Script:TAvatarScript;
begin
 if Flow=nil then raise Exception.Create('Apresentacao sem roteiro carregado.');
 Script:=ParseAvatarScript(Flow.WithoutFlowTags,4096);
 Result:=LineEnding+'Pergunta sobre a apresentacao em andamento. Responda em portugues usando o roteiro abaixo como fonte principal e os trechos do RAG fornecidos como referencias complementares. '+
 'Identifique pelo nome as fontes complementares usadas e diferencie seu conteudo do roteiro. Se as fontes nao contiverem a resposta, diga isso claramente. Nao invente detalhes das imagens ou slides. '+
 'Responda em texto, sem executar comandos, alterar a apresentacao ou escolher outro arquivo.'+LineEnding+
 DocumentContext(FileName,Script.PlainText,Question);
end;
end.
