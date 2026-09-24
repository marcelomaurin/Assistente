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
    chkEnableKinect: TCheckBox;
    chkEnableCamera: TCheckBox;
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
    function SelectedVisionSource: TVisionSource;
    procedure LoadVision(Source: TVisionSource; KinectIndex: Integer; const Camera: string);
    procedure ApplyDeviceList(AKinectDevices, ACameraDevices: TStrings;
      ASavedKinectIndex: Integer; const ASavedCamera: string;
      AWantKinect: Boolean; AWantCamera: Boolean);
    procedure UpdateVisionControlsState;
    procedure UpdateVisionStatusLabel;
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

procedure TfrmConfig.ApplyDeviceList(AKinectDevices, ACameraDevices: TStrings;
  ASavedKinectIndex: Integer; const ASavedCamera: string;
  AWantKinect: Boolean; AWantCamera: Boolean);
var
  HasKinect, HasCam: Boolean;
begin
  FLoading := True;
  try
    // --- Kinect ---
    cbKinectDevice.Items.Clear;
    HasKinect := (AKinectDevices <> nil) and (AKinectDevices.Count > 0);
    if not HasKinect then
    begin
      chkEnableKinect.Checked := False;
      chkEnableKinect.Enabled := False;
      cbKinectDevice.Items.Add('Nenhum Kinect detectado');
      cbKinectDevice.ItemIndex := -1;
      cbKinectDevice.Enabled := False;
    end
    else
    begin
      cbKinectDevice.Items.Assign(AKinectDevices);
      chkEnableKinect.Enabled := True;
      chkEnableKinect.Checked := AWantKinect;
      if (ASavedKinectIndex >= 0) and (ASavedKinectIndex < AKinectDevices.Count) then
        cbKinectDevice.ItemIndex := ASavedKinectIndex
      else if AKinectDevices.Count = 1 then
        cbKinectDevice.ItemIndex := 0
      else
        cbKinectDevice.ItemIndex := -1;
      cbKinectDevice.Enabled := chkEnableKinect.Checked;
    end;

    // --- Câmera ---
    cbCameraDevice.Items.Clear;
    HasCam := (ACameraDevices <> nil) and (ACameraDevices.Count > 0);
    if not HasCam then
    begin
      chkEnableCamera.Checked := False;
      chkEnableCamera.Enabled := False;
      cbCameraDevice.Items.Add('Nenhuma câmera detectada');
      cbCameraDevice.ItemIndex := -1;
      cbCameraDevice.Enabled := False;
    end
    else
    begin
      cbCameraDevice.Items.Assign(ACameraDevices);
      chkEnableCamera.Enabled := True;
      chkEnableCamera.Checked := AWantCamera;
      if ACameraDevices.Count = 1 then
        cbCameraDevice.ItemIndex := 0
      else
        cbCameraDevice.ItemIndex := TWebcamVision.ResolveDevice(ACameraDevices, ASavedCamera);
      cbCameraDevice.Enabled := chkEnableCamera.Checked;
    end;
  finally
    FLoading := False;
  end;

  UpdateVisionControlsState;
  UpdateVisionStatusLabel;
end;

procedure TfrmConfig.LoadVision(Source: TVisionSource; KinectIndex: Integer; const Camera: string);
var
  Sensor: TAIKinectSensor;
  LKinect, LCam: TStringList;
begin
  LKinect := TStringList.Create;
  LCam := TStringList.Create;
  try
    try
      Sensor := TAIKinectSensor.Create(nil);
      try
        Sensor.Backend := kbKinectSDK10;
        Sensor.KinectModel := kmXbox360;
        LKinect.Assign(Sensor.ListDevices);
      finally
        Sensor.Free;
      end;
    except
      on E: Exception do LKinect.Clear;
    end;

    try
      LCam.Assign(TWebcamVision.Devices);
    except
      on E: Exception do LCam.Clear;
    end;

    ApplyDeviceList(LKinect, LCam, KinectIndex, Camera,
      Source in [vsKinect, vsBoth],
      Source in [vsWebcam, vsBoth]);
  finally
    LKinect.Free;
    LCam.Free;
  end;
end;

