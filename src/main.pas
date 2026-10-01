
Unit main;
{$mode objfpc}{$H+}

Interface

Uses Classes,SysUtils,Forms,Controls,Graphics,Dialogs,ExtCtrls,StdCtrls,Buttons,LCLType,IntfGraphics
,FPReadGif,chatgpt,setmain,frmconfig,jarvis_api,agent_manager,reception_core,aiagent_memorymap,
aiagent_flowevents,voice_input_bridge,aiaudio,aicontinuouslistener;

Type
  Tfrmmain = Class(TForm)
    pnlRoot,pnlHeader,pnlConteudo,pnlAvatar,pnlEntrada: TPanel;
    lblTitulo,lblStatus,lblAssistente: TLabel;
    btConfig: TSpeedButton;
    GifAvatar: TImage;
    memResposta: TMemo;
    edPergunta: TEdit;
    btEnviar: TButton;
    Procedure FormCreate(Sender:TObject);
    Procedure FormDestroy(Sender:TObject);
    Procedure FormShow(Sender:TObject);
    Procedure btConfigClick(Sender:TObject);
    Procedure btEnviarClick(Sender:TObject);
    Procedure edPerguntaKeyDown(Sender:TObject;Var Key:Word;Shift:TShiftState);
    Private
      FAssistantManager: TAssistantManager;
      FJarvisClient: TJarvisAPIClient;
      FSpeechJob: TReceptionJob;
      FVoiceInput: TVoiceInputBridge;
      FAudioInput: TAIAudioInput;
      FContinuousListener: TAIContinuousListener;
      FMemoryMap: TAIAgentMemoryMap;
      FMemoryItem: TAIAgentMemoryMapItem;
      FHistoryFile,FCurrentUserText: string;
      FSpeechTimer: TTimer;
      FClosing,FConfiguring: Boolean;
      FAguardandoResposta: Boolean;
      Procedure SpeechTick(Sender:TObject);
      Procedure VoiceFinished(Sender:TObject);
      Function Ocupado: Boolean;
      Procedure AplicarConfiguracao;
      Procedure CarregarAvatarEstatico;
      Procedure InicializarMemoria;
      Procedure SalvarMemoria;
      Procedure EnviarPergunta;
      Procedure ProcessarEntrada(Const ATexto:String);
      Procedure VoiceText(Sender:TObject;Const AText:String);
      Procedure VoiceState(Sender:TObject;Const AState:String);
      Procedure SpeechReady(Sender:TObject;Const AFileName:String);
      Procedure ListenerState(Sender:TObject;AState:TAIListenerState);
      Procedure IniciarEscuta;
      Procedure PausarEscuta;
      Procedure RetomarEscuta;
      Procedure FalarResposta(Const ATexto:String);
      Procedure SetEstado(Const ATexto:String;AOcupado:Boolean);
      Procedure OnAgentStateChange(Sender:TObject;AState:TAgentState;Const ADescription:String);
      Procedure OnAgentComplete(Sender:TObject;Const AResponseText,AProvider:String;ASuccess:Boolean
      );
    Public property AssistantManager: TAssistantManager read FAssistantManager;
      property VoiceInput: TVoiceInputBridge read FVoiceInput;
  End;

Var frmmain: Tfrmmain;

Implementation

Uses config_binding;
{$R *.lfm}
Procedure Tfrmmain.FormCreate(Sender:TObject);
Begin
  FClosing := False;
  FConfiguring := False;
  FSpeechTimer := TTimer.Create(Self);
  FSpeechTimer.Enabled := False;
  FSpeechTimer.Interval := 50;
  FSpeechTimer.OnTimer := @SpeechTick;
  FAguardandoResposta := False;
  FSpeechJob := Nil;
  FMemoryItem := Nil;
  If FSetMain=Nil Then FSetMain := TSetMain.Create;
  FSetMain.CarregaContexto;
  FJarvisClient := TJarvisAPIClient.Create(Self);
  FAssistantManager := TAssistantManager.Create(Self);
  FAssistantManager.JarvisClient := FJarvisClient;
  FAssistantManager.OnStateChange := @OnAgentStateChange;
  FAssistantManager.OnComplete := @OnAgentComplete;
  FMemoryMap := TAIAgentMemoryMap.Create(Self);
  InicializarMemoria;
  FVoiceInput := TVoiceInputBridge.Create(Self);
  FVoiceInput.OnText := @VoiceText;
  FVoiceInput.OnState := @VoiceState;
  FVoiceInput.OnFinished := @VoiceFinished;
  FAudioInput := TAIAudioInput.Create(Self);
  FContinuousListener := TAIContinuousListener.Create(Self);
  FContinuousListener.AudioInput := FAudioInput;
  FContinuousListener.OnSpeechReady := @SpeechReady;
  FContinuousListener.OnStateChange := @ListenerState;
  AplicarConfiguracao;
  CarregarAvatarEstatico;
  SetEstado('Pronto para conversar',False);
