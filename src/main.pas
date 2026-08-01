unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, GifAnim, strutils, chatgpt, setmain, frmconfig, aivoicesynthesizer, aivoicerecognizer;

type

  { Tfrmmain }

  Tfrmmain = class(TForm)
    pnlTop: TPanel;
    GifAnim1: TGifAnim;
    pnlTopControls: TPanel;
    btIniciar: TButton;
    btAbrirConfig: TButton;
    
    pnlChat: TPanel;
    pnlHistoricoHeader: TPanel;
    lblHistorico: TLabel;
    btSpeaker: TButton;
    memHistorico: TMemo;
    
    pnlPergunta: TPanel;
    lblPergunta: TLabel;
    memPergunta: TMemo;
    btEnviar: TButton;
    btMic: TButton;

    procedure btAbrirConfigClick(Sender: TObject);
    procedure btEnviarClick(Sender: TObject);
    procedure btIniciarClick(Sender: TObject);
    procedure btMicClick(Sender: TObject);
    procedure btSpeakerClick(Sender: TObject);
    procedure memPerguntaKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
  private
    FAguardandoResposta : boolean;
    FVoiceActive: boolean;
    FVoiceSynth: TAIVoiceSynthesizer;
    FVoiceRecog: TAIVoiceRecognizer;
    procedure AplicaConfigChatGPT();
    procedure VoiceRecognized(Sender: TObject; const AText: string);
    procedure AtualizaEstadoSpeaker;
  public
    pergunta : string;
    procedure NewContext();
    procedure FazPergunta();
    procedure AdicionaMensagemHistorico(const Remetente, Mensagem: string);
    property VoiceSynth: TAIVoiceSynthesizer read FVoiceSynth;
    property VoiceRecog: TAIVoiceRecognizer read FVoiceRecog;
    property VoiceActive: boolean read FVoiceActive;
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
  frmmain.AdicionaMensagemHistorico('Assistente', FResposta);

  if frmmain.FVoiceActive and Assigned(frmmain.FVoiceSynth) then
    frmmain.FVoiceSynth.Say(FResposta);
end;

{ Tfrmmain }

procedure Tfrmmain.FormCreate(Sender: TObject);
begin
   FAguardandoResposta := false;
   FVoiceActive := true;

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

   AtualizaEstadoSpeaker();
end;

procedure Tfrmmain.AtualizaEstadoSpeaker;
begin
  if FVoiceActive then
  begin
    btSpeaker.Caption := '🔊 Voz ON';
    btSpeaker.Hint := 'Clique para desativar a fala do assistente';
  end
  else
  begin
    btSpeaker.Caption := '🔇 Voz OFF';
    btSpeaker.Hint := 'Clique para ativar a fala do assistente';
  end;
end;

procedure Tfrmmain.btSpeakerClick(Sender: TObject);
begin
  FVoiceActive := not FVoiceActive;
  AtualizaEstadoSpeaker();
end;

procedure Tfrmmain.btMicClick(Sender: TObject);
begin
  if Assigned(FVoiceRecog) then
  begin
    AdicionaMensagemHistorico('Sistema', 'Ouvindo... Fale sua pergunta.');
    FVoiceRecog.Recognize('');
  end;
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
    if pergunta <> '' then
    begin
      AdicionaMensagemHistorico('Você (Voz)', pergunta);
      FazPergunta();
    end;
  end;
end;

