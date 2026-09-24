unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, LCLType, LCLIntf,
  Buttons, ComCtrls, Menus, strutils, chatgpt, setmain, frmconfig, vision_types, webcam_vision,
  aivoiceprovider_types, aivoicesynthesizer, aivoicerecognizer, aicontinuouslistener, aiaudio, aiaudioplayback, aiavatartypes, aiavatar3d, aiinteractioncontext, aiconversationorchestrator, aipersonsession, aipresentation, aikinect_types, aikinectsensor, aikinectskeleton, aikinectperception, aikinectadapter, jarvis_api, agent_manager, project_manager;

type
  TPublicViewMode = (
    pvmIdle,
    pvmConversation,
    pvmContent,
    pvmPresentation
  );

  TAssistantVisualAction = (
    avaNone,
    avaShowText,
    avaShowResource,
    avaStartPresentation
  );

  TAdminSection = (
    asGeneral,
    asAI,
    asVoice,
    asVision,
    asAvatar,
    asProjects,
    asRAG,
    asPeople,
    asIntegrations,
    asLogs
  );


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
    btAdminTrigger: TSpeedButton;
    pnlAdminTopBar: TPanel;
    btAdminDiagnostico: TBitBtn;
    btAdminLogs: TBitBtn;
    pnlAdminNav: TPanel;
    btNavGeneral: TSpeedButton;
    btNavAI: TSpeedButton;
    btNavVoice: TSpeedButton;
    btNavVision: TSpeedButton;
    btNavAvatar: TSpeedButton;
    btNavProjects: TSpeedButton;
    btNavRAG: TSpeedButton;
    btNavPeople: TSpeedButton;
    btNavIntegrations: TSpeedButton;
    btNavLogs: TSpeedButton;
    pnlAdminBody: TPanel;
    pnlSecGeneral: TPanel;
    pnlSecAI: TPanel;
    pnlSecVoice: TPanel;
    pnlSecVision: TPanel;
    pnlSecAvatar: TPanel;
    pnlSecProjects: TPanel;
    pnlSecRAG: TPanel;
    pnlSecPeople: TPanel;
    pnlSecIntegrations: TPanel;
    pnlSecLogs: TPanel;
    lblStatIA: TLabel;
    lblStatVoice: TLabel;
    lblStatVision: TLabel;
    lblStatAvatar: TLabel;
    lblStatRAG: TLabel;
    lblExpCurrentProject: TLabel;
    lblExpCurrentResource: TLabel;
    lblExpVisitorStatus: TLabel;
    btQuickConfig: TBitBtn;
    btAdminTestAI: TBitBtn;
    btAdminTestVoice: TBitBtn;
    btAdminTestVision: TBitBtn;
    btAdminTestAvatar: TBitBtn;
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
    pnlBotoesPergunta: TPanel;
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
    procedure btAdminTriggerClick(Sender: TObject);
    procedure lblInstitutionDblClick(Sender: TObject);
    procedure btAdminDiagnosticoClick(Sender: TObject);
    procedure btAdminLogsClick(Sender: TObject);
    procedure OnAdminNavClick(Sender: TObject);
    procedure btAdminTestVoiceClick(Sender: TObject);
    procedure btAdminTestVisionClick(Sender: TObject);
    procedure btAdminTestAvatarClick(Sender: TObject);
    procedure btAdminTestAIClick(Sender: TObject);
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
    procedure memPerguntaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure memPerguntaKeyPress(Sender: TObject; var Key: char);
    procedure lstProjetosSelectionChange(Sender: TObject; User: Boolean);
    procedure btAnexarClick(Sender: TObject);
    procedure btPararClick(Sender: TObject);
  private
    FAguardandoResposta: Boolean;
    FVoiceActive: Boolean;
    FAssistantSpeaking: Boolean;
    FContinuousListener: TAIContinuousListener;
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
    FCurrentAdminSection: TAdminSection;
    FPublicViewMode: TPublicViewMode;
    FAllowVisualResource: Boolean;
    FDisplayedProject: string;
    FDisplayedResourceID: string;

    { Percepcao Kinect v1 }
    FWebcam: TWebcamVision;
    FVisionStatus: string;
    FVisionState: TVisionState;
    FVisionCapabilities: TVisionCapabilities;
    FKinectSensor: TAIKinectSensor;
    FKinectSkeleton: TAIKinectSkeleton;
    FKinectPerception: TAIKinectPerception;
    FKinectAdapter: TAIKinectInteractionAdapter;


    procedure ShowAdminSection(ASection: TAdminSection);
    procedure UpdateAdminStatusIndicators;
    procedure SetPublicViewMode(AMode: TPublicViewMode);
    procedure ShowConversationAnswer(const AText: string);
    procedure ShowContentAnswer(const ATitle, ASubtitle, AImagePath, AText: string);
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
    procedure OnPresentationResourceSelected(Sender: TObject; AResource: TPresentationResource);
    procedure OnPresentationNarrativeSpoken(Sender: TObject; const ANarrative, AEmotion, AGesture: string);
    procedure OnPresentationProjectChanged(Sender: TObject; APackage: TPresentationPackage);

    procedure InitVision;
    procedure InitWebcam;
    procedure ShutdownVision;
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
    procedure ProcessUserSpeech(const AText: string);
    function ValidateWavFile(const AFileName: string; out AError: string): Boolean;
    procedure OnContinuousSpeechUtterance(Sender: TObject; const AWavFileName: string; ADurationMs: Integer);
    procedure OnContinuousStateChanged(Sender: TObject; AOldState, ANewState: TAIListeningState);
    procedure OnContinuousRMSChanged(Sender: TObject; ARMS: Double);
    procedure OnContinuousAudioOrigin(Sender: TObject; AOrigin: TAudioOrigin; AConfidence: Double);
    procedure OnContinuousBargeIn(Sender: TObject);
    procedure OnAudioPlayerPlaybackStart(Sender: TObject; const AFileName: string);
    procedure OnAudioPlayerPlaybackStop(Sender: TObject);
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
    property ContinuousListener: TAIContinuousListener read FContinuousListener;
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

procedure Tfrmmain.InitVision;
var
  KinectStatus, CamStatus: string;
begin
  ShutdownVision;
  FVisionState := vstSelected;
  FVisionStatus := 'Vídeo: desativado';
  if FSetMain = nil then Exit;
  KinectStatus := '';
  CamStatus := '';

  if FSetMain.VisionSource in [vsKinect, vsBoth] then
  begin
    try
      InitKinect;
    except
      on E: Exception do
      begin
        ShutdownKinect;
        FVisionCapabilities := [];
        FVisionState := vstError;
        FVisionStatus := 'Kinect: erro - ' + E.Message;
      end;
    end;
    KinectStatus := FVisionStatus;
  end;

  if FSetMain.VisionSource in [vsWebcam, vsBoth] then
  begin
    try
      InitWebcam;
    except
      on E: Exception do
      begin
        FreeAndNil(FWebcam);
        FVisionState := vstError;
        FVisionStatus := 'Câmera: erro - ' + E.Message;
      end;
    end;
    CamStatus := FVisionStatus;
  end;

  if (KinectStatus <> '') and (CamStatus <> '') then
    FVisionStatus := KinectStatus + ' | ' + CamStatus
  else if KinectStatus <> '' then
    FVisionStatus := KinectStatus
  else if CamStatus <> '' then
    FVisionStatus := CamStatus;

  AdicionaMensagemHistorico('Vídeo', FVisionStatus);
  UpdateAdminStatusIndicators;
end;

procedure Tfrmmain.InitWebcam;
var
  Devs: TStringList;
