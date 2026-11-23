unit main;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, assistant_menu, ComCtrls, LCLType, chatgpt, setmain, frmconfig, jarvis_api, agent_manager,
  reception_core, aiagent_memorymap, aiagent_flowevents, voice_input_bridge,
  professor_listener, professor_state, professor_view, aichromespeech, aivoicerecognizer,
  webcam_vision, vision_types, aikinectsensor, aikinect_types, professor_catalog,
  professor_ui, professor_commands, fpjson, assistant_integration_protocol,
  assistant_integration_server, assistant_integration_jobs, presentation_package,
  presentation_media, presentation_tags, presentation_joints, presentation_rag, presentation_flow, assistant_documents, presentation_document, movement_catalog, presentation_questions, presentation_chrome;
type
  TParkedPresentation = record
    Job:TReceptionJob;AtTag,YouTubePending:Boolean;Block:string;
  end;
  Tfrmmain = class(TForm)
    pnlRoot, pnlHeader, pnlConteudo, pnlAvatar, pnlEntrada: TPanel;
    lblTitulo, lblStatus, lblAssistente: TLabel;
    btConfig: TSpeedButton;
    memResposta: TMemo;
    edPergunta: TEdit;
    btEnviar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btConfigClick(Sender: TObject);
    procedure btEnviarClick(Sender: TObject);
    procedure edPerguntaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FConfigImportMessage: string;
    FAssistantManager: TAssistantManager;
    FJarvisClient: TJarvisAPIClient;
    FSpeechJob: TReceptionJob;
    FPresentationMedia: TPresentationMedia;
    FRAGMonitor: TPresentationRAGMonitor;
    FLoadedFile,FLoadedKnowledge: string;
    FLoadedKind: TAssistantDocumentKind;
    FLoadedFlow: TFlowProgram;
    FLoadedPackage: TPVAPackage;
    FLoadedSource, FLoadedEntryBlock, FSearchQuery: string;
    FDocumentMenu: TAssistantMenu;
    FOpenFileDialog, FPVAFileDialog: TOpenDialog;
    FPDFDialog: TSaveDialog;
    FDocumentDialogOpen: Boolean;
    FPresentationRoot: string;
    FPresentationMode,FPresentationAvatarChanged: Boolean;
    procedure CreateDocumentMenu;
    procedure UpdateDocumentActions;
    procedure OpenFileClick(Sender: TObject);
    procedure UpdatePresentationTopics;
    procedure PlayPresentationClick(Sender: TObject);
    procedure PlayLoadedPresentation(const EntryBlock: string);
    procedure OpenPresentation(const FileName, EntryBlock: string; Play: Boolean);
    function PreparePresentation(Package: TPVAPackage; Flow: TFlowProgram;
      const EntryBlock: string): string;
    procedure BeginPresentation(const Compiled: string);
    procedure CloseFileClick(Sender: TObject);
    procedure PrintPDFClick(Sender: TObject);
    procedure FindTextClick(Sender: TObject);
    procedure AboutClick(Sender: TObject);
    function ExecuteDocumentCommand(const AInput: string): Boolean;
    procedure ConfigExport(Sender: TObject);
    procedure ConfigImport(Sender: TObject);
    procedure ImportConfigAtStartup;
    procedure SelectPresentationAvatar(const AvatarID: string);
    procedure FinishPresentation;
    procedure PresentationVisualChange(Sender: TObject);
  private
    FVoiceInput: TVoiceInputBridge;
    FIntegration: TAssistantIntegrationServer;
    FIntegrationJobs: TIntegrationJobs;
    FIntegrationJobID, FIntegrationStatus: string;
    FIntegrationCancelled, FConfigOpen: Boolean;
    procedure ConfigureIntegration;
    procedure IntegrationRequest(Sender:TObject;Request:TJSONObject;out Response:TJSONObject);
    function IntegrationBusy:Boolean;
  private
    FChromeSpeech: TAIChromeSpeech;
    procedure ChromeText(Sender: TObject; const AText: string);
    procedure ChromeState(Sender: TObject; const AText: string);
  private
    FContinuousListener: TProfessorListener;
    FMemoryMap: TAIAgentMemoryMap;
    FMemoryItem: TAIAgentMemoryMapItem;
    FHistoryFile, FCurrentUserText: string;
    FAguardandoResposta, FClosing, FMicMuted, FShown: Boolean;
    FProfessor: TProfessorView;
    FTimer: TTimer;
    FProfileCombo: TComboBox;
    FCatalog: TAvatarCatalog;
    FReloadButton: TSpeedButton;
    FChatPanel, FProfilePanel, FPresentationPanel, FSidebarDivider: TPanel;
    FSidebarWidth, FSidebarDragOffset: Integer;
    FAvatarCard, FInputCard: TRoundedCard;
    FChat: TConversationView;
    FSendButton: TSpeedButton;
    FAvatarStatus, FAIStatus, FRenderStatus: TLabel;
    FAIConnected: Boolean;
    FMicButton, FWaveButton, FWalkButton: TSpeedButton;
    FDeviceStatus: TLabel;
    FMovementPanel:TPanel;FMovementCombo:TComboBox;FMovementRun, FMovementReload:TButton;
    FMovementIDs:TStringList;
    FYouTubeCommandPending:Boolean;
    FParkedPresentations:array of TParkedPresentation;
    FAnsweringQuestion,FResumePresentation:Boolean;
    FAskButton:TChromeButton;
    FHeaderMenu,FHeaderAsk:TChromeButton;FStopVideo:TButton;
    FBlockMenu:TListBox;FQuestionMemo:TMemo;
    FTopicsCard, FTopicsBody, FMenuPanel, FMenuScrollBar: TPanel;
    FTopicsList: TListBox;
    FTopicsEmpty: TLabel;
    FMenuUp,FMenuDown:TButton;FMenuProgress:TProgressBar;
    FMenuHoverIndex:Integer;FMenuHoverSince:QWord;FMenuKeyboard:Boolean;
    FStepBar:TPresentationStepBar;FSpokenCaption:TPresentationCaption;
    FControlBar:TPanel;FPauseButton:TChromeButton;FProgressLabel:TPresentationProgress;
    FQuestionCard,FQuestionHead:TPanel;FQuestionTitle,FQuestionSub:TLabel;
    FCurrentBlock:string;FPresentationStarted:QWord;FPresentationThemed:Boolean;
    procedure ApplyPresentationTheme(Presenting: Boolean);
    procedure LayoutControlBar;
    procedure RefreshStepBar;
    procedure UpdatePresentationChrome;
    procedure TogglePresentationPause;
    procedure PauseButtonClick(Sender:TObject);
    procedure SidebarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure SidebarMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure SidebarMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TopicMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TopicKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ActivateTopic(Index: Integer);
    procedure PlayQuestionBlock(const TargetBlock: string);
    procedure HideBlockMenu;
    procedure UpdateMenuHover;
    procedure ScrollBlockMenu(Sender:TObject);
    procedure BlockMenuKeyDown(Sender:TObject;var Key:Word;Shift:TShiftState);
    procedure BlockMenuKeyPress(Sender:TObject;var Key:Char);
    procedure BlockMenuMouseMove(Sender:TObject;Shift:TShiftState;X,Y:Integer);
    procedure BlockMenuMouseUp(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
    procedure ShowBlockMenu;
    procedure BlockMenuClick(Sender:TObject);
    procedure AskPresentation(Sender:TObject);
    procedure HeaderMenuClick(Sender:TObject);
    procedure StopVideoClick(Sender:TObject);
    procedure UpdateVideoButton;
    procedure HeaderAskClick(Sender:TObject);
    procedure ParkPresentation(AtTag:Boolean);
    procedure ResumePresentation;
    procedure QuestionReady;
    function PresentationInput(const Input:string):Boolean;
    procedure RefreshMovements(Sender:TObject);
    procedure RunMovement(Sender:TObject);
  private
    FCamera: TWebcamVision;
    FKinect: TAIKinectSensor;
    procedure AplicarConfiguracao;
    procedure InicializarMemoria;
    procedure SalvarMemoria;
    procedure EnviarPergunta;
    procedure ProcessarEntrada(const ATexto: string);
    procedure VoiceText(Sender: TObject; const AText: string);
    procedure RemoteVoiceText(Sender: TObject; const AText: string);
    procedure VoiceState(Sender: TObject; const AState: string);
    procedure VoiceFinished(Sender: TObject);
    procedure SpeechReady(Sender: TObject; const AFileName: string);
    procedure ListenerState(Sender: TObject; AState: TProfessorListenState);
    procedure IniciarEscuta;
    procedure PausarEscuta;
    procedure RetomarEscuta;
    procedure CancelarApresentacao(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SetEstado(const ATexto: string; AOcupado: Boolean);
    procedure OnAgentStateChange(Sender: TObject; AState: TAgentState; const ADescription: string);
    procedure OnAgentComplete(Sender: TObject; const AResponseText, AProvider: string; ASuccess: Boolean);
    procedure TimerTick(Sender: TObject);
    procedure MicClick(Sender: TObject);
    procedure GestureClick(Sender: TObject);
    procedure LayoutProfessor(Sender: TObject);
    procedure CriarControles;
    procedure IniciarVideo;
    procedure PararVideo;
    procedure ProfileChange(Sender: TObject);
  public
    procedure StartPresentation(const FileName: string; const EntryBlock: string = '');
    procedure LoadDocument(const FileName: string);
    procedure CloseDocument;
    procedure SavePresentationPDF(const FileName: string);
    function SearchableDocumentText: string;
    procedure CallLoadedBlock(const BlockName: string);
    property BlockMenu:TListBox read FBlockMenu;
    property QuestionAnswer:TMemo read FQuestionMemo;
    property AskingPresentation:Boolean read FAnsweringQuestion;
    function WaitingForQuestion:Boolean;
    property LoadedDocument: string read FLoadedFile;
    property LoadedFlow: TFlowProgram read FLoadedFlow;
    procedure FalarResposta(const ATexto: string);
    function ApresentandoResposta: Boolean;
    function ActivePresentationMedia: string;
    function ActivePresentationAvatar: string;
    function ActivePresentationSound: string;
    procedure ReloadAvatars(Sender: TObject);
    property AssistantManager: TAssistantManager read FAssistantManager;
    property VoiceInput: TVoiceInputBridge read FVoiceInput;
  end;
var frmmain: Tfrmmain;
implementation
uses professor_settings, assistant_config_file, Math, Types, FileUtil, LazFileUtils, LazUTF8,
  assistant_search_dialog, presentation_pdf, Menus;
{$R *.lfm}

procedure Tfrmmain.ImportConfigAtStartup;
var FileName: string; Count: Integer;
begin
  FileName:=ConfigFileFromCommandLine;
  if FileName='' then Exit;
  try
    Count:=ImportAssistantConfig(FSetMain,ExpandFileName(FileName));
    FSetMain.SalvaContexto(False);
    FConfigImportMessage:='Configuração importada de '+ExtractFileName(FileName)+' ('+IntToStr(Count)+' itens).';
  except on E: Exception do
    FConfigImportMessage:='Não foi possível importar a configuração '+ExtractFileName(FileName)+': '+E.Message;
  end;
end;

procedure Tfrmmain.ConfigExport(Sender: TObject);
var F: TfrmConfig; Snapshot: TStringList; Draft: TSetMain; Dialog: TSaveDialog; Secrets: Boolean;
begin
  F:=Sender as TfrmConfig;
  case MessageDlg('Exportar configuração',
    'Incluir as chaves de API, tokens e senhas no arquivo?'+LineEnding+LineEnding+
    'Sim: o arquivo configura tudo automaticamente, mas guarda as credenciais em texto. Proteja o arquivo.'+LineEnding+
    'Não: as credenciais ficam de fora e serão informadas na outra instalação.',
    mtConfirmation,[mbYes,mbNo,mbCancel],0) of
    mrYes: Secrets:=True;
    mrNo: Secrets:=False;
  else Exit;
  end;
  Dialog:=TSaveDialog.Create(nil);Snapshot:=TStringList.Create;Draft:=nil;
  try
    Dialog.Title:='Exportar configuração do Assistente';Dialog.Filter:=AssistantConfigFilter;
    Dialog.DefaultExt:='json';Dialog.FileName:='assistente'+AssistantConfigExtension;
    Dialog.Options:=Dialog.Options+[ofOverwritePrompt];
    if not Dialog.Execute then Exit;
    try
      { Export what is on screen, without saving it: a copy of the stored
        settings receives the dialog values. }
      FSetMain.WriteLines(Snapshot,swExportWithSecrets);
      Draft:=TSetMain.Create;Draft.ImportLines(Snapshot);
      SaveProfessorSettings(F,Draft);
      ExportAssistantConfig(Draft,Dialog.FileName,Secrets);
      ShowMessage('Configuração exportada para:'+LineEnding+Dialog.FileName);
    except on E: Exception do ShowMessage('Não foi possível exportar: '+E.Message);end;
  finally Draft.Free;Snapshot.Free;Dialog.Free;end;
end;

procedure Tfrmmain.ConfigImport(Sender: TObject);
var F: TfrmConfig; Dialog: TOpenDialog; Count: Integer;
begin
  F:=Sender as TfrmConfig;
  Dialog:=TOpenDialog.Create(nil);
  try
    Dialog.Title:='Importar configuração do Assistente';Dialog.Filter:=AssistantConfigFilter;
    Dialog.Options:=Dialog.Options+[ofFileMustExist];
    if not Dialog.Execute then Exit;
    if MessageDlg('Importar configuração','Aplicar a configuração de '+ExtractFileName(Dialog.FileName)+'?'+LineEnding+
      'Os itens do arquivo substituem os atuais; os demais são mantidos.',mtConfirmation,[mbYes,mbNo],0)<>mrYes then Exit;
    try
      Count:=ImportAssistantConfig(FSetMain,Dialog.FileName);
      LoadProfessorSettings(F,FSetMain);
      ShowMessage('Configuração importada ('+IntToStr(Count)+' itens). Ela será salva e aplicada agora.');
      { Same path as Salvar: validates, stores and applies the settings. }
      F.btSalvarClick(F);
    except on E: Exception do ShowMessage('Não foi possível importar: '+E.Message);end;
  finally Dialog.Free;end;
end;

procedure Tfrmmain.FormCreate(Sender: TObject);
begin
  if FSetMain = nil then FSetMain := TSetMain.Create;
  FSetMain.CarregaContexto;
  ImportConfigAtStartup;
  FCatalog := TAvatarCatalog.Create;
  CriarControles;
  FProfessor := TProfessorView.Create(Self, pnlAvatar);
  FJarvisClient := TJarvisAPIClient.Create(Self);
  FAssistantManager := TAssistantManager.Create(Self);
  FAssistantManager.JarvisClient := FJarvisClient;
  FAssistantManager.OnStateChange := @OnAgentStateChange;
  FAssistantManager.OnComplete := @OnAgentComplete;
  FRAGMonitor:=TPresentationRAGMonitor.Create(PresentationRAGDirectory);
  FMemoryMap := TAIAgentMemoryMap.Create(Self);
  InicializarMemoria;
  FIntegrationJobs:=TIntegrationJobs.Create;
  FVoiceInput := TVoiceInputBridge.Create(Self);
  FVoiceInput.OnText := @VoiceText;
  FVoiceInput.OnState := @VoiceState;
  FVoiceInput.OnFinished := @VoiceFinished;
  FChromeSpeech := TAIChromeSpeech.Create(Self);
  FChromeSpeech.OnText := @ChromeText;
  FChromeSpeech.OnState := @ChromeState;
  FContinuousListener := TProfessorListener.Create(Self);
  FContinuousListener.OnSpeechReady := @SpeechReady;
  FContinuousListener.OnStateChange := @ListenerState;
  AplicarConfiguracao;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 50;
  FTimer.OnTimer := @TimerTick;
  KeyPreview:=True;
  OnKeyDown:=@CancelarApresentacao;
  SetEstado('Pronto para conversar', False);
  ConfigureIntegration;
end;

procedure Tfrmmain.CriarControles;
var TopicsHeading: TLabel;
begin
  Caption := 'Assistente | Maurinsoft';
  Font.Name:='Segoe UI';Font.Size:=10;DoubleBuffered:=True;
  FMovementIDs:=TStringList.Create;
  CreateDocumentMenu;
  Width:=1180;Height:=780;
  Constraints.MinWidth := 740;
  Constraints.MinHeight := 450;
  pnlRoot.Color := $00F8F5F3;
  pnlConteudo.Color := $00F8F5F3;
  pnlEntrada.Height := 40;
  pnlEntrada.Color := $00F8F5F3;
  pnlHeader.Visible:=True;pnlHeader.Height:=72;pnlHeader.Color:=clWhite;
  lblTitulo.Caption:='Assistente';lblTitulo.Font.Size:=20;lblTitulo.Font.Color:=$0035251D;
  lblTitulo.SetBounds(24,10,280,32);lblStatus.SetBounds(26,46,600,20);lblStatus.Font.Color:=$00746558;
  memResposta.Visible := False;
  btEnviar.Visible := False;
  FAvatarCard := TRoundedCard.Create(Self);
  FAvatarCard.Parent := pnlConteudo;
  FAvatarCard.Color := pnlConteudo.Color;
  pnlAvatar.Parent := FAvatarCard;
  pnlAvatar.Align := alClient;
  pnlAvatar.BorderSpacing.Around := 4;
  pnlAvatar.Color := clWhite;
  FProfilePanel := TPanel.Create(Self);
  FProfilePanel.Parent := pnlAvatar;
  FProfilePanel.Align := alTop;
  FProfilePanel.Height := 44;
  FProfilePanel.BevelOuter := bvNone;
  FProfilePanel.Color := clWhite;
  FProfileCombo := TComboBox.Create(Self);
  FProfileCombo.Name:='AvatarProfileSelector';
  FProfileCombo.Parent := FProfilePanel;
  FProfileCombo.Style := csDropDownList;
  FProfileCombo.Font.Size := 10;
  ReloadAvatars(nil);
  FReloadButton := TSpeedButton.Create(Self);
  FReloadButton.Parent := FProfilePanel;
  FReloadButton.Caption := '↻';
  FReloadButton.Flat := True;
  FReloadButton.Hint := 'Atualizar modelos da pasta AVATARES';
  FReloadButton.ShowHint := True;
  FReloadButton.OnClick := @ReloadAvatars;
  FSidebarDivider := TPanel.Create(Self);
  FSidebarDivider.Name := 'SidebarDivider';
  FSidebarDivider.Caption := '';
  FSidebarDivider.Parent := pnlConteudo;
  FSidebarDivider.BevelOuter := bvNone;
  FSidebarDivider.ParentBackground := False;
  FSidebarDivider.Color := $00DFD7D1;
  FSidebarDivider.Cursor := crHSplit;
  FSidebarDivider.Hint := 'Arraste para ajustar a largura da coluna esquerda.';
  FSidebarDivider.ShowHint := True;
  FSidebarDivider.OnMouseDown := @SidebarMouseDown;
  FSidebarDivider.OnMouseMove := @SidebarMouseMove;
  FSidebarDivider.OnMouseUp := @SidebarMouseUp;

  FChatPanel := TPanel.Create(Self);
  FChatPanel.Parent := pnlConteudo;
  FChatPanel.BevelOuter := bvNone;
  FChatPanel.Color := clWhite;
  FControlBar:=TPanel.Create(Self);FControlBar.Name:='PresentationControlBar';FControlBar.Caption:='';
  FControlBar.Parent:=FChatPanel;FControlBar.BevelOuter:=bvNone;FControlBar.Color:=ChromeDarkPanel;
  FControlBar.ParentBackground:=False;FControlBar.Visible:=False;
  FProgressLabel:=TPresentationProgress.Create(Self);FProgressLabel.Name:='PresentationProgressLabel';
  FProgressLabel.Parent:=FControlBar;FProgressLabel.Color:=ChromeDarkPanel;
  FProgressLabel.Font.Name:='Segoe UI';FProgressLabel.Font.Height:=-12;
  FPauseButton:=TChromeButton.Create(Self);FPauseButton.Name:='PresentationPauseButton';
  FPauseButton.Parent:=FControlBar;FPauseButton.Caption:='Pausar';FPauseButton.Icon:='❚❚';FPauseButton.KeyHint:='P';
  FPauseButton.Font.Name:='Segoe UI';FPauseButton.Font.Height:=-14;FPauseButton.OnClick:=@PauseButtonClick;
  FPauseButton.Hint:='Pausar ou retomar a narração (tecla P)';FPauseButton.ShowHint:=True;
  FPresentationPanel := TPanel.Create(Self);
  FPresentationPanel.Name := 'PresentationMediaPanel';
  FPresentationPanel.Parent := FChatPanel;
  FPresentationPanel.BevelOuter := bvNone;
  FPresentationPanel.Color := clBlack;
  FPresentationPanel.Visible := False;
  lblAssistente.Parent := FChatPanel;
  lblAssistente.Caption := 'Conversa';
  lblAssistente.AutoSize := False;
  lblAssistente.Font.Height := -14;
  lblAssistente.Font.Style := [fsBold];
  FChat := TConversationView.Create(Self);
  FChat.Parent := FChatPanel;
  FChat.Font.Name := 'Segoe UI';
  FChat.Font.Height := -13;
  FChat.AddMessage('Olá! Como posso ajudar?', False);
  FAskButton:=TChromeButton.Create(Self);FAskButton.Name:='AskPresentationButton';
  FAskButton.Parent:=FControlBar;FAskButton.Caption:='Continuar';FAskButton.Icon:='▶';FAskButton.Visible:=False;
  FAskButton.SetStyle(ChromeAccent,clWhite,ChromeAccent);FAskButton.Font.Name:='Segoe UI';FAskButton.Font.Height:=-14;
  FAskButton.Hint:='Retomar a apresentação de onde parou';FAskButton.ShowHint:=True;
  FAskButton.OnClick:=@AskPresentation;
  FHeaderMenu:=TChromeButton.Create(Self);FHeaderMenu.Name:='PresentationMenuButton';
  FHeaderMenu.Parent:=FControlBar;FHeaderMenu.Caption:='Menu';FHeaderMenu.Icon:='☰';
  FHeaderMenu.Font.Name:='Segoe UI';FHeaderMenu.Font.Height:=-14;FHeaderMenu.OnClick:=@HeaderMenuClick;
  FHeaderMenu.Hint:='Mostrar os blocos da apresentação';FHeaderMenu.ShowHint:=True;
  FHeaderAsk:=TChromeButton.Create(Self);FHeaderAsk.Name:='PresentationAskButton';
  FHeaderAsk.Parent:=FControlBar;FHeaderAsk.Caption:='Perguntar';FHeaderAsk.Icon:='✋';
  FHeaderAsk.SetStyle(ChromeAmber,ChromeAmberText,ChromeAmber);FHeaderAsk.Font.Name:='Segoe UI';FHeaderAsk.Font.Height:=-14;
  FHeaderAsk.OnClick:=@HeaderAskClick;
  FHeaderAsk.Hint:='Pausar e perguntar sobre o conteúdo apresentado';FHeaderAsk.ShowHint:=True;
  FTopicsCard:=TPanel.Create(Self);
  FTopicsCard.Name:='PresentationTopicsPanel';
  FTopicsCard.Parent:=pnlConteudo;
  FTopicsCard.BevelOuter:=bvNone;
  FTopicsCard.Color:=clWhite;
  FTopicsCard.Visible:=False;

  TopicsHeading:=TLabel.Create(Self);
  TopicsHeading.Parent:=FTopicsCard;
  TopicsHeading.Align:=alTop;
  TopicsHeading.BorderSpacing.Around:=8;
  TopicsHeading.Caption:='Assuntos';
  TopicsHeading.Font.Style:=[fsBold];

  FTopicsBody:=TPanel.Create(Self);
  FTopicsBody.Parent:=FTopicsCard;
  FTopicsBody.Align:=alClient;
  FTopicsBody.BorderSpacing.Left:=8;
  FTopicsBody.BorderSpacing.Right:=8;
  FTopicsBody.BorderSpacing.Bottom:=8;
  FTopicsBody.BevelOuter:=bvNone;

  FTopicsEmpty:=TLabel.Create(Self);
  FTopicsEmpty.Parent:=FTopicsBody;
  FTopicsEmpty.Align:=alClient;
  FTopicsEmpty.Layout:=tlCenter;
  FTopicsEmpty.WordWrap:=True;
  FTopicsEmpty.Caption:='Esta apresentação não tem assuntos.';

  FTopicsList:=TListBox.Create(Self);
  FTopicsList.Name:='PresentationTopicsList';
  FTopicsList.Parent:=FTopicsBody;
  FTopicsList.Align:=alClient;
  FTopicsList.OnMouseUp:=@TopicMouseUp;
  FTopicsList.OnKeyDown:=@TopicKeyDown;

  FMenuPanel:=TPanel.Create(Self);FMenuPanel.Parent:=FTopicsBody;FMenuPanel.Name:='PresentationMenuPanel';
  FMenuPanel.Align:=alClient;FMenuPanel.BevelOuter:=bvNone;FMenuPanel.Visible:=False;
  FMenuScrollBar:=TPanel.Create(Self);
  FMenuScrollBar.Parent:=FMenuPanel;
  FMenuScrollBar.Align:=alBottom;
  FMenuScrollBar.BevelOuter:=bvNone;
  FMenuScrollBar.Height:=25;
  FMenuUp:=TButton.Create(Self);FMenuUp.Name:='MenuScrollUp';FMenuUp.Parent:=FMenuScrollBar;FMenuUp.Align:=alLeft;
  FMenuUp.Caption:='▲ Para cima';FMenuUp.Tag:=-1;FMenuUp.OnClick:=@ScrollBlockMenu;
  FMenuDown:=TButton.Create(Self);FMenuDown.Name:='MenuScrollDown';FMenuDown.Parent:=FMenuScrollBar;FMenuDown.Align:=alClient;
  FMenuDown.Caption:='▼ Para baixo';FMenuDown.Tag:=1;FMenuDown.OnClick:=@ScrollBlockMenu;
  FMenuProgress:=TProgressBar.Create(Self);FMenuProgress.Parent:=FMenuPanel;FMenuProgress.Align:=alBottom;FMenuProgress.Height:=5;FMenuProgress.Max:=5000;
  FBlockMenu:=TListBox.Create(Self);FBlockMenu.Name:='PresentationBlockMenu';FBlockMenu.Parent:=FMenuPanel;FBlockMenu.Align:=alClient;
  FBlockMenu.Visible:=False;
  FBlockMenu.Hint:='Clique, use as setas e Enter ou mantenha o cursor por 5 segundos.';
  FBlockMenu.ShowHint:=True;
  FBlockMenu.OnKeyDown:=@BlockMenuKeyDown;FBlockMenu.OnKeyPress:=@BlockMenuKeyPress;
  FBlockMenu.OnMouseMove:=@BlockMenuMouseMove;FBlockMenu.OnMouseUp:=@BlockMenuMouseUp;
  FMenuHoverIndex:=-1;
  FStopVideo:=TButton.Create(Self);FStopVideo.Name:='StopPresentationVideoButton';
  FStopVideo.Parent:=FChatPanel;FStopVideo.Caption:='Encerrar vídeo';FStopVideo.Visible:=False;
  FStopVideo.OnClick:=@StopVideoClick;
  { Audience questions: white card with an amber header, as in the layout
    proposal. The memo keeps its parent so existing code and tests find it. }
  FQuestionCard:=TPanel.Create(Self);FQuestionCard.Name:='PresentationQuestionCard';FQuestionCard.Caption:='';
  FQuestionCard.Parent:=FChatPanel;FQuestionCard.BevelOuter:=bvNone;FQuestionCard.ParentBackground:=False;
  FQuestionCard.Color:=clWhite;FQuestionCard.Visible:=False;
  FQuestionHead:=TPanel.Create(Self);FQuestionHead.Caption:='';FQuestionHead.Parent:=FQuestionCard;
  FQuestionHead.Align:=alTop;FQuestionHead.Height:=62;FQuestionHead.BevelOuter:=bvNone;
  FQuestionHead.ParentBackground:=False;FQuestionHead.Color:=ChromeQuestionHead;
  FQuestionTitle:=TLabel.Create(Self);FQuestionTitle.Name:='PresentationQuestionTitle';FQuestionTitle.Parent:=FQuestionHead;
  FQuestionTitle.SetBounds(16,10,300,22);FQuestionTitle.Font.Name:='Segoe UI';FQuestionTitle.Font.Height:=-15;
  FQuestionTitle.Font.Style:=[fsBold];FQuestionTitle.Font.Color:=ChromeQuestionTitle;FQuestionTitle.Caption:='✋ Perguntas da plateia';
  FQuestionSub:=TLabel.Create(Self);FQuestionSub.Parent:=FQuestionHead;FQuestionSub.AutoSize:=False;
  FQuestionSub.SetBounds(16,34,300,20);FQuestionSub.Font.Name:='Segoe UI';FQuestionSub.Font.Height:=-12;
  FQuestionSub.Font.Color:=ChromeQuestionSub;FQuestionSub.Caption:='Roteiro pausado · a resposta usa o roteiro e a biblioteca';
  FQuestionMemo:=TMemo.Create(Self);FQuestionMemo.Name:='PresentationQuestionAnswer';FQuestionMemo.Parent:=FChatPanel;
  FQuestionMemo.ReadOnly:=True;FQuestionMemo.ScrollBars:=ssAutoVertical;FQuestionMemo.Visible:=False;
  FQuestionMemo.Font.Name:='Segoe UI';FQuestionMemo.Font.Height:=-14;FQuestionMemo.Font.Color:=ChromeInk;
  FQuestionMemo.BorderStyle:=bsNone;FQuestionMemo.Color:=clWhite;
  FStepBar:=TPresentationStepBar.Create(Self);FStepBar.Name:='PresentationStepBar';FStepBar.Parent:=FChatPanel;
  FStepBar.Font.Name:='Segoe UI';FStepBar.Font.Height:=-12;FStepBar.Visible:=False;
  FSpokenCaption:=TPresentationCaption.Create(Self);FSpokenCaption.Name:='PresentationCaption';FSpokenCaption.Parent:=FChatPanel;
  FSpokenCaption.Font.Name:='Segoe UI';FSpokenCaption.Font.Height:=-15;FSpokenCaption.Visible:=False;
  FInputCard := TRoundedCard.Create(Self);
  FInputCard.Parent := FChatPanel;
  FInputCard.Color := clWhite;FInputCard.Fill:=$00FAF7F5;FInputCard.Border:=$00E8E0D8;
  edPergunta.Parent := FInputCard;
  edPergunta.BorderStyle := bsNone;
  edPergunta.Color := $00FAF7F5;
  edPergunta.Font.Height := -13;
  edPergunta.TextHint := 'Digite sua pergunta...';
  edPergunta.Anchors := [akLeft,akTop,akRight];
  FSendButton := TSpeedButton.Create(Self);
  FSendButton.Parent := FChatPanel;
  FSendButton.Flat := True;
  FSendButton.Hint := 'Enviar pergunta';
  FSendButton.ShowHint := True;
  FSendButton.OnClick := @btEnviarClick;
  SetLineIcon(FSendButton, 'send', $00F67842);
  btConfig.Parent := pnlHeader;
  btConfig.Caption := '';
  btConfig.Hint := 'Configurações';
  btConfig.ShowHint := True;
  SetLineIcon(btConfig, 'config', $00707070);
  FMicButton := TSpeedButton.Create(Self);
  FMicButton.Parent := pnlConteudo;
  FMicButton.Caption := 'Microfone pausado';
  FMicButton.Hint := 'Pausar ou retomar a escuta contínua';
  FMicButton.ShowHint := True;
  FMicButton.Flat := True;
  FMicButton.Font.Height := -11;
  FMicButton.OnClick := @MicClick;
  SetLineIcon(FMicButton, 'mic', $004CAF28);
  FWaveButton := TSpeedButton.Create(Self);
  FWaveButton.Parent := FProfilePanel;
  FWaveButton.Caption := '↗';
  FWaveButton.Flat := True;
  FWaveButton.Hint := 'Acenar';
  FWaveButton.ShowHint := True;
  FWaveButton.OnClick := @GestureClick;
  FWalkButton := TSpeedButton.Create(Self);
  FWalkButton.Parent := FProfilePanel;
  FWalkButton.Caption := '↔';
  FWalkButton.Flat := True;
  FWalkButton.Hint := 'Caminhar';
  FWalkButton.ShowHint := True;
  FWalkButton.OnClick := @GestureClick;
  FDeviceStatus := TLabel.Create(Self);
  FDeviceStatus.Parent := pnlEntrada;
  FDeviceStatus.Visible := False;
  FAvatarStatus := TLabel.Create(Self);
  FAvatarStatus.Parent := pnlEntrada;
  FAvatarStatus.Font.Height := -10;
  FAvatarStatus.Caption := 'Avatar: IDLE';
  FAIStatus := TLabel.Create(Self);
  FAIStatus.Parent := pnlEntrada;
  FAIStatus.AutoSize := False;
  FAIStatus.Alignment := taCenter;
  FAIStatus.Font.Height := -10;
  FAIStatus.Caption := 'IA pronta';
  FRenderStatus := TLabel.Create(Self);
  FRenderStatus.Parent := pnlEntrada;
  FRenderStatus.AutoSize := False;
  FRenderStatus.Alignment := taRightJustify;
  FRenderStatus.Font.Height := -10;
  FRenderStatus.Caption := 'Renderização 3D';
  FMovementPanel:=TPanel.Create(Self);FMovementPanel.Parent:=pnlAvatar;FMovementPanel.Align:=alBottom;
  FMovementPanel.Height:=86;FMovementPanel.BevelOuter:=bvNone;FMovementPanel.Color:=clWhite;
  FMovementCombo:=TComboBox.Create(Self);FMovementCombo.Name:='MovementSelector';FMovementCombo.Parent:=FMovementPanel;
  FMovementCombo.Style:=csDropDownList;
  FMovementRun:=TButton.Create(Self);FMovementRun.Parent:=FMovementPanel;FMovementRun.Caption:='Executar gesto';FMovementRun.OnClick:=@RunMovement;
  FMovementRun.Hint:='Executar gesto selecionado';FMovementRun.ShowHint:=True;
  FMovementReload:=TButton.Create(Self);FMovementReload.Parent:=FMovementPanel;FMovementReload.Caption:='Recarregar';FMovementReload.OnClick:=@RefreshMovements;
  RefreshMovements(nil);
  OnResize := @LayoutProfessor;
  pnlConteudo.OnResize:=@LayoutProfessor;
  LayoutProfessor(nil);
end;

procedure Tfrmmain.RefreshMovements(Sender:TObject);
var I:Integer;M:TMovementDefinition;
begin
  try
    ReloadMovementCatalog;FMovementCombo.Clear;FMovementIDs.Clear;
    for I:=0 to MovementCount-1 do begin M:=MovementAt(I);FMovementCombo.Items.Add(M.Title);FMovementIDs.Add(M.ID);end;
    if FMovementCombo.Items.Count>0 then FMovementCombo.ItemIndex:=0;
    FMovementCombo.Hint:=MovementCatalogFile;FMovementCombo.ShowHint:=True;
    if (Sender<>nil) and (FProfessor<>nil) and (FProfessor.ModelFile<>'') then
      FProfessor.LoadModel(FProfessor.ModelFile,True);
  except on E:Exception do lblStatus.Caption:=E.Message;end;
end;
procedure Tfrmmain.RunMovement(Sender:TObject);
begin
  if (FProfessor=nil) or (FMovementCombo.ItemIndex<0) then Exit;
  try
    if not FProfessor.ExecuteMovement(FMovementIDs[FMovementCombo.ItemIndex]) then
      lblStatus.Caption:='O avatar selecionado não contém este movimento.';
  except on E:Exception do lblStatus.Caption:=E.Message;end;
end;

procedure Tfrmmain.SidebarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button<>mbLeft then Exit;
  FSidebarDragOffset:=X;
  SetCaptureControl(FSidebarDivider);
end;

procedure Tfrmmain.SidebarMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not (ssLeft in Shift) or (GetCaptureControl<>FSidebarDivider) then Exit;
  FSidebarWidth:=Max(1,FAvatarCard.Width+X-FSidebarDragOffset);
  LayoutProfessor(nil);
  FSidebarWidth:=FAvatarCard.Width;
end;

procedure Tfrmmain.SidebarMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button=mbLeft) and (GetCaptureControl=FSidebarDivider) then SetCaptureControl(nil);
end;

procedure Tfrmmain.LayoutProfessor(Sender: TObject);
var W, H, LeftWidth, ComposerWidth, CardWidth, ChatWidth,ChatHeight,MediaWidth,MediaHeight,QuestionHeight: Integer;
  Presenting: Boolean; MediaTop, BarTop, CaptionTop, QuestionWidth, QuestionLeft, StepWidth: Integer;
  TopicsHeight, AvatarTop, ReloadWidth: Integer;
begin
  if FClosing or not Assigned(FRenderStatus) then Exit;
  W := ClientWidth;
  H := pnlConteudo.ClientHeight;
  Presenting := FPresentationMode;
  LeftWidth := FSidebarWidth;
  if LeftWidth=0 then LeftWidth:=(W div 3-28) div 2;
  LeftWidth:=EnsureRange(LeftWidth,172,Max(172,W-398))+28;
  FSidebarDivider.SetBounds(LeftWidth-8,16,8,Max(1,H-32));
  AvatarTop:=16;
  if FTopicsCard.Visible then
  begin
    TopicsHeight:=EnsureRange((H-64) div 4, 96, 220);
    FTopicsCard.SetBounds(16,16,LeftWidth-28,TopicsHeight);
    FMenuUp.Width:=(FTopicsCard.ClientWidth-16) div 2;
    Inc(AvatarTop,TopicsHeight+10);
  end;
  FAvatarCard.SetBounds(16,AvatarTop,LeftWidth-28,Max(1,H-48-AvatarTop));
  FMicButton.SetBounds(16, H-40, LeftWidth-28, 32);
  ChatWidth:=W-LeftWidth-20;ChatHeight:=H-32;
  FChatPanel.SetBounds(LeftWidth+4,16,ChatWidth,ChatHeight);
  { During a presentation the chat area becomes the dark stage: block bar,
    media, spoken caption, control bar and the audience questions panel. }
  ApplyPresentationTheme(Presenting);
  lblAssistente.Visible:=not Presenting;
  FStepBar.Visible:=Presenting;FSpokenCaption.Visible:=Presenting;FControlBar.Visible:=Presenting;
  FQuestionCard.Visible:=Presenting and FQuestionMemo.Visible;
  ComposerWidth:=ChatWidth-36;
  if Presenting then begin
    StepWidth:=ChatWidth-28;
    if FStopVideo.Visible then Dec(StepWidth,170);
    FStepBar.SetBounds(14,6,Max(1,StepWidth),48);
    FStopVideo.SetBounds(ChatWidth-170,14,156,32);
    BarTop:=ChatHeight-82-70;
    FControlBar.SetBounds(14,BarTop,Max(1,ChatWidth-28),62);
    CaptionTop:=BarTop-60;
    MediaTop:=62;
    QuestionWidth:=0;
    if FQuestionMemo.Visible then QuestionWidth:=EnsureRange((ChatWidth-28) div 3,220,340);
    MediaWidth:=Max(1,ChatWidth-28);
    if QuestionWidth>0 then MediaWidth:=Max(1,MediaWidth-QuestionWidth-12);
    FSpokenCaption.SetBounds(14,CaptionTop,MediaWidth,50);
    MediaHeight:=Max(1,CaptionTop-10-MediaTop);
    FPresentationPanel.SetBounds(14,MediaTop,MediaWidth,MediaHeight);
    FChat.SetBounds(18,MediaTop,Max(1,MediaWidth-8),MediaHeight);
    QuestionLeft:=14+MediaWidth+12;
    { The card runs from the media top to the caption bottom; the memo sits
      inside it below the amber header. }
    FQuestionCard.SetBounds(QuestionLeft,MediaTop,Max(1,QuestionWidth),Max(1,CaptionTop+50-MediaTop));
    FQuestionSub.Width:=Max(1,QuestionWidth-28);FQuestionTitle.Width:=Max(1,QuestionWidth-28);
    FQuestionMemo.SetBounds(QuestionLeft+12,MediaTop+FQuestionHead.Height+10,Max(1,QuestionWidth-20),
      Max(1,CaptionTop+50-MediaTop-FQuestionHead.Height-20));
    FQuestionMemo.BringToFront;
    LayoutControlBar;
  end else begin
    lblAssistente.SetBounds(14, 12, ChatWidth-28, 22);
    QuestionHeight:=0;if FQuestionMemo.Visible then QuestionHeight:=120;
    MediaWidth:=Max(1,ChatWidth-28);MediaHeight:=Max(1,ChatHeight-178-QuestionHeight);
    FChat.SetBounds(18,48,Max(1,MediaWidth-8),MediaHeight);
    FPresentationPanel.SetBounds(14,40,MediaWidth,MediaHeight);
    FQuestionMemo.SetBounds(14,ChatHeight-250,Max(1,ChatWidth-28),110);
    FStopVideo.SetBounds(ChatWidth-170,5,156,32);
    lblAssistente.Width:=Max(1,ChatWidth-198);
  end;
  FInputCard.SetBounds(18, ChatHeight-82, ComposerWidth, 54);
  edPergunta.SetBounds(14, 15, ComposerWidth-64, 26);
  FSendButton.Parent:=FInputCard;FSendButton.SetBounds(ComposerWidth-40,12,30,30);
  btConfig.SetBounds(W-56,20,32,32);
  lblTitulo.Width:=Max(100,W-120);lblStatus.AutoSize:=False;lblStatus.Width:=Max(100,W-120);
  CardWidth := FAvatarCard.Width-8;
  FProfileCombo.SetBounds(10,9,CardWidth-88,28);
  FReloadButton.SetBounds(CardWidth-76,9,20,25);
  FWaveButton.SetBounds(CardWidth-54,9,20,25);
  FWalkButton.SetBounds(CardWidth-32,9,20,25);
  FMovementCombo.SetBounds(10,5,CardWidth-20,28);
  ReloadWidth:=Min(98,(CardWidth-24) div 2);
  FMovementRun.SetBounds(10,40,CardWidth-26-ReloadWidth,32);
  if FMovementRun.Width<96 then FMovementRun.Caption:='Executar'
  else FMovementRun.Caption:='Executar gesto';
  FMovementReload.SetBounds(CardWidth-10-ReloadWidth,40,ReloadWidth,32);
  FAvatarStatus.SetBounds(18, 13, LeftWidth-20, 16);
  FAIStatus.SetBounds(W div 3, 13, W div 3, 16);
  FRenderStatus.SetBounds(W-180, 13, 168, 16);
end;

procedure Tfrmmain.ApplyPresentationTheme(Presenting: Boolean);
{ The whole window turns into the dark stage of the layout proposal while a
  presentation runs, and returns to the light theme afterwards. }
begin
  if Presenting=FPresentationThemed then Exit;
  FPresentationThemed:=Presenting;
  if Presenting then begin
    pnlConteudo.Color:=ChromeDark;pnlHeader.Color:=ChromeDark;
    lblTitulo.Font.Color:=clWhite;lblStatus.Font.Color:=ChromeMuted;
    FChatPanel.Color:=ChromeDark;FAvatarCard.Color:=ChromeDark;FSidebarDivider.Color:=ChromeDarkPanel;
    FMicButton.Font.Color:=ChromeLight;
    FAvatarStatus.Font.Color:=ChromeMuted;FAIStatus.Font.Color:=ChromeMuted;FRenderStatus.Font.Color:=ChromeMuted;
  end else begin
    pnlConteudo.Color:=$00F8F5F3;pnlHeader.Color:=clWhite;
    lblTitulo.Font.Color:=$0035251D;lblStatus.Font.Color:=$00746558;
    FChatPanel.Color:=clWhite;FAvatarCard.Color:=pnlConteudo.Color;FSidebarDivider.Color:=$00DFD7D1;
    FMicButton.Font.Color:=clDefault;
    FAvatarStatus.Font.Color:=clDefault;FAIStatus.Font.Color:=clDefault;FRenderStatus.Font.Color:=clDefault;
  end;
  FInputCard.Color:=FChatPanel.Color;
  pnlEntrada.Color:=pnlConteudo.Color;
end;

procedure Tfrmmain.LayoutControlBar;
const Gap=10; ButtonTop=10; ButtonHeight=42;
var X: Integer;
  procedure Place(Button: TChromeButton; AWidth: Integer);
  begin
    if not Button.Visible then Exit;
    Dec(X, AWidth);Button.SetBounds(X, ButtonTop, AWidth, ButtonHeight);Dec(X, Gap);
  end;
begin
  if (FControlBar=nil) or not FControlBar.Visible then Exit;
  X:=FControlBar.ClientWidth-12;
  { Right to left: resume is the primary action while the script is parked. }
  Place(FAskButton, 150);
  Place(FHeaderAsk, 150);
  Place(FHeaderMenu, 118);
  Place(FPauseButton, 130);
  FProgressLabel.SetBounds(16, 4, Max(1, X-24), FControlBar.ClientHeight-8);
end;

procedure Tfrmmain.RefreshStepBar;
var Steps: TStringList; I, Current: Integer;
begin
  Steps:=TStringList.Create;
  try
    Steps.Add('Início');Current:=0;
    if FLoadedFlow<>nil then
      for I:=0 to FLoadedFlow.BlockCount-1 do begin
        Steps.Add(FLoadedFlow.BlockName(I));
        if (FCurrentBlock<>'') and SameText(FLoadedFlow.BlockName(I),FCurrentBlock) then Current:=I+1;
      end;
    FStepBar.SetSteps(Steps);FStepBar.Current:=Current;
    if (FTopicsList<>nil) and (Current>0) and (Current-1<FTopicsList.Items.Count) then
      FTopicsList.ItemIndex:=Current-1;
    FStepBar.Title:=ChangeFileExt(ExtractFileName(FLoadedFile),'');
    FStepBar.Subtitle:='Apresentação';
  finally Steps.Free;end;
end;

procedure Tfrmmain.UpdatePresentationChrome;
var CaptionText, TagText, Progress: string; Elapsed: QWord;
begin
  if not FPresentationMode or (FSpokenCaption=nil) then Exit;
  TagText:='LEGENDA';CaptionText:='';
  if Assigned(FSpeechJob) then begin
    if FSpeechJob.Paused then begin TagText:='PAUSA';CaptionText:='Narração pausada. Clique em Retomar ou pressione P.';end
    else begin CaptionText:=FSpeechJob.SpokenText;if FAnsweringQuestion then TagText:='RESPOSTA';end;
  end else if WaitingForQuestion then begin
    TagText:='PAUSA';
    if FMenuPanel.Visible then CaptionText:='Escolha um bloco para continuar ou clique em Continuar.'
    else CaptionText:='Faça uma pergunta, abra o Menu de blocos ou clique em Continuar.';
  end;
  FSpokenCaption.TagText:=TagText;FSpokenCaption.Text:=CaptionText;
  FPauseButton.Enabled:=Assigned(FSpeechJob) and not FAnsweringQuestion and not FResumePresentation;
  if Assigned(FSpeechJob) and FSpeechJob.Paused then begin FPauseButton.Caption:='Retomar';FPauseButton.Icon:='▶';end
  else begin FPauseButton.Caption:='Pausar';FPauseButton.Icon:='❚❚';end;
  if FStepBar.StepCount>1 then begin
    Progress:=Format('Bloco %d de %d',[FStepBar.Current+1,FStepBar.StepCount]);
    FProgressLabel.Position:=(FStepBar.Current+1)/FStepBar.StepCount;
  end else begin Progress:='Roteiro principal';FProgressLabel.Position:=0;end;
  FProgressLabel.Text:=Progress;
  if Length(FParkedPresentations)>0 then FProgressLabel.RightText:='roteiro pausado'
  else if Assigned(FSpeechJob) and FSpeechJob.Paused then FProgressLabel.RightText:='narração pausada'
  else FProgressLabel.RightText:='';
  Elapsed:=(GetTickCount64-FPresentationStarted) div 1000;
  FStepBar.Chips:=Format('⏱ %.2d:%.2d',[Elapsed div 60,Elapsed mod 60])+'|✕ Encerrar  Esc';
  LayoutControlBar;
end;

procedure Tfrmmain.TogglePresentationPause;
var Paused: Boolean;
begin
  if not FPresentationMode or not Assigned(FSpeechJob) then Exit;
  Paused:=not FSpeechJob.Paused;FSpeechJob.SetPaused(Paused);
  TPresentationScene(FProfessor.Scene).PauseJoints(Paused);
  FProfessor.SetRenderingActive(not Paused);
  try if FPresentationMedia<>nil then FPresentationMedia.SetPaused(Paused);
  except on E: Exception do begin FSpeechJob.Cancel;lblStatus.Caption:=E.Message;end;end;
  if Paused then lblStatus.Caption:='Apresentacao pausada (P retoma; Esc cancela)';
end;

procedure Tfrmmain.PauseButtonClick(Sender: TObject);
begin
  if FPauseButton.Enabled then TogglePresentationPause;
end;

procedure Tfrmmain.FormDestroy(Sender: TObject);
begin
  FClosing := True;
  FreeAndNil(FRAGMonitor);
  FreeAndNil(FLoadedFlow);
  FreeAndNil(FLoadedPackage);
  if Assigned(FTimer) then FTimer.Enabled := False;
  FreeAndNil(FIntegration);
  if Assigned(FChromeSpeech) then FChromeSpeech.Stop;
  if Assigned(FContinuousListener) then FContinuousListener.Stop;
  if Assigned(FVoiceInput) then begin FVoiceInput.OnFinished:=nil;FVoiceInput.Cancel;end;
  if Assigned(FAssistantManager) then
  begin
    FAssistantManager.OnComplete := nil;
    FAssistantManager.OnStateChange := nil;
    FreeAndNil(FAssistantManager);
  end;
  if Assigned(FSpeechJob) then begin FSpeechJob.Cancel; FreeAndNil(FSpeechJob); end;
  FinishPresentation;
  PararVideo;
  SalvarMemoria;
  FreeAndNil(FProfessor);
  FreeAndNil(FCatalog);
  FreeAndNil(FMovementIDs);
  FreeAndNil(FIntegrationJobs);
end;

procedure Tfrmmain.FormShow(Sender: TObject);
begin
  if not FShown then
  begin
    FShown := True;
    if FConfigImportMessage<>'' then begin
      memResposta.Lines.Add(FConfigImportMessage);memResposta.Lines.Add('');
    end;
    IniciarEscuta;
    IniciarVideo;
    FProfessor.Gesture(psWave);
    try
      if ParamStrUTF8(1)='--presentation-block' then begin
        if ParamCount<>3 then raise Exception.Create('Use --presentation-block nome arquivo.pva');
        StartPresentation(ParamStrUTF8(3),ParamStrUTF8(2));
      end else if (ParamStrUTF8(1)='--presentation') or (ParamStrUTF8(1)='--presentation-silent') then begin
        if ParamCount<>2 then raise Exception.Create('Informe um arquivo .pva');
        StartPresentation(ParamStrUTF8(2));
      end else if SameText(ExtractFileExt(ParamStrUTF8(1)),'.pva') then StartPresentation(ParamStrUTF8(1));
    except on E: Exception do begin FinishPresentation;MessageDlg(E.Message,mtError,[mbOK],0);end;end;
  end;
  if edPergunta.CanFocus then edPergunta.SetFocus;
end;

procedure Tfrmmain.ChromeText(Sender: TObject; const AText: string);
begin
  if FClosing or FConfigOpen or FMicMuted or FAguardandoResposta or
    Assigned(FSpeechJob) or FVoiceInput.Busy or
    (FSetMain.RecogEngine <> Ord(vreChromeWebSpeech)) then Exit;
  PausarEscuta;
  ProcessarEntrada(AText);
end;

procedure Tfrmmain.ChromeState(Sender: TObject; const AText: string);
begin
  if FClosing or FConfigOpen or FAguardandoResposta or Assigned(FSpeechJob) then Exit;
  lblStatus.Caption := AText;
  FMicButton.Caption := 'Microfone Chrome';
end;

procedure Tfrmmain.IniciarEscuta;
begin
  FMicButton.Caption := 'Microfone pausado';
  if not FSetMain.ContinuousListening or FMicMuted or FClosing then Exit;
  if FSetMain.RecogEngine = Ord(vreChromeWebSpeech) then
  begin
    FContinuousListener.Stop;
    try
      FChromeSpeech.Language := FSetMain.RecogLanguage;
      FChromeSpeech.VoiceThreshold := FSetMain.VoiceThreshold;
      FChromeSpeech.SilenceTimeoutMs := FSetMain.SilenceTimeoutMs;
      FChromeSpeech.MinSpeechMs := FSetMain.MinSpeechMs;
      if not FChromeSpeech.Active then
      begin
        FChromeSpeech.Start;
        try FChromeSpeech.OpenBrowser;
        except FChromeSpeech.Stop; raise; end;
      end;
      FChromeSpeech.SetPaused(False);
      FMicButton.Caption := 'Microfone Chrome';
      lblStatus.Caption := 'Clique em Iniciar escuta na janela do Chrome e autorize o microfone.';
    except on E: Exception do SetEstado(E.Message, False); end;
    Exit;
  end;
  FChromeSpeech.Stop;
  try
    FContinuousListener.Native.DeviceIndex := FSetMain.AudioDeviceIndex;
    FContinuousListener.Native.SampleRate := FSetMain.AudioSampleRate;
    FContinuousListener.Native.Channels := FSetMain.AudioChannels;
    FContinuousListener.Native.VoiceThreshold := FSetMain.VoiceThreshold;
    FContinuousListener.Native.SilenceTimeoutMs := FSetMain.SilenceTimeoutMs;
    FContinuousListener.Native.MinSpeechMs := FSetMain.MinSpeechMs;
    FContinuousListener.Native.MaxSpeechMs := FSetMain.MaxSpeechMs;
    FContinuousListener.Native.EchoSuppressionEnabled := FSetMain.EchoSuppressionEnabled;
    FContinuousListener.Native.SelfAudioCorrelationThreshold := FSetMain.SelfAudioCorrelationThreshold;
    FContinuousListener.Start;
    if FContinuousListener.Enabled then FMicButton.Caption := 'Escutando';
  except on E: Exception do SetEstado('Microfone indisponível: ' + E.Message, False); end;
end;

procedure Tfrmmain.PausarEscuta;
begin
  FMicButton.Caption := 'Microfone pausado';
  if Assigned(FChromeSpeech) then FChromeSpeech.SetPaused(True);
  if Assigned(FContinuousListener) and FContinuousListener.Enabled then FContinuousListener.Pause;
end;

procedure Tfrmmain.RetomarEscuta;
begin
  if FClosing or FDocumentDialogOpen or FAguardandoResposta or Assigned(FSpeechJob) or FVoiceInput.Busy then Exit;
  FProfessor.SetActivity(psIdle);
  if FMicMuted then Exit;
  if FSetMain.RecogEngine = Ord(vreChromeWebSpeech) then
  begin
    if FSetMain.ContinuousListening then
    begin
      if FChromeSpeech.Active then FChromeSpeech.SetPaused(False)
      else IniciarEscuta;
    end;
    Exit;
  end;
  if FSetMain.ContinuousListening then
    if FContinuousListener.Enabled then
    begin
      FContinuousListener.Resume;
      if FContinuousListener.Enabled then FMicButton.Caption := 'Escutando';
    end else IniciarEscuta;
end;

procedure Tfrmmain.MicClick(Sender: TObject);
begin
  FMicMuted := not FMicMuted;
  if FMicMuted then
  begin
    FChromeSpeech.Stop;
    FContinuousListener.Stop;
    FMicButton.Caption := 'Microfone pausado';
    if not FAguardandoResposta and not Assigned(FSpeechJob) then
    begin FProfessor.SetActivity(psIdle); SetEstado('Microfone pausado', False); end;
  end else RetomarEscuta;
end;

procedure Tfrmmain.GestureClick(Sender: TObject);
begin
  if Sender = FWaveButton then FProfessor.Gesture(psWave) else FProfessor.Gesture(psWalk);
end;

procedure Tfrmmain.SpeechReady(Sender: TObject; const AFileName: string);
begin
  if FClosing then Exit;
  PausarEscuta;
  if FAguardandoResposta or Assigned(FSpeechJob) or FMicMuted or
    not FVoiceInput.TranscribeWav(AFileName) then
  begin SysUtils.DeleteFile(AFileName); RetomarEscuta; end;
end;

procedure Tfrmmain.ListenerState(Sender: TObject; AState: TProfessorListenState);
begin
  if FClosing or FAguardandoResposta or Assigned(FSpeechJob) or FVoiceInput.Busy then Exit;
  case AState of
    plsListening: begin FProfessor.SetActivity(psIdle); lblStatus.Caption := 'Ouvindo...'; end;
    plsSpeech, plsSilence: begin FProfessor.SetActivity(psListening); lblStatus.Caption := 'Escutando fala...'; end;
    plsPaused: lblStatus.Caption := 'Microfone pausado';
    plsError: begin FProfessor.SetActivity(psIdle); lblStatus.Caption := 'Erro no microfone'; end;
  end;
end;

procedure Tfrmmain.RemoteVoiceText(Sender: TObject; const AText: string);
begin
  { Called by TThread.Synchronize on the Lazarus main thread. }
  if FClosing or FAguardandoResposta or Assigned(FSpeechJob) or
    FVoiceInput.Busy then Exit;
  if IsWhisperHallucination(AText) then
  begin
    RetomarEscuta;
    Exit;
  end;
  PausarEscuta;
  ProcessarEntrada(AText);
end;

procedure Tfrmmain.VoiceText(Sender: TObject; const AText: string);
begin
  if not FClosing and not IsWhisperHallucination(AText) then ProcessarEntrada(AText);
end;

procedure Tfrmmain.VoiceFinished(Sender: TObject);
begin
  if FClosing then Exit;
  SetEstado(lblStatus.Caption,FAguardandoResposta);
  RetomarEscuta;
end;

procedure Tfrmmain.VoiceState(Sender: TObject; const AState: string);
begin
  if FClosing or FAguardandoResposta or Assigned(FSpeechJob) then Exit;
  SetEstado(AState, False);
  if FVoiceInput.Busy then FProfessor.SetActivity(psThinking)
  else if (Pos('Falha', AState) = 1) or (Pos('Nenhuma', AState) = 1) or (Pos('descartado', AState) > 0) then RetomarEscuta;
end;

procedure Tfrmmain.InicializarMemoria;
begin
  if GetEnvironmentVariable('ASSISTENTE_CONFIG_DIR')<>'' then
    FHistoryFile:=IncludeTrailingPathDelimiter(GetEnvironmentVariable('ASSISTENTE_CONFIG_DIR'))+'conversation-history.json'
  else
  FHistoryFile := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'conversation-history.json';
  FMemoryMap.MaxItems := 100;
  FMemoryMap.StoreFullPrompt := True;
  FMemoryMap.StoreFullResponse := True;
  FMemoryMap.DetectInformationLoss := True;
  FMemoryMap.RedactSensitiveData := True;
  if FileExists(FHistoryFile) then
    try FMemoryMap.LoadFromFile(FHistoryFile);
    except FMemoryMap.StartFlow('', 'Assistente', 'usuario', 'interface'); end
  else FMemoryMap.StartFlow('', 'Assistente', 'usuario', 'interface');
end;

procedure Tfrmmain.SalvarMemoria;
begin
  if (FMemoryMap = nil) or (FHistoryFile = '') then Exit;
  try FMemoryMap.SaveToFile(FHistoryFile); except end;
end;

procedure Tfrmmain.AplicarConfiguracao;
var I: Integer;
begin
  FAssistantManager.ChatGPT.TOKEN := FSetMain.CHATGPT;
  if (FSetMain.ChatGPTProvider >= 0) and (FSetMain.ChatGPTProvider <= Ord(High(TAIProvider))) then
    FAssistantManager.ChatGPT.Provider := TAIProvider(FSetMain.ChatGPTProvider)
  else FAssistantManager.ChatGPT.Provider := AIP_OPENAI;
  FAssistantManager.ChatGPT.CustomModel := FSetMain.ChatGPTModel;
  FAssistantManager.ChatGPT.URL := FSetMain.ChatGPTURL;
  if FSetMain.RAGInAnswers then
    FAssistantManager.KnowledgeFolder:=ExtractFilePath(Application.ExeName)+'knowledge'
  else FAssistantManager.KnowledgeFolder:='';
  FJarvisClient.BaseURL := FSetMain.JarvisURL;
  FJarvisClient.APIKey := FSetMain.JarvisAPIKey;
  if FSetMain.Avatar3DProfile = 'custom' then
  begin
    FProfileCombo.ItemIndex := FCatalog.Count;
    FProfessor.LoadModel(FSetMain.Avatar3DModel, FSetMain.Avatar3DAutoIdle);
  end else
  begin
    I := FCatalog.IndexOfID(FSetMain.Avatar3DProfile);
    if (I < 0) and (FCatalog.Count > 0) then I := 0;
    FProfileCombo.ItemIndex := I;
    if I >= 0 then FProfessor.LoadModel(FCatalog[I].ModelFile, FSetMain.Avatar3DAutoIdle)
    else FProfessor.LoadModel('', FSetMain.Avatar3DAutoIdle);
  end;
end;

procedure Tfrmmain.ReloadAvatars(Sender: TObject);
var I: Integer;
begin
  if FClosing or FAguardandoResposta or Assigned(FSpeechJob) then Exit;
  FCatalog.Refresh;
  FProfileCombo.OnChange := nil;
  FProfileCombo.Items.Clear;
  for I := 0 to FCatalog.Count-1 do FProfileCombo.Items.Add(FCatalog[I].Name);
  FProfileCombo.Items.Add('Modelo personalizado');
  FProfileCombo.OnChange := @ProfileChange;
  FProfileCombo.Hint := FCatalog.Root + LineEnding + FCatalog.Diagnostic;
  FProfileCombo.ShowHint := True;
  if Assigned(FProfessor) and Assigned(FAssistantManager) then AplicarConfiguracao;
end;

procedure Tfrmmain.ProfileChange(Sender: TObject);
begin
  if FClosing or FAguardandoResposta or Assigned(FSpeechJob) or (FProfileCombo.ItemIndex < 0) then Exit;
  if FProfileCombo.ItemIndex = FCatalog.Count then
  begin
    if Trim(FSetMain.Avatar3DModel) = '' then
    begin
      FProfileCombo.ItemIndex := FCatalog.IndexOfID(FSetMain.Avatar3DProfile);
      lblStatus.Caption := 'Escolha um arquivo em Config. > Avatar 3D.';
      Exit;
    end;
    FSetMain.Avatar3DProfile := 'custom';
  end else FSetMain.Avatar3DProfile := FCatalog[FProfileCombo.ItemIndex].ID;
  AplicarConfiguracao;
  FSetMain.SalvaContexto(False);
end;

procedure Tfrmmain.SetEstado(const ATexto: string; AOcupado: Boolean);
begin
  lblStatus.Caption := ATexto;
  FAguardandoResposta := AOcupado;
  btEnviar.Enabled := not AOcupado and not Assigned(FSpeechJob) and not FVoiceInput.Busy;
  FHeaderAsk.Enabled:=FPresentationMode and not AOcupado and not FVoiceInput.Busy and not FResumePresentation and not (FAnsweringQuestion and Assigned(FSpeechJob));
  FHeaderMenu.Enabled:=FHeaderAsk.Enabled and (FLoadedFlow<>nil);
  if FHeaderMenu.Enabled then FHeaderMenu.Enabled:=FLoadedFlow.BlockCount>0;
  FAskButton.Visible:=FPresentationMode and (Length(FParkedPresentations)>0) and not Assigned(FSpeechJob);
  FAskButton.Enabled:=FPresentationMode and not AOcupado and not FVoiceInput.Busy and not FResumePresentation and not (FAnsweringQuestion and Assigned(FSpeechJob));
  FBlockMenu.Enabled:=btEnviar.Enabled;
  FAskButton.Caption:='Continuar';
  edPergunta.Enabled := btEnviar.Enabled;
  btConfig.Enabled := btEnviar.Enabled and not FVoiceInput.Busy;
  FWaveButton.Enabled := btEnviar.Enabled;
  FWalkButton.Enabled := btEnviar.Enabled;
  FProfileCombo.Enabled := btEnviar.Enabled;
  FReloadButton.Enabled := btEnviar.Enabled;
  FSendButton.Enabled := btEnviar.Enabled;
  if AOcupado then FAIStatus.Caption := 'IA processando...'
  else if FAIConnected then FAIStatus.Caption := 'IA conectada'
  else FAIStatus.Caption := 'IA pronta';
  FAIStatus.Hint := ATexto;
  FAIStatus.ShowHint := True;
  UpdateDocumentActions;
end;

procedure Tfrmmain.CreateDocumentMenu;
begin
  FDocumentMenu:=TAssistantMenu.Create(Self);Menu:=FDocumentMenu;
  FDocumentMenu.OpenFile.OnClick:=@OpenFileClick;
  FDocumentMenu.LoadPresentation.OnClick:=@OpenFileClick;
  FDocumentMenu.PlayPresentation.OnClick:=@PlayPresentationClick;
  FDocumentMenu.CloseFile.OnClick:=@CloseFileClick;
  FDocumentMenu.PrintPDF.OnClick:=@PrintPDFClick;
  FDocumentMenu.FindText.OnClick:=@FindTextClick;
  FDocumentMenu.About.OnClick:=@AboutClick;
  FOpenFileDialog:=TOpenDialog.Create(Self);
  FOpenFileDialog.Title:='Abrir arquivo no Assistente';
  FOpenFileDialog.Filter:='Documentos do Assistente|*.pva;*.script;*.txt;*.md;*.res;*.rag;*.json;*.csv|'+
    'Apresentações e roteiros|*.pva;*.script|Textos e documentos de consulta|*.txt;*.md;*.res;*.rag;*.json;*.csv';
  FOpenFileDialog.Options:=[ofFileMustExist,ofPathMustExist,ofEnableSizing,ofHideReadOnly];
  FPVAFileDialog:=TOpenDialog.Create(Self);
  FPVAFileDialog.Title:='Carregar apresentação';
  FPVAFileDialog.Filter:='Apresentação do Assistente (*.pva)|*.pva';
  FPVAFileDialog.DefaultExt:='pva';
  FPVAFileDialog.Options:=FOpenFileDialog.Options;
  FPDFDialog:=TSaveDialog.Create(Self);FPDFDialog.Title:='Imprimir apresentação / Salvar PDF';
  FPDFDialog.Filter:='Documento PDF|*.pdf';FPDFDialog.DefaultExt:='pdf';
  FPDFDialog.Options:=[ofOverwritePrompt,ofPathMustExist,ofEnableSizing];
end;

procedure Tfrmmain.UpdateDocumentActions;
var Available, Idle, HasPresentation: Boolean;
begin
  if FDocumentMenu=nil then Exit;
  Available:=not FClosing and not FDocumentDialogOpen and not FConfigOpen and
    not FAguardandoResposta and ((FVoiceInput=nil) or not FVoiceInput.Busy);
  Idle:=Available and (FSpeechJob=nil) and (Length(FParkedPresentations)=0);
  HasPresentation:=(FLoadedKind=adPresentation) and (FLoadedFlow<>nil);
  FDocumentMenu.OpenFile.Enabled:=Idle;
  FDocumentMenu.LoadPresentation.Enabled:=Idle;
  FDocumentMenu.PlayPresentation.Enabled:=Idle and HasPresentation;
  FDocumentMenu.Topics.Enabled:=Idle and HasPresentation;
  if FTopicsList<>nil then
    FTopicsList.Enabled:=Available and not FResumePresentation and
      ((FSpeechJob=nil) or (FPresentationMode and not FAnsweringQuestion));
  FDocumentMenu.CloseFile.Enabled:=Available and (FLoadedFile<>'') and ((FSpeechJob=nil) or FPresentationMode);
  FDocumentMenu.PrintPDF.Enabled:=Idle and (FLoadedPackage<>nil);
  FDocumentMenu.FindText.Enabled:=Idle;
  FDocumentMenu.About.Enabled:=Idle;
end;

procedure Tfrmmain.OpenFileClick(Sender: TObject);
var Directory, MessageText: string;
  Dialog: TOpenDialog;
begin
  if IntegrationBusy then Exit;
  if Sender=FDocumentMenu.LoadPresentation then Dialog:=FPVAFileDialog
  else Dialog:=FOpenFileDialog;
  Directory:=ExtractFilePath(FLoadedFile);
  if not DirectoryExists(Directory) then Directory:=PresentationRAGDirectory;
  if not DirectoryExists(Directory) then Directory:=GetUserDir;
  Dialog.InitialDir:=Directory;Dialog.FileName:='';
  FDocumentDialogOpen:=True;PausarEscuta;UpdateDocumentActions;
  try
    try
      if not Dialog.Execute then Exit;
      if Dialog=FPVAFileDialog then
      begin
        if not SameText(ExtractFileExt(Dialog.FileName),'.pva') then
          raise Exception.Create('Selecione uma apresentação com extensão .pva.');
        OpenPresentation(Dialog.FileName,'',False);
        MessageText:='Apresentação carregada: '+ExtractFileName(FLoadedFile);
      end
      else
      begin
        LoadDocument(Dialog.FileName);
        MessageText:='Arquivo carregado: '+ExtractFileName(FLoadedFile);
      end;
      FChat.AddMessage(MessageText,False);memResposta.Lines.Add(MessageText);
    except on E: Exception do MessageDlg('Abrir arquivo','Não foi possível abrir o arquivo: '+E.Message,mtError,[mbOK],0);end;
  finally
    FDocumentDialogOpen:=False;UpdateDocumentActions;RetomarEscuta;
    if edPergunta.CanFocus then edPergunta.SetFocus;
  end;
end;

procedure Tfrmmain.UpdatePresentationTopics;
var I: Integer;
  Topic: TMenuItem;
begin
  if FDocumentMenu=nil then Exit;
  FTopicsList.Items.BeginUpdate;
  try
    FTopicsList.Items.Clear;
    if FLoadedFlow<>nil then
      for I:=0 to FLoadedFlow.BlockCount-1 do
        FTopicsList.Items.Add(FLoadedFlow.BlockName(I));
  finally
    FTopicsList.Items.EndUpdate;
  end;
  FTopicsCard.Visible:=(FLoadedFlow<>nil) and
    ((FLoadedKind=adPresentation) or (FTopicsList.Items.Count>0));
  FTopicsList.Visible:=FTopicsList.Items.Count>0;
  FTopicsEmpty.Visible:=not FTopicsList.Visible;
  LayoutProfessor(nil);

  FDocumentMenu.Topics.Clear;
  if (FLoadedKind<>adPresentation) or (FLoadedFlow=nil) then Exit;
  if FLoadedFlow.BlockCount=0 then
  begin
    Topic:=TMenuItem.Create(FDocumentMenu);
    Topic.Caption:='Esta apresentação não tem assuntos';
    Topic.Enabled:=False;
    FDocumentMenu.Topics.Add(Topic);
    Exit;
  end;
  for I:=0 to FLoadedFlow.BlockCount-1 do
  begin
    Topic:=TMenuItem.Create(FDocumentMenu);
    Topic.Caption:=' '+StringReplace(FLoadedFlow.BlockName(I),'&','&&',[rfReplaceAll]);
    Topic.Tag:=I;
    Topic.OnClick:=@PlayPresentationClick;
    FDocumentMenu.Topics.Add(Topic);
  end;
end;

procedure Tfrmmain.PlayPresentationClick(Sender: TObject);
begin
  if IntegrationBusy or (FLoadedKind<>adPresentation) or (FLoadedFlow=nil) then Exit;
  if Sender=FDocumentMenu.PlayPresentation then PlayLoadedPresentation('')
  else PlayLoadedPresentation(FLoadedFlow.BlockName(TMenuItem(Sender).Tag));
end;

procedure Tfrmmain.PlayLoadedPresentation(const EntryBlock: string);
var Compiled: string;
begin
  try
    FinishPresentation;
    FQuestionMemo.Clear;
    Compiled:=PreparePresentation(FLoadedPackage,FLoadedFlow,EntryBlock);
    FLoadedEntryBlock:=EntryBlock;
    BeginPresentation(Compiled);
  except
    on E: Exception do
    begin
      FinishPresentation;
      RetomarEscuta;
      MessageDlg('Apresentação',E.Message,mtError,[mbOK],0);
    end;
  end;
end;

procedure Tfrmmain.CloseDocument;
begin
  if FClosing or FDocumentDialogOpen or FConfigOpen or FAguardandoResposta or
    ((FVoiceInput<>nil) and FVoiceInput.Busy) or ((FSpeechJob<>nil) and not FPresentationMode) then
    raise Exception.Create('Aguarde o Assistente concluir a operação atual.');
  if FLoadedFile='' then Exit;
  PausarEscuta;
  if FSpeechJob<>nil then FSpeechJob.Cancel;
  FinishPresentation;FreeAndNil(FLoadedFlow);FreeAndNil(FLoadedPackage);
  FLoadedFile:='';FLoadedKnowledge:='';FLoadedSource:='';FLoadedEntryBlock:='';FLoadedKind:=adRAG;
  UpdatePresentationTopics;
  FPresentationPanel.Visible:=False;FChat.Visible:=True;FInputCard.Visible:=True;
  FSendButton.Visible:=True;btConfig.Visible:=True;lblAssistente.Caption:='Conversa';
  SetEstado('Arquivo fechado. Pronto para conversar',False);RetomarEscuta;
end;

procedure Tfrmmain.CloseFileClick(Sender: TObject);
begin
  try CloseDocument;
  except on E: Exception do MessageDlg('Fechar arquivo',E.Message,mtError,[mbOK],0);end;
end;

procedure Tfrmmain.SavePresentationPDF(const FileName: string);
var G: TGUID; Directory: string;
begin
  if FLoadedPackage=nil then raise Exception.Create('Carregue primeiro uma apresentação ou roteiro.');
  if not SameText(ExtractFileExt(FileName),'.pdf') then raise Exception.Create('O destino deve ter a extensão .pdf.');
  CreateGUID(G);Directory:=IncludeTrailingPathDelimiter(GetTempDir(False))+'assistente-print-package-'+GUIDToString(G);
  try
    FLoadedPackage.ExtractTo(Directory);
    ExportPresentationPDF(FLoadedSource,Directory,FileName,ExtractFileName(FLoadedFile),FLoadedEntryBlock);
  finally if DirectoryExists(Directory) then DeleteDirectory(Directory,False);end;
end;

procedure Tfrmmain.PrintPDFClick(Sender: TObject);
begin
  if IntegrationBusy or (FLoadedPackage=nil) then Exit;
  FPDFDialog.FileName:=ChangeFileExt(ExtractFileName(FLoadedFile),'.pdf');
  FDocumentDialogOpen:=True;PausarEscuta;UpdateDocumentActions;
  try
    try
      if not FPDFDialog.Execute then Exit;
      SavePresentationPDF(FPDFDialog.FileName);
      MessageDlg('PDF salvo','Apresentação salva em:'+LineEnding+FPDFDialog.FileName,mtInformation,[mbOK],0);
    except on E: Exception do MessageDlg('Imprimir apresentação',E.Message,mtError,[mbOK],0);end;
  finally FDocumentDialogOpen:=False;UpdateDocumentActions;RetomarEscuta;end;
end;

function Tfrmmain.SearchableDocumentText: string;
var Flow: TFlowProgram; Script: TAvatarScript;
begin
  Result:='';
  if FLoadedFile<>'' then begin
    Result:='Documento: '+ExtractFileName(FLoadedFile)+LineEnding+LineEnding;
    if FLoadedKind=adRAG then Result:=Result+FLoadedKnowledge
    else begin
      Flow:=TFlowProgram.Create(FLoadedSource);
      try Script:=ParseAvatarScript(Flow.WithoutFlowTags,4096);Result:=Result+Script.PlainText;
      finally Flow.Free;end;
    end;
    Result:=Result+LineEnding+LineEnding;
  end;
  Result:=Result+'Conversa atual'+LineEnding+LineEnding+memResposta.Text;
end;

procedure Tfrmmain.FindTextClick(Sender: TObject);
begin
  if IntegrationBusy then Exit;
  FDocumentDialogOpen:=True;PausarEscuta;UpdateDocumentActions;
  try SearchAssistantText(Self,SearchableDocumentText,FSearchQuery);
  finally FDocumentDialogOpen:=False;UpdateDocumentActions;RetomarEscuta;end;
end;

procedure Tfrmmain.AboutClick(Sender: TObject);
begin
  if IntegrationBusy then Exit;
  FDocumentDialogOpen:=True;PausarEscuta;UpdateDocumentActions;
  try
    MessageDlg('Sobre o Assistente','Assistente | Maurinsoft'+LineEnding+LineEnding+
      'Professor virtual e apresentações com avatar 3D.'+LineEnding+
      'Desenvolvido por Marcelo Maurin Martins.'+LineEnding+'https://maurinsoft.com.br'+LineEnding+LineEnding+
      'Arquivo: abrir, fechar e imprimir apresentação em PDF.'+LineEnding+
      'Pesquisar: localizar palavras no documento e na conversa.',mtInformation,[mbOK],0);
  finally FDocumentDialogOpen:=False;UpdateDocumentActions;RetomarEscuta;end;
end;

procedure Tfrmmain.EnviarPergunta;
begin ProcessarEntrada(edPergunta.Text); end;

procedure Tfrmmain.ProcessarEntrada(const ATexto: string);
var P, H, C: string; Script: TAvatarScript;
begin
  if FClosing or FDocumentDialogOpen or FAguardandoResposta or Assigned(FSpeechJob) or FVoiceInput.Busy then Exit;
  P := Trim(ATexto);
  if P = '' then begin RetomarEscuta; Exit; end;
  if Length(FParkedPresentations)>0 then begin
    if PresentationInput(P) then Exit;
    FAnsweringQuestion:=True;FQuestionMemo.Visible:=True;LayoutProfessor(nil);FQuestionMemo.Lines.Add('Você: '+P);
  end else if ExecuteDocumentCommand(P) then Exit;
  Script:=ParseAvatarScript(P);
  if (Script.CommandCount>0) and (Trim(Script.PlainText)='') and
    (Script.PresentationCount=0) and (Script.JointCount=0) then begin
    edPergunta.Clear;
    memResposta.Lines.Add('Comando: '+P);
    FChat.AddMessage(P,True);
    FalarResposta(P);
    Exit;
  end;
  PausarEscuta;
  if Length(FParkedPresentations)=0 then FProfessor.ResetCommands;
  FCurrentUserText := P;
  H := Trim(FMemoryMap.BuildConversationContext(12));
  if H <> '' then C := 'Historico completo da conversa anterior:' + sLineBreak + H +
    sLineBreak + 'Nova fala do usuario:' + sLineBreak + P + sLineBreak +
    'Analise a nova fala considerando o historico e responda mantendo o contexto.'
  else C := P;
  if (FLoadedFile<>'') and (FLoadedKind=adRAG) then
    C:=C+LineEnding+DocumentContext(FLoadedFile,FLoadedKnowledge,P);
  if FAnsweringQuestion then begin
    C:=C+PresentationQuestionContext(FLoadedFlow,FLoadedFile,P);
    with TPresentationRAG.Create(PresentationRAGDirectory) do
    try
      Refresh;C:=C+ReferenceContext(P,FLoadedFile);
    finally Free;end;
  end else if FSetMain.RAGInAnswers then
    try
      with TPresentationRAG.Create(PresentationRAGDirectory) do
      try Refresh;C:=C+AnswerContext(P);finally Free;end;
    except { The library is optional: answer without references. } end;
  FMemoryItem := FMemoryMap.BeginAgentStep('Assistente', tamOrquestrador, P, H);
  memResposta.Lines.Add('Você: ' + P);
  FChat.AddMessage(P, True);
  memResposta.Lines.Add('');
  edPergunta.Clear;
  FProfessor.SetActivity(psThinking);
  SetEstado('Pensando...', True);
  try FAssistantManager.ProcessUserRequestAsync(C,P,((FLoadedFile='') or (FLoadedKind<>adRAG)) and not FAnsweringQuestion);
  except on E: Exception do
    begin
      if Assigned(FMemoryItem) then
      begin
        FMemoryItem.Erro := E.Message;
        FMemoryMap.EndAgentStep(FMemoryItem, 'Falha ao enviar pergunta', E.Message, 'erro', '', '');
        SalvarMemoria;
        FMemoryItem := nil;
      end;
      if Length(FParkedPresentations)>0 then begin FAnsweringQuestion:=False;QuestionReady;end
      else SetEstado('Erro. Pronto para nova tentativa', False);
      RetomarEscuta;
    end;
  end;
end;

procedure Tfrmmain.FalarResposta(const ATexto: string);
var C: TReceptionConfig; Script: TAvatarScript;
begin
  if FClosing or Assigned(FSpeechJob) then Exit;
  if FAnsweringQuestion and not FSetMain.AutoSpeak then begin FAnsweringQuestion:=False;QuestionReady;Exit;end;
  Script:=ParseAvatarScript(ATexto);
  if (Trim(ATexto)='') or (not FSetMain.AutoSpeak and (Script.CommandCount+Script.PresentationCount+Script.JointCount=0) and not FPresentationMode) then begin RetomarEscuta;Exit;end;
  PausarEscuta;
  C := Default(TReceptionConfig);
  C.EnableAvatarCommands:=True;
  C.EnablePresentationCommands:=FPresentationMode and not FAnsweringQuestion;
  C.SilentPresentation:=not FSetMain.AutoSpeak or (ParamStrUTF8(1)='--presentation-silent');
  C.Token := FSetMain.CHATGPT;
  C.AudioToken := FSetMain.VoiceAPIToken;
  if C.AudioToken = '' then C.AudioToken := FSetMain.CHATGPT;
  C.Model := FSetMain.VoiceModel;
  C.URL := FSetMain.VoiceEndpoint;
  C.Language := FSetMain.VoiceLanguage;
  C.Voice := FSetMain.SynthVoice;
  C.RemoteVoice := FSetMain.VoiceRemoteVoice;
  C.Speed := FSetMain.VoiceSpeed;
  if C.Voice = '' then C.Voice := FSetMain.VoiceRemoteVoice;
  C.Provider := FSetMain.VoiceProvider;
  C.RecogEngine := FSetMain.RecogEngine;
  C.SynthEngine := FSetMain.SynthEngine;
  C.Volume := FSetMain.SynthVolume;
  C.Rate := FSetMain.SynthRate;
  try
    FSpeechJob := TReceptionJob.Create(rjSpeak, C, ATexto, '', 'main');
    if C.SilentPresentation then SetEstado('Apresentando gestos... (Esc para parar)',False)
    else SetEstado('Preparando voz... (Esc para parar)', False);
  except on E: Exception do
    begin SetEstado('Falha na voz: ' + E.Message, False); RetomarEscuta; end;
  end;
end;

function Tfrmmain.ActivePresentationMedia: string;
begin if FPresentationMedia=nil then Result:='' else Result:=FPresentationMedia.Active;end;

function Tfrmmain.ApresentandoResposta: Boolean;
begin Result:=Assigned(FSpeechJob) or (Length(FParkedPresentations)>0);end;

procedure Tfrmmain.SelectPresentationAvatar(const AvatarID: string);
var I: Integer;
begin
  I:=FCatalog.IndexOfID(AvatarID);
  if I<0 then raise Exception.Create('Avatar nao instalado: '+AvatarID);
  FPresentationAvatarChanged:=True;
  if not FProfessor.LoadModel(FCatalog[I].ModelFile,FSetMain.Avatar3DAutoIdle) then
    raise Exception.Create('Falha ao carregar avatar: '+AvatarID);
  FProfileCombo.ItemIndex:=I;
end;
function Tfrmmain.ActivePresentationSound: string;
begin if FPresentationMedia=nil then Result:='' else Result:=FPresentationMedia.ActiveSound;end;
function Tfrmmain.ActivePresentationAvatar: string;
begin
  if (FProfileCombo.ItemIndex>=0) and (FProfileCombo.ItemIndex<FCatalog.Count) then
    Result:=FCatalog[FProfileCombo.ItemIndex].ID else Result:='custom';
end;
procedure Tfrmmain.LoadDocument(const FileName: string);
var Kind: TAssistantDocumentKind; TextValue,SourcePath: string;
begin
  if Assigned(FSpeechJob) or FAguardandoResposta then raise Exception.Create('Assistente ocupado');
  SourcePath:=ExpandFileName(FileName);Kind:=AssistantDocumentKind(SourcePath);
  if Kind<>adRAG then begin StartPresentation(SourcePath);Exit;end;
  TextValue:=ReadAssistantKnowledge(SourcePath);
  FreeAndNil(FLoadedFlow);FreeAndNil(FLoadedPackage);FLoadedSource:='';FLoadedEntryBlock:='';
  FLoadedFile:=SourcePath;FLoadedKind:=adRAG;FLoadedKnowledge:=TextValue;
  UpdatePresentationTopics;
  SetEstado('Documento de consulta carregado: '+ExtractFileName(SourcePath),False);
end;
procedure Tfrmmain.CallLoadedBlock(const BlockName: string);
begin
  if (FLoadedFile='') or (FLoadedKind=adRAG) then raise Exception.Create('Carregue primeiro um script com blocos');
  StartPresentation(FLoadedFile,BlockName);
end;
function Tfrmmain.ExecuteDocumentCommand(const AInput: string): Boolean;
var Command: TLocalDocumentCommand; Argument,FileName,MessageText: string; Item: TAIAgentMemoryMapItem;
begin
  Result:=False;Item:=nil;
  try
    Command:=ParseDocumentCommand(AInput,Argument);if Command=dcNone then Exit;
    Result:=True;PausarEscuta;FChat.AddMessage(AInput,True);edPergunta.Clear;
    if Command=dcLoadFile then begin
      FileName:=FindAssistantDocument(PresentationRAGDirectory,Argument);LoadDocument(FileName);
      if FLoadedKind=adRAG then MessageText:='Documento carregado para consulta: '+ExtractFileName(FileName)
      else MessageText:='Script carregado: '+ExtractFileName(FileName);
    end else begin CallLoadedBlock(Argument);MessageText:='Executando bloco: '+Argument;end;
    FChat.AddMessage(MessageText,False);memResposta.Lines.Add(MessageText);
    Item:=FMemoryMap.BeginAgentStep('Assistente',tamOrquestrador,AInput,'');
    FMemoryMap.EndAgentStep(Item,'Comando local',MessageText,'documento',MessageText,MessageText);SalvarMemoria;
    if not Assigned(FSpeechJob) then RetomarEscuta;
  except on E: Exception do begin
    Result:=True;MessageText:=E.Message;FChat.AddMessage(MessageText,False);
    SetEstado(MessageText,False);RetomarEscuta;
  end;end;
end;
procedure Tfrmmain.TopicMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button=mbLeft then ActivateTopic(FTopicsList.ItemAtPos(Types.Point(X,Y),True));
end;

procedure Tfrmmain.TopicKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key=VK_RETURN) and (Shift=[]) then
  begin
    Key:=0;
    ActivateTopic(FTopicsList.ItemIndex);
  end;
