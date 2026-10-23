unit main;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, LCLType, chatgpt, setmain, frmconfig, jarvis_api, agent_manager,
  reception_core, aiagent_memorymap, aiagent_flowevents, voice_input_bridge,
  professor_listener, professor_state, professor_view,
  webcam_vision, vision_types, aikinectsensor, aikinect_types, professor_catalog,
  professor_ui, professor_commands, fpjson, assistant_integration_protocol,
  assistant_integration_server, assistant_integration_jobs, presentation_package,
  presentation_media, presentation_tags, presentation_joints;
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
    FPresentationMedia: TPresentationMedia;
    FPresentationRoot: string;
    FPresentationMode,FPresentationAvatarChanged: Boolean;
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
    FChatPanel, FProfilePanel, FPresentationPanel: TPanel;
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
    procedure StartPresentation(const FileName: string);
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
uses professor_settings, Math, FileUtil, LazFileUtils, LazUTF8;
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
  FIntegrationJobs:=TIntegrationJobs.Create;
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
  ConfigureIntegration;
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
  FPresentationPanel.SetBounds(14,40,Max(1,FChatPanel.Width-28),Max(1,H-54));
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
  FreeAndNil(FIntegration);
  if Assigned(FContinuousListener) then FContinuousListener.Stop;
  if Assigned(FVoiceInput) then FVoiceInput.Cancel;
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
  FreeAndNil(FIntegrationJobs);
end;

procedure Tfrmmain.FormShow(Sender: TObject);
begin
  if not FShown then
  begin
    FShown := True;
    IniciarEscuta;
    IniciarVideo;
    FProfessor.Gesture(psWave);
    try
      if (ParamStrUTF8(1)='--presentation') or (ParamStrUTF8(1)='--presentation-silent') then begin
        if ParamCount<>2 then raise Exception.Create('Informe um arquivo .pva');
        StartPresentation(ParamStrUTF8(2));
      end else if SameText(ExtractFileExt(ParamStrUTF8(1)),'.pva') then StartPresentation(ParamStrUTF8(1));
    except on E: Exception do begin FinishPresentation;MessageDlg(E.Message,mtError,[mbOK],0);end;end;
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
  if (Trim(ATexto)='') or (not FSetMain.AutoSpeak and (Script.CommandCount+Script.PresentationCount+Script.JointCount=0) and not FPresentationMode) then begin RetomarEscuta;Exit;end;
  PausarEscuta;
  C := Default(TReceptionConfig);
  C.EnableAvatarCommands:=True;
  C.EnablePresentationCommands:=FPresentationMode;
  C.SilentPresentation:=not FSetMain.AutoSpeak or (ParamStrUTF8(1)='--presentation-silent');
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

function Tfrmmain.ActivePresentationMedia: string;
begin if FPresentationMedia=nil then Result:='' else Result:=FPresentationMedia.Active;end;

function Tfrmmain.ApresentandoResposta: Boolean;
begin Result:=Assigned(FSpeechJob);end;

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
procedure Tfrmmain.StartPresentation(const FileName: string);
var P: TPVAPackage; G: TGUID; Script: TAvatarScript; I: Integer;
begin
  if Assigned(FSpeechJob) or FAguardandoResposta then raise Exception.Create('Assistente ocupado');
  FinishPresentation;
  P:=TPVAPackage.Create;
  try
    try
    P.Load(FileName);
    Script:=ParseAvatarScript(P.Script,4096);
    for I:=0 to High(Script.Steps) do
      if (Script.Steps[I].Presentation.Action=paSelectAvatar) and
        (FCatalog.IndexOfID(Script.Steps[I].Presentation.Argument)<0) then
        raise Exception.Create('Avatar nao instalado: '+Script.Steps[I].Presentation.Argument);
    if FSetMain.AutoSpeak and (FSetMain.SynthEngine=2) then raise Exception.Create('Apresentacoes com pausa requerem SAPI ou voz remota no Windows');
    CreateGUID(G);
    FPresentationRoot:=IncludeTrailingPathDelimiter(GetTempDir(False))+'assistente-pva-'+GUIDToString(G);
    P.ExtractTo(FPresentationRoot);FPresentationMedia:=TPresentationMedia.Create(FPresentationRoot,FPresentationPanel);
    FPresentationMedia.OnVisualChange:=@PresentationVisualChange;
    FPresentationMode:=True;PausarEscuta;FProfessor.ResetCommands;
    FalarResposta(P.Script);
    if FSpeechJob=nil then FinishPresentation;
    except FinishPresentation;raise;end;
  finally P.Free;end;
end;
procedure Tfrmmain.PresentationVisualChange(Sender: TObject);
var HasVisual: Boolean;
begin
  HasVisual:=(FPresentationMedia<>nil) and (FPresentationMedia.Active<>'');
  FPresentationPanel.Visible:=HasVisual;
  FChat.Visible:=not HasVisual;FInputCard.Visible:=not HasVisual;
  FSendButton.Visible:=not HasVisual;btConfig.Visible:=not HasVisual;
  if HasVisual then begin
    lblAssistente.Caption:='Apresentação';
    FPresentationPanel.BringToFront;
  end else lblAssistente.Caption:='Conversa';
end;

procedure Tfrmmain.FinishPresentation;
begin
  FreeAndNil(FPresentationMedia);FPresentationMode:=False;
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
  FPresentationRoot:='';
