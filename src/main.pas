unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, LCLType, GifAnim, chatgpt, setmain, frmconfig, jarvis_api,
  agent_manager, reception_core, aiagent_memorymap, aiagent_flowevents,
  voice_input_bridge;

type
  Tfrmmain = class(TForm)
    pnlRoot: TPanel;
    pnlHeader: TPanel;
    lblTitulo: TLabel;
    lblStatus: TLabel;
    btConfig: TSpeedButton;
    pnlConteudo: TPanel;
    pnlAvatar: TPanel;
    GifAvatar: TGifAnim;
    lblAssistente: TLabel;
    memResposta: TMemo;
    pnlEntrada: TPanel;
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
    FMemoryMap: TAIAgentMemoryMap;
    FMemoryItem: TAIAgentMemoryMapItem;
    FHistoryFile: string;
    FCurrentUserText: string;
    FAguardandoResposta: Boolean;
    procedure AplicarConfiguracao;
    procedure CarregarAvatarEstatico;
    procedure InicializarMemoria;
    procedure SalvarMemoria;
    procedure EnviarPergunta;
    procedure ProcessarEntrada(const ATexto: string);
    procedure VoiceText(Sender: TObject; const AText: string);
    procedure VoiceState(Sender: TObject; const AState: string);
    procedure FalarResposta(const ATexto: string);
    procedure SetEstado(const ATexto: string; AOcupado: Boolean);
    procedure OnAgentStateChange(Sender: TObject; AState: TAgentState;
      const ADescription: string);
    procedure OnAgentComplete(Sender: TObject; const AResponseText,
      AProvider: string; ASuccess: Boolean);
  public
    property AssistantManager: TAssistantManager read FAssistantManager;
    property VoiceInput: TVoiceInputBridge read FVoiceInput;
  end;

var
  frmmain: Tfrmmain;

implementation

{$R *.lfm}

procedure Tfrmmain.FormCreate(Sender: TObject);
begin
  FAguardandoResposta := False;
  FSpeechJob := nil;
  FMemoryItem := nil;
  FCurrentUserText := '';

  if FSetMain = nil then
    FSetMain := TSetMain.Create;
  FSetMain.CarregaContexto;

  FJarvisClient := TJarvisAPIClient.Create(Self);
  FAssistantManager := TAssistantManager.Create(Self);
  FAssistantManager.JarvisClient := FJarvisClient;
  FAssistantManager.OnStateChange := @OnAgentStateChange;
  FAssistantManager.OnComplete := @OnAgentComplete;

  FMemoryMap := TAIAgentMemoryMap.Create(Self);
  InicializarMemoria;

  { A ponte de voz entrega texto ao mesmo fluxo usado pelo teclado. }
  FVoiceInput := TVoiceInputBridge.Create(Self);
  FVoiceInput.OnText := @VoiceText;
  FVoiceInput.OnState := @VoiceState;

  AplicarConfiguracao;
  CarregarAvatarEstatico;
  SetEstado('Pronto para conversar', False);
end;

procedure Tfrmmain.FormDestroy(Sender: TObject);
begin
  if Assigned(FVoiceInput) then
    FVoiceInput.Cancel;
  SalvarMemoria;
  if Assigned(FSpeechJob) then
  begin
    FSpeechJob.Cancel;
    FSpeechJob.Free;
    FSpeechJob := nil;
  end;
end;

procedure Tfrmmain.FormShow(Sender: TObject);
begin
  edPergunta.Text := '';
  edPergunta.SetFocus;
end;

procedure Tfrmmain.InicializarMemoria;
var BaseDir: string;
begin
  BaseDir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  FHistoryFile := BaseDir + 'conversation-history.json';
  FMemoryMap.MaxItems := 100;
  FMemoryMap.StoreFullPrompt := True;
  FMemoryMap.StoreFullResponse := True;
  FMemoryMap.DetectInformationLoss := True;
  FMemoryMap.RedactSensitiveData := True;
  if FileExists(FHistoryFile) then
  begin
    try
      FMemoryMap.LoadFromFile(FHistoryFile);
    except
      FMemoryMap.StartFlow('', 'Assistente', 'usuario', 'interface');
    end;
  end
  else
    FMemoryMap.StartFlow('', 'Assistente', 'usuario', 'interface');
end;

