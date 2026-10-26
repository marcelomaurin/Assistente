unit presentation_pdf;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils;
type
  TPrintItemKind = (pikText, pikImage, pikSlide, pikMedia);
  TPrintItem = record
    Kind: TPrintItemKind;
    Text, Resource: string;
    Slide: Integer;
  end;
  TPrintItems = array of TPrintItem;
function PresentationPrintItems(const Source: string; const EntryBlock: string = ''): TPrintItems;
procedure ExportPresentationPDF(const Source, AssetRoot, FileName, Title: string;
  const EntryBlock: string = '');
implementation
uses Math, LazUTF8, fpPDF, fpTTF, presentation_flow, professor_commands,
  presentation_tags, presentation_paths
  {$ifdef windows}, Windows, ActiveX, ComObj, Variants{$endif};

function PresentationPrintItems(const Source: string; const EntryBlock: string): TPrintItems;
var Flow: TFlowProgram; Script: TAvatarScript; I, N, Slide: Integer;
  Deck, Buffer, Ext: string; Step: TAvatarScriptStep;
  procedure Add(Kind: TPrintItemKind; const Text, Resource: string; Number: Integer = 0);
  begin
    N:=Length(Result);SetLength(Result,N+1);Result[N].Kind:=Kind;
    Result[N].Text:=Text;Result[N].Resource:=Resource;Result[N].Slide:=Number;
  end;
  procedure Flush;
  begin
    if Trim(Buffer)<>'' then Add(pikText,Trim(Buffer),'');Buffer:='';
  end;
begin
  Result:=nil;Deck:='';Slide:=0;Buffer:='';Flow:=TFlowProgram.Create(Source);
  try Script:=ParseAvatarScript(Flow.Compile(EntryBlock),4096);finally Flow.Free;end;
  for I:=0 to High(Script.Steps) do begin
    Step:=Script.Steps[I];Buffer:=Buffer+Step.Text;
    case Step.Presentation.Action of
      paOpenFile: begin
        Flush;Ext:=LowerCase(ExtractFileExt(Step.Presentation.Argument));
        if not AudioPresentationMedia(Step.Presentation.Argument) then begin Deck:='';Slide:=0;end;
        if (Ext='.png') or (Ext='.jpg') or (Ext='.jpeg') or (Ext='.bmp') then
          Add(pikImage,'',Step.Presentation.Argument)
        else if Ext='.pptx' then begin
          Deck:=Step.Presentation.Argument;Slide:=1;Add(pikSlide,'',Deck,Slide);
        end else begin
          Ext:='Mídia: '+Step.Presentation.Argument;
          if Step.Presentation.HasStart then Ext:=Ext+' (início em '+IntToStr(Step.Presentation.StartMS div 1000)+' s)';
          Add(pikMedia,Ext,Step.Presentation.Argument);
        end;
      end;
      paNextSlide,paPreviousSlide,paGoToSlide: begin
        Flush;if Deck='' then raise Exception.Create('Navegação de slide sem apresentação PPTX aberta');
        case Step.Presentation.Action of
          paNextSlide: Inc(Slide);
          paPreviousSlide: Slide:=Max(1,Slide-1);
          paGoToSlide: Slide:=Step.Presentation.Slide;
        end;
        Add(pikSlide,'',Deck,Slide);
      end;
      paYouTube: begin Flush;Add(pikMedia,'Vídeo do YouTube: '+Step.Presentation.Argument,Step.Presentation.Argument);Deck:='';end;
      paCloseFile: begin Flush;Deck:='';Slide:=0;end;
      paEndTask: begin Flush;Break;end;
    end;
  end;
  Flush;
end;

type
  TPresentationPDF = class
  private
    Document: TPDFDocument;
    FontCache: TFPFontCacheList;
    FontMetric: TFPFontCacheItem;
    Page: TPDFPage;
    FontIndex: Integer;
    Y: Double;
    FTitle, Root, TempDirectory: string;
    {$ifdef windows}
    PowerPoint, Deck: OleVariant;
    DeckFile: string;
    COMInitialized, OwnPowerPoint: Boolean;
    {$endif}
    procedure NewPage;
    procedure EnsureSpace(Height: Double);
    function TextWidth(const Text: string; Size: Integer): Double;
    procedure Paragraph(const Text: string; Size: Integer = 11);
    procedure Image(const FileName: string);
    function RenderSlide(const FileName: string; Slide: Integer): string;
    function ResourceFile(const Name: string): string;
  public
    constructor Create(const AssetRoot, Title: string);
    destructor Destroy; override;
    procedure Save(const Items: TPrintItems; const FileName: string);
  end;

function PDFFontFile: string;
var Base: string;
begin
  Base:=IncludeTrailingPathDelimiter(SysUtils.GetEnvironmentVariable('WINDIR'))+'Fonts'+PathDelim;
  if FileExists(Base+'segoeui.ttf') then Exit(Base+'segoeui.ttf');
  if FileExists(Base+'arial.ttf') then Exit(Base+'arial.ttf');
  Result:='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  if FileExists(Result) then Exit;
  Result:=ExtractFilePath(ParamStr(0))+'fonts'+PathDelim+'DejaVuSans.ttf';
  if not FileExists(Result) then raise Exception.Create('Fonte TrueType para PDF não encontrada (Segoe UI, Arial ou DejaVu Sans).');