end;
procedure Tfrmmain.CancelarApresentacao(Sender: TObject; var Key: Word; Shift: TShiftState);
var Paused: Boolean;
begin
  if not Assigned(FSpeechJob) then Exit;
  if FPresentationMode and (Key=Ord('P')) and (Shift=[]) then begin
    Paused:=not FSpeechJob.Paused;FSpeechJob.SetPaused(Paused);
    TPresentationScene(FProfessor.Scene).PauseJoints(Paused);
    FProfessor.SetRenderingActive(not Paused);
    try FPresentationMedia.SetPaused(Paused);
    except on E: Exception do begin FSpeechJob.Cancel;lblStatus.Caption:=E.Message;end;end;
    if Paused then lblStatus.Caption:='Apresentacao pausada (P retoma; Esc cancela)';
    Key:=0;Exit;
  end;
  if Key=VK_ESCAPE then begin
    FSpeechJob.Cancel;FProfessor.ResetCommands;Key:=0;
    if FPresentationMode then FinishPresentation;
    lblStatus.Caption:='Interrompendo apresentacao...';
  end;
end;

procedure Tfrmmain.TimerTick(Sender: TObject);
var Ok: Boolean; Err: string; Command: TAvatarScriptStep;
begin
  if FClosing then Exit;
  if Assigned(FIntegration) then FIntegration.Pump;
  FAvatarStatus.Caption := 'Avatar: ' + FProfessor.ActivityLabel;
  if FProfessor.ModelFile <> '' then FRenderStatus.Caption := 'Renderização 3D'
  else FRenderStatus.Caption := '3D indisponível';
  FRenderStatus.Hint := FDeviceStatus.Caption;
  FRenderStatus.ShowHint := True;
  if not Assigned(FSpeechJob) then Exit;
  if not FSpeechJob.Done then
  begin
    if FSpeechJob.Paused then begin FProfessor.SetActivity(psIdle);end
    else if FSpeechJob.PlaybackActive then
    begin FProfessor.SetActivity(psSpeaking); lblStatus.Caption := 'Falando...'; end
    else if FSpeechJob.IsSilent then FProfessor.SetActivity(psIdle)
    else FProfessor.SetActivity(psThinking);
  end;
  while FSpeechJob.TakeScriptCommand(Command) do begin
    try
      if FSpeechJob.PlaybackActive then FProfessor.SetActivity(psSpeaking);
      if FPresentationMode and (Command.Presentation.Action=paSelectAvatar) then
        SelectPresentationAvatar(Command.Presentation.Argument)
      else if FPresentationMode and (Command.Presentation.Action=paSelectVoice) then
        begin { voice is selected by the speech worker before synthesis } end
      else if FPresentationMode and (Command.Presentation.Action<>paNone) then FPresentationMedia.Execute(Command.Presentation)
      else if FPresentationMode and (Command.Joint.Bone<>'') then TPresentationScene(FProfessor.Scene).ExecuteJoint(Command.Joint)
      else FProfessor.ExecuteCommand(Command.Command);
    except on E: Exception do begin FSpeechJob.ErrorText:=E.Message;FSpeechJob.Cancel;end;end;
    FSpeechJob.ConfirmAvatarCommand;
  end;
  if not FSpeechJob.Done then Exit;
  if FPresentationMode and not FSpeechJob.Cancelled and FSpeechJob.Success then begin
    FProfessor.SetActivity(psIdle);
    try
      if FPresentationMedia.TimedPlaybackActive then begin
        if not FSpeechJob.Paused then lblStatus.Caption:='Reproduzindo midia... (P pausa; Esc cancela)';
        Exit;
      end;
    except on E: Exception do begin FSpeechJob.ErrorText:=E.Message;FSpeechJob.Cancel;end;end;
  end;
  Ok := FSpeechJob.Success;
  Err := FSpeechJob.ErrorText;
  if FSpeechJob.Cancelled and (Err='') then Err:='Apresentação cancelada';
  FreeAndNil(FSpeechJob);
  if FPresentationMode then FinishPresentation;
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
  FConfigOpen:=True;
  FContinuousListener.Stop;
  PararVideo;
  FProfessor.SetRenderingActive(False);
  F:=nil;
  try
    F := TfrmConfig.Create(Self);
    LoadProfessorSettings(F, FSetMain);
    F.IntegrationUI.Status.Caption:=FIntegrationStatus;
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

function Tfrmmain.IntegrationBusy:Boolean;
begin Result:=FClosing or FConfigOpen or FAguardandoResposta or Assigned(FSpeechJob) or FVoiceInput.Busy;end;

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
var RequestAction,RequestText,ID:string;Data:TJSONData;Items:TJSONArray;O:TJSONObject;I:Integer;Command:TAvatarCommand;
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
  for Command:=Succ(Low(TAvatarCommand)) to High(TAvatarCommand) do
    if (ID=AvatarCommandName(Command)) or ((Ord(Command)<=High(Commands)) and (ID=Commands[Ord(Command)])) then begin
      if FProfessor.ExecuteCommand(Command) then Response:=IntegrationOK(TJSONObject.Create(['accepted',True]))
      else Response:=IntegrationError('unsupported_gesture');Exit;
    end;
  Response:=IntegrationError('invalid_command');
end;

end.