end;

procedure Tfrmmain.ActivateTopic(Index: Integer);
var Topic: string;
begin
  UpdateDocumentActions;
  if not FTopicsList.Enabled or (FLoadedFlow=nil) or
    (Index<0) or (Index>=FLoadedFlow.BlockCount) then Exit;
  Topic:=FLoadedFlow.BlockName(Index);
  if not FPresentationMode then
  begin
    PlayLoadedPresentation(Topic);
    Exit;
  end;
  try
    if Assigned(FSpeechJob) then ParkPresentation(False);
    if WaitingForQuestion then PlayQuestionBlock(Topic);
  except
    on E: Exception do
    begin
      if WaitingForQuestion then QuestionReady;
      lblStatus.Caption:=E.Message;
    end;
  end;
end;

procedure Tfrmmain.ShowBlockMenu;
var I:Integer;CloseTag:TPresentationTag;
begin
  FBlockMenu.Items.Clear;
  if FLoadedFlow=nil then raise Exception.Create('Nenhuma apresentacao carregada.');
  for I:=0 to FLoadedFlow.BlockCount-1 do FBlockMenu.Items.Add(FLoadedFlow.BlockName(I));
  if FBlockMenu.Items.Count=0 then raise Exception.Create('A apresentacao nao possui blocos para o MENU.');
  if FPresentationMedia<>nil then begin CloseTag:=Default(TPresentationTag);CloseTag.Action:=paCloseFile;FPresentationMedia.Execute(CloseTag);end;
  FTopicsList.Visible:=False;
  FMenuPanel.Visible:=True;FBlockMenu.Visible:=True;FQuestionMemo.Visible:=False;
  FMenuHoverIndex:=-1;FMenuHoverSince:=0;FMenuKeyboard:=False;FMenuProgress.Position:=0;
  FBlockMenu.ItemIndex:=-1;LayoutProfessor(nil);PresentationVisualChange(nil);
