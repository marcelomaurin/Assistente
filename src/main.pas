unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, LCLType,
  Buttons, ComCtrls, Menus, strutils, chatgpt, setmain, frmconfig,
  aivoiceprovider_types, aivoicesynthesizer, aivoicerecognizer, aiaudio, aiaudioplayback, aiavatartypes, aiavatar3d, aiinteractioncontext, aiconversationorchestrator, aipersonsession, aipresentation, aikinect_types, aikinectsensor, aikinectskeleton, aikinectperception, aikinectadapter, jarvis_api, agent_manager, project_manager;

type

  { Tfrmmain }

  Tfrmmain = class(TForm)
    { Modo Exposicao / Professor Virtual (Publico) }
    pnlRoot: TPanel;
    pnlHeader: TPanel;
    lblInstitution: TLabel;
    lblAppTitle: TLabel;
    pnlFooter: TPanel;
    lblProfessorStatus: TLabel;
    pnlMain: TPanel;
    pnlAvatarStage: TPanel;
    imgAvatarStage: TImage;
    pnlPresentationArea: TPanel;
    pnlProjectHeader: TPanel;
    lblProjectTitle: TLabel;
    lblTopicSubtitle: TLabel;
    pnlNarrativeContainer: TPanel;
    lblNarrative: TLabel;
    pnlResourceHolder: TPanel;
    imgResource: TImage;
    lblResourceCaption: TLabel;
    lblResourcePlaceholder: TLabel;

    { Modo Administrativo (Oculto) }
    pnlAdminRoot: TPanel;
    btVoltarExposicao: TBitBtn;
    pnlTop: TPanel;
    imgAvatar: TImage;
    pnlTopControls: TPanel;
    lblJarvisStatusBadge: TLabel;
    lblJarvisSub: TLabel;
    btIniciar: TBitBtn;
    btAbrirConfig: TBitBtn;
    btStatusResidencia: TButton;
    btClima: TButton;

    pnlQuickBar: TPanel;
    lblQuick: TLabel;
    btLuzSala: TButton;
    btIrrigacao: TButton;
    btAuditarSeguranca: TButton;

    pnlChat: TPanel;
    pnlHistoricoHeader: TPanel;
    lblHistorico: TLabel;
    btSpeaker: TBitBtn;
    btLimparChat: TButton;
    memHistorico: TMemo;

    pnlSidebar: TPanel;
    lblProjetosHeader: TLabel;
    lstProjetos: TListBox;
    lblMemoriaHeader: TLabel;
    memProjetoInfo: TMemo;

    pnlPergunta: TPanel;
    lblPergunta: TLabel;
    memPergunta: TMemo;
    btEnviar: TBitBtn;
    btMic: TBitBtn;
    btAnexar: TBitBtn;
    btParar: TBitBtn;
    OpenDialogFiles: TOpenDialog;

    tmrCheckOnline: TTimer;
    trayIcon: TTrayIcon;
    pmTray: TPopupMenu;
    miAbrir: TMenuItem;
    miStatus: TMenuItem;
    miLuzSala: TMenuItem;
    miSep1: TMenuItem;
    miConfig: TMenuItem;
    miSep2: TMenuItem;
    miSair: TMenuItem;

    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure pnlHeaderDblClick(Sender: TObject);
    procedure btVoltarExposicaoClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure btIniciarClick(Sender: TObject);
    procedure btAbrirConfigClick(Sender: TObject);
    procedure btEnviarClick(Sender: TObject);
    procedure btMicClick(Sender: TObject);
    procedure btSpeakerClick(Sender: TObject);
    procedure btLimparChatClick(Sender: TObject);
    procedure btStatusResidenciaClick(Sender: TObject);
    procedure btClimaClick(Sender: TObject);
    procedure btLuzSalaClick(Sender: TObject);
    procedure btIrrigacaoClick(Sender: TObject);
    procedure btAuditarSegurancaClick(Sender: TObject);
    procedure tmrCheckOnlineTimer(Sender: TObject);
    procedure trayIconClick(Sender: TObject);
    procedure miAbrirClick(Sender: TObject);
    procedure miSairClick(Sender: TObject);
    procedure memPerguntaKeyPress(Sender: TObject; var Key: char);
    procedure lstProjetosSelectionChange(Sender: TObject; User: Boolean);
    procedure btAnexarClick(Sender: TObject);
    procedure btPararClick(Sender: TObject);
  private
    FAguardandoResposta: Boolean;
    FVoiceActive: Boolean;
    FAudioInput: TAIAudioInput;
    FAudioPlayer: TAIAudioPlayer;
    FListeningWavFile: string;
    FVoiceSynth: TAIVoiceSynthesizer;
    FAvatar3D: TAIAvatar3D;
    FConversationOrchestrator: TAIConversationOrchestrator;
    FPresentationAgent: TAIPresentationAgent;
    FVoiceRecog: TAIVoiceRecognizer;
    FJarvisClient: TJarvisAPIClient;
    FAssistantManager: TAssistantManager;
    FProjectManager: TAssistantProjectManager;

    { Percepcao Kinect v1 }
    FKinectSensor: TAIKinectSensor;
    FKinectSkeleton: TAIKinectSkeleton;
    FKinectPerception: TAIKinectPerception;
    FKinectAdapter: TAIKinectInteractionAdapter;

    { Controles da Interface de Exposicao / Professor Virtual }
    pnlExposicao: TPanel;
    pnlRecursoMoldura: TPanel;
    pnlExposicaoFooter: TPanel;
    imgRecursoExposicao: TImage;
    lblFatecHeader: TLabel;
    lblNarrativaExposicao: TLabel;
    lblRecursoDescricao: TLabel;
    btExposicaoContinuar: TBitBtn;
    btExposicaoProximo: TBitBtn;
    btAdminToggle: TBitBtn;

    procedure InitExposicaoUI;
    procedure UpdateExhibitionLayout;
    procedure EnterExhibitionMode;
    procedure EnterAdminMode;
    procedure ExitAdminMode;
    procedure ShowPresentationResource(const ATitle, ASubtitle, AImagePath, ANarrative: string);
    procedure ClearPresentationResource;
    procedure SetProfessorState(const AState: string);
    procedure SetNarrativeText(const AText: string);
    procedure OnVoiceSpeechStart(Sender: TObject);
    procedure OnVoiceSpeechEnd(Sender: TObject);
    procedure btExposicaoContinuarClick(Sender: TObject);
    procedure btExposicaoProximoClick(Sender: TObject);
    procedure btAdminToggleClick(Sender: TObject);
    procedure OnPresentationResourceSelected(Sender: TObject; AResource: TPresentationResource);
    procedure OnPresentationNarrativeSpoken(Sender: TObject; const ANarrative, AEmotion, AGesture: string);
    procedure OnPresentationProjectChanged(Sender: TObject; APackage: TPresentationPackage);

    procedure InitKinect;
    procedure ShutdownKinect;
    procedure OnKinectPersonEntered(Sender: TObject; ATrackingID: Integer; ADistance: Single; const APosition: string);
    procedure OnKinectPersonLeft(Sender: TObject; ATrackingID: Integer);
    procedure OnKinectDeicticResolved(Sender: TObject; const AGesture, ATarget: string);
    procedure OnKinectGestureDetected(Sender: TObject; const AGestureName, ATargetObject: string);

    procedure OnSpeechInterruption(Sender: TObject);
    procedure OnContextProjectChanged(Sender: TObject; const AOldProject, ANewProject: string);
    procedure OnActivePersonChanged(Sender: TObject; const AOldPersonID, ANewPersonID: string);
    procedure AtualizaProjetosUI();
    procedure OnAgentStateChange(Sender: TObject; AState: TAgentState; const ADescription: string);
    procedure OnAgentStepUpdate(Sender: TObject; AStepIndex, ATotalSteps: Integer; const AStepTitle, AStatus: string);
    procedure OnAgentToolLog(Sender: TObject; const AToolName, AArgsJSON, AResultJSON: string; ASuccess: Boolean);
    procedure OnAgentComplete(Sender: TObject; const AResponseText, AProvider: string; ASuccess: Boolean);
    procedure AplicaConfiguracoes();
    procedure VoiceRecognized(Sender: TObject; const AText: string);
    procedure AtualizaEstadoSpeaker();
    procedure CarregaIcones();
  public
    procedure CheckJarvisOnline();
    procedure FalaTexto(const ATexto: string);
    procedure AdicionaMensagemHistorico(const Remetente, Mensagem: string);
    procedure ExecutaComandoJarvis(const ACmd: string);
    property VoiceSynth: TAIVoiceSynthesizer read FVoiceSynth;
    property VoiceRecog: TAIVoiceRecognizer read FVoiceRecog;
    property AudioInput: TAIAudioInput read FAudioInput;
    property AudioPlayer: TAIAudioPlayer read FAudioPlayer;
    property VoiceActive: Boolean read FVoiceActive;
    property AssistantManager: TAssistantManager read FAssistantManager;
  end;

  { TAskJarvisThread
    Envia comando via API v1 em background sem travar a interface do Windows }
  TAskJarvisThread = class(TThread)
  private
    FCmd: string;
    FModoIA: string;
    FURL: string;
    FKey: string;
    FSucesso: Boolean;
    FResposta: string;
    FProvedor: string;
    FAcao: string;
    FAudioURL: string;
    procedure EntregaResposta();
  protected
    procedure Execute(); override;
  public
    constructor Create(const ACmd, AModoIA, AURL, AKey: string);
  end;

  { TAskChatGPTThread
    Compatibilidade com a engine legada CHATGPT }
  TAskChatGPTThread = class(TThread)
  private
    FPergunta: string;
    FResposta: string;
    FSucesso: Boolean;
    procedure EntregaResposta();
  protected
    procedure Execute(); override;
  public
    constructor Create(const APergunta: string);
  end;

