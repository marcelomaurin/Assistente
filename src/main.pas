unit main;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, LCLType, chatgpt, setmain, frmconfig, jarvis_api, agent_manager,
  reception_core, aiagent_memorymap, aiagent_flowevents, voice_input_bridge,
  professor_listener, professor_state, professor_view,
  webcam_vision, vision_types, aikinectsensor, aikinect_types, professor_catalog,
  professor_ui, professor_commands, remote_stt_server;
type
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
    FAssistantManager: TAssistantManager;
    FJarvisClient: TJarvisAPIClient;
    FSpeechJob: TReceptionJob;
    FVoiceInput: TVoiceInputBridge;
    FRemoteSTT: TRemoteSTTServer;
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
    FChatPanel, FProfilePanel: TPanel;
    FAvatarCard, FInputCard: TRoundedCard;
    FChat: TConversationView;
    FSendButton: TSpeedButton;
    FAvatarStatus, FAIStatus, FRenderStatus: TLabel;
    FAIConnected: Boolean;
    FMicButton, FWaveButton, FWalkButton: TSpeedButton;
    FDeviceStatus: TLabel;
    FVideoPanel: TPanel;
    FVideoPreview: TImage;
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
    procedure FalarResposta(const ATexto: string);
    function ApresentandoResposta: Boolean;
    procedure ReloadAvatars(Sender: TObject);
    property AssistantManager: TAssistantManager read FAssistantManager;
    property VoiceInput: TVoiceInputBridge read FVoiceInput;
  end;
var frmmain: Tfrmmain;
implementation
uses professor_settings, Math;
{$R *.lfm}

procedure Tfrmmain.FormCreate(Sender: TObject);
begin
  if FSetMain = nil then FSetMain := TSetMain.Create;
  FSetMain.CarregaContexto;
  FCatalog := TAvatarCatalog.Create;
  CriarControles;
  FProfessor := TProfessorView.Create(Self, pnlAvatar);
  FJarvisClient := TJarvisAPIClient.Create(Self);
  FAssistantManager := TAssistantManager.Create(Self);
  FAssistantManager.JarvisClient := FJarvisClient;
  FAssistantManager.OnStateChange := @OnAgentStateChange;
  FAssistantManager.OnComplete := @OnAgentComplete;
  FMemoryMap := TAIAgentMemoryMap.Create(Self);
  InicializarMemoria;
  FRemoteSTT := TRemoteSTTServer.Create(18765);
  FRemoteSTT.OnText := @RemoteVoiceText;
  FRemoteSTT.Start;
  FVoiceInput := TVoiceInputBridge.Create(Self);
  FVoiceInput.OnText := @VoiceText;
  FVoiceInput.OnState := @VoiceState;
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
end;

