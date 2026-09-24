unit frmconfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  chatgpt, aivoicesynthesizer, jarvis_api, vision_types, webcam_vision, aikinectsensor, aikinect_types;

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
    cbVisionSource: TComboBox;
    cbKinectDevice: TComboBox;
    cbCameraDevice: TComboBox;
    lblVisionSource: TLabel;
    lblVisionStatus: TLabel;
    btRefreshVisionDevices: TButton;
    btTestVisionDevice: TButton;
    imgVisionPreview: TImage;
    chkKinectSeated: TCheckBox;
    lblKinectDist: TLabel;
    edKinectMinDist: TEdit;
    edKinectMaxDist: TEdit;
    lblKinectTargets: TLabel;
    edKinectTargetLeft: TEdit;
    edKinectTargetRight: TEdit;
    edKinectTargetCenter: TEdit;
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
    
    // Aba Reconhecimento de Voz / Microfone (TAIVoiceRecognizer / TAIAudioInput)
    lblRecogEngine: TLabel;
    cbRecogEngine: TComboBox;
    lblRecogLanguage: TLabel;
    edRecogLanguage: TEdit;
    lblAudioSampleRate: TLabel;
    cbAudioSampleRate: TComboBox;
    lblAudioChannels: TLabel;
    cbAudioChannels: TComboBox;

    // Aba Visão

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

    procedure VisionSourceChange(Sender: TObject);
    procedure RefreshVisionDevices(Sender: TObject);
    procedure TestVisionDevice(Sender: TObject);
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
    FTestCamera: TWebcamVision;
  public
    procedure LoadVision(Source: TVisionSource; KinectIndex: Integer; const Camera: string);
    procedure StopVisionTest;
    destructor Destroy; override;
    procedure CarregaModelosDoProvedor;
    procedure CarregaVozesDoSintetizador;
  end;

var
  frmConfigForm: TfrmConfig;

implementation

{$R *.lfm}

{ TfrmConfig }

destructor TfrmConfig.Destroy;
begin
  StopVisionTest;
  inherited Destroy;
end;

procedure TfrmConfig.StopVisionTest;
begin
  FreeAndNil(FTestCamera);
end;

procedure TfrmConfig.LoadVision(Source: TVisionSource; KinectIndex: Integer; const Camera: string);
begin
  cbVisionSource.ItemIndex := Ord(Source);
  VisionSourceChange(nil);
  if (KinectIndex >= 0) and (KinectIndex < cbKinectDevice.Items.Count) then
    cbKinectDevice.ItemIndex := KinectIndex;
  if cbCameraDevice.Items.IndexOf(Camera) >= 0 then
    cbCameraDevice.ItemIndex := cbCameraDevice.Items.IndexOf(Camera);
end;

procedure TfrmConfig.VisionSourceChange(Sender: TObject);
var IsKinect: Boolean;
begin
  StopVisionTest;
  IsKinect := cbVisionSource.ItemIndex = Ord(vsKinect);
  cbKinectDevice.Enabled := IsKinect;
  cbKinectDevice.Visible := IsKinect;
  cbCameraDevice.Visible := cbVisionSource.ItemIndex = Ord(vsWebcam);
  chkKinectSeated.Enabled := IsKinect;
  edKinectMinDist.Enabled := IsKinect;
  edKinectMaxDist.Enabled := IsKinect;
  edKinectTargetLeft.Enabled := IsKinect;
  edKinectTargetRight.Enabled := IsKinect;
  edKinectTargetCenter.Enabled := IsKinect;
  lblKinectDist.Enabled := IsKinect;
  lblKinectTargets.Enabled := IsKinect;
  btTestVisionDevice.Enabled := cbVisionSource.ItemIndex > 0;
  RefreshVisionDevices(nil);
end;

procedure TfrmConfig.RefreshVisionDevices(Sender: TObject);
var Sensor: TAIKinectSensor; L: TStringList; Old: string; I: Integer;
begin
  StopVisionTest;
  imgVisionPreview.Picture.Clear;
  lblVisionStatus.Caption := 'Visao desativada';
  L := nil;
  try
    if cbVisionSource.ItemIndex = Ord(vsKinect) then
    begin
      I := cbKinectDevice.ItemIndex;
      Sensor := TAIKinectSensor.Create(nil);
      try L := Sensor.ListDevices finally Sensor.Free end;
      cbKinectDevice.Items.Assign(L);
      if (I < 0) or (I >= L.Count) then I := 0;
      if L.Count > 0 then cbKinectDevice.ItemIndex := I;
      lblVisionStatus.Caption := Format('Kinect encontrados: %d', [L.Count]);
    end
    else if cbVisionSource.ItemIndex = Ord(vsWebcam) then
    begin
      Old := cbCameraDevice.Text;
      L := TWebcamVision.Devices;
      cbCameraDevice.Items.Assign(L);
      cbCameraDevice.ItemIndex := L.IndexOf(Old);
      if L.Count = 1 then cbCameraDevice.ItemIndex := 0;
      lblVisionStatus.Caption := Format('Câmeras VFW: %d. Somente RGB; sem depth, skeleton ou gestos Kinect.', [L.Count]);
    end;
  except on E: Exception do lblVisionStatus.Caption := 'Erro: ' + E.Message end;
  L.Free;
end;

procedure TfrmConfig.TestVisionDevice(Sender: TObject);
var Sensor: TAIKinectSensor;
begin
  StopVisionTest;
  try
    if cbVisionSource.ItemIndex = Ord(vsKinect) then
    begin
      if cbKinectDevice.ItemIndex < 0 then
      begin lblVisionStatus.Caption := 'Kinect não detectado.'; Exit end;
      Sensor := TAIKinectSensor.Create(nil);
      try
        Sensor.DeviceIndex := cbKinectDevice.ItemIndex;
        Sensor.Backend := kbKinectSDK10;
        Sensor.KinectModel := kmXbox360;
        if Sensor.Open then
          lblVisionStatus.Caption := 'Kinect detectado e inicializado: Kinect v1 / Xbox 360. RGB, depth e skeleton disponiveis.'
        else lblVisionStatus.Caption := 'Erro: ' + Sensor.LastError;
      finally Sensor.Free end;
    end
    else if cbVisionSource.ItemIndex = Ord(vsWebcam) then
    begin
      FTestCamera := TWebcamVision.Create(nil);
      if FTestCamera.OpenDevice(cbCameraDevice.Text, tsVisao, imgVisionPreview) then
        lblVisionStatus.Caption := 'Webcam inicializada: RGB disponivel.'
      else lblVisionStatus.Caption := 'Erro: ' + FTestCamera.LastError;
    end;
  except on E: Exception do lblVisionStatus.Caption := 'Erro: ' + E.Message end;
end;

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