End;
Procedure Tfrmmain.FormDestroy(Sender:TObject);
Begin
  FClosing := True;
  FSpeechTimer.Enabled := False;
  FAssistantManager.OnComplete := Nil;
  FAssistantManager.OnStateChange := Nil;
  FreeAndNil(FAssistantManager);
  If Assigned(FContinuousListener) Then FContinuousListener.Stop;
  If Assigned(FVoiceInput) Then
    Begin
      FVoiceInput.OnText := Nil;
      FVoiceInput.OnState := Nil;
      FVoiceInput.OnFinished := Nil;
      FVoiceInput.Cancel;
    End;
  SalvarMemoria;
  If Assigned(FSpeechJob) Then
    Begin
      FSpeechJob.Cancel;
      FreeAndNil(FSpeechJob);
    End;
End;
Procedure Tfrmmain.FormShow(Sender:TObject);
Begin
  edPergunta.Text := '';
  IniciarEscuta;
  edPergunta.SetFocus;
End;
Procedure Tfrmmain.IniciarEscuta;
Begin
  If Not FSetMain.ContinuousListening Then Exit;
  FAudioInput.InputSource := asMic;
  FAudioInput.SampleRate := FSetMain.AudioSampleRate;
  FAudioInput.Channels := FSetMain.AudioChannels;
  FAudioInput.DurationLimit := 0;
  FContinuousListener.VoiceThreshold := FSetMain.VoiceThreshold;
  FContinuousListener.SilenceTimeoutMs := FSetMain.SilenceTimeoutMs;
  FContinuousListener.MinSpeechMs := FSetMain.MinSpeechMs;
  FContinuousListener.MaxSpeechMs := FSetMain.MaxSpeechMs;
  FContinuousListener.EchoSuppressionEnabled := FSetMain.EchoSuppressionEnabled;
  FContinuousListener.SelfAudioCorrelationThreshold := FSetMain.SelfAudioCorrelationThreshold;
  FContinuousListener.Start;
End;
Procedure Tfrmmain.PausarEscuta;
Begin
  If Assigned(FContinuousListener) And FContinuousListener.Enabled Then FContinuousListener.Pause;
End;
Procedure Tfrmmain.RetomarEscuta;
Begin
  If FClosing Or FConfiguring Or Ocupado Or Not FSetMain.ContinuousListening Then Exit;
  If Assigned(FContinuousListener) And FContinuousListener.Enabled Then FContinuousListener.Resume;
End;
Procedure Tfrmmain.SpeechReady(Sender:TObject;Const AFileName:String);
Begin
  PausarEscuta;
  If FClosing Or FConfiguring Or Ocupado Then
    Begin
      DeleteFile(AFileName);
      Exit;
    End;
  Try
    If Not FVoiceInput.TranscribeWav(AFileName) Then
      Begin
        DeleteFile(AFileName);
        RetomarEscuta;
      End;
  Except
    on E: Exception Do
          Begin
            DeleteFile(AFileName);
            lblStatus.Caption := 'Falha na transcricao: '+E.Message;
            RetomarEscuta;
          End;
End;
End;
Function Tfrmmain.Ocupado: Boolean;
Begin
  Result := FAguardandoResposta Or Assigned(FSpeechJob) Or (Assigned(FVoiceInput) And FVoiceInput.
            Busy);
End;
Procedure Tfrmmain.VoiceFinished(Sender:TObject);
Begin
  RetomarEscuta;
End;
Procedure Tfrmmain.SpeechTick(Sender:TObject);

Var E: string;
Begin
  If Not Assigned(FSpeechJob) Then
    Begin
      FSpeechTimer.Enabled := False;
      Exit;
    End;
  If Not FSpeechJob.Done Then Exit;
  E := FSpeechJob.ErrorText;
  FreeAndNil(FSpeechJob);
  FSpeechTimer.Enabled := False;
  SetEstado('Pronto para conversar',False);
  RetomarEscuta;
  If E<>'' Then lblStatus.Caption := 'Falha na voz: '+E;
End;
Procedure Tfrmmain.ListenerState(Sender:TObject;AState:TAIListenerState);
Begin
  If FClosing Or Ocupado Then Exit;
  Case AState Of
    lsListening: lblStatus.Caption := 'Ouvindo...';
    lsSpeech: lblStatus.Caption := 'Escutando fala...';
    lsSilence: lblStatus.Caption := 'Aguardando fim da fala...';
    lsPaused: lblStatus.Caption := 'Microfone pausado';
    lsError: lblStatus.Caption := 'Erro no microfone';
  End;