var
  frmmain: Tfrmmain;
  CHATGPT1: TCHATGPT;

implementation

{$R *.lfm}

{ TAskJarvisThread }

constructor TAskJarvisThread.Create(const ACmd, AModoIA, AURL, AKey: string);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FCmd := ACmd;
  FModoIA := AModoIA;
  FURL := AURL;
  FKey := AKey;
  Start;
end;

procedure TAskJarvisThread.Execute();
var
  Client: TJarvisAPIClient;
begin
  Client := TJarvisAPIClient.Create(nil);
  try
    Client.BaseURL := FURL;
    Client.APIKey := FKey;
    Client.Timeout := 35;
    FSucesso := Client.EnviarComando(FCmd, FModoIA, FResposta, FProvedor, FAcao, FAudioURL);
  finally
    Client.Free;
  end;
  Synchronize(@EntregaResposta);
end;

procedure TAskJarvisThread.EntregaResposta();
var
  TextoFinal: string;
begin
  if Assigned(frmmain) then
  begin
    TextoFinal := FResposta;
    if Trim(FAcao) <> '' then
      TextoFinal := TextoFinal + sLineBreak + '⚡ Ação executada: ' + FAcao;

    frmmain.AdicionaMensagemHistorico('JARVIS (' + FProvedor + ')', TextoFinal);

    if (FSetMain <> nil) and FSetMain.AutoSpeak then
      frmmain.FalaTexto(FResposta);

    frmmain.FAguardandoResposta := False;
    frmmain.btEnviar.Enabled := True;
  end;
end;

{ TAskChatGPTThread }

constructor TAskChatGPTThread.Create(const APergunta: string);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FPergunta := APergunta;
  Start;
end;

procedure TAskChatGPTThread.Execute();
begin
  if Assigned(CHATGPT1) then
  begin
    FSucesso := CHATGPT1.SendQuestion(FPergunta);
    if FSucesso then
      FResposta := CHATGPT1.Response
    else
    begin
      FResposta := 'Desculpe, não consegui obter uma resposta.';
      if CHATGPT1.LastError <> '' then
        FResposta := FResposta + ' (' + CHATGPT1.LastError + ')';
    end;
  end;
  Synchronize(@EntregaResposta);
end;

procedure TAskChatGPTThread.EntregaResposta();
begin
  if Assigned(frmmain) then
  begin
    frmmain.AdicionaMensagemHistorico('ChatGPT / IA', FResposta);
    if (FSetMain <> nil) and FSetMain.AutoSpeak then
      frmmain.FalaTexto(FResposta);
    frmmain.FAguardandoResposta := False;
    frmmain.btEnviar.Enabled := True;
  end;
end;

{ Tfrmmain }


{ Kinect Perception & Multi-Modal Adapter Implementation }

procedure Tfrmmain.InitKinect;
var
  DevList: TStringList;
begin
  FKinectSensor := TAIKinectSensor.Create(Self);
  FKinectSkeleton := TAIKinectSkeleton.Create(Self);
  FKinectPerception := TAIKinectPerception.Create(Self);
  FKinectAdapter := TAIKinectInteractionAdapter.Create(Self);

  FKinectSkeleton.Sensor := FKinectSensor;
  FKinectPerception.Sensor := FKinectSensor;
  FKinectPerception.Skeleton := FKinectSkeleton;

  if FSetMain <> nil then
  begin
    FKinectPerception.MinDistanceMeters := FSetMain.KinectMinDistance;
    FKinectPerception.MaxDistanceMeters := FSetMain.KinectMaxDistance;
  end;

  FKinectAdapter.Perception := FKinectPerception;
  FKinectAdapter.Orchestrator := FConversationOrchestrator;

  if FSetMain <> nil then
  begin
    FKinectAdapter.TargetLeft := FSetMain.KinectTargetLeft;
    FKinectAdapter.TargetRight := FSetMain.KinectTargetRight;
    FKinectAdapter.TargetCenter := FSetMain.KinectTargetCenter;
  end;

  FKinectAdapter.OnPersonEntered := @OnKinectPersonEntered;
  FKinectAdapter.OnPersonLeft := @OnKinectPersonLeft;
  FKinectAdapter.OnDeicticTargetResolved := @OnKinectDeicticResolved;

  if FConversationOrchestrator <> nil then
    FConversationOrchestrator.OnGestureDetected := @OnKinectGestureDetected;

  // Deteccao nao-bloqueante de hardware fisico
  DevList := FKinectSensor.ListDevices;
  try
    if (DevList.Count > 0) and ((FSetMain = nil) or FSetMain.KinectEnabled) then
    begin
      FKinectSensor.DeviceIndex := 0;
      FKinectSensor.Backend := kbKinectSDK10;
      FKinectSensor.KinectModel := kmXbox360;
      if FKinectSensor.Open then
      begin
        if FSetMain <> nil then
          FKinectSkeleton.SeatedMode := FSetMain.KinectSeatedMode;
        FKinectSkeleton.Active := True;
        AdicionaMensagemHistorico('Sensor Visual', 'Kinect v1 online: sensor primario de presenca e gestos ativado.');
      end
      else
        AdicionaMensagemHistorico('Sensor Visual', 'Falha ao conectar Kinect v1: ' + FKinectSensor.LastError);
    end
    else
    begin
      AdicionaMensagemHistorico('Sensor Visual', 'Kinect v1 offline (sem hardware fisico). Percepcao em modo prontidao/simulacao.');
    end;
  finally
    DevList.Free;
  end;
end;

procedure Tfrmmain.ShutdownKinect;
begin
  if Assigned(FKinectSkeleton) then
    FKinectSkeleton.Active := False;
  if Assigned(FKinectSensor) and FKinectSensor.IsConnected then
    FKinectSensor.Close;
end;

procedure Tfrmmain.OnKinectPersonEntered(Sender: TObject; ATrackingID: Integer;
  ADistance: Single; const APosition: string);
begin
  AdicionaMensagemHistorico('Sensor Visual', Format('Visitante aproximou-se (ID #%d, %.2fm, %s).', [ATrackingID, ADistance, APosition]));

  // Orientacao do Olhar (Gaze) e Saudacao do Avatar 3D
  if FAvatar3D <> nil then
  begin
    if APosition = 'left' then
      FAvatar3D.LookAt(ltLeft)
    else if APosition = 'right' then
      FAvatar3D.LookAt(ltRight)
    else
    begin
      FAvatar3D.LookAt(ltCenter);
      FAvatar3D.PlayGesture(agWave, 2.0);
    end;
  end;

  // Inicia ou resume apresentacao autonoma caso o professor esteja ocioso
  if (FPresentationAgent <> nil) and (FPresentationAgent.State = psIdle) then
  begin
    FPresentationAgent.StartPresentation(IntToStr(ATrackingID), 'Visitante');
  end;
end;