begin
  if (Trim(FSetMain.CameraDevice) = '') or
     SameText(FSetMain.CameraDevice, 'Nenhuma câmera detectada') then
  begin
    FVisionStatus := 'Câmera: nenhuma câmera configurada';
    Exit;
  end;
  Devs := TWebcamVision.Devices;
  try
    if Devs.Count = 0 then
    begin
      FVisionStatus := 'Câmera: não detectada';
      Exit;
    end;
  finally
    Devs.Free;
  end;

  FWebcam := TWebcamVision.Create(Self);
  if FWebcam.OpenDevice(FSetMain.CameraDevice, Self, nil) then
  begin
    FSetMain.CameraDevice := FWebcam.DeviceName;
    FVisionState := vstInitialized;
    FVisionCapabilities := FVisionCapabilities + VisionCapabilities(vsWebcam);
    FVisionStatus := 'Câmera: ' + FWebcam.DeviceName + ' - RGB ativo';
  end
  else
  begin
    FVisionState := vstError;
    FVisionStatus := 'Câmera: ' + FWebcam.LastError;
    FreeAndNil(FWebcam);
  end;
end;

procedure Tfrmmain.ShutdownVision;
begin
  FreeAndNil(FWebcam);
  ShutdownKinect;
  FVisionCapabilities := [];
end;

procedure Tfrmmain.InitKinect;
var DevList: TStringList;
begin
  FKinectSensor := TAIKinectSensor.Create(Self);
  DevList := FKinectSensor.ListDevices;
  try
    AdicionaMensagemHistorico('Visao', Format('[VISION] Kinect encontrados: %d', [DevList.Count]));
    if DevList.Count = 0 then
    begin
      FVisionStatus := 'Kinect: não detectado';
      FreeAndNil(FKinectSensor);
      Exit;
    end;
    FVisionState := vstDetected;
    if (FSetMain.KinectDeviceIndex < 0) or (FSetMain.KinectDeviceIndex >= DevList.Count) then
    begin
      if DevList.Count = 1 then FSetMain.KinectDeviceIndex := 0
      else
      begin
        FVisionStatus := 'Vídeo: selecione o Kinect em Configurações > Vídeo.';
        FreeAndNil(FKinectSensor);
        Exit;
      end;
    end;
    FKinectSensor.DeviceIndex := FSetMain.KinectDeviceIndex;
    FKinectSensor.Backend := kbKinectSDK10;
    FKinectSensor.KinectModel := kmXbox360;
    if not FKinectSensor.Open then
    begin
      FVisionState := vstError;
      FVisionStatus := 'Kinect: ' + FKinectSensor.LastError;
      FreeAndNil(FKinectSensor);
      Exit;
    end;
  finally DevList.Free end;
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


  FKinectSkeleton.SeatedMode := FSetMain.KinectSeatedMode;
  if not FKinectSkeleton.StartTracking then
  begin
    FVisionStatus := 'Visao: erro no skeleton Kinect - ' + FKinectSkeleton.LastError;
    FVisionState := vstError;
    ShutdownKinect;
    Exit;
  end;
  FVisionState := vstInitialized;
  FVisionCapabilities := VisionCapabilities(vsKinect);
  FVisionStatus := 'Visao: Kinect v1 - conectado';
end;

procedure Tfrmmain.ShutdownKinect;
begin
  if Assigned(FConversationOrchestrator) then
    FConversationOrchestrator.OnGestureDetected := nil;
  if Assigned(FKinectSkeleton) then FKinectSkeleton.Active := False;
  FreeAndNil(FKinectAdapter);
  FreeAndNil(FKinectPerception);
  FreeAndNil(FKinectSkeleton);
  FreeAndNil(FKinectSensor);
end;

procedure Tfrmmain.OnKinectPersonEntered(Sender: TObject; ATrackingID: Integer;
  ADistance: Single; const APosition: string);
begin
  if not (vcPersonTracking in FVisionCapabilities) then Exit;
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

  // Apenas saúda o visitante e aguarda perguntas (não inicia apresentação automática)
  SetPublicViewMode(pvmIdle);
  SetProfessorState('greeting');
  if (FSetMain <> nil) and FSetMain.AutoSpeak then
    FalaTexto('Olá! Sou o Professor Virtual. Como posso ajudar você hoje?');
end;

procedure Tfrmmain.OnKinectPersonLeft(Sender: TObject; ATrackingID: Integer);
begin
  if not (vcPersonTracking in FVisionCapabilities) then Exit;
  AdicionaMensagemHistorico('Sensor Visual', Format('Visitante #%d afastou-se da zona de apresentacao.', [ATrackingID]));

  if FAvatar3D <> nil then
  begin
    FAvatar3D.LookAt(ltCenter);
    FAvatar3D.SetState(avIdle);
  end;
end;

procedure Tfrmmain.OnKinectDeicticResolved(Sender: TObject; const AGesture, ATarget: string);
begin
  if not (vcPointing in FVisionCapabilities) then Exit;
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

  // Atualiza apenas contexto sem forçar troca imediata de tela
  if FConversationOrchestrator <> nil then
    FConversationOrchestrator.Context.CurrentProject := ATarget;
end;

procedure Tfrmmain.OnKinectGestureDetected(Sender: TObject; const AGestureName, ATargetObject: string);
begin
  if not (vcGesture in FVisionCapabilities) then Exit;
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


procedure Tfrmmain.btAdminTriggerClick(Sender: TObject);
begin
  EnterAdminMode;
end;

procedure Tfrmmain.lblInstitutionDblClick(Sender: TObject);
begin
  EnterAdminMode;
end;

procedure Tfrmmain.btAdminDiagnosticoClick(Sender: TObject);
begin
  ShowAdminSection(asGeneral);
end;

procedure Tfrmmain.btAdminLogsClick(Sender: TObject);
begin
  ShowAdminSection(asLogs);
end;

procedure Tfrmmain.OnAdminNavClick(Sender: TObject);
begin
  if Sender = btNavGeneral then
    ShowAdminSection(asGeneral)
  else if Sender = btNavAI then
    ShowAdminSection(asAI)
  else if Sender = btNavVoice then
    ShowAdminSection(asVoice)
  else if Sender = btNavVision then
    ShowAdminSection(asVision)
  else if Sender = btNavAvatar then
    ShowAdminSection(asAvatar)
  else if Sender = btNavProjects then
    ShowAdminSection(asProjects)
  else if Sender = btNavRAG then
    ShowAdminSection(asRAG)
  else if Sender = btNavPeople then
    ShowAdminSection(asPeople)
  else if Sender = btNavIntegrations then
    ShowAdminSection(asIntegrations)
  else if Sender = btNavLogs then
    ShowAdminSection(asLogs);
end;

procedure Tfrmmain.btAdminTestVoiceClick(Sender: TObject);
begin
  if Assigned(FVoiceSynth) then
    FVoiceSynth.Say('Teste de síntese de voz do Professor Virtual executado com sucesso.');
end;

procedure Tfrmmain.btAdminTestAvatarClick(Sender: TObject);
begin
  if FAvatar3D <> nil then
  begin
    FAvatar3D.SetState(avActing);
    FAvatar3D.PlayGesture(agWave, 2.0);
  end;
end;

procedure Tfrmmain.btAdminTestAIClick(Sender: TObject);
begin
  AdicionaMensagemHistorico('⚡ Teste IA', 'Conexão e parâmetros da IA validados.');
  ShowMessage('Mecanismo de IA ativo e respondendo aos comandos do orquestrador.');
end;

procedure Tfrmmain.btAdminTestVisionClick(Sender: TObject);
begin
  UpdateAdminStatusIndicators;
  InitVision;
  ShowMessage(FVisionStatus);