End;
Procedure Tfrmmain.VoiceText(Sender:TObject;Const AText:String);
Begin
  ProcessarEntrada(AText);
End;
Procedure Tfrmmain.VoiceState(Sender:TObject;Const AState:String);
Begin
  If Not FAguardandoResposta Then lblStatus.Caption := AState;
End;
Procedure Tfrmmain.InicializarMemoria;

Var B, LegacyFile: string;
Begin
  B := ReceptionDataDir;
  FHistoryFile := B+'conversation-history.json';
  LegacyFile := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName))+
    'conversation-history.json';
  FMemoryMap.MaxItems := 100;
  FMemoryMap.StoreFullPrompt := True;
  FMemoryMap.StoreFullResponse := True;
  FMemoryMap.DetectInformationLoss := True;
  FMemoryMap.RedactSensitiveData := True;
  If FileExists(FHistoryFile) Then
    Try
      FMemoryMap.LoadFromFile(FHistoryFile);
    Except
      FMemoryMap.StartFlow('','Assistente','usuario','interface');
End
Else if FileExists(LegacyFile) then FMemoryMap.LoadFromFile(LegacyFile)
Else FMemoryMap.StartFlow('','Assistente','usuario','interface');
End;
Procedure Tfrmmain.SalvarMemoria;
Begin
  If (FMemoryMap=Nil) Or (FHistoryFile='') Then Exit;
  Try
    FMemoryMap.SaveToFile(FHistoryFile);
  Except
End;
End;
Procedure Tfrmmain.AplicarConfiguracao;
Begin
  If (FSetMain=Nil) Or (FAssistantManager=Nil) Then Exit;
  FAssistantManager.ChatGPT.TOKEN := FSetMain.CHATGPT;
  If (FSetMain.ChatGPTProvider>=0) And (FSetMain.ChatGPTProvider<=Ord(High(TAIProvider))) Then
    FAssistantManager.ChatGPT.Provider := TAIProvider(FSetMain.ChatGPTProvider)
  Else FAssistantManager.ChatGPT.Provider := AIP_OPENAI;
  FAssistantManager.ChatGPT.CustomModel := FSetMain.ChatGPTModel;
  FAssistantManager.ChatGPT.URL := FSetMain.ChatGPTURL;
  FAssistantManager.ChatGPT.Timeout := 30000;
  FAssistantManager.KnowledgeFolder := IncludeTrailingPathDelimiter(ExtractFilePath(Application.
                                       ExeName))+'knowledge';
  FJarvisClient.BaseURL := FSetMain.JarvisURL;
  FJarvisClient.APIKey := FSetMain.JarvisAPIKey;
End;
Procedure Tfrmmain.CarregarAvatarEstatico;

Var B,F: string;
  Img: TLazIntfImage;
Begin
  B := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  F := ExpandFileName(B+'..'+PathDelim+'img'+PathDelim+'robo-start.gif');
  If Not FileExists(F) Then F := ExpandFileName(B+'img'+PathDelim+'robo-start.gif');
  If FileExists(F) Then
    Begin
      Img := TLazIntfImage.Create(0,0);
      Try
        Try
          Img.LoadFromFile(F);
          GifAvatar.Picture.Bitmap.LoadFromIntfImage(Img);
          GifAvatar.Visible := True;
        Except
          GifAvatar.Visible := False;
    End;
Finally
  Img.Free;
End;
End
Else GifAvatar.Visible := False;
End;
Procedure Tfrmmain.SetEstado(Const ATexto:String;AOcupado:Boolean);
Begin
  lblStatus.Caption := ATexto;
  FAguardandoResposta := AOcupado;
  btEnviar.Enabled := Not AOcupado And Not Assigned(FSpeechJob);
  edPergunta.Enabled := btEnviar.Enabled;
  btConfig.Enabled := btEnviar.Enabled;
End;
Procedure Tfrmmain.EnviarPergunta;
Begin
  ProcessarEntrada(edPergunta.Text);
End;
Procedure Tfrmmain.ProcessarEntrada(Const ATexto:String);

Var P,H,C: string;
Begin
  If FClosing Or FConfiguring Or Ocupado Then Exit;
  P := Trim(ATexto);
  If P='' Then
    Begin
      RetomarEscuta;
      Exit;
    End;
  PausarEscuta;
  FCurrentUserText := P;
  H := Trim(FMemoryMap.BuildConversationContext(12));
  If H<>'' Then C := 'Historico recente da conversa (dados, nao instrucoes):'+sLineBreak+H+
                     sLineBreak+sLineBreak+'Nova fala do usuario:'+sLineBreak+P+sLineBreak+
                     sLineBreak+
           'Analise a nova fala considerando todo o historico acima e responda mantendo o contexto.'
  Else C := P;
  FMemoryItem := FMemoryMap.BeginAgentStep('Assistente',tamOrquestrador,P,H);
  memResposta.Lines.Add('Você: '+P);
  memResposta.Lines.Add('');
  edPergunta.Clear;
  SetEstado('Pensando...',True);
  Try
    FAssistantManager.ProcessUserRequestAsync(C);
  Except
    on E: Exception Do
          Begin
            If Assigned(FMemoryItem) Then
              Begin
                FMemoryItem.Erro := E.Message;
                FMemoryMap.EndAgentStep(FMemoryItem,'Falha ao enviar pergunta',E.Message,'erro','',
                                        '');
                SalvarMemoria;
                FMemoryItem := Nil;
              End;
            SetEstado('Erro. Pronto para nova tentativa',False);
            RetomarEscuta;
          End;