procedure TfrmConfig.UpdateVisionControlsState;
var
  IsKinectValid, IsCamValid: Boolean;
begin
  IsKinectValid := (cbKinectDevice.Items.Count > 0) and
                   (cbKinectDevice.Text <> 'Nenhum Kinect detectado') and
                   (cbKinectDevice.ItemIndex >= 0);
  cbKinectDevice.Enabled := chkEnableKinect.Checked and IsKinectValid;

  chkKinectSeated.Enabled := chkEnableKinect.Checked;
  edKinectMinDist.Enabled := chkEnableKinect.Checked;
  edKinectMaxDist.Enabled := chkEnableKinect.Checked;
  edKinectTargetLeft.Enabled := chkEnableKinect.Checked;
  edKinectTargetRight.Enabled := chkEnableKinect.Checked;
  edKinectTargetCenter.Enabled := chkEnableKinect.Checked;
  lblKinectDist.Enabled := chkEnableKinect.Checked;
  lblKinectTargets.Enabled := chkEnableKinect.Checked;

  IsCamValid := (cbCameraDevice.Items.Count > 0) and
                (cbCameraDevice.Text <> 'Nenhuma câmera detectada') and
                (cbCameraDevice.ItemIndex >= 0);
  cbCameraDevice.Enabled := chkEnableCamera.Checked and IsCamValid;

  btTestVisionDevice.Enabled := (chkEnableKinect.Checked and IsKinectValid) or
                                (chkEnableCamera.Checked and IsCamValid);
end;

procedure TfrmConfig.UpdateVisionStatusLabel;
var
  KinectMsg, CameraMsg: string;
begin
  if (cbKinectDevice.Items.Count > 0) and (cbKinectDevice.Text <> 'Nenhum Kinect detectado') and (cbKinectDevice.ItemIndex >= 0) then
    KinectMsg := 'Kinect: ' + cbKinectDevice.Text
  else
    KinectMsg := 'Kinect: não detectado';

  if (cbCameraDevice.Items.Count > 0) and (cbCameraDevice.Text <> 'Nenhuma câmera detectada') and (cbCameraDevice.ItemIndex >= 0) then
    CameraMsg := 'Câmera: ' + cbCameraDevice.Text
  else
    CameraMsg := 'Câmera: não detectada';

  lblVisionStatus.Caption := KinectMsg + ' | ' + CameraMsg;
end;

procedure TfrmConfig.VisionSourceChange(Sender: TObject);
begin
  StopVisionTest;
  if FLoading then Exit;
  UpdateVisionControlsState;
  UpdateVisionStatusLabel;
end;

function TfrmConfig.SelectedVisionSource: TVisionSource;
var
  KinectActive, CameraActive: Boolean;
begin
  KinectActive := chkEnableKinect.Checked and
                  (cbKinectDevice.Items.Count > 0) and
                  (cbKinectDevice.Text <> 'Nenhum Kinect detectado') and
                  (cbKinectDevice.ItemIndex >= 0);

  CameraActive := chkEnableCamera.Checked and
                  (cbCameraDevice.Items.Count > 0) and
                  (cbCameraDevice.Text <> 'Nenhuma câmera detectada') and
                  (cbCameraDevice.ItemIndex >= 0);

  if KinectActive and CameraActive then
    Result := vsBoth
  else if KinectActive then
    Result := vsKinect
  else if CameraActive then
    Result := vsWebcam
  else
    Result := vsNone;
end;

procedure TfrmConfig.RefreshVisionDevices(Sender: TObject);
var
  Sensor: TAIKinectSensor;
  LKinect, LCam: TStringList;
  SavedKinectIndex: Integer;
  SavedCamera: string;
begin
  StopVisionTest;
  imgVisionPreview.Picture.Clear;
  lblVisionStatus.Caption := '';

  SavedKinectIndex := cbKinectDevice.ItemIndex;
  SavedCamera := cbCameraDevice.Text;

  LKinect := TStringList.Create;
  LCam := TStringList.Create;
  try
    try
      Sensor := TAIKinectSensor.Create(nil);
      try
        Sensor.Backend := kbKinectSDK10;
        Sensor.KinectModel := kmXbox360;
        LKinect.Assign(Sensor.ListDevices);
      finally
        Sensor.Free;
      end;
    except
      on E: Exception do LKinect.Clear;
    end;

    try
      LCam.Assign(TWebcamVision.Devices);
    except
      on E: Exception do LCam.Clear;
    end;

    ApplyDeviceList(LKinect, LCam, SavedKinectIndex, SavedCamera,
      chkEnableKinect.Checked, chkEnableCamera.Checked);
  finally
    LKinect.Free;
    LCam.Free;
  end;