procedure Tfrmmain.OnKinectPersonLeft(Sender: TObject; ATrackingID: Integer);
begin
  AdicionaMensagemHistorico('Sensor Visual', Format('Visitante #%d afastou-se da zona de apresentacao.', [ATrackingID]));

  if FAvatar3D <> nil then
  begin
    FAvatar3D.LookAt(ltCenter);
    FAvatar3D.SetState(avIdle);
  end;
end;

procedure Tfrmmain.OnKinectDeicticResolved(Sender: TObject; const AGesture, ATarget: string);
begin
  AdicionaMensagemHistorico('Gesto Fisico', Format('Visitante apontou para %s (%s).', [ATarget, AGesture]));

  // Avatar confirma o apontamento e orienta o olhar para o projeto alvo
  if FAvatar3D <> nil then
  begin
    if AGesture = 'point_left' then
      FAvatar3D.LookAt(ltLeft)
    else if AGesture = 'point_right' then
      FAvatar3D.LookAt(ltRight)
    else
      FAvatar3D.LookAt(ltCenter);

    FAvatar3D.PlayGesture(agPoint, 2.0);
  end;

  // Apresentacao autonoma migra diretamente para o projeto apontado
  if FPresentationAgent <> nil then
  begin
    FPresentationAgent.StartPresentation('visitante', 'Visitante', ATarget);
  end;
end;

procedure Tfrmmain.OnKinectGestureDetected(Sender: TObject; const AGestureName, ATargetObject: string);
begin
  // Reconhecimento de mao levantada (Aluno quer fazer pergunta)
  if (AGestureName = 'raise_hand') or (AGestureName = 'raise_right_hand') or (AGestureName = 'raise_left_hand') then
  begin
    AdicionaMensagemHistorico('Percepcao', 'Visitante levantou a mao para perguntar.');
    if FPresentationAgent <> nil then
    begin
      FPresentationAgent.PausePresentation;
    end;
    if FAvatar3D <> nil then
    begin
      FAvatar3D.PlayGesture(agNod, 1.5);
    end;
    if (FSetMain <> nil) and FSetMain.AutoSpeak then
      FalaTexto('Pode fazer sua pergunta! Estou ouvindo.');
  end;
end;

procedure Tfrmmain.OnSpeechInterruption(Sender: TObject);
begin
  if FVoiceSynth <> nil then
    FVoiceSynth.Stop;
  if FAvatar3D <> nil then
  begin
    FAvatar3D.CancelGesture;
    FAvatar3D.SetState(avListening);
  end;
  AdicionaMensagemHistorico('Sistema', 'Interrupcao de fala detectada (Barge-In).');
end;

procedure Tfrmmain.OnContextProjectChanged(Sender: TObject; const AOldProject, ANewProject: string);
begin
  if FAssistantManager <> nil then
    FAssistantManager.ActiveProject := ANewProject;
  lblJarvisSub.Caption := 'Projeto em foco: ' + ANewProject;
end;


procedure Tfrmmain.FormResize(Sender: TObject);
begin
  UpdateExhibitionLayout;
end;

procedure Tfrmmain.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  // Atalho secreto Ctrl+Alt+A para alternar entre Exposição e Administração
  if (ssCtrl in Shift) and (ssAlt in Shift) and ((Key = VK_A) or (Key = ord('A')) or (Key = ord('a'))) then
  begin
    if Assigned(pnlAdminRoot) and pnlAdminRoot.Visible then
      ExitAdminMode
    else
      EnterAdminMode;
    Key := 0;
  end;
end;

procedure Tfrmmain.pnlHeaderDblClick(Sender: TObject);
begin
  if Assigned(pnlAdminRoot) and pnlAdminRoot.Visible then
    ExitAdminMode
  else
    EnterAdminMode;
end;

procedure Tfrmmain.btVoltarExposicaoClick(Sender: TObject);
begin
  ExitAdminMode;
end;

procedure Tfrmmain.UpdateExhibitionLayout;
var
  AvWidth: Integer;
begin
  if not Assigned(pnlMain) or not Assigned(pnlAvatarStage) then Exit;
  // Avatar ocupa ~38% da tela, conteúdo ocupa ~62%
  AvWidth := Round(pnlMain.ClientWidth * 0.38);
  if AvWidth < 280 then AvWidth := 280;
  if AvWidth > 620 then AvWidth := 620;
  pnlAvatarStage.Width := AvWidth;
end;

procedure Tfrmmain.EnterExhibitionMode;
begin
  if Assigned(pnlAdminRoot) then
    pnlAdminRoot.Visible := False;
  if Assigned(pnlRoot) then
    pnlRoot.Visible := True;
  UpdateExhibitionLayout;
  SetProfessorState('idle');
end;

procedure Tfrmmain.EnterAdminMode;
begin
  if Assigned(pnlRoot) then
    pnlRoot.Visible := False;
  if Assigned(pnlAdminRoot) then
    pnlAdminRoot.Visible := True;
end;

procedure Tfrmmain.ExitAdminMode;
begin
  EnterExhibitionMode;
end;

procedure Tfrmmain.SetNarrativeText(const AText: string);
var
  CleanText: string;
begin
  CleanText := Trim(AText);
  if not Assigned(lblNarrative) then Exit;
  if CleanText = '' then
    lblNarrative.Caption := ''
  else
  begin
    if Length(CleanText) > 240 then
      CleanText := Copy(CleanText, 1, 237) + '...';
    lblNarrative.Caption := '"' + CleanText + '"';
  end;
end;

procedure Tfrmmain.SetProfessorState(const AState: string);
var
  S: string;
begin
  if not Assigned(lblProfessorStatus) then Exit;
  S := LowerCase(Trim(AState));
  if (S = 'listening') or (S = 'ouvir') or (S = 'ouvindo') then
  begin
    lblProfessorStatus.Font.Color := $0000FF99;
    lblProfessorStatus.Caption := '🎤 Ouvindo o visitante...';
    if FAvatar3D <> nil then
      FAvatar3D.SetState(avListening);
  end
  else if (S = 'thinking') or (S = 'pensando') then
  begin
    lblProfessorStatus.Font.Color := $00FFC040;
    lblProfessorStatus.Caption := '🧠 Pensando na resposta...';
    if FAvatar3D <> nil then
      FAvatar3D.SetState(avThinking);
  end
  else if (S = 'presenting') or (S = 'apresentando') or (S = 'speaking') or (S = 'falando') then
  begin
    lblProfessorStatus.Font.Color := $0000D4FF;
    lblProfessorStatus.Caption := '🗣️ Apresentando conteúdo...';
    if FAvatar3D <> nil then
      FAvatar3D.SetState(avSpeaking);
  end
  else if (S = 'greeting') or (S = 'saudacao') then
  begin
    lblProfessorStatus.Font.Color := $00FFAA00;
    lblProfessorStatus.Caption := '👋 Boas-vindas ao visitante!';
    if FAvatar3D <> nil then
    begin
      FAvatar3D.SetState(avActing);
      FAvatar3D.PlayGesture(agWave, 2.0);
    end;
  end
  else if (S = 'error') or (S = 'erro') then
  begin
    lblProfessorStatus.Font.Color := $005050FF;
    lblProfessorStatus.Caption := '⚠️ Aguardando interação...';
  end
  else
  begin
    lblProfessorStatus.Font.Color := $0000FF99;
    lblProfessorStatus.Caption := '● Pronto para conversar';
    if FAvatar3D <> nil then
      FAvatar3D.SetState(avIdle);
  end;
end;

procedure Tfrmmain.ShowPresentationResource(const ATitle, ASubtitle, AImagePath, ANarrative: string);
begin
  if Assigned(lblProjectTitle) and (Trim(ATitle) <> '') then
  begin
    lblProjectTitle.Caption := UpperCase(Trim(ATitle));
    lblProjectTitle.Visible := True;
  end;
  if Assigned(lblTopicSubtitle) and (Trim(ASubtitle) <> '') then
  begin
    lblTopicSubtitle.Caption := Trim(ASubtitle);
    lblTopicSubtitle.Visible := True;
  end;
  if Trim(ANarrative) <> '' then
    SetNarrativeText(ANarrative);

  if Assigned(imgResource) and (Trim(AImagePath) <> '') and FileExists(AImagePath) then
  begin
    try
      imgResource.Picture.LoadFromFile(AImagePath);
      imgResource.Visible := True;
      if Assigned(lblResourcePlaceholder) then
        lblResourcePlaceholder.Visible := False;
      if Assigned(lblResourceCaption) then
      begin
        lblResourceCaption.Caption := Trim(ATitle) + ' - ' + Trim(ASubtitle);
        lblResourceCaption.Visible := True;
      end;
    except
      imgResource.Visible := False;
      if Assigned(lblResourcePlaceholder) then
        lblResourcePlaceholder.Visible := True;
      if Assigned(lblResourceCaption) then
        lblResourceCaption.Visible := False;
    end;
  end
  else
  begin
    if Assigned(imgResource) then
      imgResource.Visible := False;
    if Assigned(lblResourcePlaceholder) then
      lblResourcePlaceholder.Visible := True;
    if Assigned(lblResourceCaption) then
      lblResourceCaption.Visible := False;
  end;