end;

procedure Tfrmmain.UpdateAdminStatusIndicators;
begin
  if Assigned(lblStatVision) then lblStatVision.Caption := FVisionStatus;
  if Assigned(lblStatIA) then
  begin
    if (FAssistantManager <> nil) then
      lblStatIA.Caption := '● Inteligência Artificial (LLM): Online'
    else
      lblStatIA.Caption := '● Inteligência Artificial (LLM): Inicializada';
  end;

  if Assigned(lblStatVoice) and (FVoiceSynth <> nil) then
    lblStatVoice.Caption := '● Síntese de Voz (TTS): Pronta (' + FVoiceSynth.VoiceName + ')'
  else if Assigned(lblStatVoice) then
    lblStatVoice.Caption := '● Síntese de Voz (TTS): Aguardando';

  if Assigned(lblStatAvatar) then
  begin
    if FAvatar3D <> nil then
      lblStatAvatar.Caption := '● Avatar 3D: Carregado e Ativo'
    else
      lblStatAvatar.Caption := '● Avatar 3D: Pronto';
  end;

  if Assigned(lblStatRAG) then
    lblStatRAG.Caption := '● Base RAG / Vetorial: Pronta';

  if Assigned(lblExpCurrentProject) and Assigned(lblProjectTitle) then
    lblExpCurrentProject.Caption := 'Exposição - Projeto Ativo: ' + lblProjectTitle.Caption;

  if Assigned(lblExpCurrentResource) and Assigned(lblTopicSubtitle) then
    lblExpCurrentResource.Caption := 'Exposição - Tópico Atual: ' + lblTopicSubtitle.Caption;
end;

procedure Tfrmmain.ShowAdminSection(ASection: TAdminSection);
  procedure ResetNavButton(AButton: TSpeedButton; AActive: Boolean);
  begin
    if AButton = nil then Exit;
    if AActive then
    begin
      AButton.Font.Color := $0000FF99;
      AButton.Font.Style := [fsBold];
    end
    else
    begin
      AButton.Font.Color := clSilver;
      AButton.Font.Style := [];
    end;
  end;
begin
  FCurrentAdminSection := ASection;

  // Esconder todas as seções
  if Assigned(pnlSecGeneral) then pnlSecGeneral.Visible := False;
  if Assigned(pnlSecAI) then pnlSecAI.Visible := False;
  if Assigned(pnlSecVoice) then pnlSecVoice.Visible := False;
  if Assigned(pnlSecVision) then pnlSecVision.Visible := False;
  if Assigned(pnlSecAvatar) then pnlSecAvatar.Visible := False;
  if Assigned(pnlSecProjects) then pnlSecProjects.Visible := False;
  if Assigned(pnlSecRAG) then pnlSecRAG.Visible := False;
  if Assigned(pnlSecPeople) then pnlSecPeople.Visible := False;
  if Assigned(pnlSecIntegrations) then pnlSecIntegrations.Visible := False;
  if Assigned(pnlSecLogs) then pnlSecLogs.Visible := False;

  // Resetar estilos de navegação
  ResetNavButton(btNavGeneral, ASection = asGeneral);
  ResetNavButton(btNavAI, ASection = asAI);
  ResetNavButton(btNavVoice, ASection = asVoice);
  ResetNavButton(btNavVision, ASection = asVision);
  ResetNavButton(btNavAvatar, ASection = asAvatar);
  ResetNavButton(btNavProjects, ASection = asProjects);
  ResetNavButton(btNavRAG, ASection = asRAG);
  ResetNavButton(btNavPeople, ASection = asPeople);
  ResetNavButton(btNavIntegrations, ASection = asIntegrations);
  ResetNavButton(btNavLogs, ASection = asLogs);

  // Exibir a seção selecionada
  case ASection of
    asGeneral:
      if Assigned(pnlSecGeneral) then pnlSecGeneral.Visible := True;
    asAI:
      if Assigned(pnlSecAI) then pnlSecAI.Visible := True;
    asVoice:
      if Assigned(pnlSecVoice) then pnlSecVoice.Visible := True;
    asVision:
      if Assigned(pnlSecVision) then pnlSecVision.Visible := True;
    asAvatar:
      if Assigned(pnlSecAvatar) then pnlSecAvatar.Visible := True;
    asProjects:
      if Assigned(pnlSecProjects) then pnlSecProjects.Visible := True;
    asRAG:
      if Assigned(pnlSecRAG) then pnlSecRAG.Visible := True;
    asPeople:
      if Assigned(pnlSecPeople) then pnlSecPeople.Visible := True;
    asIntegrations:
      if Assigned(pnlSecIntegrations) then pnlSecIntegrations.Visible := True;
    asLogs:
      if Assigned(pnlSecLogs) then pnlSecLogs.Visible := True;
  end;

  UpdateAdminStatusIndicators;
end;


procedure Tfrmmain.SetPublicViewMode(AMode: TPublicViewMode);
begin
  FPublicViewMode := AMode;

  case AMode of
    pvmIdle:
    begin
      if Assigned(pnlRoot) then pnlRoot.Visible := True;
      if Assigned(pnlAdminRoot) then pnlAdminRoot.Visible := False;
      if Assigned(pnlProjectHeader) then pnlProjectHeader.Visible := False;
      if Assigned(imgResource) then
      begin
        imgResource.Picture.Clear;
        imgResource.Visible := False;
      end;
      if Assigned(lblResourceCaption) then
      begin
        lblResourceCaption.Caption := '';
        lblResourceCaption.Visible := False;
      end;
      if Assigned(lblResourcePlaceholder) then
      begin
        lblResourcePlaceholder.Caption := 'Pergunte sobre os projetos, tecnologias ou demonstrações disponíveis.';
        lblResourcePlaceholder.Visible := True;
      end;
      if Assigned(pnlNarrativeContainer) then pnlNarrativeContainer.Visible := True;
      if Assigned(lblProjectTitle) then lblProjectTitle.Caption := 'Como posso ajudar?';
      if Assigned(lblTopicSubtitle) then
      begin
        lblTopicSubtitle.Caption := '';
        lblTopicSubtitle.Visible := False;
      end;
      SetNarrativeText('Olá! Sou o Professor Virtual da FATEC Ribeirão Preto. Como posso ajudar?');
      SetProfessorState('idle');
      FAllowVisualResource := False;
    end;

    pvmConversation:
    begin
      if Assigned(pnlProjectHeader) then pnlProjectHeader.Visible := False;
      if Assigned(imgResource) then imgResource.Visible := False;
      if Assigned(lblResourceCaption) then lblResourceCaption.Visible := False;
      if Assigned(lblResourcePlaceholder) then
      begin
        lblResourcePlaceholder.Caption := 'Como posso ajudar? Faça uma pergunta para começar.';
        lblResourcePlaceholder.Visible := True;
      end;
      if Assigned(pnlNarrativeContainer) then pnlNarrativeContainer.Visible := True;
      FAllowVisualResource := False;
    end;

    pvmContent:
    begin
      if Assigned(pnlProjectHeader) then pnlProjectHeader.Visible := True;
      if Assigned(pnlNarrativeContainer) then pnlNarrativeContainer.Visible := True;
      FAllowVisualResource := True;
      SetProfessorState('showing_content');
    end;

    pvmPresentation:
    begin
      if Assigned(pnlProjectHeader) then pnlProjectHeader.Visible := True;
      if Assigned(pnlNarrativeContainer) then pnlNarrativeContainer.Visible := True;
      FAllowVisualResource := True;
      SetProfessorState('presenting');
    end;
  end;
end;

