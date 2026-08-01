unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, GifAnim, strutils, chatgpt, setmain, frmconfig, aivoicesynthesizer, aivoicerecognizer;

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
    FVoiceSynth: TAIVoiceSynthesizer;
    FVoiceRecog: TAIVoiceRecognizer;
    procedure AplicaConfigChatGPT();
    procedure VoiceRecognized(Sender: TObject; const AText: string);
  public
    pergunta : string;
    procedure NewContext();
    procedure FazPergunta();
    property VoiceSynth: TAIVoiceSynthesizer read FVoiceSynth;
    property VoiceRecog: TAIVoiceRecognizer read FVoiceRecog;
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
  if Assigned(frmmain.FVoiceSynth) then
    frmmain.FVoiceSynth.Say(FResposta);
end;

{ Tfrmmain }

procedure Tfrmmain.FormCreate(Sender: TObject);
begin
   FAguardandoResposta := false;
   FSetMain := TSetMain.create();
   FSetMain.CarregaContexto();

   FVoiceSynth := TAIVoiceSynthesizer.Create(Self);
   FVoiceSynth.Engine := seSystemDefault;

   FVoiceRecog := TAIVoiceRecognizer.Create(Self);
   FVoiceRecog.Engine := vreOpenAIWhisper;
   FVoiceRecog.OnRecognized := @VoiceRecognized;

   CHATGPT1 := TCHATGPT.create(self);
   CHATGPT1.Dev := 'Você é o Assistente de IA da FATEC. Responda de forma clara, direta e em português.';
   AplicaConfigChatGPT();
end;

procedure Tfrmmain.VoiceRecognized(Sender: TObject; const AText: string);
var
  info: string;
  posicao: integer;
begin
  info := AText;
  posicao := Pos(FSetMain.Frase, info);
  if (posicao <> 0) or (FSetMain.Frase = '') then
  begin
    if FSetMain.Frase <> '' then
      info := ReplaceStr(info, FSetMain.Frase, '');

    NewContext();
    pergunta := Trim(info);
    FazPergunta();
  end;
end;

procedure Tfrmmain.AplicaConfigChatGPT();
begin
  if CHATGPT1 = nil then
    Exit;

  CHATGPT1.TOKEN := FSetMain.CHATGPT;
  CHATGPT1.Provider := TAIProvider(FSetMain.ChatGPTProvider);
  CHATGPT1.CustomModel := FSetMain.ChatGPTModel;
  CHATGPT1.URL := FSetMain.ChatGPTURL;

  if Assigned(FVoiceRecog) then
    FVoiceRecog.OpenAIToken := FSetMain.CHATGPT;
  if Assigned(FVoiceSynth) then
    FVoiceSynth.OpenAIToken := FSetMain.CHATGPT;
end;

procedure Tfrmmain.btAbrirConfigClick(Sender: TObject);
var
  FormCfg: TfrmConfig;
begin
  FormCfg := TfrmConfig.Create(Self);
  try
    FormCfg.cbProvider.ItemIndex := FSetMain.ChatGPTProvider;
    if (FormCfg.cbProvider.ItemIndex < 0) or (FormCfg.cbProvider.ItemIndex >= FormCfg.cbProvider.Items.Count) then
      FormCfg.cbProvider.ItemIndex := 0;

    FormCfg.cbModel.Text := FSetMain.ChatGPTModel;
    FormCfg.edTokenGPT.Text := FSetMain.CHATGPT;
    FormCfg.edURL.Text := FSetMain.ChatGPTURL;
    FormCfg.edFrase.Text := FSetMain.Frase;
    FormCfg.edSynthIP.Text := FSetMain.VoiceSynthIP;
    FormCfg.edSynthPort.Text := IntToStr(FSetMain.VoiceSynthPort);
    FormCfg.edRecogIP.Text := FSetMain.VoiceRecogIP;
    FormCfg.edRecogPort.Text := IntToStr(FSetMain.VoiceRecogPort);

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
      FSetMain.ChatGPTProvider := FormCfg.cbProvider.ItemIndex;
      FSetMain.ChatGPTModel := FormCfg.cbModel.Text;
      FSetMain.CHATGPT := FormCfg.edTokenGPT.Text;
      FSetMain.ChatGPTURL := FormCfg.edURL.Text;
      FSetMain.Frase := FormCfg.edFrase.Text;
      FSetMain.VoiceSynthIP := FormCfg.edSynthIP.Text;
      FSetMain.VoiceSynthPort := StrToIntDef(FormCfg.edSynthPort.Text, 8096);
      FSetMain.VoiceRecogIP := FormCfg.edRecogIP.Text;
      FSetMain.VoiceRecogPort := StrToIntDef(FormCfg.edRecogPort.Text, 8097);

      FSetMain.HostnameMy := FormCfg.edMyHost.Text;
      FSetMain.BancoMy := FormCfg.edMyDb.Text;
      FSetMain.UsernameMy := FormCfg.edMyUser.Text;
      FSetMain.PasswordMy := FormCfg.edMyPass.Text;
      FSetMain.HostnamePost := FormCfg.edPostHost.Text;
      FSetMain.BancoPOST := FormCfg.edPostDb.Text;
      FSetMain.UsernamePost := FormCfg.edPostUser.Text;
      FSetMain.PasswordPost := FormCfg.edPostPass.Text;
      FSetMain.SchemaPost := FormCfg.edPostSchema.Text;

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

  GifAnim1.visible := true;
  GifAnim1.Animate := true;
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
       if Assigned(FVoiceSynth) then
         FVoiceSynth.Say('Claro, deixa eu pesquisar sua pergunta, aguarde um momento');

       TAskChatGPTThread.Create(pergunta);
     end;
end;

end.
