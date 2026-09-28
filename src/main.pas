unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, LCLType, GifAnim, chatgpt, setmain, frmconfig, jarvis_api, agent_manager;

type
  { Tfrmmain
    Tela principal minima. A UI apenas recebe a entrada e apresenta o resultado.
    Configuracoes continuam centralizadas em TSetMain/frmconfig. }
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
    FAguardandoResposta: Boolean;
    procedure AplicarConfiguracao;
    procedure CarregarAvatarEstatico;
    procedure EnviarPergunta;
    procedure SetEstado(const ATexto: string; AOcupado: Boolean);
    procedure OnAgentStateChange(Sender: TObject; AState: TAgentState;
      const ADescription: string);
    procedure OnAgentComplete(Sender: TObject; const AResponseText,
      AProvider: string; ASuccess: Boolean);
  public
    property AssistantManager: TAssistantManager read FAssistantManager;
  end;

var
  frmmain: Tfrmmain;

implementation

{$R *.lfm}

procedure Tfrmmain.FormCreate(Sender: TObject);
begin
  FAguardandoResposta := False;

  { TSetMain permanece sendo a fonte unica das configuracoes. }
  if FSetMain = nil then
    FSetMain := TSetMain.Create;
  FSetMain.CarregaContexto;

  { Nesta primeira fase inicializamos somente o necessario para texto -> agente. }
  FJarvisClient := TJarvisAPIClient.Create(Self);
  FAssistantManager := TAssistantManager.Create(Self);
  FAssistantManager.JarvisClient := FJarvisClient;
  FAssistantManager.OnStateChange := @OnAgentStateChange;
  FAssistantManager.OnComplete := @OnAgentComplete;

  AplicarConfiguracao;
  CarregarAvatarEstatico;
  SetEstado('Pronto para conversar', False);
end;

procedure Tfrmmain.FormDestroy(Sender: TObject);
begin
  { Componentes com Owner=Self sao liberados pelo formulario.
    FSetMain continua com o mesmo ciclo de vida global usado pelo projeto. }
end;

procedure Tfrmmain.FormShow(Sender: TObject);
begin
  edPergunta.Text := '';
  edPergunta.SetFocus;
end;

procedure Tfrmmain.AplicarConfiguracao;
begin
  if (FSetMain = nil) or (FAssistantManager = nil) then Exit;

  { IA: propaga exatamente os valores mantidos pela tela de configuracao. }
  FAssistantManager.ChatGPT.TOKEN := FSetMain.CHATGPT;
  if (FSetMain.ChatGPTProvider >= 0) and
     (FSetMain.ChatGPTProvider <= Ord(High(TAIProvider))) then
    FAssistantManager.ChatGPT.Provider := TAIProvider(FSetMain.ChatGPTProvider)
  else
    FAssistantManager.ChatGPT.Provider := AIP_OPENAI;

  FAssistantManager.ChatGPT.CustomModel := FSetMain.ChatGPTModel;
  FAssistantManager.ChatGPT.URL := FSetMain.ChatGPTURL;

  { Jarvis e apenas uma dependencia do agente; nenhuma automacao e iniciada aqui. }
  FJarvisClient.BaseURL := FSetMain.JarvisURL;
  FJarvisClient.APIKey := FSetMain.JarvisAPIKey;
end;

procedure Tfrmmain.CarregarAvatarEstatico;
var
  BaseDir, AvatarFile: string;
begin
  { O espaco do avatar ja nasce separado do restante da UI.
    Nesta etapa usamos somente o primeiro quadro do GIF existente. }
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
var
  Pergunta: string;
begin
  if FAguardandoResposta then Exit;

  Pergunta := Trim(edPergunta.Text);
  if Pergunta = '' then Exit;

  memResposta.Lines.Add('Você: ' + Pergunta);
  memResposta.Lines.Add('');
  edPergunta.Clear;
  SetEstado('Pensando...', True);

  try
    FAssistantManager.ProcessUserRequestAsync(Pergunta);
  except
    on E: Exception do
    begin
      memResposta.Lines.Add('Assistente: erro ao enviar a pergunta: ' + E.Message);
      memResposta.Lines.Add('');
      SetEstado('Erro. Pronto para nova tentativa', False);
      edPergunta.SetFocus;
    end;
  end;
end;

procedure Tfrmmain.btEnviarClick(Sender: TObject);
begin
  EnviarPergunta;
end;

procedure Tfrmmain.edPerguntaKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0;
    EnviarPergunta;
  end;
end;

procedure Tfrmmain.btConfigClick(Sender: TObject);
var
  FormCfg: TfrmConfig;
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
    asIdle:          lblStatus.Caption := 'Pronto para conversar';
    asPlanning:      lblStatus.Caption := 'Analisando...';
    asExecutingStep: lblStatus.Caption := 'Processando...';
    asCallingTool:   lblStatus.Caption := 'Executando...';
    asFinished:      lblStatus.Caption := 'Resposta recebida';
    asError:         lblStatus.Caption := 'Erro no agente';
    asCancelled:     lblStatus.Caption := 'Cancelado';
  end;
end;

procedure Tfrmmain.OnAgentComplete(Sender: TObject; const AResponseText,
  AProvider: string; ASuccess: Boolean);
var
  Texto: string;
begin
  Texto := Trim(AResponseText);
  if Texto = '' then
  begin
    if ASuccess then
      Texto := '(resposta vazia)'
    else
      Texto := 'Não foi possível obter uma resposta.';
  end;

  memResposta.Lines.Add('Assistente: ' + Texto);
  memResposta.Lines.Add('');

  if ASuccess then
    SetEstado('Pronto para conversar', False)
  else
    SetEstado('Falha na resposta. Tente novamente', False);

  edPergunta.SetFocus;
end;

end.
