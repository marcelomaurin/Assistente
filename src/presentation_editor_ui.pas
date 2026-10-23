unit presentation_editor_ui;
{$mode objfpc}{$H+}
interface
uses Windows, Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, SynEdit,
  Graphics, Buttons, ComCtrls, Menus, ImgList, Math, Types, LazUTF8, LCLProc, movement_catalog, assistente_visual_identity,
  Process, FileUtil, LazFileUtils, presentation_package, presentation_document,
  presentation_paths, presentation_tags, presentation_ai, professor_catalog, presentation_rag, presentation_flow;
type
  TPresentationEditor = class(TForm)
  private
    FEdit: TSynEdit;FResources: TListBox;FStatus: TLabel;FToolbar: TFlowPanel;
    FAssistant: TEdit;FTimer: TTimer;
    FMediaToolbar,FFlowToolbar:TFlowPanel;FImages:TImageList;
    FMovements:TListBox;FMovementSearch:TEdit;FMovementDetail:TLabel;
    FMovementIDs:TStringList;
    FBrandHeader,FConnection:TPanel;FPreviewButton,FBrowseButton:TButton;
    procedure LayoutEditor(Sender:TObject);
    procedure DrawMovement(Control:TWinControl;Index:Integer;ARect:TRect;State:TOwnerDrawState);
    procedure FilterMovements(Sender:TObject);
    procedure MovementSelected(Sender:TObject);
    procedure MovementInsert(Sender:TObject);
    procedure ReloadMovements(Sender:TObject);
    procedure AssistantChanged(Sender:TObject);
  private
    FSettings: TPresentationAIConfig;FJob: TPresentationAIJob;
    FRoot,FFile,FOriginal: string;FDirty,FLoading: Boolean;
    procedure Action(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure Closing(Sender: TObject; var CanClose: Boolean);
    procedure AddButton(const Title: string; ID: Integer);
    procedure Insert(const AText: string);
    procedure ExportTo(const AFileName: string);
    procedure RefreshResources;
    procedure ResourceInsert(Sender: TObject);
    procedure InsertResource(const Resource: string);
    procedure ChooseAvatar;
    function CanDiscard: Boolean;
    procedure InsertFlowAction(ID: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadPackage(const FileName: string);
    procedure InsertMovement(const ID:string);
    procedure RefreshMovementLibrary;
    property MovementList:TListBox read FMovements;
    property MovementSearch:TEdit read FMovementSearch;
    procedure SavePackage(const FileName: string);
    procedure InsertFlowDirective(Kind: TFlowAction; const ABlock: string = ''; const EventName: string = '');
    function CompiledScript(const EntryBlock: string = ''): string;
  end;
implementation
function NewPrivateDirectory: string;
var G: TGUID;
begin CreateGUID(G);Result:=IncludeTrailingPathDelimiter(GetTempDir(False))+'assistente-editor-'+GUIDToString(G);end;
constructor TPresentationEditor.Create(AOwner: TComponent);
var P,Header,Body,Inspector,Detail,Connection,TopShell:TPanel; L:TLabel; B:TButton;
  Pages,Tools:TPageControl;Tab:TTabSheet;Split:TSplitter;Config:string;
  MainMenuBar:TMainMenu;Group,Item:TMenuItem;
  function Pane(Parent:TWinControl;Align:TAlign;Size:Integer;Color:TColor):TPanel;
  begin
    Result:=TPanel.Create(Self);Result.Parent:=Parent;if Align=alTop then Result.Top:=10000;Result.Align:=Align;
    Result.BevelOuter:=bvNone;Result.Color:=Color;
    if Align in [alTop,alBottom] then Result.Height:=Size else Result.Width:=Size;
  end;
  function LabelOn(Parent:TWinControl;const Text:string;X,Y,Size:Integer;Bold:Boolean):TLabel;
  begin
    Result:=TLabel.Create(Self);Result.Parent:=Parent;Result.Caption:=Text;
    Result.SetBounds(X,Y,400,30);Result.Font.Size:=Size;Result.Font.Color:=$0035251D;
    if Bold then Result.Font.Style:=[fsBold];
  end;
  procedure MenuAction(const Text:string;ID:Integer;const Shortcut:string='');
  begin
    Item:=TMenuItem.Create(MainMenuBar);Item.Caption:=Text;Item.Tag:=ID;Item.OnClick:=@Action;
    if Shortcut<>'' then Item.ShortCut:=TextToShortCut(Shortcut);
    Item.ImageIndex:=AssistenteIconForCaption(Text);Group.Add(Item);
  end;
  function ToolPage(const Title:string):TFlowPanel;
  begin
    Tab:=TTabSheet.Create(Self);Tab.PageControl:=Tools;Tab.Caption:=Title;
    Result:=TFlowPanel.Create(Self);Result.Parent:=Tab;Result.Align:=alClient;
    Result.BevelOuter:=bvNone;Result.Color:=clWhite;Result.AutoWrap:=False;
    Result.BorderSpacing.Around:=5;
  end;
begin
  inherited CreateNew(AOwner);Caption:='Assistente | Editor de Apresentações';SetBounds(80,50,1240,820);
  Font.Name:='Segoe UI';Font.Size:=10;Color:=$00F8F5F3;DoubleBuffered:=True;
  Constraints.MinWidth:=960;Constraints.MinHeight:=620;OnCloseQuery:=@Closing;
  FMovementIDs:=TStringList.Create;
  FRoot:=NewPrivateDirectory;ForceDirectories(FRoot+PathDelim+'assets');
  Config:=GetEnvironmentVariable('ASSISTENTE_CONFIG_DIR');
  if Config='' then Config:=IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA'))+'assistente';
  FSettings:=LoadPresentationAIConfig(Config);
  FImages:=TImageList.Create(Self);FImages.Width:=24;FImages.Height:=24;AssistenteBuildProfessionalIcons(FImages);
  MainMenuBar:=TMainMenu.Create(Self);MainMenuBar.Images:=FImages;Self.Menu:=MainMenuBar;
  Group:=TMenuItem.Create(MainMenuBar);Group.Caption:='Arquivo';MainMenuBar.Items.Add(Group);
  MenuAction('Novo',1,'Ctrl+N');MenuAction('Abrir apresentação',2,'Ctrl+O');MenuAction('Salvar',3,'Ctrl+S');MenuAction('Salvar como',4,'Ctrl+Shift+S');
  Group:=TMenuItem.Create(MainMenuBar);Group.Caption:='Editar';MainMenuBar.Items.Add(Group);
  MenuAction('Desfazer',10,'Ctrl+Z');MenuAction('Refazer',11,'Ctrl+Y');
  Group:=TMenuItem.Create(MainMenuBar);Group.Caption:='Apresentação';MainMenuBar.Items.Add(Group);
  MenuAction('Validar roteiro',12,'Ctrl+Shift+V');MenuAction('Prévia no Assistente',14,'F5');MenuAction('Gerar movimentos IA',13,'Ctrl+G');MenuAction('Cancelar IA',15);
  TopShell:=Pane(Self,alTop,205,clWhite);
  P:=Pane(TopShell,alNone,0,$00F67842);P.SetBounds(0,0,ClientWidth,4);P.Anchors:=[akTop,akLeft,akRight];
  Header:=Pane(TopShell,alNone,0,clWhite);Header.SetBounds(0,4,ClientWidth,76);Header.Anchors:=[akTop,akLeft,akRight];FBrandHeader:=Header;
  L:=LabelOn(Header,'MAURINSOFT  /  ASSISTENTE',20,9,8,True);L.Font.Color:=$00F67842;
  LabelOn(Header,'Editor de Apresentações',20,28,19,True);
  B:=TButton.Create(Self);B.Parent:=Header;B.Name:='PreviewButton';FPreviewButton:=B;B.Caption:='▶  Prévia no Assistente';B.Tag:=14;B.OnClick:=@Action;
  B.SetBounds(Header.ClientWidth-228,20,208,38);B.Anchors:=[akTop,akRight];B.Font.Color:=$00F67842;
  Connection:=Pane(TopShell,alNone,0,$00F8F5F3);Connection.SetBounds(0,80,ClientWidth,42);Connection.Anchors:=[akTop,akLeft,akRight];FConnection:=Connection;
  L:=LabelOn(Connection,'Assistente conectado',18,12,9,True);L.Width:=160;
  FAssistant:=TEdit.Create(Self);FAssistant.Parent:=Connection;FAssistant.SetBounds(185,7,930,28);
  FAssistant.Anchors:=[akLeft,akTop,akRight];FAssistant.OnEditingDone:=@AssistantChanged;
  FAssistant.Text:=IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA'))+'Programs'+PathDelim+'Assistente'+PathDelim+'assistente.exe';
  if FileExists(ExtractFilePath(ParamStr(0))+'assistente.exe') then FAssistant.Text:=ExtractFilePath(ParamStr(0))+'assistente.exe';
  B:=TButton.Create(Self);B.Parent:=Connection;B.SetBounds(1124,6,98,30);B.Anchors:=[akTop,akRight];
  FBrowseButton:=B;B.Name:='BrowseAssistant';B.Caption:='Escolher...';B.Tag:=16;B.OnClick:=@Action;
  Tools:=TPageControl.Create(Self);Tools.Parent:=TopShell;Tools.SetBounds(0,122,ClientWidth,83);Tools.Anchors:=[akTop,akLeft,akRight];
  FToolbar:=ToolPage('Arquivo e roteiro');FMediaToolbar:=ToolPage('Mídia, slides e voz');FFlowToolbar:=ToolPage('Blocos e fluxo');
  Tools.ActivePageIndex:=0;
  AddButton('Novo',1);AddButton('Abrir .pva',2);AddButton('Salvar',3);AddButton('Salvar como',4);
  AddButton('Desfazer',10);AddButton('Refazer',11);AddButton('Validar',12);AddButton('Gerar movimentos IA',13);AddButton('Cancelar IA',15);
  AddButton('Inserir mídia',5);AddButton('Fechar mídia',6);AddButton('Slide anterior',7);
  AddButton('Próximo slide',8);AddButton('Ir ao slide',9);AddButton('Escolher avatar',17);AddButton('Escolher voz',18);AddButton('Fechar som',19);
  AddButton('Bloco',20);AddButton('GOTO',21);AddButton('Chamar bloco',22);AddButton('Evento futuro',23);AddButton('FIM',24);AddButton('Prévia do bloco',25);
  P:=Pane(Self,alBottom,32,$00F8F5F3);
  FStatus:=TLabel.Create(Self);FStatus.Parent:=P;FStatus.Align:=alClient;FStatus.Layout:=tlCenter;
  FStatus.BorderSpacing.Left:=18;FStatus.Font.Size:=9;FStatus.Font.Color:=$00746558;
  FStatus.Caption:='Pronto. Escreva o roteiro ou insira um movimento da biblioteca.';
  Body:=Pane(Self,alClient,0,$00F8F5F3);Body.BorderSpacing.Around:=12;
  Inspector:=Pane(Body,alRight,306,clWhite);Inspector.Constraints.MinWidth:=260;
  Split:=TSplitter.Create(Self);Split.Parent:=Body;Split.Align:=alRight;Split.Width:=8;
  Pages:=TPageControl.Create(Self);Pages.Parent:=Inspector;Pages.Align:=alClient;
  Tab:=TTabSheet.Create(Self);Tab.PageControl:=Pages;Tab.Caption:='Movimentos';
  P:=Pane(Tab,alTop,72,clWhite);LabelOn(P,'BIBLIOTECA DE MOVIMENTOS',10,8,9,True);
  FMovementSearch:=TEdit.Create(Self);FMovementSearch.Name:='MovementSearch';FMovementSearch.Parent:=P;
  FMovementSearch.SetBounds(10,34,265,28);FMovementSearch.Anchors:=[akLeft,akTop,akRight];
  FMovementSearch.Text:='';FMovementSearch.TextHint:='Buscar gesto, mão, cabeça...';FMovementSearch.OnChange:=@FilterMovements;
  Detail:=Pane(Tab,alBottom,142,clWhite);
  FMovementDetail:=TLabel.Create(Self);FMovementDetail.Parent:=Detail;FMovementDetail.Align:=alClient;
  FMovementDetail.BorderSpacing.Around:=10;FMovementDetail.WordWrap:=True;FMovementDetail.Font.Size:=9;
  P:=Pane(Detail,alBottom,40,clWhite);
  B:=TButton.Create(Self);B.Parent:=P;B.Caption:='Inserir tag';B.SetBounds(8,3,156,32);B.OnClick:=@MovementInsert;
  B:=TButton.Create(Self);B.Parent:=P;B.Caption:='Recarregar';B.SetBounds(170,3,112,32);B.OnClick:=@ReloadMovements;
  FMovements:=TListBox.Create(Self);FMovements.Name:='MovementLibrary';FMovements.Parent:=Tab;FMovements.Align:=alClient;
  FMovements.BorderStyle:=bsNone;FMovements.Style:=lbOwnerDrawFixed;FMovements.ItemHeight:=30;FMovements.OnDrawItem:=@DrawMovement;FMovements.OnClick:=@MovementSelected;FMovements.OnDblClick:=@MovementInsert;
  Tab:=TTabSheet.Create(Self);Tab.PageControl:=Pages;Tab.Caption:='Mídias importadas';
  P:=Pane(Tab,alTop,54,clWhite);L:=LabelOn(P,'Duplo clique para inserir no roteiro',10,12,9,False);
  FResources:=TListBox.Create(Self);FResources.Parent:=Tab;FResources.Align:=alClient;FResources.BorderStyle:=bsNone;
  FResources.OnDblClick:=@ResourceInsert;FResources.Hint:='Somente recursos usados no roteiro serão exportados.';FResources.ShowHint:=True;
  Pages.ActivePageIndex:=0;
  P:=Pane(Body,alClient,0,clWhite);
  Header:=Pane(P,alTop,44,clWhite);LabelOn(Header,'ROTEIRO DA APRESENTAÇÃO',16,13,9,True);
  FEdit:=TSynEdit.Create(Self);FEdit.Parent:=P;FEdit.Align:=alClient;FEdit.BorderStyle:=bsNone;
  FEdit.Font.Name:='Consolas';FEdit.Font.Size:=12;FEdit.Color:=clWhite;FEdit.Font.Color:=$0035251D;
  FEdit.Gutter.Color:=$00FAF7F5;FEdit.Gutter.Width:=48;
  FEdit.LineHighlightColor.Background:=$00FFF5EC;
  FEdit.BorderSpacing.Around:=6;FEdit.OnChange:=@Changed;
  FEdit.Lines.Text:='Olá! Escreva aqui o roteiro da apresentação.';FDirty:=False;
  OnResize:=@LayoutEditor;OnShow:=@LayoutEditor;
  FBrandHeader.OnResize:=@LayoutEditor;FConnection.OnResize:=@LayoutEditor;LayoutEditor(nil);
  RefreshMovementLibrary;
  FTimer:=TTimer.Create(Self);FTimer.Interval:=100;FTimer.OnTimer:=@Tick;
end;

destructor TPresentationEditor.Destroy;
begin
  if FJob<>nil then FJob.Free;
  FMovementIDs.Free;

  if (Pos('assistente-editor-',ExtractFileName(FRoot))=1) and
    (ExtractFileDir(FRoot)=ExcludeTrailingPathDelimiter(GetTempDir(False))) then DeleteDirectory(FRoot,False);
  inherited Destroy;
end;
procedure TPresentationEditor.AddButton(const Title: string; ID: Integer);
var B:TBitBtn;IconIndex:Integer;
begin
  B:=TBitBtn.Create(Self);
  if ID in [20..25] then B.Parent:=FFlowToolbar
  else if ID in [5..9,17..19] then B.Parent:=FMediaToolbar else B.Parent:=FToolbar;
  B.Caption:=Title;B.AutoSize:=True;B.Height:=34;B.BorderSpacing.Around:=3;
  B.Tag:=ID;B.OnClick:=@Action;B.Margin:=8;B.Spacing:=6;
  B.Hint:=Title;B.ShowHint:=True;
  if ID in [10,11] then begin B.AutoSize:=False;B.Width:=38;B.Caption:='';end;
  if ID=13 then B.Caption:='Movimentos IA';
  if ID=15 then B.Caption:='Cancelar';
  if ID=17 then B.Caption:='Avatar';
  if ID=18 then B.Caption:='Voz';
  if ID=7 then B.Caption:='Anterior';
  if ID=8 then B.Caption:='Próximo';
  IconIndex:=AssistenteIconForCaption(Title);
  if ID=13 then IconIndex:=ASSISTENTE_ICON_AI;
  if ID=15 then IconIndex:=ASSISTENTE_ICON_STOP;
  if ID=12 then IconIndex:=ASSISTENTE_ICON_TASKS;
  if IconIndex>=0 then FImages.GetBitmap(IconIndex,B.Glyph);
end;

procedure TPresentationEditor.LayoutEditor(Sender:TObject);
begin
  if (FPreviewButton=nil) or (FBrowseButton=nil) then Exit;
  FPreviewButton.SetBounds(Max(420,FBrandHeader.Width-228),20,208,38);
  FAssistant.SetBounds(185,7,Max(220,FConnection.Width-308),28);
  FBrowseButton.SetBounds(FConnection.Width-112,6,98,30);
end;
procedure TPresentationEditor.DrawMovement(Control:TWinControl;Index:Integer;ARect:TRect;State:TOwnerDrawState);
var C:TCanvas;
begin
  C:=FMovements.Canvas;C.Font.Assign(FMovements.Font);
  if Index=FMovements.ItemIndex then begin C.Brush.Color:=$00FFF0E7;C.Font.Color:=$00D65F2C;end
  else begin C.Brush.Color:=clWhite;C.Font.Color:=$0035251D;end;
  C.FillRect(ARect);C.TextRect(ARect,ARect.Left+10,ARect.Top+6,FMovements.Items[Index]);
end;

procedure TPresentationEditor.RefreshMovementLibrary;
begin FilterMovements(nil);end;
procedure TPresentationEditor.FilterMovements(Sender:TObject);
var I:Integer;M:TMovementDefinition;Query:string;
begin
  if FMovements=nil then Exit;
  FMovements.Items.BeginUpdate;
  try
    FMovements.Clear;FMovementIDs.Clear;Query:=NormalizeMovementTag(FMovementSearch.Text);
    for I:=0 to MovementCount-1 do begin
      M:=MovementAt(I);
      if (Query='') or (Pos(Query,NormalizeMovementTag(M.Title+' '+M.Tag+' '+M.Category+' '+M.Description))>0) then begin
        FMovements.Items.Add(M.Title);FMovementIDs.Add(M.ID);
      end;
    end;
    if FMovements.Count>0 then FMovements.ItemIndex:=0;
  finally FMovements.Items.EndUpdate;end;
  MovementSelected(nil);
end;
procedure TPresentationEditor.MovementSelected(Sender:TObject);
var M:TMovementDefinition;
begin
  if (FMovements.ItemIndex<0) or not FindMovement(FMovementIDs[FMovements.ItemIndex],M) then begin FMovementDetail.Caption:='Nenhum movimento encontrado.';Exit;end;
  FMovementDetail.Caption:='['+M.Tag+']'+LineEnding+M.Description+LineEnding+M.Category;
end;
procedure TPresentationEditor.InsertMovement(const ID:string);
var M:TMovementDefinition;
begin
  if FJob<>nil then raise Exception.Create('Aguarde a geração de movimentos');
  if not FindMovement(ID,M) then raise Exception.Create('Movimento não encontrado no catálogo');
  Insert('['+M.Tag+']');FStatus.Caption:='Movimento inserido: '+M.Title;
end;
procedure TPresentationEditor.MovementInsert(Sender:TObject);
begin
  if FMovements.ItemIndex>=0 then
    try InsertMovement(FMovementIDs[FMovements.ItemIndex]);except on E:Exception do FStatus.Caption:=E.Message;end;
end;
procedure TPresentationEditor.ReloadMovements(Sender:TObject);
var Candidate:string;
begin
  try
    Candidate:=ExtractFilePath(FAssistant.Text)+'AVATARES'+PathDelim+'movimentos.json';
    if FileExists(Candidate) then ReloadMovementCatalog(Candidate) else ReloadMovementCatalog;
    RefreshMovementLibrary;FStatus.Caption:=IntToStr(MovementCount)+' movimentos · '+MovementCatalogFile;
  except on E:Exception do FStatus.Caption:=E.Message;end;
end;
procedure TPresentationEditor.AssistantChanged(Sender:TObject);
begin ReloadMovements(nil);end;

procedure TPresentationEditor.Changed(Sender: TObject);
begin
  if not FLoading then FDirty:=True;
  Caption:='Assistente | Editor de Apresentações - '+ExtractFileName(FFile);
  if FDirty then Caption:=Caption+' *';
end;
function TPresentationEditor.CanDiscard: Boolean;
var R: Integer;
begin
  Result:=True;if not FDirty then Exit;
  R:=MessageDlg('Salvar as alteracoes antes de continuar?',mtConfirmation,[mbYes,mbNo,mbCancel],0);
  if R=mrCancel then Exit(False);
  if R=mrYes then begin
    for R:=0 to ComponentCount-1 do
      if (Components[R] is TBitBtn) and (TBitBtn(Components[R]).Tag=3) then begin Action(Components[R]);Break;end;
    Result:=not FDirty;
  end;
end;
procedure TPresentationEditor.Closing(Sender: TObject; var CanClose: Boolean);
begin
  CanClose:=False;
  if FJob<>nil then begin FJob.Cancel;FStatus.Caption:='Cancelando geracao. Aguarde o termino antes de fechar.';Exit;end;
  CanClose:=CanDiscard;
end;
procedure TPresentationEditor.Insert(const AText: string);
begin FEdit.SelText:=AText;FEdit.SetFocus;end;
procedure TPresentationEditor.ResourceInsert(Sender: TObject);
begin
  if (FJob=nil) and (FResources.ItemIndex>=0) then
    try InsertResource(FResources.Items[FResources.ItemIndex]);except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0);end;
end;
procedure TPresentationEditor.InsertResource(const Resource: string);
var StartTime: string;
begin
  StartTime:='';
  if TimedPresentationMedia(Resource) then
    if not InputQuery('Inicio do recurso','Opcional: hh:mm:ss. Vazio inicia no comeco.',StartTime) then Exit;
  Insert(PresentationMediaTag(Resource,StartTime));
end;
procedure TPresentationEditor.InsertFlowDirective(Kind: TFlowAction; const ABlock: string; const EventName: string);
var Directive: string;
begin
  if FJob<>nil then raise Exception.Create('Aguarde a geracao');
  Directive:=MakeFlowTag(Kind,ABlock,EventName);
  if Kind=faBlock then Directive:=LineEnding+Directive+LineEnding;
  Insert(Directive);
end;
function TPresentationEditor.CompiledScript(const EntryBlock: string): string;
var Flow: TFlowProgram;
begin
  ValidatePresentationScript(FEdit.Text);Flow:=TFlowProgram.Create(FEdit.Text);
  try Result:=Flow.Compile(EntryBlock);ValidateRuntimeScript(Result);finally Flow.Free;end;
end;
procedure TPresentationEditor.InsertFlowAction(ID: Integer);
var BlockValue,Event: string; D: TForm; Select: TComboBox; OK,Cancel: TButton; I: Integer;
  Proc: TProcess; PackageBlockValue: string;
begin
  if ID=24 then begin InsertFlowDirective(faEnd);Exit;end;
  BlockValue:='';if not InputQuery('Bloco','Nome do bloco:',BlockValue) then Exit;
  Event:='';
  if ID=23 then begin
    D:=TForm.CreateNew(Self);
    try
      D.Caption:='Evento futuro (sem disparo de sensores)';D.SetBounds(100,100,460,130);D.Position:=poOwnerFormCenter;
      Select:=TComboBox.Create(D);Select.Parent:=D;Select.SetBounds(10,15,440,28);Select.Style:=csDropDownList;
      for I:=0 to High(FlowEventNames) do Select.Items.Add(FlowEventTitles[I]);Select.ItemIndex:=0;
      OK:=TButton.Create(D);OK.Parent:=D;OK.Caption:='Inserir';OK.ModalResult:=mrOK;OK.SetBounds(250,65,90,28);
      Cancel:=TButton.Create(D);Cancel.Parent:=D;Cancel.Caption:='Cancelar';Cancel.ModalResult:=mrCancel;Cancel.SetBounds(350,65,90,28);
      if D.ShowModal<>mrOK then Exit;Event:=Select.Text;
    finally D.Free;end;
  end;
  case ID of
    20: InsertFlowDirective(faBlock,BlockValue);
    21: InsertFlowDirective(faGoto,BlockValue);
    22: InsertFlowDirective(faCall,BlockValue);
    23: InsertFlowDirective(faEvent,BlockValue,Event);
    25: begin
      CompiledScript(BlockValue);
      if not FileExists(FAssistant.Text) then raise Exception.Create('Selecione o Assistente atualizado');
      PackageBlockValue:=FRoot+PathDelim+'previa-bloco.pva';ExportTo(PackageBlockValue);
      Proc:=TProcess.Create(nil);
      try
        Proc.Executable:=FAssistant.Text;Proc.Parameters.Add('--presentation-block');Proc.Parameters.Add(BlockValue);Proc.Parameters.Add(PackageBlockValue);
        Proc.Options:=[poNoConsole];Proc.Execute;FStatus.Caption:='Previa do bloco iniciada.';
      finally Proc.Free;end;
    end;
  end;
end;
procedure TPresentationEditor.ChooseAvatar;
var Catalog: TAvatarCatalog; D: TForm; List: TListBox; OK,Cancel: TButton; I: Integer;
begin
  Catalog:=TAvatarCatalog.Create(ExtractFilePath(FAssistant.Text)+'AVATARES');
  D:=nil;
  try
    if Catalog.Count=0 then raise Exception.Create('Nenhum avatar encontrado junto do Assistente selecionado');
    D:=TForm.CreateNew(Self);D.Caption:='Escolher avatar';D.Position:=poOwnerFormCenter;D.SetBounds(100,100,440,420);
    List:=TListBox.Create(D);List.Parent:=D;List.SetBounds(10,10,420,350);List.Anchors:=[akTop,akLeft,akRight,akBottom];
    for I:=0 to Catalog.Count-1 do List.Items.Add(Catalog[I].Name+' ('+Catalog[I].ID+')');
    List.ItemIndex:=0;
    OK:=TButton.Create(D);OK.Parent:=D;OK.Caption:='Inserir';OK.ModalResult:=mrOK;OK.SetBounds(230,375,90,28);OK.Anchors:=[akBottom,akRight];
    Cancel:=TButton.Create(D);Cancel.Parent:=D;Cancel.Caption:='Cancelar';Cancel.ModalResult:=mrCancel;Cancel.SetBounds(330,375,90,28);Cancel.Anchors:=[akBottom,akRight];
    if (D.ShowModal=mrOK) and (List.ItemIndex>=0) then Insert('[avatar='+Catalog[List.ItemIndex].ID+']');
  finally D.Free;Catalog.Free;end;
end;
procedure TPresentationEditor.RefreshResources;
var R: TSearchRec;
begin
  FResources.Clear;
  if FindFirst(FRoot+PathDelim+'assets'+PathDelim+'*',faAnyFile,R)=0 then
  try repeat if (R.Attr and faDirectory)=0 then FResources.Items.Add('assets/'+R.Name);until FindNext(R)<>0;finally FindClose(R);end;
end;
procedure TPresentationEditor.ExportTo(const AFileName: string);
var P: TPVAPackage;
begin
  ValidatePresentationScript(FEdit.Text);P:=TPVAPackage.Create;
  try P.ExportFile(AFileName,FEdit.Text,FRoot);finally P.Free;end;
end;
procedure TPresentationEditor.SavePackage(const FileName: string);
begin
  if FJob<>nil then raise Exception.Create('Aguarde a geracao');
  ExportTo(FileName);FFile:=FileName;FDirty:=False;
  Caption:='Assistente | Editor de Apresentações - '+ExtractFileName(FFile);
  FStatus.Caption:='Pacote salvo. Disponibilizando para a IA...';
  PublishPresentation(FileName);
  FStatus.Caption:='Salvo e incluido na biblioteca da IA: '+PresentationRAGDirectory;
end;
procedure TPresentationEditor.LoadPackage(const FileName: string);
var P: TPVAPackage;NewRoot: string;Succeeded: Boolean;
begin
  if FJob<>nil then raise Exception.Create('Aguarde a geracao');
  P:=TPVAPackage.Create;NewRoot:=NewPrivateDirectory;Succeeded:=False;
  try
    P.Load(FileName);P.ExtractTo(NewRoot);
    ForceDirectories(NewRoot+PathDelim+'assets');
    DeleteDirectory(FRoot,False);FRoot:=NewRoot;Succeeded:=True;FLoading:=True;
    try FEdit.Text:=P.Script;finally FLoading:=False;end;
    FFile:=FileName;FDirty:=False;FEdit.ClearUndo;RefreshResources;
    Caption:='Assistente | Editor de Apresentações - '+ExtractFileName(FFile);
  finally
    P.Free;
    if not Succeeded and DirectoryExists(NewRoot) then DeleteDirectory(NewRoot,False);
  end;
end;
procedure TPresentationEditor.Action(Sender: TObject);
var ID,N: Integer; D: TOpenDialog; S: TSaveDialog; P: TPVAPackage; M: TMemoryStream;
  AFileName,Dest: string; Proc: TProcess; VoiceTag: TPresentationTag;
begin
  ID:=TComponent(Sender).Tag;
  if FJob<>nil then begin if ID=15 then FJob.Cancel;Exit;end;
  try
    case ID of
      20..25: InsertFlowAction(ID);
      1: if CanDiscard then begin FEdit.Clear;FEdit.ClearUndo;FFile:='';FDirty:=False;Caption:='Assistente | Editor de Apresentações';end;
      2: if CanDiscard then begin
        D:=TOpenDialog.Create(Self);
        try
          D.Filter:='Apresentacao|*.pva';
          if D.Execute then begin
            LoadPackage(D.FileName);
          end;
        finally D.Free;end;
      end;
      3,4: begin
        AFileName:=FFile;
        if (ID=4) or (AFileName='') then begin
          S:=TSaveDialog.Create(Self);
          try S.Filter:='Apresentacao|*.pva';S.DefaultExt:='pva';S.Options:=S.Options+[ofOverwritePrompt];if not S.Execute then Exit;AFileName:=S.FileName;finally S.Free;end;
        end;
        SavePackage(AFileName);
      end;
      5: begin
        D:=TOpenDialog.Create(Self);
        try
          D.Filter:='Midia|*.png;*.jpg;*.jpeg;*.bmp;*.mp4;*.avi;*.wmv;*.pptx;*.wav;*.mp3;*.wma';
          if D.Execute then begin
            if not SupportedPresentationMedia(D.FileName) then raise Exception.Create('Formato nao suportado');
            M:=TMemoryStream.Create;
            try
              if FileSize(D.FileName)>PVAMaxFile then raise Exception.Create('Arquivo excede 64 MiB');
              M.LoadFromFile(D.FileName);
              AFileName:='assets/'+PresentationSHA256(M)+LowerCase(ExtractFileExt(D.FileName));
              Dest:=FRoot+PathDelim+StringReplace(AFileName,'/',PathDelim,[rfReplaceAll]);
              M.SaveToFile(Dest);
            finally M.Free;end;
            InsertResource(AFileName);RefreshResources;
          end;
        finally D.Free;end;
      end;
      6: Insert('[fechar arquivo]');
      7: Insert('[slide anterior]');
      8: Insert('[proximo slide]');
      9: begin
        AFileName:=InputBox('Ir ao slide','Numero do slide (a partir de 1)','1');
        if not TryStrToInt(AFileName,N) or (N<1) or (N>10000) then raise Exception.Create('Slide invalido');
        Insert('[ir para slide='+IntToStr(N)+']');
      end;
      10: FEdit.Undo;
      11: FEdit.Redo;
      12: begin
        AFileName:=FRoot+PathDelim+'validacao.pva';ExportTo(AFileName);
        P:=TPVAPackage.Create;try P.Load(AFileName);finally P.Free;end;
        FStatus.Caption:='Roteiro, recursos e integridade validos.';
      end;
      13: begin
        ValidatePresentationScript(FEdit.Text);FOriginal:=FEdit.Text;
        FJob:=TPresentationAIJob.Create(FSettings,FOriginal);FEdit.ReadOnly:=True;FStatus.Caption:='Gerando movimentos...';
      end;
      17: ChooseAvatar;
      18: begin
        AFileName:='padrao';
        if InputQuery('Escolher voz','Nome exato da voz do provedor/SAPI, ou padrao:',AFileName) then begin
          if not TryParsePresentationTag('[voz='+AFileName+']',VoiceTag) then raise Exception.Create('Nome de voz invalido');
          Insert('[voz='+AFileName+']');
        end;
      end;
      19: Insert('[fechar som]');
      16: begin
        D:=TOpenDialog.Create(Self);
        try D.Filter:='Assistente|assistente.exe';if D.Execute then begin FAssistant.Text:=D.FileName;ReloadMovements(nil);end;finally D.Free;end;
      end;
      14: begin
        if not FileExists(FAssistant.Text) then raise Exception.Create('Selecione o executavel atualizado do Assistente');
        AFileName:=FRoot+PathDelim+'previa.pva';ExportTo(AFileName);
        Proc:=TProcess.Create(nil);
        try
          Proc.Executable:=FAssistant.Text;Proc.Parameters.Add('--presentation');Proc.Parameters.Add(AFileName);
          Proc.Options:=[poNoConsole];Proc.Execute;FStatus.Caption:='Previa iniciada. P pausa/retoma; Esc cancela no Assistente.';
        finally Proc.Free;end;
      end;
    end;
  except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0);end;
end;
procedure TPresentationEditor.Tick(Sender: TObject);
var J: TPresentationAIJob; Saved: string;
begin
  if (FJob=nil) or not FJob.Finished then Exit;
  J:=FJob;FJob:=nil;FEdit.ReadOnly:=False;
  try
    if J.WasCancelled then FStatus.Caption:='Geracao cancelada.'
    else if J.ErrorText<>'' then FStatus.Caption:=J.ErrorText
    else begin
      if FEdit.Text<>FOriginal then raise Exception.Create('Roteiro mudou durante a geracao');
      Saved:=AcceptGeneratedMovements(FOriginal,J.Output);
      FEdit.BeginUndoBlock;
      try FEdit.SelectAll;FEdit.SelText:=Saved;finally FEdit.EndUndoBlock;end;
      FStatus.Caption:='Movimentos aplicados. Desfazer restaura o roteiro anterior.';
    end;
  except on E: Exception do FStatus.Caption:=E.Message;end;
  J.Free;
end;
end.