end;

procedure Tfrmmain.ClearPresentationResource;
begin
  if Assigned(imgResource) then
  begin
    imgResource.Picture.Clear;
    imgResource.Visible := False;
  end;
  if Assigned(lblResourcePlaceholder) then
    lblResourcePlaceholder.Visible := True;
  if Assigned(lblResourceCaption) then
  begin
    lblResourceCaption.Caption := '';
    lblResourceCaption.Visible := False;
  end;
  if Assigned(lblProjectTitle) then
    lblProjectTitle.Caption := 'PROFESSOR VIRTUAL';
  if Assigned(lblTopicSubtitle) then
    lblTopicSubtitle.Caption := 'Projetos desenvolvidos na FATEC Ribeirão Preto';
  SetNarrativeText('Aproxime-se para conhecer os projetos desenvolvidos pelos nossos pesquisadores...');
end;

procedure Tfrmmain.OnVoiceSpeechStart(Sender: TObject);
begin
  if FAvatar3D <> nil then
    FAvatar3D.SetState(avSpeaking);
  SetProfessorState('presenting');
end;

procedure Tfrmmain.OnVoiceSpeechEnd(Sender: TObject);
begin
  if FAvatar3D <> nil then
    FAvatar3D.SetState(avIdle);
  SetProfessorState('idle');
end;

procedure Tfrmmain.InitExposicaoUI;
begin
  // Estrutura declarada nativamente no form (pnlRoot)
  EnterExhibitionMode;
end;

procedure Tfrmmain.btExposicaoContinuarClick(Sender: TObject);
begin
  if FPresentationAgent <> nil then
  begin
    if FPresentationAgent.State = psAnsweringQuestion then
      FPresentationAgent.ResumePresentation
    else
      FPresentationAgent.ContinuePresentation;
  end;
end;

procedure Tfrmmain.btExposicaoProximoClick(Sender: TObject);
begin
  if FPresentationAgent <> nil then
    FPresentationAgent.SelectNextProject;
end;

procedure Tfrmmain.btAdminToggleClick(Sender: TObject);
begin
  pnlSidebar.Visible := not pnlSidebar.Visible;
  pnlQuickBar.Visible := pnlSidebar.Visible;
  if pnlSidebar.Visible then
    btAdminToggle.Caption := '✖ Fechar Admin'
  else
    btAdminToggle.Caption := '⚙ Admin / Logs';
end;

procedure Tfrmmain.OnPresentationResourceSelected(Sender: TObject; AResource: TPresentationResource);
var
  ImgFile: string;
begin
  if AResource = nil then Exit;
  if Assigned(lblRecursoDescricao) then
    lblRecursoDescricao.Caption := 'Recurso Selecionado: ' + AResource.Title + ' - ' + AResource.Description;

  ImgFile := AResource.FilePath;
  if not FileExists(ImgFile) then
    ImgFile := ExtractFilePath(Application.ExeName) + AResource.FilePath;
  if not FileExists(ImgFile) then
    ImgFile := ExtractFilePath(Application.ExeName) + 'img' + PathDelim + ExtractFileName(AResource.FilePath);
  if not FileExists(ImgFile) then
    ImgFile := 'D:\projetos\maurinsoft\Assistente\img\' + ExtractFileName(AResource.FilePath);

  ShowPresentationResource(AResource.Title, AResource.Description, ImgFile, '');
end;

procedure Tfrmmain.OnPresentationNarrativeSpoken(Sender: TObject; const ANarrative, AEmotion, AGesture: string);
begin
  SetNarrativeText(ANarrative);
  SetProfessorState('presenting');

  if lblNarrativaExposicao <> nil then
    lblNarrativaExposicao.Caption := '"' + ANarrative + '"';

  AdicionaMensagemHistorico('🎓 Professor Virtual', ANarrative);

  if FAvatar3D <> nil then
  begin
    if AEmotion = 'alegria' then
      FAvatar3D.SetEmotion(aeHappy, 1.0)
    else
      FAvatar3D.SetEmotion(aeNeutral, 1.0);

    if AGesture = 'agWave' then
      FAvatar3D.PlayGesture(agWave, 2.0)
    else if AGesture = 'agPoint' then
      FAvatar3D.PlayGesture(agPoint, 2.0)
    else if AGesture = 'agNod' then
      FAvatar3D.PlayGesture(agNod, 1.8)
    else
      FAvatar3D.PlayGesture(agExplain, 2.2);
  end;

  if (FSetMain <> nil) and FSetMain.AutoSpeak then
    FalaTexto(ANarrative);
end;

procedure Tfrmmain.OnPresentationProjectChanged(Sender: TObject; APackage: TPresentationPackage);
begin
  if APackage = nil then Exit;
  if Assigned(lblProjectTitle) then
  begin
    lblProjectTitle.Caption := 'PROJETO ' + UpperCase(APackage.ProjectCode);
    lblProjectTitle.Visible := True;
  end;
  if Assigned(lblTopicSubtitle) then
  begin
    lblTopicSubtitle.Caption := APackage.Title;
    lblTopicSubtitle.Visible := True;
  end;
  lblJarvisStatusBadge.Caption := '● EXPOSIÇÃO: ' + UpperCase(APackage.ProjectCode);
  lblJarvisSub.Caption := APackage.Title;
  if FAssistantManager <> nil then
    FAssistantManager.ActiveProject := APackage.ProjectCode;
end;

procedure Tfrmmain.OnActivePersonChanged(Sender: TObject; const AOldPersonID, ANewPersonID: string);
var
  S: TAIPersonSession;
begin
  if FConversationOrchestrator <> nil then
  begin
    S := FConversationOrchestrator.SessionManager.ActiveSession;
    if S <> nil then
    begin
      AdicionaMensagemHistorico('👤 Interlocutor', 'Sessão ativa: ' + S.Name + ' [ID: ' + S.PersonID + ']');
      if FPresentationAgent <> nil then
        FPresentationAgent.StartPresentation(S.PersonID, S.Name, S.CurrentProject);
    end;
  end;
end;

procedure Tfrmmain.FormCreate(Sender: TObject);
var
  ImgPath: string;