end;

procedure TfrmConfig.TestVisionDevice(Sender: TObject);
var
  Sensor: TAIKinectSensor;
  CameraStatus, KinectStatus: string;
  CanTestKinect, CanTestCam: Boolean;
begin
  StopVisionTest;
  lblVisionStatus.Caption := '';
  KinectStatus := '';
  CameraStatus := '';

  CanTestKinect := chkEnableKinect.Checked and
                   (cbKinectDevice.Items.Count > 0) and
                   (cbKinectDevice.Text <> 'Nenhum Kinect detectado') and
                   (cbKinectDevice.ItemIndex >= 0);

  CanTestCam := chkEnableCamera.Checked and
                (cbCameraDevice.Items.Count > 0) and
                (cbCameraDevice.Text <> 'Nenhuma câmera detectada') and
                (cbCameraDevice.ItemIndex >= 0);

  if CanTestKinect then
  begin
    try
      Sensor := TAIKinectSensor.Create(nil);
      try
        Sensor.DeviceIndex := cbKinectDevice.ItemIndex;
        Sensor.Backend := kbKinectSDK10;
        Sensor.KinectModel := kmXbox360;
        if Sensor.Open then
          KinectStatus := 'Kinect: inicializado com sucesso.'
        else
          KinectStatus := 'Kinect: ' + Sensor.LastError;
      finally
        Sensor.Free;
      end;
    except
      on E: Exception do
        KinectStatus := 'Kinect: ' + E.Message;
    end;
  end
  else if chkEnableKinect.Checked then
    KinectStatus := 'Kinect: não detectado ou inválido.';

  if CanTestCam then
  begin
    try
      FTestCamera := TWebcamVision.Create(nil);
      if FTestCamera.OpenDevice(cbCameraDevice.Text, tsVisao, imgVisionPreview) then
        CameraStatus := 'Câmera: inicializada - RGB disponível.'
      else
      begin
        CameraStatus := 'Câmera: ' + FTestCamera.LastError;
        FreeAndNil(FTestCamera);
      end;
    except
      on E: Exception do
      begin
        CameraStatus := 'Câmera: ' + E.Message;
        FreeAndNil(FTestCamera);
      end;
    end;
  end
  else if chkEnableCamera.Checked then
    CameraStatus := 'Câmera: não detectada ou inválida.';

  if (KinectStatus <> '') and (CameraStatus <> '') then
    lblVisionStatus.Caption := KinectStatus + ' | ' + CameraStatus
  else if KinectStatus <> '' then
    lblVisionStatus.Caption := KinectStatus
  else if CameraStatus <> '' then
    lblVisionStatus.Caption := CameraStatus
  else
    lblVisionStatus.Caption := 'Nenhum dispositivo habilitado para teste.';
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
  if chkEnableKinect.Checked and (cbKinectDevice.Items.Count > 0) and
     (cbKinectDevice.ItemIndex < 0) then
  begin
    pcConfig.ActivePage := tsVisao;
    ShowMessage('Selecione o Kinect que deseja utilizar.');
    if cbKinectDevice.CanFocus then
    begin
      try
        cbKinectDevice.SetFocus;
      except
      end;
    end;
    Exit;
  end;
  if chkEnableCamera.Checked and (cbCameraDevice.Items.Count > 0) and
     (cbCameraDevice.ItemIndex < 0) then
  begin
    pcConfig.ActivePage := tsVisao;
    ShowMessage('Selecione a câmera que deseja utilizar.');
    if cbCameraDevice.CanFocus then
    begin
      try
        cbCameraDevice.SetFocus;
      except
      end;
    end;
    Exit;
  end;
  ModalResult := mrOk;
end;

procedure TfrmConfig.btCancelarClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