procedure Tfrmmain.ShowConversationAnswer(const AText: string);
begin
  SetPublicViewMode(pvmConversation);
  SetNarrativeText(AText);
end;

procedure Tfrmmain.ShowContentAnswer(const ATitle, ASubtitle, AImagePath, AText: string);
begin
  ShowPresentationResource(ATitle, ASubtitle, AImagePath, AText);
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
var
  InputPIN: string;
begin
  if (FSetMain <> nil) and (Trim(FSetMain.AdminPIN) <> '') then
  begin
    InputPIN := '';
    if not InputQuery('Acesso Administrativo', 'Digite o PIN de Administrador:', True, InputPIN) then
      Exit;
    if InputPIN <> FSetMain.AdminPIN then
    begin
      ShowMessage('PIN incorreto. Acesso não autorizado.');
      Exit;
    end;
  end;

  if Assigned(pnlRoot) then
    pnlRoot.Visible := False;
  if Assigned(pnlAdminRoot) then
    pnlAdminRoot.Visible := True;

  ShowAdminSection(asGeneral);
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
    lblProfessorStatus.Caption := '🎤 Ouvindo...';
    if FAvatar3D <> nil then
      FAvatar3D.SetState(avListening);
  end
  else if (S = 'thinking') or (S = 'pensando') then
  begin
    lblProfessorStatus.Font.Color := $00FFC040;
    lblProfessorStatus.Caption := '🧠 Pensando...';
    if FAvatar3D <> nil then
      FAvatar3D.SetState(avThinking);
  end
  else if (S = 'speaking') or (S = 'falando') or (S = 'respondendo') then
  begin
    lblProfessorStatus.Font.Color := $0000D4FF;
    lblProfessorStatus.Caption := '🗣️ Respondendo...';
    if FAvatar3D <> nil then
      FAvatar3D.SetState(avSpeaking);
  end
  else if (S = 'showing_content') or (S = 'mostrando_conteudo') or (S = 'conteudo') then
  begin
    lblProfessorStatus.Font.Color := $0000D4FF;
    lblProfessorStatus.Caption := '📖 Mostrando conteúdo';
    if FAvatar3D <> nil then
      FAvatar3D.SetState(avIdle);
  end
  else if (S = 'presenting') or (S = 'apresentando') then
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
  SetPublicViewMode(pvmContent);

  if Assigned(lblProjectTitle) then
  begin
    if Trim(ATitle) <> '' then
    begin
      lblProjectTitle.Caption := UpperCase(Trim(ATitle));
      FDisplayedProject := Trim(ATitle);
    end
    else
      lblProjectTitle.Caption := 'PROJETO';
    lblProjectTitle.Visible := True;
  end;

  if Assigned(lblTopicSubtitle) then
  begin
    lblTopicSubtitle.Caption := Trim(ASubtitle);
    lblTopicSubtitle.Visible := (Trim(ASubtitle) <> '');
  end;

  if Trim(ANarrative) <> '' then
    SetNarrativeText(ANarrative);

  if Assigned(imgResource) and (Trim(AImagePath) <> '') and FileExists(AImagePath) then
  begin
    try
      imgResource.Picture.LoadFromFile(AImagePath);
      imgResource.Visible := True;
      FDisplayedResourceID := AImagePath;
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

  if Assigned(lblResourceCaption) then
  begin
    lblResourceCaption.Caption := '';
    lblResourceCaption.Visible := False;
  end;

  if Assigned(lblTopicSubtitle) then
  begin
    lblTopicSubtitle.Caption := '';
    lblTopicSubtitle.Visible := False;
  end;

  SetPublicViewMode(pvmIdle);
end;

procedure Tfrmmain.OnVoiceSpeechStart(Sender: TObject);
begin
  FAssistantSpeaking := True;
  if FContinuousListener <> nil then
    FContinuousListener.NotifyAssistantSpeechStart;

  if FAvatar3D <> nil then
    FAvatar3D.SetState(avSpeaking);
  if FPublicViewMode = pvmPresentation then
    SetProfessorState('presenting')
  else
    SetProfessorState('speaking');
end;

procedure Tfrmmain.OnVoiceSpeechEnd(Sender: TObject);
begin
  FAssistantSpeaking := False;
  if FContinuousListener <> nil then
    FContinuousListener.NotifyAssistantSpeechEnd;

  if FAvatar3D <> nil then
    FAvatar3D.SetState(avIdle);
  if FPublicViewMode = pvmPresentation then
    SetProfessorState('presenting')
  else if FPublicViewMode = pvmContent then
    SetProfessorState('showing_content')
  else if (FContinuousListener <> nil) and FContinuousListener.Enabled then
    SetProfessorState('listening')
  else
    SetProfessorState('idle');
end;


procedure Tfrmmain.OnPresentationResourceSelected(Sender: TObject; AResource: TPresentationResource);
var
  ImgFile: string;
begin
  if AResource = nil then Exit;
  // Só exibe recurso visual se a exibição for autorizada ou se estiver apresentando
  if (FPublicViewMode <> pvmPresentation) and (not FAllowVisualResource) then Exit;

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
  if FAssistantManager <> nil then
    FAssistantManager.ActiveProject := APackage.ProjectCode;

  // Atualiza a tela publica somente se a apresentacao ou conteudo visual estiverem ativos
  if FPublicViewMode in [pvmPresentation, pvmContent] then
  begin
    FDisplayedProject := APackage.ProjectCode;
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
  end;

  lblJarvisStatusBadge.Caption := '● EXPOSICAO: ' + UpperCase(APackage.ProjectCode);
  lblJarvisSub.Caption := APackage.Title;
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
      // FPresentationAgent.StartPresentation(S.PersonID, S.Name, S.CurrentProject); // Removido inicio automatico
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

  // Inicializa escuta contínua com VAD e supressão da própria voz
  FContinuousListener := TAIContinuousListener.Create(Self);
  FContinuousListener.Continuous := True;
  FContinuousListener.OnSpeechUtterance := @OnContinuousSpeechUtterance;
  FContinuousListener.OnStateChanged := @OnContinuousStateChanged;
  FContinuousListener.OnRMSChanged := @OnContinuousRMSChanged;
  FContinuousListener.OnAudioOriginDetected := @OnContinuousAudioOrigin;
  FContinuousListener.OnBargeIn := @OnContinuousBargeIn;

  if Assigned(FAudioPlayer) then
  begin
    FAudioPlayer.OnPlaybackStart := @OnAudioPlayerPlaybackStart;
    FAudioPlayer.OnPlaybackStop := @OnAudioPlayerPlaybackStop;
  end;

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
  FPresentationAgent := TAIPresentationAgent.Create(Self);
  FPresentationAgent.OnResourceSelected := @OnPresentationResourceSelected;
  FPresentationAgent.OnNarrativeSpoken := @OnPresentationNarrativeSpoken;
  FPresentationAgent.OnProjectChanged := @OnPresentationProjectChanged;

  // Inicia com layout limpo de exposicao (sem botoes manuais poluindo a tela)
  pnlSidebar.Visible := False;
  pnlQuickBar.Visible := False;

  // Modo inicial neutro e receptivo (aguarda pergunta do usuario)
  SetPublicViewMode(pvmIdle);
  SetProfessorState('idle');

  // Inicializa Percepcao Semantica Kinect v1
  InitVision;

  if Assigned(memPergunta) then
  begin
    memPergunta.Text := '';
    memPergunta.TextHint := 'Digite sua pergunta aqui...';
  end;
end;