begin
  FAguardandoResposta := False;
  FVoiceActive := False;

  if FSetMain = nil then
    FSetMain := TSetMain.create();

  FJarvisClient := TJarvisAPIClient.Create(Self);

  // Inicializa componentes de áudio e voz da biblioteca CHATGPT
  FAudioInput := TAIAudioInput.Create(Self);
  FAudioPlayer := TAIAudioPlayer.Create(Self);
  FVoiceSynth := TAIVoiceSynthesizer.Create(Self);
  FVoiceSynth.OnSpeechStart := @OnVoiceSpeechStart;
  FVoiceSynth.OnSpeechEnd := @OnVoiceSpeechEnd;
  FVoiceRecog := TAIVoiceRecognizer.Create(Self);
  FVoiceRecog.OnRecognized := @VoiceRecognized;

  CHATGPT1 := TCHATGPT.Create(Self);

  FProjectManager := TAssistantProjectManager.Create(Self);

  FAssistantManager := TAssistantManager.Create(Self);
  FAssistantManager.JarvisClient := FJarvisClient;
  FAssistantManager.ActiveProject := FProjectManager.ActiveProject.Name;
  FAssistantManager.OnStateChange := @OnAgentStateChange;
  FAssistantManager.OnStepUpdate := @OnAgentStepUpdate;
  FAssistantManager.OnToolLog := @OnAgentToolLog;
  FAssistantManager.OnComplete := @OnAgentComplete;

  AtualizaProjetosUI();

  AplicaConfiguracoes();
  CarregaIcones();

  // Inicializa Orquestrador de Conversacao Continua e Barge-In
  FConversationOrchestrator := TAIConversationOrchestrator.Create(Self);
  if FAssistantManager <> nil then
    FConversationOrchestrator.Agent := FAssistantManager.Agent;
  FConversationOrchestrator.OnInterruption := @OnSpeechInterruption;
  FConversationOrchestrator.OnProjectChanged := @OnContextProjectChanged;
  FConversationOrchestrator.OnActivePersonChanged := @OnActivePersonChanged;

  FAvatar3D := TAIAvatar3D.Create(Self);
  FAvatar3D.VoiceSynthesizer := FVoiceSynth;
  if FSetMain <> nil then
  begin
    FAvatar3D.AutoIdle := FSetMain.Avatar3DAutoIdle;
    FAvatar3D.AutoBlink := FSetMain.Avatar3DAutoBlink;
    if Trim(FSetMain.Avatar3DModel) <> '' then
    begin
      if FileExists(FSetMain.Avatar3DModel) then
        FAvatar3D.LoadAvatar(FSetMain.Avatar3DModel);
    end;
  end;

  // Tenta carregar avatar se existir
  ImgPath := ExtractFilePath(Application.ExeName) + 'img' + PathDelim + 'robo8.gif';
  if not FileExists(ImgPath) then
    ImgPath := ExtractFilePath(Application.ExeName) + 'robo8.gif';
  if not FileExists(ImgPath) then
    ImgPath := ExtractFilePath(Application.ExeName) + 'img' + PathDelim + 'avatar.png';

  if FileExists(ImgPath) then
  begin
    try
      imgAvatar.Picture.LoadFromFile(ImgPath);
      if Assigned(imgAvatarStage) then
        imgAvatarStage.Picture.LoadFromFile(ImgPath);
    except
    end;
  end;
  EnterExhibitionMode;

  AdicionaMensagemHistorico('Sistema', 'JARVIS Desktop Client inicializado com sucesso no Windows.');
  CheckJarvisOnline();

  // Inicializa Interface de Exposicao do Professor Virtual
  InitExposicaoUI;
  FPresentationAgent := TAIPresentationAgent.Create(Self);
  FPresentationAgent.OnResourceSelected := @OnPresentationResourceSelected;
  FPresentationAgent.OnNarrativeSpoken := @OnPresentationNarrativeSpoken;
  FPresentationAgent.OnProjectChanged := @OnPresentationProjectChanged;

  // Inicia com layout limpo de exposicao (sem botoes manuais poluindo a tela)
  pnlSidebar.Visible := False;
  pnlQuickBar.Visible := False;

  // Inicia exposicao autonoma do primeiro projeto de destaque
  FPresentationAgent.StartPresentation('', 'Visitante');

  // Inicializa Percepcao Semantica Kinect v1
  InitKinect;
end;

procedure Tfrmmain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  ShutdownKinect;
  if (FSetMain <> nil) and FSetMain.MinimizeToTray and (CloseAction <> caFree) then
  begin
    CloseAction := caNone;
    Hide;
    trayIcon.Show;
    trayIcon.ShowBalloonHint;
  end;
end;

procedure Tfrmmain.CarregaIcones();
begin
  AtualizaEstadoSpeaker();
end;

procedure Tfrmmain.AtualizaEstadoSpeaker();
begin
  if (FSetMain <> nil) and FSetMain.AutoSpeak then
  begin
    btSpeaker.Caption := '🔊 Voz ON';
    btSpeaker.Font.Color := clGreen;
  end
  else
  begin
    btSpeaker.Caption := '🔇 Voz MUTE';
    btSpeaker.Font.Color := clGray;
  end;
end;

procedure Tfrmmain.AplicaConfiguracoes();
begin
  if FSetMain = nil then Exit;

  FJarvisClient.BaseURL := FSetMain.JarvisURL;
  FJarvisClient.APIKey := FSetMain.JarvisAPIKey;
  FJarvisClient.IAMode := FSetMain.JarvisIAMode;

  // ChatGPT Suite Legado
  CHATGPT1.TOKEN := FSetMain.CHATGPT;
  if (FSetMain.ChatGPTProvider >= 0) and (FSetMain.ChatGPTProvider <= Ord(High(TAIProvider))) then
    CHATGPT1.Provider := TAIProvider(FSetMain.ChatGPTProvider)
  else
    CHATGPT1.Provider := AIP_OPENAI;
  CHATGPT1.CustomModel := FSetMain.ChatGPTModel;
  CHATGPT1.URL := FSetMain.ChatGPTURL;

  if Assigned(FAssistantManager) and Assigned(FAssistantManager.ChatGPT) then
  begin
    FAssistantManager.ChatGPT.TOKEN := FSetMain.CHATGPT;
    if (FSetMain.ChatGPTProvider >= 0) and (FSetMain.ChatGPTProvider <= Ord(High(TAIProvider))) then
      FAssistantManager.ChatGPT.Provider := TAIProvider(FSetMain.ChatGPTProvider)
    else
      FAssistantManager.ChatGPT.Provider := AIP_OPENAI;
    FAssistantManager.ChatGPT.CustomModel := FSetMain.ChatGPTModel;
    FAssistantManager.ChatGPT.URL := FSetMain.ChatGPTURL;
  end;

  // Configurações do Capturador de Áudio (TAIAudioInput do CHATGPT)
  if Assigned(FAudioInput) then
  begin
    FAudioInput.InputSource := asMic;
    if FSetMain.AudioSampleRate > 0 then
      FAudioInput.SampleRate := FSetMain.AudioSampleRate
    else
      FAudioInput.SampleRate := 16000;
    if FSetMain.AudioChannels > 0 then
      FAudioInput.Channels := FSetMain.AudioChannels
    else
      FAudioInput.Channels := 1;
  end;

  // Configurações do Reconhecedor de Voz (TAIVoiceRecognizer do CHATGPT)
  if Assigned(FVoiceRecog) then
  begin
    case FSetMain.RecogEngine of
      0: FVoiceRecog.Engine := vreOpenAIWhisper;
      1: FVoiceRecog.Engine := vreSAPI;
      2: FVoiceRecog.Engine := vreSystemDefault;
    else
      FVoiceRecog.Engine := vreOpenAIWhisper;
    end;
    if Trim(FSetMain.RecogLanguage) <> '' then
      FVoiceRecog.Language := FSetMain.RecogLanguage
    else
      FVoiceRecog.Language := 'pt';
    FVoiceRecog.OpenAIToken := FSetMain.CHATGPT;
  end;

  // Configurações do Sintetizador de Voz (TAIVoiceSynthesizer do CHATGPT)
  if Assigned(FVoiceSynth) then
  begin
    case FSetMain.SynthEngine of
      0: FVoiceSynth.Engine := seSystemDefault;
      1: FVoiceSynth.Engine := seSAPI;
      2: FVoiceSynth.Engine := seEspeak;
      3: FVoiceSynth.Engine := seOpenAI;
    else
      FVoiceSynth.Engine := seSAPI;
    end;
    FVoiceSynth.VoiceName := FSetMain.SynthVoice;
    FVoiceSynth.Volume := FSetMain.SynthVolume;
    FVoiceSynth.Rate := FSetMain.SynthRate;
    FVoiceSynth.Asynchronous := FSetMain.SynthAsync;

    // Provedor Remoto Independente
    FVoiceSynth.Provider := TAIVoiceProvider(FSetMain.VoiceProvider);
    FVoiceSynth.APIToken := FSetMain.VoiceAPIToken;
    FVoiceSynth.Model := FSetMain.VoiceModel;
    FVoiceSynth.Endpoint := FSetMain.VoiceEndpoint;
    FVoiceSynth.RemoteVoice := FSetMain.VoiceRemoteVoice;
    FVoiceSynth.Language := FSetMain.VoiceLanguage;
    FVoiceSynth.OutputFormat := FSetMain.VoiceOutputFormat;
    FVoiceSynth.Speed := FSetMain.VoiceSpeed;
  end;

  AtualizaEstadoSpeaker();
end;

procedure Tfrmmain.CheckJarvisOnline();
var
  Msg: string;
