unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, GifAnim, toolsfalar, toolsouvir, chatgpt, toolsver, setmain, frmconfig;

type

  { Tfrmmain }

  Tfrmmain = class(TForm)
    btEnviarPrompt: TButton;
    btIniciar: TButton;
    btAbrirConfig: TButton;
    edPrompt: TEdit;
    GifAnim1: TGifAnim;
    Label8: TLabel;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    procedure btAbrirConfigClick(Sender: TObject);
    procedure btEnviarPromptClick(Sender: TObject);
    procedure btIniciarClick(Sender: TObject);
    procedure edPromptKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
  private
    FAguardandoResposta : boolean;
    procedure AplicaConfigChatGPT();
  public
    pergunta : string;
    procedure NewContext();
    procedure FazPergunta();
  end;

  { TAskChatGPTThread
    Executa CHATGPT1.SendQuestion em background. }
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
  inherited Create(true);
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

   frmToolsfalar := TfrmToolsfalar.Create(self);
   frmToolsOuvir := TfrmToolsOuvir.create(self);
   frmToolsVer := TfrmToolsver.create(self);

   chatgpt1 := TCHATGPT.create(self);
   chatgpt1.Dev := 'Você é o Assistente de IA da FATEC. Responda de forma clara, direta e em português.';
   AplicaConfigChatGPT();
end;

// Repassa para o componente TCHATGPT as configurações salvas no FSetMain
procedure Tfrmmain.AplicaConfigChatGPT();
begin
  if CHATGPT1 = nil then
    Exit;

  chatgpt1.TOKEN := FSetMain.CHATGPT;
  chatgpt1.Provider := TAIProvider(FSetMain.ChatGPTProvider);
  chatgpt1.CustomModel := FSetMain.ChatGPTModel;
  chatgpt1.URL := FSetMain.ChatGPTURL;
end;

// Chama a janela modal de configurações (frmconfig.pas)
procedure Tfrmmain.btAbrirConfigClick(Sender: TObject);
var
  FormCfg: TfrmConfig;
begin
  FormCfg := TfrmConfig.Create(Self);
  try
    // Carrega dados do FSetMain nos campos da aba
    FormCfg.edTokenGPT.Text := FSetMain.CHATGPT;
    FormCfg.edFrase.Text := FSetMain.Frase;
    FormCfg.cbProvider.ItemIndex := FSetMain.ChatGPTProvider;
    if (FormCfg.cbProvider.ItemIndex < 0) or (FormCfg.cbProvider.ItemIndex > 5) then
      FormCfg.cbProvider.ItemIndex := 0;
    FormCfg.edModel.Text := FSetMain.ChatGPTModel;
    FormCfg.edURL.Text := FSetMain.ChatGPTURL;
    FormCfg.edSynthIP.Text := FSetMain.VoiceSynthIP;
    FormCfg.edSynthPort.Text := IntToStr(FSetMain.VoiceSynthPort);
    FormCfg.edRecogIP.Text := FSetMain.VoiceRecogIP;
    FormCfg.edRecogPort.Text := IntToStr(FSetMain.VoiceRecogPort);

    if FormCfg.ShowModal = mrOk then
    begin
      // Salva no FSetMain e persiste no Setmain.cfg
      FSetMain.CHATGPT := FormCfg.edTokenGPT.Text;
      FSetMain.Frase := FormCfg.edFrase.Text;
      FSetMain.ChatGPTProvider := FormCfg.cbProvider.ItemIndex;
      FSetMain.ChatGPTModel := FormCfg.edModel.Text;
      FSetMain.ChatGPTURL := FormCfg.edURL.Text;
      FSetMain.VoiceSynthIP := FormCfg.edSynthIP.Text;
      FSetMain.VoiceSynthPort := StrToIntDef(FormCfg.edSynthPort.Text, 8096);
      FSetMain.VoiceRecogIP := FormCfg.edRecogIP.Text;
      FSetMain.VoiceRecogPort := StrToIntDef(FormCfg.edRecogPort.Text, 8097);
      FSetMain.SalvaContexto(false);

      AplicaConfigChatGPT();
    end;
  finally
    FormCfg.Free;
  end;
end;

procedure Tfrmmain.btIniciarClick(Sender: TObject);
begin
  AplicaConfigChatGPT();

  GifAnim1.visible:= true;
  GifAnim1.Animate:=true;

  frmToolsOuvir.edIP.text := FSetMain.VoiceRecogIP;
  frmToolsOuvir.edPort.text := IntToStr(FSetMain.VoiceRecogPort);
  frmToolsOuvir.frase := FSetMain.Frase;
  frmToolsOuvir.Show();
  frmToolsOuvir.Conectar();

  frmToolsfalar.edIP.text := FSetMain.VoiceSynthIP;
  frmToolsfalar.edPort.text := IntToStr(FSetMain.VoiceSynthPort);
  frmToolsfalar.Show();
  frmToolsfalar.Conectar();
  frmToolsfalar.btConectClick(self);

  frmToolsver.show();
  frmToolsver.Conectar();
  frmToolsver.btConectClick(self);
end;

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
         Exit;

       FAguardandoResposta := true;
       frmToolsfalar.edFalar.Text := 'Claro, deixa eu pesquisar sua pergunta , aguarde um momento  ';
       frmToolsfalar.Falar();

       TAskChatGPTThread.Create(pergunta);
     end;
end;

end.