end;

constructor TPresentationPDF.Create(const AssetRoot, Title: string);
var FontFile: string; G: TGUID;
begin
  inherited Create;Root:=IncludeTrailingPathDelimiter(ExpandFileName(AssetRoot));FTitle:=Title;
  CreateGUID(G);TempDirectory:=IncludeTrailingPathDelimiter(GetTempDir(False))+'assistente-print-'+GUIDToString(G);
  if not CreateDir(TempDirectory) then raise Exception.Create('Não foi possível criar a pasta temporária do PDF.');
  Document:=TPDFDocument.Create(nil);FontCache:=TFPFontCacheList.Create;FontCache.DPI:=72;
  FontFile:=PDFFontFile;FontMetric:=TFPFontCacheItem.Create(FontFile);FontCache.Add(FontMetric);
  Document.Options:=[poPageOriginAtTop,poSubsetFont,poCompressFonts,poCompressImages,poCompressText,poUseImageTransparency,poUTF16info];
  Document.DefaultPaperType:=ptA4;Document.DefaultUnitOfMeasure:=uomMillimeters;
  Document.Infos.Title:=Title;Document.Infos.Author:='Assistente | Maurinsoft';
  Document.Infos.CreationDate:=Now;Document.Infos.Producer:='Assistente | Maurinsoft';
  Document.StartDocument;Document.Sections.AddSection;
  FontIndex:=Document.AddFont(FontFile,'Assistente');
  {$ifdef windows}PowerPoint:=Unassigned;Deck:=Unassigned;{$endif}
end;
destructor TPresentationPDF.Destroy;
var Search: TSearchRec;
begin
  {$ifdef windows}
  try if not VarIsEmpty(Deck) then Deck.Close;except end;
  Deck:=Unassigned;
  try if OwnPowerPoint and not VarIsEmpty(PowerPoint) then PowerPoint.Quit;except end;
  PowerPoint:=Unassigned;if COMInitialized then CoUninitialize;
  {$endif}
  Document.Free;FontCache.Free;
  if TempDirectory<>'' then begin
    if FindFirst(IncludeTrailingPathDelimiter(TempDirectory)+'*',faAnyFile,Search)=0 then
    try repeat
      if (Search.Attr and faDirectory)=0 then SysUtils.DeleteFile(IncludeTrailingPathDelimiter(TempDirectory)+Search.Name);
    until FindNext(Search)<>0;finally SysUtils.FindClose(Search);end;
    RemoveDir(TempDirectory);
  end;
  inherited Destroy;
end;
function TPresentationPDF.TextWidth(const Text: string; Size: Integer): Double;
begin Result:=FontMetric.TextWidth(Text,Size)*25.4/72;end;
procedure TPresentationPDF.NewPage;
var Header: string;
begin
  Page:=Document.Pages.AddPage;Document.Sections[0].AddPage(Page);
  Header:='Assistente | '+FTitle;
  while (TextWidth(Header,9)>174) and (UTF8Length(Header)>4) do Header:=UTF8Copy(Header,1,UTF8Length(Header)-4)+'...';
  Page.SetFont(FontIndex,9);Page.SetColor($667085,False);Page.WriteText(18,15,Header);
  Page.SetColor($202733,False);Y:=28;
end;
procedure TPresentationPDF.EnsureSpace(Height: Double);
begin if (Page=nil) or (Y+Height>276) then NewPage;end;
procedure TPresentationPDF.Paragraph(const Text: string; Size: Integer);
var Lines: TStringList; I, Lo, Hi, Mid, Count, Cut, J: Integer; Line, Part: string;
  LineHeight: Double;