procedure Tfrmmain.AdicionaMensagemHistorico(const Remetente, Mensagem: string);
begin
  if memHistorico <> nil then
  begin
    memHistorico.Lines.Add('[' + FormatDateTime('hh:nn', Now) + '] ' + Remetente + ':');
    memHistorico.Lines.Add(Mensagem);
    memHistorico.Lines.Add('');
    memHistorico.SelStart := Length(memHistorico.Text);
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
  begin
    FVoiceSynth.OpenAIToken := FSetMain.CHATGPT;
    case FSetMain.SynthEngine of
      0: FVoiceSynth.Engine := seSystemDefault;
      1: FVoiceSynth.Engine := seSAPI;
      2: FVoiceSynth.Engine := seEspeak;
      3: FVoiceSynth.Engine := seOpenAI;
    else
      FVoiceSynth.Engine := seSystemDefault;
    end;
    FVoiceSynth.VoiceName := FSetMain.SynthVoice;
    FVoiceSynth.Volume := FSetMain.SynthVolume;
    FVoiceSynth.Rate := FSetMain.SynthRate;
    FVoiceSynth.Asynchronous := FSetMain.SynthAsync;
  end;
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

    FormCfg.CarregaModelosDoProvedor;
    if Trim(FSetMain.ChatGPTModel) <> '' then
      FormCfg.cbModel.Text := FSetMain.ChatGPTModel;
    FormCfg.edTokenGPT.Text := FSetMain.CHATGPT;
    FormCfg.edURL.Text := FSetMain.ChatGPTURL;

    // Aba Output Voice
    FormCfg.cbSynthEngine.ItemIndex := FSetMain.SynthEngine;
    if (FormCfg.cbSynthEngine.ItemIndex < 0) or (FormCfg.cbSynthEngine.ItemIndex >= FormCfg.cbSynthEngine.Items.Count) then
      FormCfg.cbSynthEngine.ItemIndex := 0;
    FormCfg.CarregaVozesDoSintetizador;
    if Trim(FSetMain.SynthVoice) <> '' then
      FormCfg.cbSynthVoice.Text := FSetMain.SynthVoice;
    FormCfg.tbSynthVolume.Position := FSetMain.SynthVolume;
    FormCfg.tbSynthVolumeChange(Self);
    FormCfg.tbSynthRate.Position := FSetMain.SynthRate;
    FormCfg.tbSynthRateChange(Self);
    FormCfg.chkSynthAsync.Checked := FSetMain.SynthAsync;

    FormCfg.edFrase.Text := FSetMain.Frase;
    FormCfg.edSynthIP.Text := FSetMain.VoiceSynthIP;
    FormCfg.edSynthPort.Text := IntToStr(FSetMain.VoiceSynthPort);
    FormCfg.edRecogIP.Text := FSetMain.VoiceRecogIP;
    FormCfg.edRecogPort.Text := IntToStr(FSetMain.VoiceRecogPort);
    FormCfg.edVerIP.Text := FSetMain.VerIP;
    FormCfg.edVerPort.Text := IntToStr(FSetMain.VerPort);

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

      // Aba Output Voice
      FSetMain.SynthEngine := FormCfg.cbSynthEngine.ItemIndex;
      FSetMain.SynthVoice := FormCfg.cbSynthVoice.Text;
      FSetMain.SynthVolume := FormCfg.tbSynthVolume.Position;
      FSetMain.SynthRate := FormCfg.tbSynthRate.Position;
      FSetMain.SynthAsync := FormCfg.chkSynthAsync.Checked;

      FSetMain.Frase := FormCfg.edFrase.Text;
      FSetMain.VoiceSynthIP := FormCfg.edSynthIP.Text;
      FSetMain.VoiceSynthPort := StrToIntDef(FormCfg.edSynthPort.Text, 8096);
      FSetMain.VoiceRecogIP := FormCfg.edRecogIP.Text;
      FSetMain.VoiceRecogPort := StrToIntDef(FormCfg.edRecogPort.Text, 8097);
      FSetMain.VerIP := FormCfg.edVerIP.Text;
      FSetMain.VerPort := StrToIntDef(FormCfg.edVerPort.Text, 8097);

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

procedure Tfrmmain.btEnviarClick(Sender: TObject);
begin
  if Trim(memPergunta.Text) = '' then
    Exit;

  NewContext();
  pergunta := Trim(memPergunta.Text);
  AdicionaMensagemHistorico('Você', pergunta);
  FazPergunta();
  memPergunta.Text := '';
end;

procedure Tfrmmain.memPerguntaKeyPress(Sender: TObject; var Key: char);
begin
  if (Key = #13) and not (ssCtrl in GetKeyShiftState) then
  begin
    Key := #0;
    btEnviarClick(Sender);
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

       TAskChatGPTThread.Create(pergunta);
     end;
end;

end.