begin
  if Trim(FSetMain.JarvisURL) = '' then
  begin
    lblJarvisStatusBadge.Caption := '● NÃO CONFIGURADO';
    lblJarvisStatusBadge.Font.Color := clGray;
    Exit;
  end;

  FJarvisClient.BaseURL := FSetMain.JarvisURL;
  FJarvisClient.APIKey := FSetMain.JarvisAPIKey;
  FJarvisClient.Timeout := 5;

  if FJarvisClient.TestarConexao(Msg) then
  begin
    if Pos('trycloudflare.com', LowerCase(FSetMain.JarvisURL)) > 0 then
      lblJarvisStatusBadge.Caption := '● ONLINE (Cloudflare Edge)'
    else
      lblJarvisStatusBadge.Caption := '● ONLINE (Rede Local)';
    lblJarvisStatusBadge.Font.Color := $0034D399; // Verde Esmeralda
  end
  else
  begin
    lblJarvisStatusBadge.Caption := '● OFFLINE / CONECTANDO...';
    lblJarvisStatusBadge.Font.Color := $004545EF; // Vermelho
  end;
end;

procedure Tfrmmain.FalaTexto(const ATexto: string);
var
  TextoLimpo: string;
begin
  if (FSetMain = nil) or (not FSetMain.AutoSpeak) then Exit;

  // Limpa possíveis tags
  TextoLimpo := Trim(ReplaceStr(ATexto, '[[CMD:', ''));
  if Assigned(FVoiceSynth) and (TextoLimpo <> '') then
  begin
    try
      if FConversationOrchestrator <> nil then
        FConversationOrchestrator.StartSpeaking;
            FVoiceSynth.Say(TextoLimpo);
    except
    end;
  end;
end;

procedure Tfrmmain.AdicionaMensagemHistorico(const Remetente, Mensagem: string);
begin
  if memHistorico <> nil then
  begin
    memHistorico.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Remetente + ':');
    memHistorico.Lines.Add(Mensagem);
    memHistorico.Lines.Add('');
    memHistorico.SelStart := Length(memHistorico.Text);
  end;
end;

procedure Tfrmmain.ExecutaComandoJarvis(const ACmd: string);
var
  ComandoTrim: string;
begin
  ComandoTrim := Trim(ACmd);
  if ComandoTrim = '' then Exit;

  if FAguardandoResposta then
  begin
    ShowMessage('Aguarde o processamento do comando anterior.');
    Exit;
  end;

  FAguardandoResposta := True;
  btEnviar.Enabled := False;
  AdicionaMensagemHistorico('Você', ComandoTrim);
  // Notifica orquestrador de conversacao e resolve pronomes continuos
  if FConversationOrchestrator <> nil then
  begin
    FConversationOrchestrator.NotifySpeechStart;
    FConversationOrchestrator.Context.ResolveReference(ComandoTrim);
    if (FAssistantManager <> nil) and (FConversationOrchestrator.Context.CurrentProject <> '') then
      FAssistantManager.ActiveProject := FConversationOrchestrator.Context.CurrentProject;
    if FConversationOrchestrator.SessionManager.ActiveSession <> nil then
      FConversationOrchestrator.SessionManager.ActiveSession.AddMessage('user', ComandoTrim);
  end;

  // Avatar entra em Listening e Thinking (Tarefa 119)
  if FAvatar3D <> nil then
  begin
    FAvatar3D.SetState(avListening);
    FAvatar3D.SetState(avThinking);
  end;

  // Se o Professor Virtual estiver em apresentacao, responde a duvida com desvio didatico
  if (FPresentationAgent <> nil) and (FPresentationAgent.State in [psPresentingConcept, psGreeting]) then
  begin
    FPresentationAgent.AnswerQuestion(ComandoTrim);
    FAguardandoResposta := False;
    btEnviar.Enabled := True;
    Exit;
  end;


  // Executa pelo Pipeline Inteligente do Agente (TAIAgent + TAIPlanner + Tools)
  if Assigned(FAssistantManager) then
  begin
    FAssistantManager.ProcessUserRequestAsync(ComandoTrim);
  end
  else if Trim(FSetMain.JarvisURL) <> '' then
  begin
    TAskJarvisThread.Create(ComandoTrim, FSetMain.JarvisIAMode, FSetMain.JarvisURL, FSetMain.JarvisAPIKey);
  end
  else
  begin
    TAskChatGPTThread.Create(ComandoTrim);
  end;
end;

procedure Tfrmmain.btEnviarClick(Sender: TObject);
var
  Cmd: string;
begin
  Cmd := memPergunta.Text;
  memPergunta.Clear;
  ExecutaComandoJarvis(Cmd);
end;

procedure Tfrmmain.memPerguntaKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    btEnviarClick(Sender);
  end;
end;

procedure Tfrmmain.btMicClick(Sender: TObject);
begin
  btIniciarClick(Sender);
end;

procedure Tfrmmain.btIniciarClick(Sender: TObject);
begin
  if FAudioInput = nil then Exit;

  if not FAudioInput.Recording then
  begin
    FListeningWavFile := IncludeTrailingPathDelimiter(GetTempDir) + 'assistente_mic.wav';
    if FileExists(FListeningWavFile) then
      DeleteFile(FListeningWavFile);

    if FAudioInput.StartRecord(FListeningWavFile) then
    begin
      btIniciar.Caption := '⏹ Parar';
      btMic.Caption := '⏹ Parar';
      if FAvatar3D <> nil then
        FAvatar3D.SetState(avListening);
      AdicionaMensagemHistorico('Voz', '🎤 Gravando microfone via TAIAudioInput... Fale agora e clique em Parar.');
    end
    else
    begin
      AdicionaMensagemHistorico('Erro', 'Falha ao iniciar microfone: ' + FAudioInput.LastError);
    end;
  end
  else
  begin
    FAudioInput.StopRecord;
    btIniciar.Caption := '🎤 Ouvir';
    btMic.Caption := '🎤 Falar';

    if FileExists(FListeningWavFile) then
    begin
      AdicionaMensagemHistorico('Voz', 'Transcrevendo áudio gravado via TAIVoiceRecognizer...');
      if (FVoiceRecog <> nil) and FVoiceRecog.Recognize(FListeningWavFile) then
      begin
        AdicionaMensagemHistorico('Você (Voz)', FVoiceRecog.RecognizedText);
        ExecutaComandoJarvis(FVoiceRecog.RecognizedText);
      end
      else if FVoiceRecog <> nil then
      begin
        AdicionaMensagemHistorico('Erro', 'Falha na transcrição: ' + FVoiceRecog.LastError);
      end;
    end
    else
    begin
      AdicionaMensagemHistorico('Erro', 'Arquivo de áudio não foi gerado pelo microfone.');
    end;
  end;
end;

procedure Tfrmmain.VoiceRecognized(Sender: TObject; const AText: string);
var
  Info: string;
begin
  Info := Trim(AText);
  if Info <> '' then
  begin
    AdicionaMensagemHistorico('Você (Voz)', Info);
    ExecutaComandoJarvis(Info);
  end;
end;

procedure Tfrmmain.btSpeakerClick(Sender: TObject);
begin
  if FSetMain <> nil then
  begin
    FSetMain.AutoSpeak := not FSetMain.AutoSpeak;
    FSetMain.SalvaContexto(False);
    AtualizaEstadoSpeaker();
  end;
end;

procedure Tfrmmain.btLimparChatClick(Sender: TObject);
begin
  memHistorico.Clear;
end;

procedure Tfrmmain.btStatusResidenciaClick(Sender: TObject);
var
  Resumo: string;
begin
  if FJarvisClient.ObterStatus(Resumo) then
  begin
    AdicionaMensagemHistorico('JARVIS Telemetria', Resumo);
    CheckJarvisOnline();
  end
  else
  begin
    AdicionaMensagemHistorico('Erro', 'Falha ao consultar status da residência: ' + FJarvisClient.LastError);
  end;
end;

procedure Tfrmmain.btClimaClick(Sender: TObject);
var
  Temp, Umidade, Descricao: string;
  VaiChover: Boolean;
  Msg: string;
begin
  if FJarvisClient.ObterClima(Temp, Umidade, Descricao, VaiChover) then
  begin
    Msg := Format('Meteorologia Atual: Temperatura de %s e Umidade de %s.' + sLineBreak + '%s',
      [Temp, Umidade, Descricao]);
    AdicionaMensagemHistorico('JARVIS Clima', Msg);
    if (FSetMain <> nil) and FSetMain.AutoSpeak then
      FalaTexto(Msg);
  end
  else
  begin
    AdicionaMensagemHistorico('Erro', 'Falha ao obter telemetria climática.');
  end;
