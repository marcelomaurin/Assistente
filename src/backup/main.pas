unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls,  GifAnim, toolsfalar, toolsouvir, chatgpt , toolsver, setmain;

type

  { Tfrmmain }

  Tfrmmain = class(TForm)
    btEnviarPrompt: TButton;
    btIniciar: TButton;
    cbProvider: TComboBox;
    edFrase: TEdit;
    edModel: TEdit;
    edPrompt: TEdit;
    edRecogIP: TEdit;
    edRecogPort: TEdit;
    edSynthIP: TEdit;
    edSynthPort: TEdit;
    edTokenGPT: TEdit;
    edURL: TEdit;
    GifAnim1: TGifAnim;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    procedure btEnviarPromptClick(Sender: TObject);
    procedure btIniciarClick(Sender: TObject);
    procedure edPromptKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
  private
    FAguardandoResposta : boolean;
    procedure AplicaConfigChatGPT();
    procedure SalvaConfig();
  public
    pergunta : string;
    procedure NewContext();
    procedure FazPergunta();
  end;

  { TAskChatGPTThread
    Executa CHATGPT1.SendQuestion em background: a chamada de rede do
    componente TCHATGPT (unit chatgpt.pas) é sincrona/bloqueante, então sem
    isso a interface travava (inclusive a animação do GifAnim1) durante todo
    o tempo de resposta da API. O resultado volta para a thread principal via
    Synchronize antes de tocar a resposta no toolsfalar. }
  TAskChatGPTThread = class(TThread)
  private
    FPergunta : string;
    FResposta : string;
    FSucesso  : boolean;
    procedure EntregaResposta;
  protected
    procedure Execute; override;
  public
    constructor Create(const APergunta : string);
  end;

var
  frmmain: Tfrmmain;

implementation

{$R *.lfm}

{ TAskChatGPTThread }

constructor TAskChatGPTThread.Create(const APergunta: string);
begin
  inherited Create(true); // cria suspensa para atribuir FPergunta com segurança antes do Execute rodar
  FreeOnTerminate := true;
  FPergunta := APergunta;
  Start;
end;

procedure TAskChatGPTThread.Execute;
begin
  FSucesso := CHATGPT1.SendQuestion(FPergunta);
  if FSucesso then
    FResposta := CHATGPT1.Response
  else
  begin
    FResposta := 'Desculpe, não consegui obter uma resposta agora.';
    if CHATGPT1.LastError <> '' then
      FResposta := FResposta + ' (' + CHATGPT1.LastError + ')';
  end;
  Synchronize(@EntregaResposta);
end;

procedure TAskChatGPTThread.EntregaResposta;
begin
  frmmain.FAguardandoResposta := false;
  frmToolsfalar.edFalar.Text := FResposta;
  frmToolsfalar.Falar();
end;

{ Tfrmmain }

procedure Tfrmmain.FormCreate(Sender: TObject);
begin
   FAguardandoResposta := false;
   FSetMain := TSetMain.create();
   FSetMain.CarregaContexto();

   // Carrega os campos da UI a partir do que foi persistido pelo setmain
   edTokenGPT.text := FSetMain.CHATGPT;
   edFrase.text := FSetMain.Frase;
   cbProvider.ItemIndex := FSetMain.ChatGPTProvider;
   if (cbProvider.ItemIndex < 0) or (cbProvider.ItemIndex > 5) then
     cbProvider.ItemIndex := 0;
   edModel.text := FSetMain.ChatGPTModel;
   edURL.text := FSetMain.ChatGPTURL;
   edSynthIP.text := FSetMain.VoiceSynthIP;
   edSynthPort.text := inttostr(FSetMain.VoiceSynthPort);
   edRecogIP.text := FSetMain.VoiceRecogIP;
   edRecogPort.text := inttostr(FSetMain.VoiceRecogPort);

   frmToolsfalar := TfrmToolsfalar.Create(self);
   frmToolsOuvir := TfrmToolsOuvir.create(self);
   frmToolsVer := TfrmToolsver.create(self);

   chatgpt1 := TCHATGPT.create(self);
   chatgpt1.Dev := 'Você é o Assistente de IA da FATEC. Responda de forma clara, direta e em português.';
   AplicaConfigChatGPT();