procedure Tfrmmain.SalvarMemoria;
begin
  if (FMemoryMap = nil) or (FHistoryFile = '') then Exit;
  try
    FMemoryMap.SaveToFile(FHistoryFile);
  except
  end;
end;

procedure Tfrmmain.AplicarConfiguracao;
begin
  if (FSetMain = nil) or (FAssistantManager = nil) then Exit;
  FAssistantManager.ChatGPT.TOKEN := FSetMain.CHATGPT;
  if (FSetMain.ChatGPTProvider >= 0) and
     (FSetMain.ChatGPTProvider <= Ord(High(TAIProvider))) then
    FAssistantManager.ChatGPT.Provider := TAIProvider(FSetMain.ChatGPTProvider)
  else
    FAssistantManager.ChatGPT.Provider := AIP_OPENAI;
  FAssistantManager.ChatGPT.CustomModel := FSetMain.ChatGPTModel;
  FAssistantManager.ChatGPT.URL := FSetMain.ChatGPTURL;
  FJarvisClient.BaseURL := FSetMain.JarvisURL;
  FJarvisClient.APIKey := FSetMain.JarvisAPIKey;
end;

procedure Tfrmmain.CarregarAvatarEstatico;
var BaseDir, AvatarFile: string;
begin
  GifAvatar.Animate := False;
  BaseDir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  AvatarFile := ExpandFileName(BaseDir + '..' + PathDelim + 'img' + PathDelim + 'robo-start.gif');
  if not FileExists(AvatarFile) then
    AvatarFile := ExpandFileName(BaseDir + 'img' + PathDelim + 'robo-start.gif');
  if not FileExists(AvatarFile) then
    AvatarFile := ExpandFileName(BaseDir + '..' + PathDelim + '..' + PathDelim + 'img' + PathDelim + 'robo-start.gif');
  if FileExists(AvatarFile) then
  begin
    GifAvatar.FileName := AvatarFile;
    GifAvatar.Animate := False;
    GifAvatar.Visible := True;
  end
  else
    GifAvatar.Visible := False;
end;

procedure Tfrmmain.SetEstado(const ATexto: string; AOcupado: Boolean);
begin
  lblStatus.Caption := ATexto;
  FAguardandoResposta := AOcupado;
  btEnviar.Enabled := not AOcupado;
  edPergunta.Enabled := not AOcupado;
end;

procedure Tfrmmain.EnviarPergunta;
begin
  ProcessarEntrada(edPergunta.Text);
end;

procedure Tfrmmain.VoiceText(Sender: TObject; const AText: string);
begin
  ProcessarEntrada(AText);
end;

procedure Tfrmmain.VoiceState(Sender: TObject; const AState: string);
begin
  if not FAguardandoResposta then
    lblStatus.Caption := AState;
end;

procedure Tfrmmain.ProcessarEntrada(const ATexto: string);
var
  Pergunta, Historico, PromptComContexto: string;
begin
  if FAguardandoResposta then Exit;
  Pergunta := Trim(ATexto);
  if Pergunta = '' then Exit;

  FCurrentUserText := Pergunta;
  Historico := '';
  if Assigned(FMemoryMap) then
    Historico := Trim(FMemoryMap.BuildConversationContext(100));

  if Historico <> '' then
    PromptComContexto :=
      'Historico completo da conversa anterior:' + sLineBreak + Historico +
      sLineBreak + sLineBreak + 'Nova fala do usuario:' + sLineBreak + Pergunta +
      sLineBreak + sLineBreak +
      'Analise a nova fala considerando todo o historico acima e responda mantendo o contexto.'
  else
    PromptComContexto := Pergunta;

  if Assigned(FMemoryMap) then
    FMemoryItem := FMemoryMap.BeginAgentStep('Assistente', tamOrquestrador,
      Pergunta, Historico)
  else
    FMemoryItem := nil;

  memResposta.Lines.Add('Você: ' + Pergunta);
  memResposta.Lines.Add('');
  edPergunta.Clear;
  SetEstado('Pensando...', True);

  try
    FAssistantManager.ProcessUserRequestAsync(PromptComContexto);
  except
    on E: Exception do
    begin
      if Assigned(FMemoryItem) then
      begin
        FMemoryItem.Erro := E.Message;
        FMemoryMap.EndAgentStep(FMemoryItem, 'Falha ao enviar pergunta', E.Message,
          'erro', '', '');
        SalvarMemoria;
        FMemoryItem := nil;
      end;
      memResposta.Lines.Add('Assistente: erro ao enviar a pergunta: ' + E.Message);
      memResposta.Lines.Add('');
      SetEstado('Erro. Pronto para nova tentativa', False);
    end;
  end;
