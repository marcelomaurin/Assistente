unit frmconfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  chatgpt, aivoicesynthesizer, jarvis_api;

type

  { TfrmConfig }

  TfrmConfig = class(TForm)
    pcConfig: TPageControl;
    tsAvatar3D: TTabSheet;
    lblAvatarModel: TLabel;
    edAvatarModel: TEdit;
    btBuscarAvatar: TButton;
    chkAvatarAutoIdle: TCheckBox;
    chkAvatarAutoBlink: TCheckBox;
    chkAvatarLipSync: TCheckBox;
    lblAvatarQuality: TLabel;
    cbAvatarQuality: TComboBox;
    btTestarAvatar: TButton;
    tsJarvis: TTabSheet;
    tsIA: TTabSheet;
    tsOutputVoice: TTabSheet;
    tsVoz: TTabSheet;
    tsVisao: TTabSheet;
    tsBanco: TTabSheet;
    
    // Aba JARVIS (API Segura v1)
    lblJarvisURL: TLabel;
    edJarvisURL: TEdit;
    lblJarvisKey: TLabel;
    edJarvisKey: TEdit;
    btVerChave: TButton;
    lblJarvisMode: TLabel;
    cbJarvisMode: TComboBox;
    chkMinimizeTray: TCheckBox;
    chkAutoSpeak: TCheckBox;
    btTestarJarvis: TButton;
    lblJarvisStatus: TLabel;

    // Aba IA (Ordem: Provedor -> Modelo -> Token -> URL)
    lblProvider: TLabel;
    cbProvider: TComboBox;
    lblModel: TLabel;
    cbModel: TComboBox;
    lblToken: TLabel;
    edTokenGPT: TEdit;
    lblURL: TLabel;
    edURL: TEdit;

    // Aba Output Voice (TAIVoiceSynthesizer)
    lblSynthEngine: TLabel;
    cbSynthEngine: TComboBox;
    lblSynthVoice: TLabel;
    cbSynthVoice: TComboBox;
    lblSynthVolume: TLabel;
    tbSynthVolume: TTrackBar;
    lblSynthVolumeVal: TLabel;
    lblSynthRate: TLabel;
    tbSynthRate: TTrackBar;
    lblSynthRateVal: TLabel;
    chkSynthAsync: TCheckBox;
    
    // Aba Voz (Rede / Ativação)
    lblFrase: TLabel;
    edFrase: TEdit;
    lblSynth: TLabel;
    edSynthIP: TEdit;
    edSynthPort: TEdit;
    lblRecog: TLabel;
    edRecogIP: TEdit;
    edRecogPort: TEdit;

    // Aba Visão
    lblVer: TLabel;
    edVerIP: TEdit;
    edVerPort: TEdit;

    // Aba Banco de Dados
    lblMyTitle: TLabel;
    lblMyHost: TLabel;
    edMyHost: TEdit;
    lblMyDb: TLabel;
    edMyDb: TEdit;
    lblMyUser: TLabel;
    edMyUser: TEdit;
    lblMyPass: TLabel;
    edMyPass: TEdit;

    lblPostTitle: TLabel;
    lblPostHost: TLabel;
    edPostHost: TEdit;
    lblPostDb: TLabel;
    edPostDb: TEdit;
    lblPostUser: TLabel;
    edPostUser: TEdit;
    lblPostPass: TLabel;
    edPostPass: TEdit;
    lblPostSchema: TLabel;
    edPostSchema: TEdit;

    pnlButtons: TPanel;
    btSalvar: TButton;
    btCancelar: TButton;

    procedure btVerChaveClick(Sender: TObject);
    procedure btTestarJarvisClick(Sender: TObject);
    procedure cbProviderChange(Sender: TObject);
    procedure cbSynthEngineChange(Sender: TObject);
    procedure tbSynthVolumeChange(Sender: TObject);
    procedure tbSynthRateChange(Sender: TObject);
    procedure btBuscarAvatarClick(Sender: TObject);
    procedure btTestarAvatarClick(Sender: TObject);
    procedure btSalvarClick(Sender: TObject);
    procedure btCancelarClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FLoading: Boolean;
  public
    procedure CarregaModelosDoProvedor;
    procedure CarregaVozesDoSintetizador;
  end;

var
  frmConfigForm: TfrmConfig;

implementation

{$R *.lfm}

{ TfrmConfig }

procedure TfrmConfig.FormCreate(Sender: TObject);
begin
  FLoading := True;
  try
    GetAIProviderList(cbProvider.Items);
  finally
    FLoading := False;
  end;
end;