end;
procedure Tfrmmain.BlockMenuClick(Sender:TObject);
begin
  if WaitingForQuestion and (FBlockMenu.ItemIndex>=0) then
    ActivateTopic(FBlockMenu.ItemIndex);
end;
procedure Tfrmmain.HideBlockMenu;
begin
  FMenuPanel.Visible:=False;FBlockMenu.Visible:=False;FMenuHoverIndex:=-1;FMenuHoverSince:=0;
  FTopicsList.Visible:=FTopicsList.Items.Count>0;
  FMenuProgress.Position:=0;PresentationVisualChange(nil);
end;
procedure Tfrmmain.ScrollBlockMenu(Sender:TObject);
var Rows,Last:Integer;
begin
  Rows:=Max(1,FBlockMenu.ClientHeight div Max(1,FBlockMenu.ItemHeight));Last:=Max(0,FBlockMenu.Items.Count-Rows);
  FBlockMenu.TopIndex:=EnsureRange(FBlockMenu.TopIndex+TButton(Sender).Tag*Max(1,Rows div 2),0,Last);
  FMenuHoverSince:=0;FMenuHoverIndex:=-1;FMenuProgress.Position:=0;
end;
procedure Tfrmmain.BlockMenuKeyDown(Sender:TObject;var Key:Word;Shift:TShiftState);
var I,Rows:Integer;
begin
  FMenuKeyboard:=True;FMenuHoverSince:=0;FMenuHoverIndex:=-1;FMenuProgress.Position:=0;
  if Key in [VK_RETURN,VK_SPACE] then begin Key:=0;BlockMenuClick(Sender);Exit;end;
  if not (Key in [VK_UP,VK_DOWN,VK_LEFT,VK_RIGHT,VK_HOME,VK_END,VK_PRIOR,VK_NEXT]) then Exit;
  Rows:=Max(1,FBlockMenu.ClientHeight div Max(1,FBlockMenu.ItemHeight));I:=FBlockMenu.ItemIndex;
  case Key of
    VK_UP,VK_LEFT:Dec(I);
    VK_DOWN,VK_RIGHT:Inc(I);
    VK_HOME:I:=0;
    VK_END:I:=FBlockMenu.Items.Count-1;
    VK_PRIOR:Dec(I,Rows);
    VK_NEXT:Inc(I,Rows);
  end;
  I:=EnsureRange(I,0,FBlockMenu.Items.Count-1);FBlockMenu.ItemIndex:=I;
  if I<FBlockMenu.TopIndex then FBlockMenu.TopIndex:=I
  else if I>=FBlockMenu.TopIndex+Rows then FBlockMenu.TopIndex:=I-Rows+1;
  Key:=0;