procedure Tfrmmain.CriarControles;
begin
  Caption := 'Professor Virtual — Lazarus';
  Constraints.MinWidth := 740;
  Constraints.MinHeight := 450;
  pnlRoot.Color := $00F6F6F6;
  pnlConteudo.Color := $00F6F6F6;
  pnlEntrada.Height := 40;
  pnlEntrada.Color := $00F6F6F6;
  pnlHeader.Visible := False;
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
  FProfilePanel.Height := 28;
  FProfilePanel.BevelOuter := bvNone;
  FProfilePanel.Color := clWhite;
  FProfileCombo := TComboBox.Create(Self);
  FProfileCombo.Parent := FProfilePanel;
  FProfileCombo.Style := csDropDownList;
  FProfileCombo.Font.Size := 8;
  ReloadAvatars(nil);
  FReloadButton := TSpeedButton.Create(Self);
  FReloadButton.Parent := FProfilePanel;
  FReloadButton.Caption := '↻';
  FReloadButton.Flat := True;
  FReloadButton.Hint := 'Atualizar modelos da pasta AVATARES';
  FReloadButton.ShowHint := True;
  FReloadButton.OnClick := @ReloadAvatars;
  FChatPanel := TPanel.Create(Self);
  FChatPanel.Parent := pnlConteudo;
  FChatPanel.BevelOuter := bvNone;
  FChatPanel.Color := clWhite;
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
  FInputCard := TRoundedCard.Create(Self);
  FInputCard.Parent := FChatPanel;
  FInputCard.Color := clWhite;
  edPergunta.Parent := FInputCard;
  edPergunta.BorderStyle := bsNone;
  edPergunta.Color := clWhite;
  edPergunta.Font.Height := -13;
  edPergunta.TextHint := 'Digite sua pergunta...';
  edPergunta.Anchors := [akLeft,akTop,akRight];
  FSendButton := TSpeedButton.Create(Self);
  FSendButton.Parent := FChatPanel;
  FSendButton.Flat := True;
  FSendButton.Hint := 'Enviar pergunta';
  FSendButton.ShowHint := True;
  FSendButton.OnClick := @btEnviarClick;
  SetLineIcon(FSendButton, 'send', $00707070);
  btConfig.Parent := FChatPanel;
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
  FVideoPanel := TPanel.Create(Self);
  FVideoPanel.Parent := pnlAvatar;
  FVideoPanel.Align := alBottom;
  FVideoPanel.Height := 100;
  FVideoPanel.BevelOuter := bvNone;
  FVideoPanel.Visible := False;
  FVideoPreview := TImage.Create(Self);
  FVideoPreview.Parent := FVideoPanel;
  FVideoPreview.Align := alClient;
  FVideoPreview.Proportional := True;
  FVideoPreview.Center := True;
  OnResize := @LayoutProfessor;
  LayoutProfessor(nil);
end;

procedure Tfrmmain.LayoutProfessor(Sender: TObject);
var W, H, LeftWidth, ComposerWidth, CardWidth: Integer;
begin
  if FClosing or not Assigned(FRenderStatus) then Exit;
  W := ClientWidth;
  H := pnlConteudo.ClientHeight;
  LeftWidth := W div 3;
  FAvatarCard.SetBounds(14, 8, LeftWidth-22, H-46);
  FMicButton.SetBounds(14, H-34, LeftWidth-22, 28);
  FChatPanel.SetBounds(LeftWidth, 0, W-LeftWidth, H);
  lblAssistente.SetBounds(14, 12, FChatPanel.Width-28, 22);
  FChat.SetBounds(14, 40, FChatPanel.Width-28, Max(60,H-130));
  ComposerWidth := FChat.ContentWidth;
  FInputCard.SetBounds(14, H-80, ComposerWidth, 36);
  edPergunta.SetBounds(10, 9, ComposerWidth-20, 22);
  FSendButton.SetBounds(14+ComposerWidth-52, H-40, 24, 26);
  btConfig.SetBounds(14+ComposerWidth-26, H-40, 24, 26);
  CardWidth := FAvatarCard.Width-8;
  FProfileCombo.SetBounds(6, 2, Max(100,CardWidth-102), 24);
  FReloadButton.SetBounds(CardWidth-92, 1, 28, 25);
  FWaveButton.SetBounds(CardWidth-62, 1, 28, 25);
  FWalkButton.SetBounds(CardWidth-32, 1, 28, 25);
  FAvatarStatus.SetBounds(12, 13, LeftWidth-20, 16);
  FAIStatus.SetBounds(W div 3, 13, W div 3, 16);
  FRenderStatus.SetBounds(W-180, 13, 168, 16);
end;

procedure Tfrmmain.FormDestroy(Sender: TObject);
begin
  FClosing := True;
  if Assigned(FTimer) then FTimer.Enabled := False;
  if Assigned(FRemoteSTT) then FreeAndNil(FRemoteSTT);
  if Assigned(FContinuousListener) then FContinuousListener.Stop;
  if Assigned(FVoiceInput) then FVoiceInput.Cancel;
  if Assigned(FAssistantManager) then
  begin
    FAssistantManager.OnComplete := nil;
    FAssistantManager.OnStateChange := nil;
    FreeAndNil(FAssistantManager);
  end;
  if Assigned(FSpeechJob) then begin FSpeechJob.Cancel; FreeAndNil(FSpeechJob); end;
  PararVideo;
  SalvarMemoria;
  FreeAndNil(FProfessor);
  FreeAndNil(FCatalog);