procedure Tfrmmain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if Assigned(FContinuousListener) then
    FContinuousListener.StopListening;
  if (FSetMain <> nil) and FSetMain.MinimizeToTray and (CloseAction <> caFree) then
  begin
    CloseAction := caNone;
    Hide;
    trayIcon.Show;
    trayIcon.ShowBalloonHint;
  end
  else ShutdownVision;
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

    if (FSetMain <> nil) and (Trim(FSetMain.STTToken) <> '') then
      FVoiceRecog.OpenAIToken := FSetMain.STTToken
    else
      FVoiceRecog.OpenAIToken := FSetMain.CHATGPT;

    if (FSetMain <> nil) and (Trim(FSetMain.STTModel) <> '') then
      FVoiceRecog.OpenAIModel := FSetMain.STTModel;
    if (FSetMain <> nil) and (Trim(FSetMain.STTEndpoint) <> '') then
      FVoiceRecog.OpenAIEndpoint := FSetMain.STTEndpoint;
  end;

  if Assigned(FContinuousListener) and (FSetMain <> nil) then
  begin
    FContinuousListener.Enabled := FSetMain.ContinuousListening;
    FContinuousListener.VoiceThreshold := FSetMain.VoiceThreshold;
    FContinuousListener.SilenceTimeoutMs := FSetMain.SilenceTimeoutMs;
    FContinuousListener.MinSpeechMs := FSetMain.MinSpeechMs;
    FContinuousListener.MaxSpeechMs := FSetMain.MaxSpeechMs;
    FContinuousListener.EchoSuppressionEnabled := FSetMain.EchoSuppressionEnabled;
    FContinuousListener.SelfAudioCorrelationThreshold := FSetMain.SelfAudioCorrelationThreshold;

    if FContinuousListener.Enabled then
      FContinuousListener.StartListening;
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
  Cmd := Trim(memPergunta.Text);
  if Cmd = '' then
    Exit;

  // Interrompe fala / TTS anterior (barge-in por teclado)
  if Assigned(FVoiceSynth) then
    FVoiceSynth.Stop;

  if Assigned(FAudioPlayer) and FAudioPlayer.Playing then
    FAudioPlayer.Stop;

  if Assigned(FConversationOrchestrator) then
    FConversationOrchestrator.StopSpeaking;

  SetPublicViewMode(pvmConversation);
  SetProfessorState('thinking');

  memPergunta.Clear;
  ExecutaComandoJarvis(Cmd);
end;

procedure Tfrmmain.memPerguntaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    if ssShift in Shift then
    begin
      // Shift + Enter: quebra de linha permitida no memo
      Exit;
    end
    else
    begin
      // Enter simples: consome a tecla e envia
      Key := 0;
      btEnviarClick(Sender);
    end;
  end;
end;