end;
procedure Tfrmmain.BlockMenuKeyPress(Sender:TObject;var Key:Char);
begin
  if Key>=#32 then begin
    edPergunta.SetFocus;edPergunta.Text:=edPergunta.Text+Key;edPergunta.SelStart:=Length(edPergunta.Text);Key:=#0;
  end;
end;
procedure Tfrmmain.BlockMenuMouseMove(Sender:TObject;Shift:TShiftState;X,Y:Integer);
begin FMenuKeyboard:=False;end;
procedure Tfrmmain.BlockMenuMouseUp(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
var I:Integer;
begin
  if Button<>mbLeft then Exit;
  I:=FBlockMenu.ItemAtPos(Types.Point(X,Y),True);
  if I<0 then Exit;FBlockMenu.ItemIndex:=I;FMenuHoverSince:=0;FMenuProgress.Position:=0;BlockMenuClick(Sender);
end;
procedure Tfrmmain.UpdateMenuHover;
var P:TPoint;I,Rows,Last:Integer;Elapsed:QWord;
begin
  if not FMenuPanel.Visible then Exit;
  Rows:=Max(1,FBlockMenu.ClientHeight div Max(1,FBlockMenu.ItemHeight));Last:=Max(0,FBlockMenu.Items.Count-Rows);
  FMenuUp.Enabled:=WaitingForQuestion and (FBlockMenu.TopIndex>0);
  FMenuDown.Enabled:=WaitingForQuestion and (FBlockMenu.TopIndex<Last);
  if not WaitingForQuestion or FMenuKeyboard then begin FMenuHoverSince:=0;FMenuProgress.Position:=0;Exit;end;
  P:=FBlockMenu.ScreenToClient(Mouse.CursorPos);I:=-1;
  if (P.X>=0) and (P.Y>=0) and (P.X<FBlockMenu.ClientWidth) and (P.Y<FBlockMenu.ClientHeight) then I:=FBlockMenu.ItemAtPos(P,True);
  if I<0 then begin FMenuHoverIndex:=-1;FMenuHoverSince:=0;FMenuProgress.Position:=0;Exit;end;
  if (I<>FMenuHoverIndex) or (FMenuHoverSince=0) then begin FMenuHoverIndex:=I;FMenuHoverSince:=GetTickCount64;end;
  FBlockMenu.ItemIndex:=I;Elapsed:=GetTickCount64-FMenuHoverSince;
  FMenuProgress.Position:=Min(5000,Elapsed);
  if Elapsed>5000 then begin FMenuHoverSince:=0;FMenuHoverIndex:=-1;FMenuProgress.Position:=0;BlockMenuClick(FBlockMenu);end;
end;
function Tfrmmain.WaitingForQuestion:Boolean;
begin Result:=(Length(FParkedPresentations)>0) and not Assigned(FSpeechJob) and not FAguardandoResposta;end;
procedure Tfrmmain.QuestionReady;
begin
  if FPresentationMedia<>nil then FPresentationMedia.SetPaused(True);
  FQuestionMemo.Visible:=not FMenuPanel.Visible;LayoutProfessor(nil);
  FProfessor.SetActivity(psIdle);edPergunta.TextHint:='Pergunte sobre a apresentacao ou informe um bloco...';
  SetEstado('Apresentacao pausada: pergunte, escolha um bloco ou continue.',False);
  RetomarEscuta;
  if not Visible then Exit;
  if FMenuPanel.Visible then begin if FBlockMenu.CanFocus then FBlockMenu.SetFocus;end
  else if edPergunta.CanFocus then edPergunta.SetFocus;
end;
procedure Tfrmmain.ParkPresentation(AtTag:Boolean);
var N:Integer;
begin
  if not Assigned(FSpeechJob) then Exit;
  N:=Length(FParkedPresentations);if N>=32 then raise Exception.Create('Limite de 32 perguntas aninhadas.');
  if not AtTag then FSpeechJob.SetPaused(True);
  SetLength(FParkedPresentations,N+1);FParkedPresentations[N].Job:=FSpeechJob;FParkedPresentations[N].AtTag:=AtTag;
  FParkedPresentations[N].YouTubePending:=FYouTubeCommandPending;FYouTubeCommandPending:=False;
  FParkedPresentations[N].Block:=FCurrentBlock;
  FSpeechJob:=nil;FAnsweringQuestion:=False;
  try QuestionReady;
  except
    // Restore ownership before the timer records an error or cancels the job.
    FSpeechJob:=FParkedPresentations[N].Job;
    FYouTubeCommandPending:=FParkedPresentations[N].YouTubePending;
    SetLength(FParkedPresentations,N);
    if not AtTag then FSpeechJob.SetPaused(False);
    raise;
  end;
end;
procedure Tfrmmain.ResumePresentation;
var N:Integer;AtTag:Boolean;
begin
  N:=High(FParkedPresentations);if N<0 then raise Exception.Create('Nao existe apresentacao pausada.');
  HideBlockMenu;FQuestionMemo.Visible:=False;LayoutProfessor(nil);
  PausarEscuta;AtTag:=FParkedPresentations[N].AtTag;FSpeechJob:=FParkedPresentations[N].Job;
  FYouTubeCommandPending:=FParkedPresentations[N].YouTubePending;
  FCurrentBlock:=FParkedPresentations[N].Block;RefreshStepBar;SetLength(FParkedPresentations,N);
  FAnsweringQuestion:=False;FSpeechJob.SetPaused(False);if AtTag then FSpeechJob.ConfirmAvatarCommand;
  if FPresentationMedia<>nil then FPresentationMedia.SetPaused(False);
  edPergunta.TextHint:='Digite sua pergunta...';SetEstado('Continuando apresentacao...',False);
end;
procedure Tfrmmain.UpdateVideoButton;
var WasVisible: Boolean;
begin
  WasVisible:=FStopVideo.Visible;
  FStopVideo.Visible:=(FPresentationMedia<>nil) and FPresentationMedia.IsVideo;
  if FStopVideo.Visible<>WasVisible then begin
    LayoutProfessor(nil);if FStopVideo.Visible then FStopVideo.BringToFront;
  end;
  FStopVideo.Enabled:=not FResumePresentation and not (FAnsweringQuestion and Assigned(FSpeechJob));
end;
procedure Tfrmmain.StopVideoClick(Sender:TObject);
var CloseTag:TPresentationTag;N:Integer;
begin
  if not FStopVideo.Enabled or (FPresentationMedia=nil) or not FPresentationMedia.IsVideo then Exit;
  try
    if Assigned(FSpeechJob) then ParkPresentation(False);
    N:=High(FParkedPresentations);
    if (N>=0) and FParkedPresentations[N].YouTubePending then begin
      FParkedPresentations[N].YouTubePending:=False;
      FParkedPresentations[N].AtTag:=True;
    end;
    CloseTag:=Default(TPresentationTag);CloseTag.Action:=paCloseFile;FPresentationMedia.Execute(CloseTag);
    if WaitingForQuestion then begin HideBlockMenu;QuestionReady;end;
  except on E:Exception do SetEstado(E.Message,False);end;
end;
procedure Tfrmmain.HeaderAskClick(Sender:TObject);
begin
  if not FHeaderAsk.Enabled then Exit;
  if Assigned(FSpeechJob) then ParkPresentation(False);
  if WaitingForQuestion then begin HideBlockMenu;QuestionReady;end;
end;
procedure Tfrmmain.HeaderMenuClick(Sender:TObject);
begin
  if not FHeaderMenu.Enabled then Exit;
  try
    if Assigned(FSpeechJob) then ParkPresentation(False);
    if WaitingForQuestion then begin ShowBlockMenu;QuestionReady;end;
  except on E:Exception do SetEstado(E.Message,False);end;
end;
procedure Tfrmmain.AskPresentation(Sender:TObject);
begin
  if FClosing or FAguardandoResposta or FVoiceInput.Busy or not FPresentationMode then Exit;
  if Assigned(FSpeechJob) then begin
    if not FAnsweringQuestion then ParkPresentation(False);
  end else if Length(FParkedPresentations)>0 then ResumePresentation;
end;
function Tfrmmain.PresentationInput(const Input:string):Boolean;
var TargetBlock,Key:string;
begin
  Result:=True;
  try
    Key:=FlowNameKey(Input);
    if (Key='menu') or (Key='[menu]') then begin edPergunta.Clear;ShowBlockMenu;QuestionReady;Exit;end;
    if (Key='continuar') or (Key='[continuar]') then begin edPergunta.Clear;ResumePresentation;Exit;end;
    if not QuestionBlock(FLoadedFlow,Input,TargetBlock) then Exit(False);
    PlayQuestionBlock(TargetBlock);
  except on E:Exception do begin QuestionReady;lblStatus.Caption:=E.Message;end;end;
end;

procedure Tfrmmain.PlayQuestionBlock(const TargetBlock: string);
var Compiled: string;
begin
  Compiled:=FLoadedFlow.Compile(TargetBlock,False);ValidateRuntimeScript(Compiled);
  HideBlockMenu;LayoutProfessor(nil);
  PausarEscuta;edPergunta.Clear;FChat.AddMessage('Bloco: '+TargetBlock,True);
  FCurrentBlock:=TargetBlock;RefreshStepBar;
  FAnsweringQuestion:=False;
  if FPresentationMedia<>nil then FPresentationMedia.SetPaused(False);
  if Trim(Compiled)='' then QuestionReady else FalarResposta(Compiled);
end;
procedure Tfrmmain.StartPresentation(const FileName,EntryBlock: string);
begin
  OpenPresentation(FileName,EntryBlock,True);
end;

function Tfrmmain.PreparePresentation(Package: TPVAPackage; Flow: TFlowProgram;
  const EntryBlock: string): string;
var G: TGUID;
  Script: TAvatarScript;
  I: Integer;
begin
  Result:=Flow.Compile(EntryBlock);
  ValidateRuntimeScript(Result);
  Script:=ParseAvatarScript(Result,4096);
  for I:=0 to High(Script.Steps) do
    if (Script.Steps[I].Presentation.Action=paSelectAvatar) and
      (FCatalog.IndexOfID(Script.Steps[I].Presentation.Argument)<0) then
      raise Exception.Create('Avatar nao instalado: '+Script.Steps[I].Presentation.Argument);
  if FSetMain.AutoSpeak and (FSetMain.SynthEngine=2) then
    raise Exception.Create('Apresentacoes com pausa requerem SAPI ou voz remota no Windows');
  CreateGUID(G);
  FPresentationRoot:=IncludeTrailingPathDelimiter(GetTempDir(False))+'assistente-pva-'+GUIDToString(G);
  Package.ExtractTo(FPresentationRoot);
  FPresentationMedia:=TPresentationMedia.Create(FPresentationRoot,FPresentationPanel);
  FPresentationMedia.OnVisualChange:=@PresentationVisualChange;
end;

procedure Tfrmmain.BeginPresentation(const Compiled: string);
begin
  FPresentationMode:=True;FPresentationStarted:=GetTickCount64;
  FCurrentBlock:=FLoadedEntryBlock;RefreshStepBar;LayoutProfessor(nil);
  PausarEscuta;
  FProfessor.ResetCommands;
  FalarResposta(Compiled);
  if FSpeechJob=nil then FinishPresentation;
end;

procedure Tfrmmain.OpenPresentation(const FileName, EntryBlock: string; Play: Boolean);
var Package: TPVAPackage;
  Flow: TFlowProgram;
  Compiled, SourcePath: string;
  Kind: TAssistantDocumentKind;
begin
  if Assigned(FSpeechJob) or FAguardandoResposta then raise Exception.Create('Assistente ocupado');
  SourcePath:=ExpandFileName(FileName);
  Kind:=AssistantDocumentKind(SourcePath);
  FinishPresentation;
  FQuestionMemo.Clear;
  Package:=OpenAssistantPackage(SourcePath);
  Flow:=nil;
  try
    try
      Flow:=TFlowProgram.Create(Package.Script);
      if Play then Compiled:=PreparePresentation(Package,Flow,EntryBlock);
      FreeAndNil(FLoadedFlow);FLoadedFlow:=Flow;Flow:=nil;
      FreeAndNil(FLoadedPackage);FLoadedPackage:=Package;Package:=nil;
      FLoadedSource:=FLoadedPackage.Script;FLoadedEntryBlock:=EntryBlock;
      FLoadedFile:=SourcePath;FLoadedKnowledge:='';FLoadedKind:=Kind;
      UpdatePresentationTopics;
      if Play then BeginPresentation(Compiled)
      else SetEstado('Apresentação carregada: '+ExtractFileName(SourcePath),False);
    except
      FinishPresentation;
      raise;
    end;
  finally
    Flow.Free;
    Package.Free;
  end;
end;
procedure Tfrmmain.PresentationVisualChange(Sender: TObject);
var HasVisual: Boolean;
begin
  UpdateVideoButton;
  HasVisual:=(FPresentationMedia<>nil) and (FPresentationMedia.Active<>'');
  FPresentationPanel.Visible:=HasVisual;
  FChat.Visible:=not HasVisual;FInputCard.Visible:=True;
  FSendButton.Visible:=True;btConfig.Visible:=True;
  if HasVisual then begin
    lblAssistente.Caption:='Apresentação';
    FPresentationPanel.BringToFront;
  end else lblAssistente.Caption:='Conversa';
end;

procedure Tfrmmain.FinishPresentation;
var I:Integer;
begin
  for I:=High(FParkedPresentations) downto 0 do begin FParkedPresentations[I].Job.Cancel;FParkedPresentations[I].Job.Free;end;
  SetLength(FParkedPresentations,0);FAnsweringQuestion:=False;FResumePresentation:=False;
  if Assigned(FAskButton) then FAskButton.Visible:=False;
  HideBlockMenu;FQuestionMemo.Visible:=False;
  edPergunta.TextHint:='Digite sua pergunta...';
  FYouTubeCommandPending:=False;
  FreeAndNil(FPresentationMedia);FPresentationMode:=False;FCurrentBlock:='';
  if FPresentationAvatarChanged then begin
    FPresentationAvatarChanged:=False;
    if not FClosing then AplicarConfiguracao;
  end;
  if Assigned(FProfessor) then begin
    TPresentationScene(FProfessor.Scene).PauseJoints(False);
    FProfessor.SetRenderingActive(True);FProfessor.ResetCommands;
  end;
  if (Pos('assistente-pva-',ExtractFileName(FPresentationRoot))=1) and
    (ExtractFileDir(FPresentationRoot)=ExcludeTrailingPathDelimiter(GetTempDir(False))) then
    DeleteDirectory(FPresentationRoot,False);
  FPresentationRoot:='';LayoutProfessor(nil);
end;
procedure Tfrmmain.CancelarApresentacao(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if not Assigned(FSpeechJob) and (Length(FParkedPresentations)=0) then Exit;
  if FPresentationMode and Assigned(FSpeechJob) and (ActiveControl<>edPergunta) and (Key=Ord('P')) and (Shift=[]) then begin
    TogglePresentationPause;Key:=0;Exit;
  end;
  if Key=VK_ESCAPE then begin
    if FAnsweringQuestion and FAguardandoResposta then FAssistantManager.CancelExecution;
    if Assigned(FSpeechJob) then FSpeechJob.Cancel;FProfessor.ResetCommands;Key:=0;
    if FPresentationMode then FinishPresentation;
    lblStatus.Caption:='Interrompendo apresentacao...';
    if not Assigned(FSpeechJob) then begin SetEstado('Pronto para conversar',False);RetomarEscuta;end;
  end;
end;

procedure Tfrmmain.TimerTick(Sender: TObject);
var Ok: Boolean; Err: string; Command: TAvatarScriptStep;
begin
  if FClosing then Exit;
  UpdateDocumentActions;
  FChromeSpeech.Poll;UpdateMenuHover;UpdateVideoButton;UpdatePresentationChrome;
  if Assigned(FIntegration) then FIntegration.Pump;
  FAvatarStatus.Caption := 'Avatar: ' + FProfessor.ActivityLabel;
  if FProfessor.ModelFile <> '' then FRenderStatus.Caption := 'Renderização 3D'
  else FRenderStatus.Caption := '3D indisponível';
  FRenderStatus.Hint := FDeviceStatus.Caption;
  FRenderStatus.ShowHint := True;
  if not Assigned(FSpeechJob) then Exit;
  if FYouTubeCommandPending then begin
    try
      if (FPresentationMedia=nil) or not FPresentationMedia.YouTubeWaiting then begin
        FYouTubeCommandPending:=False;FSpeechJob.ConfirmAvatarCommand;
      end;
    except on E:Exception do begin
      FSpeechJob.ErrorText:=E.Message;FSpeechJob.Cancel;FYouTubeCommandPending:=False;
    end;end;
  end;
  if not FSpeechJob.Done then
  begin
    if FSpeechJob.Paused then begin FProfessor.SetActivity(psIdle);end
    else if FYouTubeCommandPending then begin
      FProfessor.SetActivity(psIdle);lblStatus.Caption:='YouTube: reproduza o video ou clique em Continuar apresentacao. P pausa; Esc cancela.';
    end
    else if FSpeechJob.PlaybackActive then
    begin FProfessor.SetActivity(psSpeaking); lblStatus.Caption := 'Falando...'; end
    else if FSpeechJob.IsSilent then FProfessor.SetActivity(psIdle)
    else FProfessor.SetActivity(psThinking);
  end;
  while FSpeechJob.TakeScriptCommand(Command) do begin
    try
      if FSpeechJob.PlaybackActive then FProfessor.SetActivity(psSpeaking);
      if FPresentationMode and (Command.Presentation.Action in [paAsk,paMenu]) then begin
        if Command.Presentation.Action=paMenu then ShowBlockMenu;
        ParkPresentation(True);Exit;end
      else if FPresentationMode and (Command.Presentation.Action=paContinue) then begin
        if Length(FParkedPresentations)=0 then raise Exception.Create('CONTINUAR exige uma apresentacao pausada por PERGUNTAR.');
        FResumePresentation:=True;FSpeechJob.Cancel;Break;
      end
      else if FPresentationMode and (Command.Presentation.Action=paEndTask) and (Length(FParkedPresentations)>0) then FinishPresentation
      else if FPresentationMode and (Command.Presentation.Action=paSelectAvatar) then
        SelectPresentationAvatar(Command.Presentation.Argument)
      else if FPresentationMode and (Command.Presentation.Action=paSelectVoice) then
        begin { voice is selected by the speech worker before synthesis } end
      else if FPresentationMode and (Command.Presentation.Action<>paNone) then begin
        FPresentationMedia.Execute(Command.Presentation);
        if Command.Presentation.Action=paYouTube then FYouTubeCommandPending:=True;
      end
      else if FPresentationMode and (Command.Joint.Bone<>'') then TPresentationScene(FProfessor.Scene).ExecuteJoint(Command.Joint)
      else if Command.MovementID<>'' then begin
        if not FProfessor.ExecuteMovement(Command.MovementID) then
          raise Exception.Create('Nao foi possivel executar a tag ['+Command.MovementID+']. Verifique os movimentos do avatar selecionado.');
      end
      else FProfessor.ExecuteCommand(Command.Command);
    except on E: Exception do begin
      if not Assigned(FSpeechJob) then begin
        FinishPresentation;SetEstado('Falha na apresentação: '+E.Message,False);Exit;
      end;
      FSpeechJob.ErrorText:=E.Message;FSpeechJob.Cancel;
    end;end;
    if not FYouTubeCommandPending then FSpeechJob.ConfirmAvatarCommand;
  end;
  if not FSpeechJob.Done then Exit;
  if FPresentationMode and (Length(FParkedPresentations)=0) and not FSpeechJob.Cancelled and FSpeechJob.Success then begin
    FProfessor.SetActivity(psIdle);
    try
      if FPresentationMedia.TimedPlaybackActive then begin
        if not FSpeechJob.Paused then lblStatus.Caption:='Reproduzindo midia... (P pausa; Esc cancela)';
        Exit;
      end;
    except on E: Exception do begin FSpeechJob.ErrorText:=E.Message;FSpeechJob.Cancel;end;end;
  end;
  if FResumePresentation then begin
    FreeAndNil(FSpeechJob);FResumePresentation:=False;ResumePresentation;Exit;
  end;
  if Length(FParkedPresentations)>0 then begin
    Err:=FSpeechJob.ErrorText;FreeAndNil(FSpeechJob);FAnsweringQuestion:=False;
    QuestionReady;if Err<>'' then lblStatus.Caption:=Err;Exit;
  end;
  Ok := FSpeechJob.Success;
  Err := FSpeechJob.ErrorText;
  if FSpeechJob.Cancelled and (Err='') then Err:='Apresentação cancelada';
  FreeAndNil(FSpeechJob);
  if FPresentationMode then FinishPresentation;
  SetEstado('Pronto para conversar', False);
  RetomarEscuta;
  if not Ok then begin FProfessor.ResetCommands;lblStatus.Caption := 'Falha na voz: '+Err;end;
end;

procedure Tfrmmain.btEnviarClick(Sender: TObject);
begin EnviarPergunta; end;

procedure Tfrmmain.edPerguntaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then begin Key := 0; EnviarPergunta; end;
end;

procedure Tfrmmain.btConfigClick(Sender: TObject);
var F: TfrmConfig;
begin
  if FAguardandoResposta or Assigned(FSpeechJob) or FVoiceInput.Busy then Exit;
  FConfigOpen:=True;
  FChromeSpeech.Stop;
  FContinuousListener.Stop;
  PararVideo;
  FProfessor.SetRenderingActive(False);
  F:=nil;
  try
    F := TfrmConfig.Create(Self);
    LoadProfessorSettings(F, FSetMain);
    F.IntegrationUI.Status.Caption:=FIntegrationStatus;
    F.OnExportConfig:=@ConfigExport;
    F.OnImportConfig:=@ConfigImport;
    if F.ShowModal = mrOk then
    begin
      SaveProfessorSettings(F, FSetMain);
      FSetMain.SalvaContexto(False);
      AplicarConfiguracao;
      ConfigureIntegration;
    end;
  finally FConfigOpen:=False;F.Free;FProfessor.SetRenderingActive(True);IniciarEscuta;IniciarVideo;end;
end;

procedure Tfrmmain.OnAgentStateChange(Sender: TObject; AState: TAgentState; const ADescription: string);
begin
  if FClosing then Exit;
  case AState of
    asPlanning: lblStatus.Caption := 'Analisando...';
    asExecutingStep: lblStatus.Caption := 'Processando...';
    asCallingTool: lblStatus.Caption := 'Executando...';
    asError: lblStatus.Caption := 'Erro no agente';
  end;
end;

procedure Tfrmmain.OnAgentComplete(Sender: TObject; const AResponseText, AProvider: string; ASuccess: Boolean);
var T, Annotated,Selected: string; Script: TAvatarScript;
begin
  if FClosing then Exit;
  Selected:='';
  if ASuccess then Selected:=FAssistantManager.SelectedPresentation;
  Annotated:=Trim(AResponseText);
  if Selected<>'' then begin
    SetEstado('Preparando apresentacao...',False);
    try
      ValidateRAGPlayback(Selected,FAssistantManager.SelectedPresentationDigest);
      StartPresentation(Selected);
    except on E: Exception do begin
      ASuccess:=False;Annotated:='Nao foi possivel iniciar a apresentacao: '+E.Message;
    end;end;
  end;
  Script:=ParseAvatarScript(Annotated);
  T := Trim(Script.PlainText);
  if T = '' then
    if ASuccess and (Script.CommandCount>0) then T:='(gesto do avatar)'
    else if ASuccess then T := '(resposta vazia)' else T := 'Não foi possível obter uma resposta.';
  if Assigned(FMemoryItem) then
  begin
    if not ASuccess then FMemoryItem.Erro := T;
    FMemoryMap.EndAgentStep(FMemoryItem, 'Nova fala analisada', 'Resposta produzida', 'responder', T, T);
    SalvarMemoria;
    FMemoryItem := nil;
  end;
  memResposta.Lines.Add('Professor: ' + T);
  FChat.AddMessage(T, False);
  if Length(FParkedPresentations)>0 then FQuestionMemo.Lines.Add('Assistente: '+T);
  FAIConnected := ASuccess;
  memResposta.Lines.Add('');
  SetEstado('Pronto para conversar', False);
  if ASuccess then begin
    if Selected='' then FalarResposta(Annotated)
    else SetEstado('Apresentando: '+ChangeFileExt(ExtractFileName(Selected),''),False);
  end else begin
    if Length(FParkedPresentations)>0 then begin FAnsweringQuestion:=False;QuestionReady;end
    else RetomarEscuta;
  end;
  if FIntegrationJobID<>'' then begin
    FIntegrationJobs.Complete(FIntegrationJobID,T,AProvider,ASuccess,FIntegrationCancelled);
    FIntegrationJobID:='';FIntegrationCancelled:=False;
  end;
  FCurrentUserText := '';
end;

procedure Tfrmmain.PararVideo;
begin
  FreeAndNil(FCamera);
  FreeAndNil(FKinect);
end;

procedure Tfrmmain.IniciarVideo;
var Status: string;
begin
  PararVideo;
  Status := 'Vídeo desativado';
  if FSetMain.VisionSource in [vsWebcam, vsBoth] then
  begin
    Status := 'Câmera: seleção ausente';
    if Trim(FSetMain.CameraDevice) <> '' then
      try
        FCamera := TWebcamVision.Create(Self);
        if FCamera.OpenDevice(FSetMain.CameraDevice, Self, nil) then Status := 'Câmera RGB ativa'
        else Status := 'Câmera indisponível: ' + FCamera.LastError;
      except
        on E: Exception do Status := 'Câmera: ' + E.Message; end;
  end;
  if FSetMain.VisionSource in [vsKinect, vsBoth] then
    try
      FKinect := TAIKinectSensor.Create(Self);
      FKinect.DeviceIndex := FSetMain.KinectDeviceIndex;
      FKinect.Backend := kbKinectSDK10;
      FKinect.KinectModel := kmXbox360;
      if (FKinect.DeviceIndex >= 0) and FKinect.Open then Status := Status + ' | Kinect conectado'
      else Status := Status + ' | Kinect indisponível';
    except on E: Exception do Status := Status + ' | Kinect: ' + E.Message; end;
  FDeviceStatus.Caption := Status;
  FDeviceStatus.Hint := Status;
  FDeviceStatus.ShowHint := True;
end;

function Tfrmmain.IntegrationBusy:Boolean;
begin Result:=FClosing or FConfigOpen or FDocumentDialogOpen or FAguardandoResposta or Assigned(FSpeechJob) or (Length(FParkedPresentations)>0) or FVoiceInput.Busy;end;

procedure Tfrmmain.ConfigureIntegration;
begin
  FreeAndNil(FIntegration);FIntegrationStatus:='Integração desativada.';
  if not FSetMain.Integration.Enabled then Exit;
  try
    FIntegration:=TAssistantIntegrationServer.Create(FSetMain.Integration);
    FIntegration.OnRequest:=@IntegrationRequest;FIntegration.Start;
    FIntegrationStatus:='Integração ativa: '+FSetMain.Integration.BindIP+':'+IntToStr(FSetMain.Integration.Port);
  except on E:Exception do begin FreeAndNil(FIntegration);FIntegrationStatus:='Integração não iniciada: '+E.Message;end;end;
end;

procedure Tfrmmain.IntegrationRequest(Sender:TObject;Request:TJSONObject;out Response:TJSONObject);
const Commands:array[0..7] of string=('','smile','neutral','applause','raise_right_hand','lower_right_hand','wave','walk');
var RequestAction,RequestText,ID:string;Data:TJSONData;Items:TJSONArray;O:TJSONObject;I:Integer;Command:TAvatarCommand;Movement:TMovementDefinition;
begin
  RequestAction:=IntegrationString(Request,'action');Response:=nil;
  if RequestAction='status' then begin
    Response:=IntegrationOK(TJSONObject.Create(['service','Assistente','busy',IntegrationBusy,
      'state',FProfessor.ActivityLabel,'profile',FSetMain.Avatar3DProfile,'speaking',Assigned(FSpeechJob)]));Exit;
  end;
  if RequestAction='get_job' then begin
    ID:=IntegrationString(Request,'id');Data:=FIntegrationJobs.Lookup(ID);
    if Data=nil then Response:=IntegrationError('not_found') else Response:=IntegrationOK(Data);Exit;
  end;
  if RequestAction='avatars' then begin
    Items:=TJSONArray.Create;
    for I:=0 to FCatalog.Count-1 do Items.Add(TJSONObject.Create(['id',FCatalog[I].ID,'name',FCatalog[I].Name]));
    Response:=IntegrationOK(Items);Exit;
  end;
  if FConfigOpen or FClosing then begin Response:=IntegrationError('busy');Exit;end;
  if RequestAction='cancel' then begin
    if FAguardandoResposta then begin FIntegrationCancelled:=True;FAssistantManager.CancelExecution;end;
    if Assigned(FSpeechJob) then FSpeechJob.Cancel;
    if FPresentationMode then FinishPresentation;
    FProfessor.ResetCommands;Response:=IntegrationOK(TJSONObject.Create(['accepted',True]));Exit;
  end;
  if not ((RequestAction='ask') or (RequestAction='speak') or (RequestAction='avatar') or (RequestAction='select_avatar')) then begin
    Response:=IntegrationError('unknown_action');Exit;
  end;
  if IntegrationBusy then begin Response:=IntegrationError('busy');Exit;end;
  if (RequestAction='ask') or (RequestAction='speak') then begin
    RequestText:=Trim(IntegrationString(Request,'text'));
    if (RequestText='') or (Length(RequestText)>8192) then begin Response:=IntegrationError('invalid_text');Exit;end;
    if RequestAction='speak' then begin
      if not FSetMain.AutoSpeak then begin Response:=IntegrationError('speech_disabled');Exit;end;
      FalarResposta(RequestText);
      if Assigned(FSpeechJob) then Response:=IntegrationOK(TJSONObject.Create(['accepted',True]))
      else Response:=IntegrationError('speech_unavailable');
      Exit;
    end;
    FIntegrationJobID:=FIntegrationJobs.BeginJob;FIntegrationCancelled:=False;ID:=FIntegrationJobID;
    ProcessarEntrada(RequestText);
    if not FAguardandoResposta then begin
      FIntegrationJobs.Complete(ID,'Não foi possível iniciar a pergunta.','',False,False);FIntegrationJobID:='';
    end;
    O:=TJSONObject.Create(['id',ID]);Response:=IntegrationOK(O);Exit;
  end;
  if RequestAction='select_avatar' then begin
    I:=FCatalog.IndexOfID(IntegrationString(Request,'id'));
    if I<0 then Response:=IntegrationError('not_found')
    else begin FProfileCombo.ItemIndex:=I;ProfileChange(nil);Response:=IntegrationOK(TJSONObject.Create(['id',FCatalog[I].ID]));end;
    Exit;
  end;
  ID:=IntegrationString(Request,'command');
  if FindMovement(ID,Movement) then begin
    if FProfessor.ExecuteMovement(Movement.ID) then Response:=IntegrationOK(TJSONObject.Create(['accepted',True]))
    else Response:=IntegrationError('unsupported_gesture');Exit;
  end;
  for Command:=Succ(Low(TAvatarCommand)) to High(TAvatarCommand) do
    if (ID=AvatarCommandName(Command)) or ((Ord(Command)<=High(Commands)) and (ID=Commands[Ord(Command)])) then begin
      if FProfessor.ExecuteCommand(Command) then Response:=IntegrationOK(TJSONObject.Create(['accepted',True]))
      else Response:=IntegrationError('unsupported_gesture');Exit;
    end;
  Response:=IntegrationError('invalid_command');
end;

end.