end;

procedure Tfrmmain.btLuzSalaClick(Sender: TObject);
begin
  ExecutaComandoJarvis('Ligue a iluminação da sala');
end;

procedure Tfrmmain.btIrrigacaoClick(Sender: TObject);
begin
  ExecutaComandoJarvis('Ligue a irrigação da piscina');
end;

procedure Tfrmmain.btAuditarSegurancaClick(Sender: TObject);
begin
  ExecutaComandoJarvis('Qual o status de segurança e firewall?');
end;

procedure Tfrmmain.tmrCheckOnlineTimer(Sender: TObject);
begin
  CheckJarvisOnline();
end;

procedure Tfrmmain.trayIconClick(Sender: TObject);
begin
  miAbrirClick(Sender);
end;

procedure Tfrmmain.miAbrirClick(Sender: TObject);
begin
  Show;
  WindowState := wsNormal;
  BringToFront;
end;

procedure Tfrmmain.miSairClick(Sender: TObject);
begin
  if FSetMain <> nil then
    FSetMain.MinimizeToTray := False;
  Close;
end;

procedure Tfrmmain.btAbrirConfigClick(Sender: TObject);
var
  FormCfg: TfrmConfig;
begin
  FormCfg := TfrmConfig.Create(Self);
  try
    // Aba JARVIS
    FormCfg.edJarvisURL.Text := FSetMain.JarvisURL;
    FormCfg.edJarvisKey.Text := FSetMain.JarvisAPIKey;
    if FSetMain.JarvisIAMode = 'local_only' then
      FormCfg.cbJarvisMode.ItemIndex := 1
    else if FSetMain.JarvisIAMode = 'cloud_only' then
      FormCfg.cbJarvisMode.ItemIndex := 2
    else
      FormCfg.cbJarvisMode.ItemIndex := 0;
    FormCfg.chkMinimizeTray.Checked := FSetMain.MinimizeToTray;
    FormCfg.chkAutoSpeak.Checked := FSetMain.AutoSpeak;

    // Aba IA Legada
    FormCfg.cbProvider.ItemIndex := FSetMain.ChatGPTProvider;
    if (FormCfg.cbProvider.ItemIndex < 0) or (FormCfg.cbProvider.ItemIndex >= FormCfg.cbProvider.Items.Count) then
      FormCfg.cbProvider.ItemIndex := 0;
    FormCfg.CarregaModelosDoProvedor;
    if Trim(FSetMain.ChatGPTModel) <> '' then
      FormCfg.cbModel.Text := FSetMain.ChatGPTModel;
    FormCfg.edTokenGPT.Text := FSetMain.CHATGPT;
    FormCfg.edURL.Text := FSetMain.ChatGPTURL;

    // Aba Output Voice
    FormCfg.cbSynthEngine.ItemIndex := FSetMain.SynthEngine;
    if (FormCfg.cbSynthEngine.ItemIndex < 0) or (FormCfg.cbSynthEngine.ItemIndex >= FormCfg.cbSynthEngine.Items.Count) then
      FormCfg.cbSynthEngine.ItemIndex := 1;
    FormCfg.CarregaVozesDoSintetizador;
    if Trim(FSetMain.SynthVoice) <> '' then
      FormCfg.cbSynthVoice.Text := FSetMain.SynthVoice;
    FormCfg.tbSynthVolume.Position := FSetMain.SynthVolume;
    FormCfg.tbSynthVolumeChange(Self);
    FormCfg.tbSynthRate.Position := FSetMain.SynthRate;
    FormCfg.tbSynthRateChange(Self);
    FormCfg.chkSynthAsync.Checked := FSetMain.SynthAsync;

    // Aba Reconhecimento de Voz / Microfone (CHATGPT)
    FormCfg.cbRecogEngine.ItemIndex := FSetMain.RecogEngine;
    FormCfg.edRecogLanguage.Text := FSetMain.RecogLanguage;
    if FSetMain.AudioSampleRate = 44100 then
      FormCfg.cbAudioSampleRate.ItemIndex := 1
    else
      FormCfg.cbAudioSampleRate.ItemIndex := 0;
    if FSetMain.AudioChannels = 2 then
      FormCfg.cbAudioChannels.ItemIndex := 1
    else
      FormCfg.cbAudioChannels.ItemIndex := 0;

    // Aba Avatar 3D (Tarefa 123)
    FormCfg.edAvatarModel.Text := FSetMain.Avatar3DModel;
    FormCfg.chkAvatarAutoIdle.Checked := FSetMain.Avatar3DAutoIdle;
    FormCfg.chkAvatarAutoBlink.Checked := FSetMain.Avatar3DAutoBlink;
    FormCfg.chkAvatarLipSync.Checked := FSetMain.Avatar3DLipSync;
    FormCfg.cbAvatarQuality.Text := FSetMain.Avatar3DQuality;

    // Aba Banco
    FormCfg.edMyHost.Text := FSetMain.HostnameMy;
    FormCfg.edMyDb.Text := FSetMain.BancoMy;
    FormCfg.edMyUser.Text := FSetMain.UsernameMy;
    FormCfg.edMyPass.Text := FSetMain.PasswordMy;
    FormCfg.edPostHost.Text := FSetMain.HostnamePost;
    FormCfg.edPostDb.Text := FSetMain.BancoPOST;
    FormCfg.edPostUser.Text := FSetMain.UsernamePost;
    FormCfg.edPostPass.Text := FSetMain.PasswordPost;
    FormCfg.edPostSchema.Text := FSetMain.SchemaPost;

      // Aba Visao / Kinect
      FormCfg.chkKinectEnabled.Checked := FSetMain.KinectEnabled;
      FormCfg.chkKinectSeated.Checked := FSetMain.KinectSeatedMode;
      FormCfg.edKinectMinDist.Text := FloatToStr(FSetMain.KinectMinDistance);
      FormCfg.edKinectMaxDist.Text := FloatToStr(FSetMain.KinectMaxDistance);
      FormCfg.edKinectTargetLeft.Text := FSetMain.KinectTargetLeft;
      FormCfg.edKinectTargetRight.Text := FSetMain.KinectTargetRight;
      FormCfg.edKinectTargetCenter.Text := FSetMain.KinectTargetCenter;

    if FormCfg.ShowModal = mrOk then
    begin
      // Salva JARVIS
      FSetMain.JarvisURL := Trim(FormCfg.edJarvisURL.Text);
      FSetMain.JarvisAPIKey := Trim(FormCfg.edJarvisKey.Text);
      case FormCfg.cbJarvisMode.ItemIndex of
        1: FSetMain.JarvisIAMode := 'local_only';
        2: FSetMain.JarvisIAMode := 'cloud_only';
      else
        FSetMain.JarvisIAMode := 'auto';
      end;
      FSetMain.MinimizeToTray := FormCfg.chkMinimizeTray.Checked;
      FSetMain.AutoSpeak := FormCfg.chkAutoSpeak.Checked;

      // Salva IA Legada
      FSetMain.ChatGPTProvider := FormCfg.cbProvider.ItemIndex;
      FSetMain.ChatGPTModel := Trim(FormCfg.cbModel.Text);
      FSetMain.CHATGPT := Trim(FormCfg.edTokenGPT.Text);
      FSetMain.ChatGPTURL := Trim(FormCfg.edURL.Text);

      // Salva Voz
      FSetMain.SynthEngine := FormCfg.cbSynthEngine.ItemIndex;
      FSetMain.SynthVoice := Trim(FormCfg.cbSynthVoice.Text);
      FSetMain.SynthVolume := FormCfg.tbSynthVolume.Position;
      FSetMain.SynthRate := FormCfg.tbSynthRate.Position;
      FSetMain.SynthAsync := FormCfg.chkSynthAsync.Checked;

      // Salva Entrada de Voz / Audio (CHATGPT)
      FSetMain.RecogEngine := FormCfg.cbRecogEngine.ItemIndex;
      FSetMain.RecogLanguage := Trim(FormCfg.edRecogLanguage.Text);
      if FormCfg.cbAudioSampleRate.ItemIndex = 1 then
        FSetMain.AudioSampleRate := 44100
      else
        FSetMain.AudioSampleRate := 16000;
      if FormCfg.cbAudioChannels.ItemIndex = 1 then
        FSetMain.AudioChannels := 2
      else
        FSetMain.AudioChannels := 1;

      // Salva Banco
      FSetMain.HostnameMy := Trim(FormCfg.edMyHost.Text);
      FSetMain.BancoMy := Trim(FormCfg.edMyDb.Text);
      FSetMain.UsernameMy := Trim(FormCfg.edMyUser.Text);
      FSetMain.PasswordMy := Trim(FormCfg.edMyPass.Text);
      FSetMain.HostnamePost := Trim(FormCfg.edPostHost.Text);
      FSetMain.BancoPOST := Trim(FormCfg.edPostDb.Text);
      FSetMain.UsernamePost := Trim(FormCfg.edPostUser.Text);
      FSetMain.PasswordPost := Trim(FormCfg.edPostPass.Text);

      // Salva Visao / Kinect
      FSetMain.KinectEnabled := FormCfg.chkKinectEnabled.Checked;
      FSetMain.KinectSeatedMode := FormCfg.chkKinectSeated.Checked;
      FSetMain.KinectMinDistance := StrToFloatDef(Trim(FormCfg.edKinectMinDist.Text), 0.8);
      FSetMain.KinectMaxDistance := StrToFloatDef(Trim(FormCfg.edKinectMaxDist.Text), 2.5);
      FSetMain.KinectTargetLeft := Trim(FormCfg.edKinectTargetLeft.Text);
      FSetMain.KinectTargetRight := Trim(FormCfg.edKinectTargetRight.Text);
      FSetMain.KinectTargetCenter := Trim(FormCfg.edKinectTargetCenter.Text);
      FSetMain.SchemaPost := Trim(FormCfg.edPostSchema.Text);

      FSetMain.SalvaContexto(False);
      AplicaConfiguracoes();
      CheckJarvisOnline();
    end;
  finally
    FormCfg.Free;
  end;