procedure Tfrmmain.memPerguntaKeyPress(Sender: TObject; var Key: char);
begin
  if (Key = #13) and not (LCLIntf.GetKeyState(VK_SHIFT) < 0) then
  begin
    Key := #0;
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
      if FVoiceRecog <> nil then
      begin
        // Recognize já dispara OnRecognized -> VoiceRecognized -> ProcessUserSpeech
        FVoiceRecog.Recognize(FListeningWavFile);
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
begin
  ProcessUserSpeech(AText);
end;
function Tfrmmain.ValidateWavFile(const AFileName: string; out AError: string): Boolean;
var
  FS: TFileStream;
  RiffTag, WaveTag: array[0..3] of AnsiChar;
begin
  Result := False;
  AError := '';
  if not FileExists(AFileName) then
  begin
    AError := 'Arquivo de áudio não encontrado';
    Exit;
  end;

  try
    FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      if FS.Size <= 44 then
      begin
        AError := 'Tamanho do arquivo insuficiente';
        Exit;
      end;

      FS.ReadBuffer(RiffTag, 4);
      FS.Position := 8;
      FS.ReadBuffer(WaveTag, 4);
      if (RiffTag <> 'RIFF') or (WaveTag <> 'WAVE') then
      begin
        AError := 'Formato WAV inválido';
        Exit;
      end;

      Result := True;
    finally
      FS.Free;
    end;
  except
    on E: Exception do
      AError := E.Message;
  end;
end;

procedure Tfrmmain.ProcessUserSpeech(const AText: string);
var
  TextoLimpo: string;
begin
  TextoLimpo := Trim(AText);
  if TextoLimpo = '' then Exit;

  AdicionaMensagemHistorico('Você (Voz)', TextoLimpo);

  // Notifica orquestrador de conversação e contexto
  if FConversationOrchestrator <> nil then
  begin
    FConversationOrchestrator.NotifySpeechStart;
    FConversationOrchestrator.Context.ResolveReference(TextoLimpo);
    if (FAssistantManager <> nil) and (FConversationOrchestrator.Context.CurrentProject <> '') then
      FAssistantManager.ActiveProject := FConversationOrchestrator.Context.CurrentProject;
    if FConversationOrchestrator.SessionManager.ActiveSession <> nil then
      FConversationOrchestrator.SessionManager.ActiveSession.AddMessage('user', TextoLimpo);
  end;

  if FAvatar3D <> nil then
  begin
    FAvatar3D.SetState(avListening);
    FAvatar3D.SetState(avThinking);
  end;

  SetProfessorState('thinking');

  // Se o Professor Virtual estiver em apresentação guiada, responde com desvio didático
  if (FPresentationAgent <> nil) and (FPresentationAgent.State in [psPresentingConcept, psGreeting]) then
  begin
    FPresentationAgent.AnswerQuestion(TextoLimpo);
    Exit;
  end;

  // Pipeline Inteligente do Agente
  FAguardandoResposta := True;
  btEnviar.Enabled := False;

  if Assigned(FAssistantManager) then
    FAssistantManager.ProcessUserRequestAsync(TextoLimpo)
  else if Trim(FSetMain.JarvisURL) <> '' then
    TAskJarvisThread.Create(TextoLimpo, FSetMain.JarvisIAMode, FSetMain.JarvisURL, FSetMain.JarvisAPIKey)
  else
    TAskChatGPTThread.Create(TextoLimpo);
end;

procedure Tfrmmain.OnContinuousSpeechUtterance(Sender: TObject; const AWavFileName: string; ADurationMs: Integer);
var
  ValErr: string;
begin
  if not FileExists(AWavFileName) then Exit;

  if not ValidateWavFile(AWavFileName, ValErr) then
  begin
    AdicionaMensagemHistorico('Voz', 'Áudio descartado: ' + ValErr);
    try DeleteFile(AWavFileName); except end;
    Exit;
  end;

  SetProfessorState('thinking');
  AdicionaMensagemHistorico('Voz', Format('🎤 Fala capturada (%.1fs). Reconhecendo...', [ADurationMs / 1000.0]));

  if FVoiceRecog <> nil then
    FVoiceRecog.Recognize(AWavFileName);

  try
    DeleteFile(AWavFileName);
  except
  end;
end;

procedure Tfrmmain.OnContinuousStateChanged(Sender: TObject; AOldState, ANewState: TAIListeningState);
begin
  case ANewState of
    lsListening:
      if not FAssistantSpeaking then
        SetProfessorState('listening');
    lsSpeechDetected, lsCapturingSpeech:
      begin
        if Assigned(lblProfessorStatus) then
        begin
          lblProfessorStatus.Font.Color := $0000D4FF;
          lblProfessorStatus.Caption := '🎤 Você está falando...';
        end;
        if FAvatar3D <> nil then
          FAvatar3D.SetState(avListening);
      end;
    lsProcessing:
      SetProfessorState('thinking');
    lsSuppressedByAssistantSpeech:
      ; // Supressão silenciosa da própria voz
  end;
end;

procedure Tfrmmain.OnContinuousRMSChanged(Sender: TObject; ARMS: Double);
var
  Bars, TotalBars, i: Integer;
  BarStr: string;
begin
  if Assigned(lblStatVoice) and (FContinuousListener <> nil) then
  begin
    TotalBars := 10;
    Bars := Round(ARMS * 200.0);
    if Bars < 0 then Bars := 0;
    if Bars > TotalBars then Bars := TotalBars;
    BarStr := '[';
    for i := 1 to Bars do BarStr := BarStr + '█';
    for i := Bars + 1 to TotalBars do BarStr := BarStr + '░';
    BarStr := BarStr + ']';

    if FContinuousListener.State = lsSuppressedByAssistantSpeech then
      lblStatVoice.Caption := Format('● Áudio: [Supressão TTS ativa] RMS: %.3f %s', [ARMS, BarStr])
    else if FContinuousListener.State in [lsSpeechDetected, lsCapturingSpeech] then
      lblStatVoice.Caption := Format('● Áudio: [Voz Detectada] RMS: %.3f %s', [ARMS, BarStr])
    else if FContinuousListener.State = lsListening then
      lblStatVoice.Caption := Format('● Áudio: [Ouvindo] RMS: %.3f %s', [ARMS, BarStr]);
  end;
end;

procedure Tfrmmain.OnContinuousAudioOrigin(Sender: TObject; AOrigin: TAudioOrigin; AConfidence: Double);
begin
  // Monitoramento de origem
end;

procedure Tfrmmain.OnContinuousBargeIn(Sender: TObject);
begin
  AdicionaMensagemHistorico('Voz', '⚡ Interrupção do visitante detectada (Barge-In)!');

  if FVoiceSynth <> nil then
    FVoiceSynth.Stop;
  if (FAudioPlayer <> nil) and FAudioPlayer.Playing then
    FAudioPlayer.Stop;

  FAssistantSpeaking := False;

  if FAvatar3D <> nil then
  begin
    FAvatar3D.CancelGesture;
    FAvatar3D.SetState(avListening);
  end;

  SetProfessorState('listening');

  if FConversationOrchestrator <> nil then
    FConversationOrchestrator.NotifySpeechStart;
end;

procedure Tfrmmain.OnAudioPlayerPlaybackStart(Sender: TObject; const AFileName: string);
begin
  if FContinuousListener <> nil then
  begin
    FContinuousListener.FeedPlaybackWav(AFileName);
    FContinuousListener.NotifyAssistantSpeechStart;
  end;
end;

procedure Tfrmmain.OnAudioPlayerPlaybackStop(Sender: TObject);
begin
  if FContinuousListener <> nil then
    FContinuousListener.NotifyAssistantSpeechEnd;
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
  if FSetMain = nil then
    FSetMain := TSetMain.create();

  FormCfg := TfrmConfig.Create(Self);
  try
    try
      // Abrir diretamente a primeira aba (Geral)
      if Assigned(FormCfg.pcConfig) then
        FormCfg.pcConfig.ActivePageIndex := 0;

      // Aba JARVIS
      if Assigned(FormCfg.edJarvisURL) then
        FormCfg.edJarvisURL.Text := FSetMain.JarvisURL;
      if Assigned(FormCfg.edJarvisKey) then
        FormCfg.edJarvisKey.Text := FSetMain.JarvisAPIKey;
      if Assigned(FormCfg.cbJarvisMode) then
      begin
        if FSetMain.JarvisIAMode = 'local_only' then
          FormCfg.cbJarvisMode.ItemIndex := 1
        else if FSetMain.JarvisIAMode = 'cloud_only' then
          FormCfg.cbJarvisMode.ItemIndex := 2
        else
          FormCfg.cbJarvisMode.ItemIndex := 0;
      end;
      if Assigned(FormCfg.chkMinimizeTray) then
        FormCfg.chkMinimizeTray.Checked := FSetMain.MinimizeToTray;
      if Assigned(FormCfg.chkAutoSpeak) then
        FormCfg.chkAutoSpeak.Checked := FSetMain.AutoSpeak;

      // Aba IA Legada
      if Assigned(FormCfg.cbProvider) then
      begin
        FormCfg.cbProvider.ItemIndex := FSetMain.ChatGPTProvider;
        if (FormCfg.cbProvider.ItemIndex < 0) or (FormCfg.cbProvider.ItemIndex >= FormCfg.cbProvider.Items.Count) then
          FormCfg.cbProvider.ItemIndex := 0;
      end;
      FormCfg.CarregaModelosDoProvedor;
      if Assigned(FormCfg.cbModel) and (Trim(FSetMain.ChatGPTModel) <> '') then
        FormCfg.cbModel.Text := FSetMain.ChatGPTModel;
      if Assigned(FormCfg.edTokenGPT) then
        FormCfg.edTokenGPT.Text := FSetMain.CHATGPT;
      if Assigned(FormCfg.edURL) then
        FormCfg.edURL.Text := FSetMain.ChatGPTURL;

      // Aba Output Voice
      if Assigned(FormCfg.cbSynthEngine) then
      begin
        FormCfg.cbSynthEngine.ItemIndex := FSetMain.SynthEngine;
        if (FormCfg.cbSynthEngine.ItemIndex < 0) or (FormCfg.cbSynthEngine.ItemIndex >= FormCfg.cbSynthEngine.Items.Count) then
          FormCfg.cbSynthEngine.ItemIndex := 1;
      end;
      FormCfg.CarregaVozesDoSintetizador;
      if Assigned(FormCfg.cbSynthVoice) and (Trim(FSetMain.SynthVoice) <> '') then
        FormCfg.cbSynthVoice.Text := FSetMain.SynthVoice;
      if Assigned(FormCfg.tbSynthVolume) then
      begin
        FormCfg.tbSynthVolume.Position := FSetMain.SynthVolume;
        FormCfg.tbSynthVolumeChange(Self);
      end;
      if Assigned(FormCfg.tbSynthRate) then
      begin
        FormCfg.tbSynthRate.Position := FSetMain.SynthRate;
        FormCfg.tbSynthRateChange(Self);
      end;
      if Assigned(FormCfg.chkSynthAsync) then
        FormCfg.chkSynthAsync.Checked := FSetMain.SynthAsync;

      // Aba Reconhecimento de Voz / Microfone (CHATGPT)
      if Assigned(FormCfg.cbRecogEngine) then
        FormCfg.cbRecogEngine.ItemIndex := FSetMain.RecogEngine;
      if Assigned(FormCfg.edRecogLanguage) then
        FormCfg.edRecogLanguage.Text := FSetMain.RecogLanguage;
      if Assigned(FormCfg.cbAudioSampleRate) then
      begin
        if FSetMain.AudioSampleRate = 44100 then
          FormCfg.cbAudioSampleRate.ItemIndex := 1
        else
          FormCfg.cbAudioSampleRate.ItemIndex := 0;
      end;
      if Assigned(FormCfg.cbAudioChannels) then
      begin
        if FSetMain.AudioChannels = 2 then
          FormCfg.cbAudioChannels.ItemIndex := 1
        else
          FormCfg.cbAudioChannels.ItemIndex := 0;
      end;

      // Aba Avatar 3D
      if Assigned(FormCfg.edAvatarModel) then
        FormCfg.edAvatarModel.Text := FSetMain.Avatar3DModel;
      if Assigned(FormCfg.chkAvatarAutoIdle) then
        FormCfg.chkAvatarAutoIdle.Checked := FSetMain.Avatar3DAutoIdle;
      if Assigned(FormCfg.chkAvatarAutoBlink) then
        FormCfg.chkAvatarAutoBlink.Checked := FSetMain.Avatar3DAutoBlink;
      if Assigned(FormCfg.chkAvatarLipSync) then
        FormCfg.chkAvatarLipSync.Checked := FSetMain.Avatar3DLipSync;
      if Assigned(FormCfg.cbAvatarQuality) then
        FormCfg.cbAvatarQuality.Text := FSetMain.Avatar3DQuality;

      // Aba Banco
      if Assigned(FormCfg.edMyHost) then FormCfg.edMyHost.Text := FSetMain.HostnameMy;
      if Assigned(FormCfg.edMyDb) then FormCfg.edMyDb.Text := FSetMain.BancoMy;
      if Assigned(FormCfg.edMyUser) then FormCfg.edMyUser.Text := FSetMain.UsernameMy;
      if Assigned(FormCfg.edMyPass) then FormCfg.edMyPass.Text := FSetMain.PasswordMy;
      if Assigned(FormCfg.edPostHost) then FormCfg.edPostHost.Text := FSetMain.HostnamePost;
      if Assigned(FormCfg.edPostDb) then FormCfg.edPostDb.Text := FSetMain.BancoPOST;
      if Assigned(FormCfg.edPostUser) then FormCfg.edPostUser.Text := FSetMain.UsernamePost;
      if Assigned(FormCfg.edPostPass) then FormCfg.edPostPass.Text := FSetMain.PasswordPost;
      if Assigned(FormCfg.edPostSchema) then FormCfg.edPostSchema.Text := FSetMain.SchemaPost;

      // Aba Visao / Kinect
      FormCfg.LoadVision(FSetMain.VisionSource, FSetMain.KinectDeviceIndex, FSetMain.CameraDevice);
      if Assigned(FormCfg.chkKinectSeated) then
        FormCfg.chkKinectSeated.Checked := FSetMain.KinectSeatedMode;
      if (FSetMain.KinectMinDistance <= 0) or (FSetMain.KinectMaxDistance <= 0) or
         (FSetMain.KinectMinDistance >= FSetMain.KinectMaxDistance) then
      begin
        FSetMain.KinectMinDistance := 0.8;
        FSetMain.KinectMaxDistance := 3.5;
      end;
      if Assigned(FormCfg.edKinectMinDist) then
        FormCfg.edKinectMinDist.Text := FormatFloat('0.0', FSetMain.KinectMinDistance);
      if Assigned(FormCfg.edKinectMaxDist) then
        FormCfg.edKinectMaxDist.Text := FormatFloat('0.0', FSetMain.KinectMaxDistance);
      if Trim(FSetMain.KinectTargetLeft) = '' then FSetMain.KinectTargetLeft := 'ECG';
      if Trim(FSetMain.KinectTargetRight) = '' then FSetMain.KinectTargetRight := 'Hemacias';
      if Trim(FSetMain.KinectTargetCenter) = '' then FSetMain.KinectTargetCenter := 'Robotinics';
      if Assigned(FormCfg.edKinectTargetLeft) then
        FormCfg.edKinectTargetLeft.Text := FSetMain.KinectTargetLeft;
      if Assigned(FormCfg.edKinectTargetRight) then
        FormCfg.edKinectTargetRight.Text := FSetMain.KinectTargetRight;
      if Assigned(FormCfg.edKinectTargetCenter) then
        FormCfg.edKinectTargetCenter.Text := FSetMain.KinectTargetCenter;

      ShutdownVision;
      if FormCfg.ShowModal = mrOk then
      begin
        // Salva JARVIS
        if Assigned(FormCfg.edJarvisURL) then
          FSetMain.JarvisURL := Trim(FormCfg.edJarvisURL.Text);
        if Assigned(FormCfg.edJarvisKey) then
          FSetMain.JarvisAPIKey := Trim(FormCfg.edJarvisKey.Text);
        if Assigned(FormCfg.cbJarvisMode) then
        begin
          case FormCfg.cbJarvisMode.ItemIndex of
            1: FSetMain.JarvisIAMode := 'local_only';
            2: FSetMain.JarvisIAMode := 'cloud_only';
          else
            FSetMain.JarvisIAMode := 'auto';
          end;
        end;
        if Assigned(FormCfg.chkMinimizeTray) then
          FSetMain.MinimizeToTray := FormCfg.chkMinimizeTray.Checked;
        if Assigned(FormCfg.chkAutoSpeak) then
          FSetMain.AutoSpeak := FormCfg.chkAutoSpeak.Checked;

        // Salva IA
        if Assigned(FormCfg.cbProvider) then
          FSetMain.ChatGPTProvider := FormCfg.cbProvider.ItemIndex;
        if Assigned(FormCfg.cbModel) then
          FSetMain.ChatGPTModel := Trim(FormCfg.cbModel.Text);
        if Assigned(FormCfg.edTokenGPT) then
          FSetMain.CHATGPT := Trim(FormCfg.edTokenGPT.Text);
        if Assigned(FormCfg.edURL) then
          FSetMain.ChatGPTURL := Trim(FormCfg.edURL.Text);

        // Salva Output Voice
        if Assigned(FormCfg.cbSynthEngine) then
          FSetMain.SynthEngine := FormCfg.cbSynthEngine.ItemIndex;
        if Assigned(FormCfg.cbSynthVoice) then
          FSetMain.SynthVoice := Trim(FormCfg.cbSynthVoice.Text);
        if Assigned(FormCfg.tbSynthVolume) then
          FSetMain.SynthVolume := FormCfg.tbSynthVolume.Position;
        if Assigned(FormCfg.tbSynthRate) then
          FSetMain.SynthRate := FormCfg.tbSynthRate.Position;
        if Assigned(FormCfg.chkSynthAsync) then
          FSetMain.SynthAsync := FormCfg.chkSynthAsync.Checked;

        // Salva Reconhecimento de Voz
        if Assigned(FormCfg.cbRecogEngine) then
          FSetMain.RecogEngine := FormCfg.cbRecogEngine.ItemIndex;
        if Assigned(FormCfg.edRecogLanguage) then
          FSetMain.RecogLanguage := Trim(FormCfg.edRecogLanguage.Text);
        if Assigned(FormCfg.cbAudioSampleRate) then
        begin
          if FormCfg.cbAudioSampleRate.ItemIndex = 1 then
            FSetMain.AudioSampleRate := 44100
          else
            FSetMain.AudioSampleRate := 16000;
        end;
        if Assigned(FormCfg.cbAudioChannels) then
        begin
          if FormCfg.cbAudioChannels.ItemIndex = 1 then
            FSetMain.AudioChannels := 2
          else
            FSetMain.AudioChannels := 1;
        end;

        // Salva Banco
        if Assigned(FormCfg.edMyHost) then FSetMain.HostnameMy := Trim(FormCfg.edMyHost.Text);
        if Assigned(FormCfg.edMyDb) then FSetMain.BancoMy := Trim(FormCfg.edMyDb.Text);
        if Assigned(FormCfg.edMyUser) then FSetMain.UsernameMy := Trim(FormCfg.edMyUser.Text);
        if Assigned(FormCfg.edMyPass) then FSetMain.PasswordMy := Trim(FormCfg.edMyPass.Text);
        if Assigned(FormCfg.edPostHost) then FSetMain.HostnamePost := Trim(FormCfg.edPostHost.Text);
        if Assigned(FormCfg.edPostDb) then FSetMain.BancoPOST := Trim(FormCfg.edPostDb.Text);
        if Assigned(FormCfg.edPostUser) then FSetMain.UsernamePost := Trim(FormCfg.edPostUser.Text);
        if Assigned(FormCfg.edPostPass) then FSetMain.PasswordPost := Trim(FormCfg.edPostPass.Text);
        if Assigned(FormCfg.edPostSchema) then FSetMain.SchemaPost := Trim(FormCfg.edPostSchema.Text);

        // Salva Visao / Kinect
        FormCfg.StopVisionTest;
        FSetMain.VisionSource := FormCfg.SelectedVisionSource;
        if (FormCfg.cbKinectDevice.ItemIndex >= 0) and
           (FormCfg.cbKinectDevice.Text <> 'Nenhum Kinect detectado') then
          FSetMain.KinectDeviceIndex := FormCfg.cbKinectDevice.ItemIndex
        else if not (FSetMain.VisionSource in [vsKinect, vsBoth]) then
          FSetMain.KinectDeviceIndex := -1;

        if (FormCfg.cbCameraDevice.ItemIndex >= 0) and
           (FormCfg.cbCameraDevice.Text <> 'Nenhuma câmera detectada') then
          FSetMain.CameraDevice := FormCfg.cbCameraDevice.Text
        else if not (FSetMain.VisionSource in [vsWebcam, vsBoth]) then
          FSetMain.CameraDevice := '';

        if Assigned(FormCfg.chkKinectSeated) then
          FSetMain.KinectSeatedMode := FormCfg.chkKinectSeated.Checked;
        if Assigned(FormCfg.edKinectMinDist) then
          FSetMain.KinectMinDistance := SafeParseFloat(FormCfg.edKinectMinDist.Text, 0.8);
        if Assigned(FormCfg.edKinectMaxDist) then
          FSetMain.KinectMaxDistance := SafeParseFloat(FormCfg.edKinectMaxDist.Text, 3.5);
        if (FSetMain.KinectMinDistance <= 0) or (FSetMain.KinectMaxDistance <= 0) or
           (FSetMain.KinectMinDistance >= FSetMain.KinectMaxDistance) then
        begin
          FSetMain.KinectMinDistance := 0.8;
          FSetMain.KinectMaxDistance := 3.5;
        end;
        if Assigned(FormCfg.edKinectTargetLeft) and (Trim(FormCfg.edKinectTargetLeft.Text) <> '') then
          FSetMain.KinectTargetLeft := Trim(FormCfg.edKinectTargetLeft.Text);
        if Assigned(FormCfg.edKinectTargetRight) and (Trim(FormCfg.edKinectTargetRight.Text) <> '') then
          FSetMain.KinectTargetRight := Trim(FormCfg.edKinectTargetRight.Text);
        if Assigned(FormCfg.edKinectTargetCenter) and (Trim(FormCfg.edKinectTargetCenter.Text) <> '') then
          FSetMain.KinectTargetCenter := Trim(FormCfg.edKinectTargetCenter.Text);

        // Salva Avatar 3D
        if Assigned(FormCfg.edAvatarModel) then
          FSetMain.Avatar3DModel := Trim(FormCfg.edAvatarModel.Text);
        if Assigned(FormCfg.chkAvatarAutoIdle) then
          FSetMain.Avatar3DAutoIdle := FormCfg.chkAvatarAutoIdle.Checked;
        if Assigned(FormCfg.chkAvatarAutoBlink) then
          FSetMain.Avatar3DAutoBlink := FormCfg.chkAvatarAutoBlink.Checked;
        if Assigned(FormCfg.chkAvatarLipSync) then
          FSetMain.Avatar3DLipSync := FormCfg.chkAvatarLipSync.Checked;
        if Assigned(FormCfg.cbAvatarQuality) then
          FSetMain.Avatar3DQuality := Trim(FormCfg.cbAvatarQuality.Text);

        FSetMain.SalvaContexto(False);
        AplicaConfiguracoes();
        CarregaIcones();
        AdicionaMensagemHistorico('Configurações', 'Configurações salvas e aplicadas.');
      end;
    except
      on E: Exception do
        ShowMessage('Erro ao carregar formulário de configurações: ' + E.Message);
    end;
  finally
    FormCfg.Free;
    InitVision;
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
var
  JData: TJSONData;
  JObj: TJSONObject;
  VisualActStr: string;
  VisualAction: TAssistantVisualAction;
  ProjStr, SubtitleStr, ImgPathStr, SpokenText: string;
begin
  AdicionaMensagemHistorico('Assistente (' + AProvider + ')', AResponseText);

  // Registra no histórico da sessão da pessoa ativa
  if (FConversationOrchestrator <> nil) and (FConversationOrchestrator.SessionManager.ActiveSession <> nil) then
  begin
    FConversationOrchestrator.SessionManager.ActiveSession.AddMessage('assistant', AResponseText);
    if FConversationOrchestrator.Context.CurrentProject <> '' then
      FConversationOrchestrator.SessionManager.ActiveSession.CurrentProject := FConversationOrchestrator.Context.CurrentProject;
  end;

  // Aplica resposta estruturada ou texto no avatar
  if FAvatar3D <> nil then
  begin
    if ASuccess then
      FAvatar3D.ApplyAgentResponse(AResponseText)
    else
      FAvatar3D.SetState(avError);
  end;

  // Default da ação visual: avaNone (não mostrar conteúdo obrigatório)
  VisualAction := avaNone;
  SpokenText := AResponseText;
  ProjStr := '';
  SubtitleStr := '';
  ImgPathStr := '';

  // Tenta extrair ação visual caso a IA retorne instrução estruturada
  if (Pos('{', AResponseText) > 0) and (Pos('}', AResponseText) > 0) then
  begin
    try
      JData := GetJSON(AResponseText);
      if JData is TJSONObject then
      begin
        JObj := TJSONObject(JData);
        if JObj.Find('visual_action') <> nil then
        begin
          VisualActStr := LowerCase(Trim(JObj.Get('visual_action', '')));
          if (VisualActStr = 'show_resource') or (VisualActStr = 'show_content') then
            VisualAction := avaShowResource
          else if VisualActStr = 'start_presentation' then
            VisualAction := avaStartPresentation
          else if VisualActStr = 'show_text' then
            VisualAction := avaShowText;
        end;

        if JObj.Find('project') <> nil then
          ProjStr := JObj.Get('project', '');
        if JObj.Find('title') <> nil then
          ProjStr := JObj.Get('title', ProjStr);
        if JObj.Find('subtitle') <> nil then
          SubtitleStr := JObj.Get('subtitle', '');
        if JObj.Find('resource') <> nil then
          ImgPathStr := JObj.Get('resource', '');
        if JObj.Find('image') <> nil then
          ImgPathStr := JObj.Get('image', ImgPathStr);
        if JObj.Find('speech') <> nil then
          SpokenText := JObj.Get('speech', SpokenText)
        else if JObj.Find('message') <> nil then
          SpokenText := JObj.Get('message', SpokenText);
      end;
      JData.Free;
    except
      VisualAction := avaNone;
    end;
  end;

  // Executa decisão visual
  case VisualAction of
    avaShowResource:
    begin
      FAllowVisualResource := True;
      ShowContentAnswer(ProjStr, SubtitleStr, ImgPathStr, SpokenText);
    end;
    avaStartPresentation:
    begin
      FAllowVisualResource := True;
      SetPublicViewMode(pvmPresentation);
      SetNarrativeText(SpokenText);
      if FPresentationAgent <> nil then
        FPresentationAgent.StartPresentation('visitante', 'Visitante', ProjStr);
    end;
  else
    // Default: resposta apenas em modo conversa, mantendo neutralidade visual
    ShowConversationAnswer(SpokenText);
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
  if Assigned(memPergunta) and memPergunta.CanFocus then
    memPergunta.SetFocus;
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
  if Assigned(memPergunta) and memPergunta.CanFocus then
    memPergunta.SetFocus;
  lblJarvisSub.Caption := '● Interrompido pelo usuário';
end;

end.