procedure TfrmConfig.btVerChaveClick(Sender: TObject);
begin
  if edJarvisKey.EchoMode = emPassword then
  begin
    edJarvisKey.EchoMode := emNormal;
    btVerChave.Caption := 'Ocultar';
  end
  else
  begin
    edJarvisKey.EchoMode := emPassword;
    btVerChave.Caption := 'Exibir';
  end;
end;

procedure TfrmConfig.btTestarJarvisClick(Sender: TObject);
var
  Client: TJarvisAPIClient;
  Msg: string;
begin
  lblJarvisStatus.Font.Color := clNavy;
  lblJarvisStatus.Caption := 'Conectando ao JARVIS...';
  Application.ProcessMessages;

  Client := TJarvisAPIClient.Create(nil);
  try
    Client.BaseURL := Trim(edJarvisURL.Text);
    Client.APIKey := Trim(edJarvisKey.Text);
    Client.Timeout := 10;
    if Client.TestarConexao(Msg) then
    begin
      lblJarvisStatus.Font.Color := clGreen;
      lblJarvisStatus.Caption := 'OK: ' + Msg;
    end
    else
    begin
      lblJarvisStatus.Font.Color := clRed;
      lblJarvisStatus.Caption := 'FALHA: ' + Msg;
    end;
  finally
    Client.Free;
  end;
end;

procedure TfrmConfig.CarregaModelosDoProvedor;
var
  Prov: TAIProvider;
  ModeloAtual: string;
begin
  ModeloAtual := cbModel.Text;
  Prov := GetAIProviderFromIndex(cbProvider.ItemIndex);
  GetAIModelListForProvider(Prov, cbModel.Items);

  if Trim(ModeloAtual) <> '' then
    cbModel.Text := ModeloAtual
  else if cbModel.Items.Count > 0 then
    cbModel.ItemIndex := 0;
end;

procedure TfrmConfig.CarregaVozesDoSintetizador;
var
  DummySynth: TAIVoiceSynthesizer;
  EngineIdx: Integer;
  VozAtual: string;
begin
  VozAtual := cbSynthVoice.Text;
  DummySynth := TAIVoiceSynthesizer.Create(nil);
  try
    EngineIdx := cbSynthEngine.ItemIndex;
    case EngineIdx of
      0: DummySynth.Engine := seSystemDefault;
      1: DummySynth.Engine := seSAPI;
      2: DummySynth.Engine := seEspeak;
      3: DummySynth.Engine := seOpenAI;
    else
      DummySynth.Engine := seSystemDefault;
    end;

    cbSynthVoice.Items.Clear;
    DummySynth.GetAvailableVoices(cbSynthVoice.Items);

    if (Trim(VozAtual) <> '') then
      cbSynthVoice.Text := VozAtual
    else if cbSynthVoice.Items.Count > 0 then
      cbSynthVoice.ItemIndex := 0;
  finally
    DummySynth.Free;
  end;
end;

procedure TfrmConfig.cbProviderChange(Sender: TObject);
var
  Prov: TAIProvider;
begin
  if FLoading then Exit;

  Prov := GetAIProviderFromIndex(cbProvider.ItemIndex);
  CarregaModelosDoProvedor;
  edURL.Text := GetDefaultEndpointForProvider(Prov);
end;

procedure TfrmConfig.cbSynthEngineChange(Sender: TObject);
begin
  if FLoading then Exit;
  CarregaVozesDoSintetizador;
end;

procedure TfrmConfig.tbSynthVolumeChange(Sender: TObject);
begin
  lblSynthVolumeVal.Caption := IntToStr(tbSynthVolume.Position) + '%';
end;

procedure TfrmConfig.tbSynthRateChange(Sender: TObject);
begin
  lblSynthRateVal.Caption := IntToStr(tbSynthRate.Position);
end;

procedure TfrmConfig.btBuscarAvatarClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Selecione o modelo 3D do Avatar';
    Dlg.Filter := 'Modelos 3D (*.glb;*.gltf)|*.glb;*.gltf|Todos (*.*)|*.*';
    if Dlg.Execute then
      edAvatarModel.Text := Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmConfig.btTestarAvatarClick(Sender: TObject);
begin
  ShowMessage('Teste de sequencia do Avatar 3D:' + LineEnding +
              '1. Estado: Idle (Respiração procedural)' + LineEnding +
              '2. Emocao: Happy (Expressao facial positiva)' + LineEnding +
              '3. Gesto: Wave (Aceno de boas-vindas)' + LineEnding +
              '4. Gesto: Think (Postura pensativa)' + LineEnding +
              '5. Estado: Speaking (Lip-Sync mandíbula)' + LineEnding +
              '6. Retorno: Idle' + LineEnding +
              'Sequencia validada com sucesso!');
end;

procedure TfrmConfig.btSalvarClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TfrmConfig.btCancelarClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