end;


procedure Tfrmmain.OnAgentStateChange(Sender: TObject; AState: TAgentState; const ADescription: string);
begin
  case AState of
    asPlanning:
      lblJarvisSub.Caption := '● Agente Planejando Tarefa...';
    asExecutingStep:
      lblJarvisSub.Caption := '● Executando Etapa do Agente...';
    asCallingTool:
      lblJarvisSub.Caption := '● Acionando Tool Especializada...';
    asFinished:
      lblJarvisSub.Caption := '● Resposta Concluída';
    asCancelled:
      lblJarvisSub.Caption := '● Operação Cancelada';
    asError:
      lblJarvisSub.Caption := '● Erro na Execução';
  else
    lblJarvisSub.Caption := 'Central de Automação & Multi-IA';
  end;
end;

procedure Tfrmmain.OnAgentStepUpdate(Sender: TObject; AStepIndex, ATotalSteps: Integer; const AStepTitle, AStatus: string);
begin
  if AStatus = 'running' then
    AdicionaMensagemHistorico('⚡ Agente [Etapa ' + IntToStr(AStepIndex + 1) + '/' + IntToStr(ATotalSteps) + ']', '▶ ' + AStepTitle)
  else if AStatus = 'done' then
    AdicionaMensagemHistorico('✓ Agente [Etapa ' + IntToStr(AStepIndex + 1) + ']', 'Concluída: ' + AStepTitle);
end;

procedure Tfrmmain.OnAgentToolLog(Sender: TObject; const AToolName, AArgsJSON, AResultJSON: string; ASuccess: Boolean);
begin
  if ASuccess then
    AdicionaMensagemHistorico('🔧 Tool [' + AToolName + ']', AResultJSON)
  else
    AdicionaMensagemHistorico('⚠ Tool Falhou [' + AToolName + ']', AResultJSON);
end;

procedure Tfrmmain.OnAgentComplete(Sender: TObject; const AResponseText, AProvider: string; ASuccess: Boolean);
begin
  AdicionaMensagemHistorico('Assistente (' + AProvider + ')', AResponseText);
  // Registra no histórico da sessão da pessoa ativa
  if (FConversationOrchestrator <> nil) and (FConversationOrchestrator.SessionManager.ActiveSession <> nil) then
  begin
    FConversationOrchestrator.SessionManager.ActiveSession.AddMessage('assistant', AResponseText);
    if FConversationOrchestrator.Context.CurrentProject <> '' then
      FConversationOrchestrator.SessionManager.ActiveSession.CurrentProject := FConversationOrchestrator.Context.CurrentProject;
  end;

  // Aplica resposta estruturada ou texto no avatar (Tarefas 120 e 121)
  if FAvatar3D <> nil then
  begin
    if ASuccess then
      FAvatar3D.ApplyAgentResponse(AResponseText)
    else
      FAvatar3D.SetState(avError);
  end;


  if (FSetMain <> nil) and FSetMain.AutoSpeak then
    FalaTexto(AResponseText);

  FAguardandoResposta := False;
  btEnviar.Enabled := True;
  lblJarvisSub.Caption := 'Central de Automação & Multi-IA';
end;


procedure Tfrmmain.AtualizaProjetosUI;
var
  I: Integer;
  P: TProjectProfile;
begin
  if (FProjectManager = nil) or (lstProjetos = nil) then Exit;
  lstProjetos.Items.BeginUpdate;
  try
    lstProjetos.Items.Clear;
    for I := 0 to FProjectManager.ProjectCount - 1 do
    begin
      P := FProjectManager.GetProject(I);
      lstProjetos.Items.Add(P.Icon + ' ' + P.Name);
    end;
    if lstProjetos.Items.Count > 0 then
      lstProjetos.ItemIndex := 0;
  finally
    lstProjetos.Items.EndUpdate;
  end;

  if FProjectManager.ActiveProject <> nil then
    memProjetoInfo.Text := FProjectManager.ActiveProject.GetContextPrompt;
end;

procedure Tfrmmain.lstProjetosSelectionChange(Sender: TObject; User: Boolean);
var
  Idx: Integer;
  P: TProjectProfile;
begin
  Idx := lstProjetos.ItemIndex;
  if (Idx >= 0) and (FProjectManager <> nil) then
  begin
    P := FProjectManager.GetProject(Idx);
    if P <> nil then
    begin
      FProjectManager.SetActiveProjectByCode(P.Code);
      if Assigned(FAssistantManager) then
        FAssistantManager.ActiveProject := P.Name;
      memProjetoInfo.Text := P.GetContextPrompt;
      AdicionaMensagemHistorico('Sistema', '📁 Projeto alterado para [' + P.Icon + ' ' + P.Name + ']. Contexto ativado.');
    end;
  end;
end;

procedure Tfrmmain.btAnexarClick(Sender: TObject);
begin
  if OpenDialogFiles.Execute then
  begin
    if (FProjectManager <> nil) and (FProjectManager.ActiveProject <> nil) then
    begin
      FProjectManager.ActiveProject.AttachedFiles.Add(OpenDialogFiles.FileName);
      memProjetoInfo.Text := FProjectManager.ActiveProject.GetContextPrompt;
    end;
    AdicionaMensagemHistorico('📎 Anexo', 'Arquivo vinculado: ' + ExtractFileName(OpenDialogFiles.FileName));
    memPergunta.Text := 'Analise o arquivo anexado: ' + OpenDialogFiles.FileName;
  end;
end;

procedure Tfrmmain.btPararClick(Sender: TObject);
begin
  if (FAudioInput <> nil) and FAudioInput.Recording then
  begin
    FAudioInput.StopRecord;
    btIniciar.Caption := '🎤 Ouvir';
    btMic.Caption := '🎤 Falar';
    AdicionaMensagemHistorico('Sistema', 'Gravação de microfone interrompida.');
  end;

  if Assigned(FVoiceSynth) then
    FVoiceSynth.Stop;

  if Assigned(FAudioPlayer) and FAudioPlayer.Playing then
    FAudioPlayer.Stop;

  if Assigned(FAvatar3D) then
  begin
    FAvatar3D.SetState(avIdle);
    FAvatar3D.CancelGesture;
  end;

  if Assigned(FConversationOrchestrator) then
    FConversationOrchestrator.StopSpeaking;

  if Assigned(FAssistantManager) then
  begin
    FAssistantManager.CancelExecution;
    AdicionaMensagemHistorico('Sistema', '■ Interrupção solicitada pelo usuário.');
  end;

  FAguardandoResposta := False;
  btEnviar.Enabled := True;
  lblJarvisSub.Caption := '● Interrompido pelo usuário';
end;

end.
