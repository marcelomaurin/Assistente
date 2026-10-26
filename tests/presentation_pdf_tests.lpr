program presentation_pdf_tests;
{$mode objfpc}{$H+}{$codepage utf8}
uses Classes, SysUtils, FPImage, FPWritePNG, LazUTF8, presentation_pdf,
  assistant_text_search, movement_catalog;
var Directory, Source, Target, Catalog: string; Items: TPrintItems;
  Position, Count, I: Integer; Wrapped, Failed: Boolean; Text: TStringList;
procedure Check(Value: Boolean; const Message: string);
begin if not Value then raise Exception.Create(Message);end;
procedure WriteFile(const Name, Value: string);
var Stream: TFileStream;
begin Stream:=TFileStream.Create(Name,fmCreate);try if Value<>'' then Stream.WriteBuffer(Value[1],Length(Value));finally Stream.Free;end;end;
procedure Image(const Name: string; W,H: Integer; Red: Boolean);
var Picture: TFPMemoryImage; Writer: TFPWriterPNG; X,Y: Integer; Color: TFPColor;
begin
  Picture:=TFPMemoryImage.Create(W,H);Writer:=TFPWriterPNG.Create;
  try
    Color:=colWhite;if Red then begin Color.Red:=$FFFF;Color.Green:=$4000;Color.Blue:=$4000;end
    else begin Color.Red:=$3000;Color.Green:=$8000;Color.Blue:=$FFFF;end;
    for Y:=0 to H-1 do for X:=0 to W-1 do Picture.Colors[X,Y]:=Color;
    Picture.SaveToFile(Name,Writer);
  finally Picture.Free;Writer.Free;end;
end;
begin
  try
    if ParamCount<>1 then raise Exception.Create('Use presentation_pdf_tests <output-directory>');
    Directory:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));ForceDirectories(Directory+'assets');
    Catalog:=Directory+'movements.json';
    WriteFile(Catalog,'{"version":1,"movements":[{"id":"sorriso","tag":"sorriso","clip":"idle","title":"Sorriso"}]}');
    ReloadMovementCatalog(Catalog);
    Source:='Introdução. [sorriso][executar arquivo=assets/slide1.png]Coração e circulação. [{Detalhe}] Final. [FIM] Não imprimir.'+
      '[BLOCO:{Detalhe}][executar arquivo=assets/slide2.png]Explicação com ação, pressão e hemácias.';
    Items:=PresentationPrintItems(Source);
    Check(Length(Items)=5,'Unexpected print event count');
    Check((Items[0].Kind=pikText) and (Items[0].Text='Introdução.'),'Intro order');
    Check((Items[1].Kind=pikImage) and (Items[1].Resource='assets/slide1.png'),'First image order');
    Check((Items[2].Kind=pikText) and (Pos('Coração',Items[2].Text)>0),'Narration order');
    Check((Items[3].Kind=pikImage) and (Items[3].Resource='assets/slide2.png'),'Called block image order');
    Check((Pos('Explicação',Items[4].Text)>0) and (Pos('Final.',Items[4].Text)>0) and
      (Pos('Não imprimir',Items[4].Text)=0),'Inline call or FIM ordering');
    Items:=PresentationPrintItems(Source,'Detalhe');
    Check((Length(Items)=2) and (Items[0].Resource='assets/slide2.png'),'Entry block export');
    Items:=PresentationPrintItems('[executar arquivo=assets/deck.pptx]Um.[proximo slide]Dois.[slide anterior]Um.[ir para slide=3]Três.');
    Check((Items[0].Slide=1) and (Items[2].Slide=2) and (Items[4].Slide=1) and (Items[6].Slide=3),'PPTX navigation order');
    Check(FindAssistantText('Ação e AÇÃO; coração.','ação',0,Position,Count,Wrapped) and
      (Position=0) and (Count=4) and not Wrapped,'Accented case insensitive search');
    Check(FindAssistantText('Ação e AÇÃO; coração.','ação',4,Position,Count,Wrapped) and (Position=7),'Next UTF8 occurrence');
    Check(FindAssistantText('Ação e AÇÃO; coração.','ação',11,Position,Count,Wrapped) and (Position=16),'Substring search');
    Check(FindAssistantText('Ação e AÇÃO; coração.','ação',20,Position,Count,Wrapped) and (Position=0) and Wrapped,'Wrap search');
    Check(not FindAssistantText('coração','ausente',0,Position,Count,Wrapped),'Absent search');
    Check(not FindAssistantText('coração','',0,Position,Count,Wrapped),'Empty search');
    Image(Directory+'assets/slide1.png',1200,600,True);Image(Directory+'assets/slide2.png',500,900,False);
    Target:=Directory+'presentation.pdf';ExportPresentationPDF(Source,Directory,Target,'Apresentação de teste');
    Check(FileExists(Target),'PDF missing');
    Source:='[executar arquivo=assets/slide1.png]'+LineEnding+'Circulação, ação, pressão, hemácias e coração.'+LineEnding;
    for I:=1 to 110 do Source:=Source+'Parágrafo '+IntToStr(I)+': conferência de paginação e leitura em português.'+LineEnding;
    Source:=Source+StringOfChar('W',250)+LineEnding+'Fim da apresentação.';
    ExportPresentationPDF(Source,Directory,Directory+'pagination.pdf','Paginação e palavras longas');
    Target:=Directory+'preserved.pdf';WriteFile(Target,'existing PDF');Failed:=False;
    try ExportPresentationPDF('[executar arquivo=assets/missing.png]Texto',Directory,Target,'Erro');
    except on E: Exception do Failed:=True;end;
    Check(Failed,'Missing image must fail');Text:=TStringList.Create;
    try Text.LoadFromFile(Target);Check(Trim(Text.Text)='existing PDF','Failed export overwrote destination');finally Text.Free;end;
    Failed:=False;try Items:=PresentationPrintItems('[GOTO:{Inexistente}]');except on E: Exception do Failed:=True;end;
    Check(Failed,'Invalid flow must fail');
    WriteLn('PASS: execution order, inline blocks, FIM, entry blocks, PPTX navigation, UTF-8 search, PDF generation, pagination and failed-export preservation');
  except on E: Exception do begin WriteLn('FAIL: '+E.Message);Halt(1);end;end;
end.