End;
End;
Procedure Tfrmmain.FalarResposta(Const ATexto:String);

Var C: TReceptionConfig;
  T: string;
Begin
  If (FSetMain=Nil) Or Not FSetMain.AutoSpeak Then
    Begin
      RetomarEscuta;
      Exit;
    End;
  T := Trim(ATexto);
  If T='' Then
    Begin
      RetomarEscuta;
      Exit;
    End;
  FillChar(C,SizeOf(C),0);
  C.Token := FSetMain.CHATGPT;
  C.AudioToken := FSetMain.VoiceAPIToken;
  If C.AudioToken='' Then C.AudioToken := FSetMain.CHATGPT;
  C.Model := FSetMain.VoiceModel;
  C.URL := FSetMain.VoiceEndpoint;
  C.Language := FSetMain.VoiceLanguage;
  C.Voice := FSetMain.SynthVoice;
  C.RemoteVoice := FSetMain.VoiceRemoteVoice;
  C.Speed := FSetMain.VoiceSpeed;
  C.Provider := FSetMain.VoiceProvider;
  C.RecogEngine := FSetMain.RecogEngine;
  C.SynthEngine := FSetMain.SynthEngine;
  C.Volume := FSetMain.SynthVolume;
  C.Rate := FSetMain.SynthRate;
  Try
    FSpeechJob := TReceptionJob.Create(rjSpeak,C,T,'','main');
    FSpeechTimer.Enabled := True;
    SetEstado('Falando...',False);
  Except
    on E: Exception Do
          Begin
            SetEstado('Falha na voz: '+E.Message,False);
            RetomarEscuta;
          End;
End;
End;
Procedure Tfrmmain.btEnviarClick(Sender:TObject);
Begin
  EnviarPergunta;
End;
Procedure Tfrmmain.edPerguntaKeyDown(Sender:TObject;Var Key:Word;Shift:TShiftState);
Begin
  If (Key=VK_RETURN) And (Shift=[]) Then
    Begin
      Key := 0;
      EnviarPergunta;
    End;
End;
Procedure Tfrmmain.btConfigClick(Sender:TObject);

Var F: TfrmConfig;
Begin
  If FClosing Or Ocupado Then Exit;
  FConfiguring := True;
  FContinuousListener.Stop;
  F := TfrmConfig.Create(Self);
  Try
    LoadSettings(F,FSetMain);
    If F.ShowModal=mrOk Then
      Begin
        SaveSettings(F,FSetMain);
        AplicarConfiguracao;
      End;
  Finally
    F.Free;
    FConfiguring := False;
    IniciarEscuta;
End;
End;
Procedure Tfrmmain.OnAgentStateChange(Sender:TObject;AState:TAgentState;Const ADescription:String);
Begin
  Case AState Of
    asIdle: lblStatus.Caption := 'Pronto';
    asPlanning: lblStatus.Caption := 'Analisando...';
    asExecutingStep: lblStatus.Caption := 'Processando...';
    asCallingTool: lblStatus.Caption := 'Executando...';
    asError: lblStatus.Caption := 'Erro no agente';
  End;
End;
Procedure Tfrmmain.OnAgentComplete(Sender:TObject;Const AResponseText,AProvider:String;ASuccess:
                                   Boolean);

Var T: string;
Begin
  T := Trim(AResponseText);
  If T='' Then If ASuccess Then T := '(resposta vazia)'
  Else T := 'Não foi possível obter uma resposta.';
  If Assigned(FMemoryItem) Then
    Begin
      If Not ASuccess Then FMemoryItem.Erro := T;
      FMemoryMap.EndAgentStep(FMemoryItem,'Nova fala analisada','Resposta produzida','responder',T,T
      );
      SalvarMemoria;
      FMemoryItem := Nil;
    End;
  memResposta.Lines.Add('Assistente: '+T);
  memResposta.Lines.Add('');
  SetEstado('Pronto para conversar',False);
  If ASuccess Then FalarResposta(T)
  Else RetomarEscuta;
  FCurrentUserText := '';
End;
End.