end;

procedure Tfrmmain.FormShow(Sender: TObject);
begin
  if not FShown then
  begin
    FShown := True;
    IniciarEscuta;
    IniciarVideo;
    FProfessor.Gesture(psWave);
  end;
  if edPergunta.CanFocus then edPergunta.SetFocus;
end;

procedure Tfrmmain.IniciarEscuta;
begin
  FMicButton.Caption := 'Microfone pausado';
  if not FSetMain.ContinuousListening or FMicMuted or FClosing then Exit;
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
  if Assigned(FContinuousListener) and FContinuousListener.Enabled then FContinuousListener.Pause;
end;

procedure Tfrmmain.RetomarEscuta;
begin
  if FClosing or FAguardandoResposta or Assigned(FSpeechJob) or FVoiceInput.Busy then Exit;
  FProfessor.SetActivity(psIdle);
  if FMicMuted then Exit;
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
  PausarEscuta;
  ProcessarEntrada(AText);
end;

procedure Tfrmmain.VoiceText(Sender: TObject; const AText: string);
begin
  if not FClosing then ProcessarEntrada(AText);
end;

procedure Tfrmmain.VoiceState(Sender: TObject; const AState: string);
begin
  if FClosing or FAguardandoResposta or Assigned(FSpeechJob) then Exit;
  SetEstado(AState, False);
  if FVoiceInput.Busy then FProfessor.SetActivity(psThinking)
  else if (Pos('Falha', AState) = 1) or (Pos('Nenhuma', AState) = 1) then RetomarEscuta;
end;

procedure Tfrmmain.InicializarMemoria;
begin
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
end;

procedure Tfrmmain.EnviarPergunta;
begin ProcessarEntrada(edPergunta.Text); end;

procedure Tfrmmain.ProcessarEntrada(const ATexto: string);
var P, H, C: string;
begin
  if FClosing or FAguardandoResposta or Assigned(FSpeechJob) or FVoiceInput.Busy then Exit;
  P := Trim(ATexto);
  if P = '' then begin RetomarEscuta; Exit; end;
  PausarEscuta;
  FProfessor.ResetCommands;
  FCurrentUserText := P;
  H := Trim(FMemoryMap.BuildConversationContext(100));
  if H <> '' then C := 'Historico completo da conversa anterior:' + sLineBreak + H +
    sLineBreak + 'Nova fala do usuario:' + sLineBreak + P + sLineBreak +
    'Analise a nova fala considerando o historico e responda mantendo o contexto.'
  else C := P;
  FMemoryItem := FMemoryMap.BeginAgentStep('Assistente', tamOrquestrador, P, H);
  memResposta.Lines.Add('Você: ' + P);
  FChat.AddMessage(P, True);
  memResposta.Lines.Add('');
  edPergunta.Clear;
  FProfessor.SetActivity(psThinking);
  SetEstado('Pensando...', True);
  try FAssistantManager.ProcessUserRequestAsync(C);
  except on E: Exception do
    begin
      if Assigned(FMemoryItem) then
      begin
        FMemoryItem.Erro := E.Message;
        FMemoryMap.EndAgentStep(FMemoryItem, 'Falha ao enviar pergunta', E.Message, 'erro', '', '');
        SalvarMemoria;
        FMemoryItem := nil;
      end;
      SetEstado('Erro. Pronto para nova tentativa', False);
      RetomarEscuta;
    end;
  end;
end;

procedure Tfrmmain.FalarResposta(const ATexto: string);
var C: TReceptionConfig; Script: TAvatarScript;
begin
  if FClosing or Assigned(FSpeechJob) then Exit;
  Script:=ParseAvatarScript(ATexto);
  if (Trim(ATexto)='') or (not FSetMain.AutoSpeak and (Script.CommandCount=0)) then begin RetomarEscuta;Exit;end;
  PausarEscuta;
  C := Default(TReceptionConfig);
  C.EnableAvatarCommands:=True;
  C.SilentPresentation:=not FSetMain.AutoSpeak;
  C.Token := FSetMain.CHATGPT;
  C.AudioToken := FSetMain.VoiceAPIToken;
  if C.AudioToken = '' then C.AudioToken := FSetMain.CHATGPT;
  C.Model := FSetMain.VoiceModel;
  C.URL := FSetMain.VoiceEndpoint;
  C.Language := FSetMain.VoiceLanguage;
  C.Voice := FSetMain.SynthVoice;
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

