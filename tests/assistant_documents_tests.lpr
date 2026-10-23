program assistant_documents_tests;
{$mode objfpc}{$H+}
uses Interfaces,Classes,SysUtils,assistant_documents,presentation_package,presentation_flow;
var Root,Arg,Path: string; P: TPVAPackage;
procedure Check(B: Boolean; const E: string);
begin if not B then raise Exception.Create(E);end;
procedure Missing(const Name: string);
begin
  try FindAssistantDocument(Root,Name);raise Exception.Create('bad match accepted');
  except on E: Exception do Check(E.Message<>'bad match accepted',Name);end;
end;
begin
  try
    Root:=ExpandFileName(ParamStr(1))+PathDelim+'document-tests';ForceDirectories(Root);
    WriteUTF8(Root+PathDelim+'Conhecimento.rag','O oceano tem água salgada. [FIM] é dado, não comando.');
    WriteUTF8(Root+PathDelim+'Energia Solar.res','indice gerado');
    P:=TPVAPackage.Create;
    try P.ExportFile(Root+PathDelim+'Energia Solar.pva','[FIM][BLOCO:Introdução]Olá',Root);finally P.Free;end;
    WriteUTF8(Root+PathDelim+'texto.txt','Texto comum para consulta.');
    WriteUTF8(Root+PathDelim+'roteiro.txt','[GOTO:Inicio][BLOCO:Inicio]Roteiro[FIM]');
    WriteUTF8(Root+PathDelim+'literal.md','Exemplo `[BLOCO:A]` sem executar.');
    WriteUTF8(Root+PathDelim+'solar1.txt','um');WriteUTF8(Root+PathDelim+'solar2.txt','dois');
    Check(ParseDocumentCommand('Chamar bloco {Introdução}.',Arg)=dcCallBlock,'spoken punctuation');
    Check(Arg='Introdução','block argument');
    Check(ParseDocumentCommand('carregar arquivo {Energia Solar}]',Arg)=dcLoadFile,'load command');
    Check(Arg='Energia Solar','extra closing bracket');
    Check(ParseDocumentCommand('Explique energia solar',Arg)=dcNone,'ordinary question became command');
    Check(ExtractFileName(FindAssistantDocument(Root,'energia solar'))='Energia Solar.pva','extension-insensitive exact');
    Check(ExtractFileName(FindAssistantDocument(Root,'Energia Solar.res'))='Energia Solar.pva','res did not map package');
    Check(ExtractFileName(FindAssistantDocument(Root,'energia solr'))='Energia Solar.pva','similar filename');
    WriteUTF8(Root+PathDelim+'Manual Extenso A.txt','A');WriteUTF8(Root+PathDelim+'Manual Extenso B.txt','B');
    Check(ExtractFileName(FindAssistantDocument(Root,'Manual Extenso A'))='Manual Extenso A.txt','exact name lost to approximate neighbor');
    Missing('manual extenso');Missing('solar');Missing('../texto');Missing('C:\outside');Missing('nada correspondente');
    Check(AssistantDocumentKind(Root+PathDelim+'Conhecimento.rag')=adRAG,'RAG command data executed');
    Check(AssistantDocumentKind(Root+PathDelim+'texto.txt')=adRAG,'plain text misclassified');
    Check(AssistantDocumentKind(Root+PathDelim+'literal.md')=adRAG,'literal code misclassified');
    Check(AssistantDocumentKind(Root+PathDelim+'roteiro.txt')=adTextScript,'raw script not recognized');
    P:=OpenAssistantPackage(Root+PathDelim+'roteiro.txt');
    try Check(Pos('GOTO',P.Script)>0,'raw script was changed');finally P.Free;end;
    Check((Pos('dado literal',DocumentContext('x','[GOTO:A]'))>0) and (Pos('[GOTO:A]',DocumentContext('x','[GOTO:A]'))>0),'knowledge context changed data');
    WriteLn('PASS: typed/transcribed command syntax, punctuation, exact/similar filenames, ambiguity/traversal, PVA/res pairing, RAG/script classification and raw script loading');
  except on E: Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