end;

procedure Tfrmmain.FalarResposta(const ATexto: string);
var Cfg: TReceptionConfig; Texto: string;
begin
  if (FSetMain = nil) or (not FSetMain.AutoSpeak) then Exit;
  Texto := Trim(ATexto);
  if Texto = '' then Exit;
  if Assigned(FSpeechJob) then
  begin
    FSpeechJob.Cancel;
    FSpeechJob.Free;
    FSpeechJob := nil;
  end;
  FillChar(Cfg, SizeOf(Cfg), 0);
  Cfg.Token := FSetMain.CHATGPT;
  Cfg.AudioToken := FSetMain.VoiceAPIToken;
  if Cfg.AudioToken = '' then Cfg.AudioToken := FSetMain.CHATGPT;
  Cfg.Model := FSetMain.VoiceModel;
  Cfg.URL := FSetMain.VoiceEndpoint;
  Cfg.Language := FSetMain.VoiceLanguage;
  Cfg.Voice := FSetMain.SynthVoice;
  if Cfg.Voice = '' then Cfg.Voice := FSetMain.VoiceRemoteVoice;
  Cfg.Provider := FSetMain.VoiceProvider;
  Cfg.RecogEngine := FSetMain.RecogEngine;
  Cfg.SynthEngine := FSetMain.SynthEngine;
  Cfg.Volume := FSetMain.SynthVolume;
  Cfg.Rate := FSetMain.SynthRate;
  FSpeechJob := TReceptionJob.Create(rjSpeak, Cfg, Texto, '', 'main');
end;

procedure Tfrmmain.btEnviarClick(Sender: TObject);
begin
  EnviarPergunta;
end;

procedure Tfrmmain.edPerguntaKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0;
    EnviarPergunta;
  end;
end;

procedure Tfrmmain.btConfigClick(Sender: TObject);
var FormCfg: TfrmConfig;
begin
  if FAguardandoResposta then Exit;
  FormCfg := TfrmConfig.Create(Self);
  try
    if FormCfg.ShowModal = mrOk then
    begin
      FSetMain.CarregaContexto;
      AplicarConfiguracao;
      SetEstado('Configurações atualizadas', False);
    end;
  finally
    FormCfg.Free;
  end;
  edPergunta.SetFocus;
end;

procedure Tfrmmain.OnAgentStateChange(Sender: TObject; AState: TAgentState;
  const ADescription: string);
begin
  case AState of
    asIdle: lblStatus.Caption := 'Pronto para conversar';
    asPlanning: lblStatus.Caption := 'Analisando...';
    asExecutingStep: lblStatus.Caption := 'Processando...';
    asCallingTool: lblStatus.Caption := 'Executando...';
    asFinished: lblStatus.Caption := 'Resposta recebida';
    asError: lblStatus.Caption := 'Erro no agente';
    asCancelled: lblStatus.Caption := 'Cancelado';
  end;
end;

procedure Tfrmmain.OnAgentComplete(Sender: TObject; const AResponseText,
  AProvider: string; ASuccess: Boolean);
var Texto: string;
begin
  Texto := Trim(AResponseText);
  if Texto = '' then
    if ASuccess then Texto := '(resposta vazia)'
    else Texto := 'Não foi possível obter uma resposta.';

  if Assigned(FMemoryItem) and Assigned(FMemoryMap) then
  begin
    if not ASuccess then FMemoryItem.Erro := Texto;
    FMemoryMap.EndAgentStep(FMemoryItem,
      'Nova fala analisada considerando o historico da conversa',
      'Resposta produzida pelo agente com memoria contextual',
      'responder', Texto, Texto);
    SalvarMemoria;
    FMemoryItem := nil;
  end;

  memResposta.Lines.Add('Assistente: ' + Texto);
  memResposta.Lines.Add('');
  if ASuccess then
  begin
    SetEstado('Pronto para conversar', False);
    FalarResposta(Texto);
  end
  else
    SetEstado('Falha na resposta. Tente novamente', False);
  FCurrentUserText := '';
  edPergunta.SetFocus;
end;

end.