function Tfrmmain.ApresentandoResposta: Boolean;
begin Result:=Assigned(FSpeechJob);end;

procedure Tfrmmain.CancelarApresentacao(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key=VK_ESCAPE) and Assigned(FSpeechJob) then
  begin
    FSpeechJob.Cancel;FProfessor.ResetCommands;Key:=0;
    lblStatus.Caption:='Interrompendo apresentação...';
  end;
end;

procedure Tfrmmain.TimerTick(Sender: TObject);
var Ok: Boolean; Err: string; Command: TAvatarCommand;
begin
  if FClosing then Exit;
  FAvatarStatus.Caption := 'Avatar: ' + FProfessor.ActivityLabel;
  if FProfessor.ModelFile <> '' then FRenderStatus.Caption := 'Renderização 3D'
  else FRenderStatus.Caption := '3D indisponível';
  FRenderStatus.Hint := FDeviceStatus.Caption;
  FRenderStatus.ShowHint := True;
  if not Assigned(FSpeechJob) then Exit;
  if not FSpeechJob.Done then
  begin
    if FSpeechJob.PlaybackActive then
    begin FProfessor.SetActivity(psSpeaking); lblStatus.Caption := 'Falando...'; end
    else if FSpeechJob.IsSilent then FProfessor.SetActivity(psIdle)
    else FProfessor.SetActivity(psThinking);
  end;
  while FSpeechJob.TakeAvatarCommand(Command) do
    try
      if not FSpeechJob.IsSilent then FProfessor.SetActivity(psSpeaking);
      FProfessor.ExecuteCommand(Command);
    finally FSpeechJob.ConfirmAvatarCommand;end;
  if not FSpeechJob.Done then Exit;
  Ok := FSpeechJob.Success;
  Err := FSpeechJob.ErrorText;
  if FSpeechJob.Cancelled then Err:='Apresentação cancelada';
  FreeAndNil(FSpeechJob);
  SetEstado('Pronto para conversar', False);
  RetomarEscuta;
  if not Ok then begin FProfessor.ResetCommands;lblStatus.Caption := Err;end;
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
  FContinuousListener.Stop;
  PararVideo;
  FProfessor.SetRenderingActive(False);
  F:=nil;
  try
    F := TfrmConfig.Create(Self);
    LoadProfessorSettings(F, FSetMain);
    if F.ShowModal = mrOk then
    begin
      SaveProfessorSettings(F, FSetMain);
      FSetMain.SalvaContexto(False);
      AplicarConfiguracao;
    end;
  finally F.Free;FProfessor.SetRenderingActive(True);IniciarEscuta;IniciarVideo;end;
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
var T, Annotated: string; Script: TAvatarScript;
begin
  if FClosing then Exit;
  Annotated:=Trim(AResponseText);
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
  FAIConnected := ASuccess;
  memResposta.Lines.Add('');
  SetEstado('Pronto para conversar', False);
  if ASuccess then FalarResposta(Annotated) else RetomarEscuta;
  FCurrentUserText := '';
end;

procedure Tfrmmain.PararVideo;
begin
  FreeAndNil(FCamera);
  FreeAndNil(FKinect);
  if Assigned(FVideoPanel) then FVideoPanel.Visible := False;
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
        FVideoPanel.Visible := True;
        if FCamera.OpenDevice(FSetMain.CameraDevice, FVideoPanel, FVideoPreview) then Status := 'Câmera RGB ativa'
        else begin Status := 'Câmera indisponível: ' + FCamera.LastError; FVideoPanel.Visible := False; end;
      except on E: Exception do begin Status := 'Câmera: ' + E.Message; FVideoPanel.Visible := False; end; end;
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
end.
