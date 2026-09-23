unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, ComCtrls, Menus, strutils, chatgpt, setmain, frmconfig,
  aivoicesynthesizer, aivoicerecognizer, aiavatartypes, aiavatar3d, aiinteractioncontext, aiconversationorchestrator, jarvis_api, agent_manager, project_manager;

type

  { Tfrmmain }

  Tfrmmain = class(TForm)
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
    FVoiceSynth: TAIVoiceSynthesizer;
    FAvatar3D: TAIAvatar3D;
    FConversationOrchestrator: TAIConversationOrchestrator;
    FVoiceRecog: TAIVoiceRecognizer;
    FJarvisClient: TJarvisAPIClient;
    FAssistantManager: TAssistantManager;
    FProjectManager: TAssistantProjectManager;
    procedure OnSpeechInterruption(Sender: TObject);
    procedure OnContextProjectChanged(Sender: TObject; const AOldProject, ANewProject: string);
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

procedure Tfrmmain.FormCreate(Sender: TObject);
var
  ImgPath: string;
begin
  FAguardandoResposta := False;
  FVoiceActive := False;

  if FSetMain = nil then
    FSetMain := TSetMain.create();

  FJarvisClient := TJarvisAPIClient.Create(Self);

  // Inicializa componentes de voz
  FVoiceSynth := TAIVoiceSynthesizer.Create(Self);
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

  // Inicializa Avatar 3D (Tarefas 117 e 118)

  // Inicializa Orquestrador de Conversacao Continua e Barge-In
  FConversationOrchestrator := TAIConversationOrchestrator.Create(Self);
  if FAssistantManager <> nil then
    FConversationOrchestrator.Agent := FAssistantManager.Agent;
  FConversationOrchestrator.OnInterruption := @OnSpeechInterruption;
  FConversationOrchestrator.OnProjectChanged := @OnContextProjectChanged;

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
    except
    end;
  end;

  AdicionaMensagemHistorico('Sistema', 'JARVIS Desktop Client inicializado com sucesso no Windows.');
  CheckJarvisOnline();
end;

procedure Tfrmmain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
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

  // Sintetizador
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
  end;

  // Avatar entra em Listening e Thinking (Tarefa 119)
  if FAvatar3D <> nil then
  begin
    FAvatar3D.SetState(avListening);
    FAvatar3D.SetState(avThinking);
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
var
  AudioDlg: TOpenDialog;
begin
  AudioDlg := TOpenDialog.Create(Self);
  try
    AudioDlg.Title := 'Selecione arquivo de voz para transcrever e enviar';
    AudioDlg.Filter := 'Arquivos de Áudio (*.wav;*.mp3)|*.wav;*.mp3|Todos (*.*)|*.*';
    if AudioDlg.Execute then
    begin
      AdicionaMensagemHistorico('Voz', 'Processando áudio: ' + ExtractFileName(AudioDlg.FileName) + '...');
      if FVoiceRecog.Recognize(AudioDlg.FileName) then
      begin
        AdicionaMensagemHistorico('Você (Voz)', FVoiceRecog.RecognizedText);
        ExecutaComandoJarvis(FVoiceRecog.RecognizedText);
      end
      else
      begin
        AdicionaMensagemHistorico('Erro', 'Não foi possível transcrever áudio: ' + FVoiceRecog.LastError);
      end;
    end;
  finally
    AudioDlg.Free;
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

    // Aba Voz
    FormCfg.edFrase.Text := FSetMain.Frase;
    FormCfg.edSynthIP.Text := FSetMain.VoiceSynthIP;
    FormCfg.edSynthPort.Text := IntToStr(FSetMain.VoiceSynthPort);
    FormCfg.edRecogIP.Text := FSetMain.VoiceRecogIP;
    FormCfg.edRecogPort.Text := IntToStr(FSetMain.VoiceRecogPort);
    FormCfg.edVerIP.Text := FSetMain.VerIP;
    FormCfg.edVerPort.Text := IntToStr(FSetMain.VerPort);

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

      FSetMain.Frase := Trim(FormCfg.edFrase.Text);
      FSetMain.VoiceSynthIP := Trim(FormCfg.edSynthIP.Text);
      FSetMain.VoiceSynthPort := StrToIntDef(Trim(FormCfg.edSynthPort.Text), 8096);
      FSetMain.VoiceRecogIP := Trim(FormCfg.edRecogIP.Text);
      FSetMain.VoiceRecogPort := StrToIntDef(Trim(FormCfg.edRecogPort.Text), 8097);
      FSetMain.VerIP := Trim(FormCfg.edVerIP.Text);
      FSetMain.VerPort := StrToIntDef(Trim(FormCfg.edVerPort.Text), 8097);

      // Salva Banco
      FSetMain.HostnameMy := Trim(FormCfg.edMyHost.Text);
      FSetMain.BancoMy := Trim(FormCfg.edMyDb.Text);
      FSetMain.UsernameMy := Trim(FormCfg.edMyUser.Text);
      FSetMain.PasswordMy := Trim(FormCfg.edMyPass.Text);
      FSetMain.HostnamePost := Trim(FormCfg.edPostHost.Text);
      FSetMain.BancoPOST := Trim(FormCfg.edPostDb.Text);
      FSetMain.UsernamePost := Trim(FormCfg.edPostUser.Text);
      FSetMain.PasswordPost := Trim(FormCfg.edPostPass.Text);
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
  if Assigned(FAssistantManager) then
  begin
    FAssistantManager.CancelExecution;
    AdicionaMensagemHistorico('Sistema', '■ Interrupção solicitada pelo usuário.');
  end;
end;

end.