begin
  Lines:=TStringList.Create;
  try
    Lines.Text:=StringReplace(Text,#9,'    ',[rfReplaceAll]);LineHeight:=Size*25.4/72*1.45;
    for I:=0 to Lines.Count-1 do begin
      Line:=Lines[I];
      if Line='' then begin EnsureSpace(LineHeight);Y:=Y+LineHeight;Continue;end;
      while Line<>'' do begin
        Count:=UTF8Length(Line);Lo:=1;Hi:=Count;
        while Lo<Hi do begin
          Mid:=(Lo+Hi+1) div 2;
          if TextWidth(UTF8Copy(Line,1,Mid),Size)<=174 then Lo:=Mid else Hi:=Mid-1;
        end;
        Cut:=Lo;
        if Cut<Count then begin
          Part:=UTF8Copy(Line,1,Cut);
          for J:=Length(Part) downto 1 do if Part[J]=' ' then begin Cut:=UTF8Length(Copy(Part,1,J-1));Break;end;
          if Cut<1 then Cut:=Lo;
        end;
        Part:=UTF8Copy(Line,1,Cut);EnsureSpace(LineHeight);Page.SetFont(FontIndex,Size);
        Page.WriteText(18,Y+LineHeight*0.8,Part);Y:=Y+LineHeight;
        Line:=TrimLeft(UTF8Copy(Line,Cut+1,Count));
      end;
    end;
    Y:=Y+3;
  finally Lines.Free;end;
end;
procedure TPresentationPDF.Image(const FileName: string);
var Index: Integer; W,H,Scale: Double;
begin
  Index:=Document.Images.AddFromFile(FileName);
  W:=Document.Images[Index].Width;H:=Document.Images[Index].Height;
  if (W<=0) or (H<=0) then raise Exception.Create('Imagem sem dimensões: '+ExtractFileName(FileName));
  if (Page<>nil) and (Y>29) then NewPage;
  Scale:=Math.Min(174/W,118/H);W:=W*Scale;H:=H*Scale;EnsureSpace(H+5);
  // With poPageOriginAtTop, DrawImage still takes the bottom-left corner.
  Page.DrawImage(18+(174-W)/2,Y+H,W,H,Index);Y:=Y+H+5;
end;
function TPresentationPDF.ResourceFile(const Name: string): string;
begin
  if not SafePresentationPath(Name) then raise Exception.Create('Caminho de recurso inválido: '+Name);
  Result:=Root+StringReplace(Name,'/',PathDelim,[rfReplaceAll]);
  if not FileExists(Result) then raise Exception.Create('Recurso ausente: '+Name);
end;
function TPresentationPDF.RenderSlide(const FileName: string; Slide: Integer): string;
begin
  Result:='';
  {$ifdef windows}
  if VarIsEmpty(PowerPoint) then begin
    COMInitialized:=CoInitialize(nil)>=0;
    try
      try PowerPoint:=GetActiveOleObject('PowerPoint.Application');
      except PowerPoint:=CreateOleObject('PowerPoint.Application');OwnPowerPoint:=True;end;
    except raise Exception.Create('Para incluir os slides PPTX no PDF, instale o Microsoft PowerPoint.');end;
  end;
  if DeckFile<>FileName then begin
    if not VarIsEmpty(Deck) then Deck.Close;Deck:=Unassigned;
    Deck:=PowerPoint.Presentations.Open(WideString(UTF8Decode(FileName)),True,False,False);DeckFile:=FileName;
  end;
  if (Slide<1) or (Slide>Integer(Deck.Slides.Count)) then
    raise Exception.CreateFmt('Slide %d inexistente em %s',[Slide,ExtractFileName(FileName)]);
  Result:=IncludeTrailingPathDelimiter(TempDirectory)+'slide.png';
  if FileExists(Result) then SysUtils.DeleteFile(Result);
  Deck.Slides.Item(Slide).Export(WideString(UTF8Decode(Result)),'PNG',1600,900);
  {$else}
  raise Exception.Create('A conversão de slides PPTX requer PowerPoint no Windows. Use imagens PNG ou JPEG no roteiro.');
  {$endif}
end;
procedure TPresentationPDF.Save(const Items: TPrintItems; const FileName: string);
var I: Integer; Output: TMemoryStream; TempFile: string; G: TGUID;
begin
  for I:=0 to High(Items) do case Items[I].Kind of
    pikText: Paragraph(Items[I].Text);
    pikImage: Image(ResourceFile(Items[I].Resource));
    pikSlide: Image(RenderSlide(ResourceFile(Items[I].Resource),Items[I].Slide));
    pikMedia: Paragraph(Items[I].Text,10);
  end;
  if Document.Pages.Count=0 then raise Exception.Create('A apresentação não contém texto nem imagens para imprimir.');
  for I:=0 to Document.Pages.Count-1 do begin
    Page:=Document.Pages[I];Page.SetFont(FontIndex,9);Page.SetColor($667085,False);
    Page.WriteText(18,286,'Página '+IntToStr(I+1)+' de '+IntToStr(Document.Pages.Count));
  end;
  Output:=TMemoryStream.Create;CreateGUID(G);TempFile:=FileName+'.'+GUIDToString(G)+'.tmp';
  try
    // Finish rendering before touching the destination, then replace atomically.
    Document.SaveToStream(Output);Output.SaveToFile(TempFile);
    {$ifdef windows}
    if not MoveFileExW(PWideChar(UTF8Decode(TempFile)),PWideChar(UTF8Decode(FileName)),
      MOVEFILE_REPLACE_EXISTING) then RaiseLastOSError;
    {$else}
    if not RenameFile(TempFile,FileName) then raise Exception.Create('Não foi possível salvar o PDF: '+FileName);
    {$endif}
  finally Output.Free;if FileExists(TempFile) then SysUtils.DeleteFile(TempFile);end;
end;
procedure ExportPresentationPDF(const Source, AssetRoot, FileName, Title: string; const EntryBlock: string);
var Items: TPrintItems; Writer: TPresentationPDF;
begin
  Items:=PresentationPrintItems(Source,EntryBlock);Writer:=TPresentationPDF.Create(AssetRoot,Title);
  try Writer.Save(Items,ExpandFileName(FileName));finally Writer.Free;end;
end;
end.