end;

// Repassa para o componente TCHATGPT (provedor/modelo/url/token) o que está
// preenchido na aba Configuração.
procedure Tfrmmain.AplicaConfigChatGPT();
begin
  if CHATGPT1 = nil then
    Exit;

  chatgpt1.TOKEN := edTokenGPT.text;
  chatgpt1.Provider := TAIProvider(cbProvider.ItemIndex);
  chatgpt1.CustomModel := edModel.text;
  chatgpt1.URL := edURL.text;
end;

// Persiste no setmain (Setmain.cfg) tudo que está preenchido na UI: token,
// provedor/modelo/url do ChatGPT, frase de ativação e IP/porta dos serviços
// de voz (síntese e reconhecimento).
procedure Tfrmmain.SalvaConfig();
begin
  FSetMain.CHATGPT := edTokenGPT.text;
  FSetMain.Frase := edFrase.text;
  FSetMain.ChatGPTProvider := cbProvider.ItemIndex;
  FSetMain.ChatGPTModel := edModel.text;
  FSetMain.ChatGPTURL := edURL.text;
  FSetMain.VoiceSynthIP := edSynthIP.text;
  FSetMain.VoiceSynthPort := StrToIntDef(edSynthPort.text, 8096);
  FSetMain.VoiceRecogIP := edRecogIP.text;
  FSetMain.VoiceRecogPort := StrToIntDef(edRecogPort.text, 8097);
  FSetMain.SalvaContexto(false);
end;

procedure Tfrmmain.btIniciarClick(Sender: TObject);
begin
  SalvaConfig();
  AplicaConfigChatGPT();

  GifAnim1.visible:= true;
  GifAnim1.Animate:=true;

  frmToolsOuvir.edIP.text := edRecogIP.text;
  frmToolsOuvir.edPort.text := edRecogPort.text;
  frmToolsOuvir.frase := edFrase.text;
  frmToolsOuvir.Show();
  frmToolsOuvir.Conectar();

  frmToolsfalar.edIP.text := edSynthIP.text;
  frmToolsfalar.edPort.text := edSynthPort.text;
  frmToolsfalar.Show();
  frmToolsfalar.Conectar();
  frmToolsfalar.btConectClick(self);

  frmToolsver.show();
  frmToolsver.Conectar();
  frmToolsver.btConectClick(self);
end;

// Permite digitar a pergunta em vez de falar no microfone (aba "Perguntar").
// Segue o mesmo fluxo do ToolsOuvir: define o contexto e chama FazPergunta,
// que dispara a chamada ao ChatGPT em background e fala a resposta.
procedure Tfrmmain.btEnviarPromptClick(Sender: TObject);
begin
  if Trim(edPrompt.Text) = '' then
    Exit;

  NewContext();
  pergunta := edPrompt.Text;
  FazPergunta();
  edPrompt.Text := '';
end;

procedure Tfrmmain.edPromptKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    btEnviarPromptClick(Sender);
  end;
end;

procedure Tfrmmain.NewContext();
begin
    pergunta := '';
end;

procedure Tfrmmain.FazPergunta();
begin
     if(CHATGPT1 = nil) then
     begin
         CHATGPT1 := TCHATGPT.create(self);
     end;
     AplicaConfigChatGPT();

     if(pergunta <> '') then
     begin
       if FAguardandoResposta then
         Exit; // já existe uma pergunta em andamento, evita disparar duas em paralelo

       FAguardandoResposta := true;
       frmToolsfalar.edFalar.Text := 'Claro, deixa eu pesquisar sua pergunta , aguarde um momento  ';
       frmToolsfalar.Falar();

       // Chamada de rede roda em background (TAskChatGPTThread) para não
       // travar a interface enquanto aguarda a resposta da API.
       TAskChatGPTThread.Create(pergunta);
     end;
end;

end.

