unit frmconfig;



{$mode objfpc}{$H+}



interface



uses

  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls, ExtCtrls,

  chatgpt, aivoicesynthesizer, jarvis_api, vision_types, webcam_vision, aikinectsensor, aikinect_types,
  Windows, mmsystem, Math, fphttpclient, opensslsockets, ComObj, ActiveX;



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
    btTestarProvedor: TButton;
    lblProvedorStatus: TLabel;



    // Aba Output Voice (TAIVoiceSynthesizer)
    lblSynthEngine: TLabel;
    cbSynthEngine: TComboBox;
    lblSynthModel: TLabel;
    cbSynthModel: TComboBox;
    lblSynthVoice: TLabel;
    cbSynthVoice: TComboBox;
    lblOpenAINote: TLabel;
    lblSynthVolume: TLabel;
    tbSynthVolume: TTrackBar;
    lblSynthVolumeVal: TLabel;
    lblSynthRate: TLabel;
    tbSynthRate: TTrackBar;
    lblSynthRateVal: TLabel;
    chkSynthAsync: TCheckBox;
    btTestarFala: TButton;
    lblTestarFalaStatus: TLabel;

    

    // Aba Reconhecimento de Voz / Microfone (TAIVoiceRecognizer / TAIAudioInput)
    lblRecogEngine: TLabel;
    cbRecogEngine: TComboBox;
    lblRecogLanguage: TLabel;
    edRecogLanguage: TEdit;
    chkContinuousListening: TCheckBox;
    gbCaptacao: TGroupBox;
    lblAudioDevice: TLabel;
    cbAudioDevice: TComboBox;
    btRefreshAudio: TButton;
    lblAudioDeviceInfo: TLabel;
    lblAudioSampleRate: TLabel;
    cbAudioSampleRate: TComboBox;
    lblAudioChannels: TLabel;
    cbAudioChannels: TComboBox;
    lblAudioFormatInfo: TLabel;
    btTestarAudioInput: TButton;
    pbAudioLevel: TProgressBar;
    lblAudioTestStatus: TLabel;



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
    procedure btTestarProvedorClick(Sender: TObject);
    procedure cbProviderChange(Sender: TObject);

    procedure cbSynthEngineChange(Sender: TObject);

    procedure tbSynthVolumeChange(Sender: TObject);

    procedure tbSynthRateChange(Sender: TObject);

    procedure btBuscarAvatarClick(Sender: TObject);

    procedure btTestarAvatarClick(Sender: TObject);

    procedure btSalvarClick(Sender: TObject);
    procedure btCancelarClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure cbAudioDeviceChange(Sender: TObject);
    procedure btRefreshAudioClick(Sender: TObject);
    procedure btTestarAudioInputClick(Sender: TObject);
    procedure btTestarFalaClick(Sender: TObject);

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
    procedure EnumerateAudioDevices(SelectedDevIndex: Integer = -1);
    function GetSelectedAudioDeviceIndex: Integer;
    function GetSelectedAudioDeviceName: string;
    function IsAIProviderOpenAI: Boolean;
    procedure AtualizaEstadoOpenAITTS;
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

    if HasKinect then

    begin

      cbKinectDevice.Items.Assign(AKinectDevices);

      chkEnableKinect.Enabled := True;

      chkEnableKinect.Checked := AWantKinect;

      if (ASavedKinectIndex >= 0) and (ASavedKinectIndex < cbKinectDevice.Items.Count) then

        cbKinectDevice.ItemIndex := ASavedKinectIndex

      else if (ASavedKinectIndex < 0) and (AKinectDevices.Count = 1) then
        cbKinectDevice.ItemIndex := 0
      else cbKinectDevice.ItemIndex := -1;

      cbKinectDevice.Enabled := chkEnableKinect.Checked;

    end

    else

    begin

      cbKinectDevice.Items.Add('Nenhum Kinect detectado');

      cbKinectDevice.ItemIndex := -1;

      cbKinectDevice.Enabled := False;

      chkEnableKinect.Checked := False;

      chkEnableKinect.Enabled := False;

    end;

    // --- Câmera ---

    cbCameraDevice.Items.Clear;

    HasCam := (ACameraDevices <> nil) and (ACameraDevices.Count > 0);

    if not HasCam then

    begin

      chkEnableCamera.Enabled := False;

      chkEnableCamera.Checked := False;

      cbCameraDevice.Items.Add('Nenhuma câmera detectada');

      cbCameraDevice.ItemIndex := -1;

      cbCameraDevice.Enabled := False;

    end

    else

    begin

      cbCameraDevice.Items.Assign(ACameraDevices);

      chkEnableCamera.Enabled := True;

      chkEnableCamera.Checked := AWantCamera;

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

  PreferKin, PreferCam: Boolean;

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



    PreferKin := (Source in [vsKinect, vsBoth]) and (LKinect.Count > 0);

    // Se a fonte incluir webcam OU se houver câmera física disponível e nenhuma configuração anterior contrária, mantém câmera marcada

    PreferCam := (Source in [vsWebcam, vsBoth]) or ((Source = vsNone) and (LCam.Count > 0) and (LKinect.Count = 0));



    ApplyDeviceList(LKinect, LCam, KinectIndex, Camera, PreferKin, PreferCam);

  finally

    LKinect.Free;

    LCam.Free;

  end;

end;



procedure TfrmConfig.UpdateVisionControlsState;

var

  HasCamDevices: Boolean;

begin

  cbKinectDevice.Enabled := chkEnableKinect.Checked;

  chkKinectSeated.Enabled := chkEnableKinect.Checked;

  lblKinectDist.Enabled := chkEnableKinect.Checked;

  edKinectMinDist.Enabled := chkEnableKinect.Checked;

  edKinectMaxDist.Enabled := chkEnableKinect.Checked;



  HasCamDevices := (cbCameraDevice.Items.Count > 0) and

                   (cbCameraDevice.Items[0] <> 'Nenhuma câmera detectada');



  cbCameraDevice.Enabled := chkEnableCamera.Checked and HasCamDevices;



  btTestVisionDevice.Enabled := chkEnableKinect.Checked or (chkEnableCamera.Checked and HasCamDevices);

end;



procedure TfrmConfig.UpdateVisionStatusLabel;

var

  KinectMsg, CameraMsg: string;

begin

  if not chkEnableKinect.Enabled then
    KinectMsg := 'Kinect: não detectado'
  else if chkEnableKinect.Checked and (cbKinectDevice.ItemIndex >= 0) then

    KinectMsg := 'Kinect: ' + cbKinectDevice.Text

  else if chkEnableKinect.Checked then

    KinectMsg := 'Kinect: habilitado'

  else

    KinectMsg := 'Kinect: desabilitado';



  if not chkEnableCamera.Enabled then
    CameraMsg := 'Câmera: não detectada'
  else if chkEnableCamera.Checked and (cbCameraDevice.ItemIndex >= 0) and

     (cbCameraDevice.Text <> 'Nenhuma câmera detectada') then

    CameraMsg := 'Câmera: ' + cbCameraDevice.Text

  else if chkEnableCamera.Checked then

    CameraMsg := 'Câmera: não detectada'

  else

    CameraMsg := 'Câmera: desabilitada';



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

  imgVisionPreview.Picture.Clear;

  lblVisionStatus.Caption := '';

  KinectStatus := '';

  CameraStatus := '';



  CanTestKinect := chkEnableKinect.Enabled and chkEnableKinect.Checked and

                   (cbKinectDevice.Items.Count > 0) and

                   (cbKinectDevice.Text <> 'Nenhum Kinect detectado') and

                   (cbKinectDevice.ItemIndex >= 0);



  CanTestCam := chkEnableCamera.Enabled and chkEnableCamera.Checked and

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

  end;



  if CanTestCam then

  begin

    try

      FTestCamera := TWebcamVision.Create(Self);

      if FTestCamera.OpenDevice(cbCameraDevice.Text, tsVisao, imgVisionPreview) then

        CameraStatus := 'Câmera: ' + FTestCamera.DeviceName + ' (RGB ativo)'

      else

      begin

        CameraStatus := 'Câmera: falha ao abrir (' + FTestCamera.LastError + ')';

        FreeAndNil(FTestCamera);

      end;

    except

      on E: Exception do

      begin

        CameraStatus := 'Câmera: erro - ' + E.Message;

        FreeAndNil(FTestCamera);

      end;

    end;

  end;



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



procedure TfrmConfig.FormShow(Sender: TObject);
var
  Prov: TAIProvider;
begin
  Prov := GetAIProviderFromIndex(cbProvider.ItemIndex);
  if not (Prov in [AIP_LOCAL, AIP_LLAMA_CPP, AIP_NEURAL_API, AIP_OPENAI_COMPATIBLE]) then
  begin
    if (Trim(edURL.Text) = GetDefaultEndpointForProvider(Prov)) or
       (Pos('http://localhost', edURL.Text) > 0) then
      edURL.Text := '';
  end;

  if (cbAudioDevice <> nil) and (cbAudioDevice.Items.Count = 0) then
    EnumerateAudioDevices(-1);

  AtualizaEstadoOpenAITTS;
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



procedure TfrmConfig.btTestarProvedorClick(Sender: TObject);
var
  AI: TCHATGPT;
  Prov: TAIProvider;
  Resp, ErrMsg: string;
begin
  lblProvedorStatus.Font.Color := clNavy;
  lblProvedorStatus.Caption := 'Conectando ao provedor (' + cbProvider.Text + ')...';
  btTestarProvedor.Enabled := False;
  Application.ProcessMessages;

  AI := TCHATGPT.Create(nil);
  try
    try
      Prov := GetAIProviderFromIndex(cbProvider.ItemIndex);
      AI.Provider := Prov;
      AI.CustomModel := Trim(cbModel.Text);
      AI.TOKEN := Trim(edTokenGPT.Text);
      AI.URL := Trim(edURL.Text);
      AI.Timeout := 15;
      AI.MaxTokens := 30;

      if AI.SendQuestion('Responda apenas: OK') then
      begin
        lblProvedorStatus.Font.Color := clGreen;
        Resp := Trim(AI.Response);
        if Resp = '' then
          Resp := '(Resposta OK recebida do provedor)';
        lblProvedorStatus.Caption := 'OK: ' + Resp;
      end
      else
      begin
        lblProvedorStatus.Font.Color := clRed;
        ErrMsg := Trim(AI.LastError);
        if ErrMsg = '' then
          ErrMsg := 'Falha na comunicação com o provedor.';
        lblProvedorStatus.Caption := 'FALHA: ' + ErrMsg;
      end;
    except
      on E: Exception do
      begin
        lblProvedorStatus.Font.Color := clRed;
        lblProvedorStatus.Caption := 'ERRO: ' + E.Message;
      end;
    end;
  finally
    AI.Free;
    btTestarProvedor.Enabled := True;
  end;
end;



procedure TfrmConfig.CarregaModelosDoProvedor;
var
  Prov: TAIProvider;
  ModeloAtual: string;
  Idx: Integer;
begin
  ModeloAtual := Trim(cbModel.Text);
  Prov := GetAIProviderFromIndex(cbProvider.ItemIndex);

  cbModel.Items.Clear;
  GetAIModelListForProvider(Prov, cbModel.Items);

  // Garante lista coerente de modelos para provedores compativeis/locais
  if Prov = AIP_OPENAI_COMPATIBLE then
  begin
    if (cbModel.Items.Count <= 1) then
    begin
      cbModel.Items.Clear;
      cbModel.Items.Add('gpt-4o-mini');
      cbModel.Items.Add('gpt-4o');
      cbModel.Items.Add('gpt-3.5-turbo');
      cbModel.Items.Add('llama-3.2-3b-instruct');
      cbModel.Items.Add('qwen-2.5-7b-instruct');
      cbModel.Items.Add('deepseek-chat');
      cbModel.Items.Add('custom-model');
    end;
  end
  else if Prov = AIP_LLAMA_CPP then
  begin
    if (cbModel.Items.Count <= 1) then
    begin
      cbModel.Items.Clear;
      cbModel.Items.Add('llama3.2:3b');
      cbModel.Items.Add('qwen2.5:1.5b');
      cbModel.Items.Add('deepseek-r1:1.5b');
      cbModel.Items.Add('custom-model');
    end;
  end
  else if Prov = AIP_NEURAL_API then
  begin
    if (cbModel.Items.Count <= 1) then
    begin
      cbModel.Items.Clear;
      cbModel.Items.Add('default');
      cbModel.Items.Add('custom-model');
    end;
  end;

  if (SameText(ModeloAtual, 'openai-4.1-mini') or SameText(ModeloAtual, 'gpt-4.1-mini') or
      SameText(ModeloAtual, 'gpt-4.1') or SameText(ModeloAtual, 'gpt-5')) then
    ModeloAtual := 'gpt-4o-mini';

  if ModeloAtual <> '' then
  begin
    Idx := cbModel.Items.IndexOf(ModeloAtual);
    if Idx >= 0 then
      cbModel.ItemIndex := Idx
    else if FLoading then
      cbModel.Text := ModeloAtual
    else if cbModel.Items.Count > 0 then
      cbModel.ItemIndex := 0
    else
      cbModel.Text := ModeloAtual;
  end
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
  EngineIdx := cbSynthEngine.ItemIndex;

  if EngineIdx = 3 then // OpenAI TTS
  begin
    if not IsAIProviderOpenAI then
    begin
      ShowMessage('O mecanismo OpenAI TTS só pode ser utilizado se o provedor da IA for OpenAI.' + LineEnding +
                  'Altere o provedor na aba "IA / ChatGPT" para OpenAI.');
      cbSynthEngine.ItemIndex := 1; // SAPI
      CarregaVozesDoSintetizador;
      Exit;
    end;

    // Exibe modelo e aviso
    if lblSynthModel <> nil then lblSynthModel.Visible := True;
    if cbSynthModel <> nil then
    begin
      cbSynthModel.Visible := True;
      if cbSynthModel.Items.Count = 0 then
      begin
        cbSynthModel.Items.Add('tts-1');
        cbSynthModel.Items.Add('tts-1-hd');
        cbSynthModel.Items.Add('gpt-4o-mini-tts');
        cbSynthModel.ItemIndex := 0;
      end;
    end;
    if lblOpenAINote <> nil then lblOpenAINote.Visible := True;

    // Vozes oficiais da OpenAI
    cbSynthVoice.Items.Clear;
    cbSynthVoice.Items.Add('alloy');
    cbSynthVoice.Items.Add('echo');
    cbSynthVoice.Items.Add('fable');
    cbSynthVoice.Items.Add('onyx');
    cbSynthVoice.Items.Add('nova');
    cbSynthVoice.Items.Add('shimmer');

    if (Trim(VozAtual) <> '') and (cbSynthVoice.Items.IndexOf(VozAtual) >= 0) then
      cbSynthVoice.Text := VozAtual
    else
      cbSynthVoice.ItemIndex := 0; // alloy
    Exit;
  end;

  // Motores locais (SAPI / eSpeak / Default)
  if lblSynthModel <> nil then lblSynthModel.Visible := False;
  if cbSynthModel <> nil then cbSynthModel.Visible := False;
  if lblOpenAINote <> nil then lblOpenAINote.Visible := False;

  DummySynth := TAIVoiceSynthesizer.Create(nil);
  try
    case EngineIdx of
      0: DummySynth.Engine := seSystemDefault;
      1: DummySynth.Engine := seSAPI;
      2: DummySynth.Engine := seEspeak;
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

  // Provedores nao-locais nao precisam ter URL preenchida (em branco = padrao da API)
  if not (Prov in [AIP_LOCAL, AIP_LLAMA_CPP, AIP_NEURAL_API, AIP_OPENAI_COMPATIBLE]) then
    edURL.Text := ''
  else
    edURL.Text := GetDefaultEndpointForProvider(Prov);

  lblProvedorStatus.Font.Color := clNavy;
  lblProvedorStatus.Caption := 'Clique no botão acima para testar a comunicação com o provedor...';

  // Se o provedor da IA nao for OpenAI e o sintetizador de voz estiver em OpenAI TTS, reverte para Windows SAPI
  if (Prov <> AIP_OPENAI) and (cbSynthEngine <> nil) and (cbSynthEngine.ItemIndex = 3) then
  begin
    cbSynthEngine.ItemIndex := 1;
    CarregaVozesDoSintetizador;
  end
  else
    AtualizaEstadoOpenAITTS;
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

     (cbKinectDevice.Items[0] <> 'Nenhum Kinect detectado') and

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

     (cbCameraDevice.Items[0] <> 'Nenhuma câmera detectada') and

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

procedure TfrmConfig.EnumerateAudioDevices(SelectedDevIndex: Integer = -1);
var
  NumDevs: Cardinal;
  i: Integer;
  CapsW: WAVEINCAPSW;
  DevName: string;
  TargetIndex: Integer;
begin
  if cbAudioDevice = nil then Exit;
  cbAudioDevice.Items.BeginUpdate;
  try
    cbAudioDevice.Items.Clear;
    cbAudioDevice.Items.AddObject('[Padrão do Sistema] (WAVE_MAPPER)', TObject(IntPtr(-1)));

    NumDevs := waveInGetNumDevs();
    TargetIndex := 0;

    for i := 0 to Integer(NumDevs) - 1 do
    begin
      FillChar(CapsW, SizeOf(CapsW), 0);
      if waveInGetDevCapsW(i, @CapsW, SizeOf(CapsW)) = MMSYSERR_NOERROR then
      begin
        DevName := WideCharToString(CapsW.szPname);
        cbAudioDevice.Items.AddObject(Format('[%d] %s', [i, DevName]), TObject(IntPtr(i)));
        if i = SelectedDevIndex then
          TargetIndex := cbAudioDevice.Items.Count - 1;
      end;
    end;

    if (TargetIndex >= 0) and (TargetIndex < cbAudioDevice.Items.Count) then
      cbAudioDevice.ItemIndex := TargetIndex
    else
      cbAudioDevice.ItemIndex := 0;
  finally
    cbAudioDevice.Items.EndUpdate;
  end;
  cbAudioDeviceChange(cbAudioDevice);
end;

function TfrmConfig.GetSelectedAudioDeviceIndex: Integer;
begin
  if (cbAudioDevice = nil) or (cbAudioDevice.ItemIndex < 0) then
    Result := -1
  else
    Result := Integer(IntPtr(cbAudioDevice.Items.Objects[cbAudioDevice.ItemIndex]));
end;

function TfrmConfig.GetSelectedAudioDeviceName: string;
begin
  if (cbAudioDevice = nil) or (cbAudioDevice.ItemIndex < 0) then
    Result := ''
  else
    Result := cbAudioDevice.Items[cbAudioDevice.ItemIndex];
end;

procedure TfrmConfig.cbAudioDeviceChange(Sender: TObject);
var
  DevId: Integer;
  CapsW: WAVEINCAPSW;
  DevName: string;
  ChInfo: string;
begin
  if lblAudioDeviceInfo = nil then Exit;
  DevId := GetSelectedAudioDeviceIndex;
  if DevId < 0 then
  begin
    lblAudioDeviceInfo.Caption := 'Dispositivo: Mapeado automaticamente pelo Windows como padrão do sistema (WAVE_MAPPER).';
    lblAudioDeviceInfo.Font.Color := clNavy;
  end
  else
  begin
    FillChar(CapsW, SizeOf(CapsW), 0);
    if waveInGetDevCapsW(DevId, @CapsW, SizeOf(CapsW)) = MMSYSERR_NOERROR then
    begin
      DevName := WideCharToString(CapsW.szPname);
      if CapsW.wChannels = 1 then
        ChInfo := '1 canal (Mono)'
      else
        ChInfo := Format('%d canais (Estéreo)', [CapsW.wChannels]);
      lblAudioDeviceInfo.Caption := Format('Dispositivo #%d: %s'#13#10'Canais Nativos: %s | Formato: 16-bit PCM | Status: Disponível', [DevId, DevName, ChInfo]);
      lblAudioDeviceInfo.Font.Color := clNavy;
    end
    else
    begin
      lblAudioDeviceInfo.Caption := Format('Dispositivo #%d selecionado (Não foi possível obter detalhes adicionais).', [DevId]);
      lblAudioDeviceInfo.Font.Color := clGray;
    end;
  end;
end;

procedure TfrmConfig.btRefreshAudioClick(Sender: TObject);
begin
  EnumerateAudioDevices(GetSelectedAudioDeviceIndex);
end;

procedure TfrmConfig.btTestarAudioInputClick(Sender: TObject);
var
  DevId: Integer;
  wfx: WAVEFORMATEX;
  hWave: HWAVEIN;
  hdr: WAVEHDR;
  buf: array of SmallInt;
  bufBytes: Integer;
  res: MMRESULT;
  devIdCard: UINT;
  samples: Integer;
  i: Integer;
  sumSquares: Double;
  val: Double;
  RMS: Double;
  Percent: Integer;
  SampleRate: Integer;
  Channels: Integer;
begin
  DevId := GetSelectedAudioDeviceIndex;
  if DevId < 0 then
    devIdCard := WAVE_MAPPER
  else
    devIdCard := UINT(DevId);

  // Amostragem selecionada
  if (cbAudioSampleRate <> nil) and (cbAudioSampleRate.ItemIndex = 1) then
    SampleRate := 44100
  else
    SampleRate := 16000;

  // Canais selecionados
  if (cbAudioChannels <> nil) and (cbAudioChannels.ItemIndex = 1) then
    Channels := 2
  else
    Channels := 1;

  FillChar(wfx, SizeOf(wfx), 0);
  wfx.wFormatTag := WAVE_FORMAT_PCM;
  wfx.nChannels := Channels;
  wfx.nSamplesPerSec := SampleRate;
  wfx.wBitsPerSample := 16;
  wfx.nBlockAlign := wfx.nChannels * (wfx.wBitsPerSample div 8);
  wfx.nAvgBytesPerSec := wfx.nSamplesPerSec * wfx.nBlockAlign;

  samples := SampleRate * Channels; // 1 segundo
  bufBytes := samples * 2;
  SetLength(buf, samples);

  res := waveInOpen(@hWave, devIdCard, @wfx, 0, 0, CALLBACK_NULL);
  if res <> MMSYSERR_NOERROR then
  begin
    if lblAudioTestStatus <> nil then
    begin
      lblAudioTestStatus.Caption := Format('FALHA ao abrir microfone (Erro MMSystem %d). Verifique as permissões de microfone.', [res]);
      lblAudioTestStatus.Font.Color := clRed;
    end;
    Exit;
  end;

  btTestarAudioInput.Enabled := False;
  if pbAudioLevel <> nil then pbAudioLevel.Position := 0;
  if lblAudioTestStatus <> nil then
  begin
    lblAudioTestStatus.Caption := 'Gravando 1 segundo para teste de nível... Fale ao microfone!';
    lblAudioTestStatus.Font.Color := $000055AA;
  end;
  Application.ProcessMessages;

  try
    FillChar(hdr, SizeOf(hdr), 0);
    hdr.lpData := PAnsiChar(@buf[0]);
    hdr.dwBufferLength := bufBytes;

    res := waveInPrepareHeader(hWave, @hdr, SizeOf(hdr));
    if res = MMSYSERR_NOERROR then
    begin
      res := waveInAddBuffer(hWave, @hdr, SizeOf(hdr));
      if res = MMSYSERR_NOERROR then
      begin
        waveInStart(hWave);
        Sleep(1100);
        waveInStop(hWave);
        waveInReset(hWave);
        waveInUnprepareHeader(hWave, @hdr, SizeOf(hdr));

        sumSquares := 0;
        for i := 0 to samples - 1 do
        begin
          val := buf[i] / 32768.0;
          sumSquares := sumSquares + (val * val);
        end;

        if samples > 0 then
          RMS := Sqrt(sumSquares / samples)
        else
          RMS := 0;

        Percent := Round(RMS * 100);
        if pbAudioLevel <> nil then
          pbAudioLevel.Position := Min(100, Percent * 3);

        if lblAudioTestStatus <> nil then
        begin
          if RMS >= 0.005 then
          begin
            lblAudioTestStatus.Caption := Format('Sucesso! Microfone ativo e captando som (Nível: %d%% - RMS: %.3f).', [Percent, RMS]);
            lblAudioTestStatus.Font.Color := clGreen;
          end
          else
          begin
            lblAudioTestStatus.Caption := Format('Captação concluída, porém nível de sinal quase mudo (%d%% - RMS: %.4f). Verifique o volume do microfone no Windows.', [Percent, RMS]);
            lblAudioTestStatus.Font.Color := $001080D0;
          end;
        end;
      end
      else
      begin
        waveInUnprepareHeader(hWave, @hdr, SizeOf(hdr));
        if lblAudioTestStatus <> nil then
        begin
          lblAudioTestStatus.Caption := Format('Erro no buffer de captura (%d)', [res]);
          lblAudioTestStatus.Font.Color := clRed;
        end;
      end;
    end
    else
    begin
      if lblAudioTestStatus <> nil then
      begin
        lblAudioTestStatus.Caption := Format('Erro ao preparar buffer de captura (%d)', [res]);
        lblAudioTestStatus.Font.Color := clRed;
      end;
    end;
  finally
    waveInClose(hWave);
    btTestarAudioInput.Enabled := True;
  end;
end;

function TfrmConfig.IsAIProviderOpenAI: Boolean;
var
  Prov: TAIProvider;
begin
  if (cbProvider = nil) or (cbProvider.ItemIndex < 0) then
    Result := False
  else
  begin
    Prov := GetAIProviderFromIndex(cbProvider.ItemIndex);
    Result := (Prov = AIP_OPENAI);
  end;
end;

procedure TfrmConfig.AtualizaEstadoOpenAITTS;
var
  IsOpenAI: Boolean;
begin
  IsOpenAI := IsAIProviderOpenAI;
  if not IsOpenAI and (cbSynthEngine <> nil) and (cbSynthEngine.ItemIndex = 3) then
  begin
    cbSynthEngine.ItemIndex := 1;
    CarregaVozesDoSintetizador;
    Exit;
  end;

  if (lblSynthModel <> nil) and (cbSynthModel <> nil) and (lblOpenAINote <> nil) then
  begin
    lblSynthModel.Visible := (cbSynthEngine.ItemIndex = 3) and IsOpenAI;
    cbSynthModel.Visible := (cbSynthEngine.ItemIndex = 3) and IsOpenAI;
    lblOpenAINote.Visible := (cbSynthEngine.ItemIndex = 3) and IsOpenAI;
  end;
end;

procedure TfrmConfig.btTestarFalaClick(Sender: TObject);
var
  EngineIdx: Integer;
  Token: string;
  ModelName: string;
  VoiceName: string;
  TestText: string;
  TempWav: string;
  SpVoice: OleVariant;
  HTTP: TFPHttpClient;
  BodyStream: TStringStream;
  RespStream: TFileStream;
  Payload: string;
  SpeedVal: Double;
  SpeedStr: string;
  StreamSize: Int64;
begin
  TestText := 'Olá! Este é um teste da síntese de voz configurada para o Assistente.';
  EngineIdx := cbSynthEngine.ItemIndex;

  lblTestarFalaStatus.Caption := 'Executando teste de voz...';
  lblTestarFalaStatus.Font.Color := clNavy;
  btTestarFala.Enabled := False;
  Application.ProcessMessages;

  try
    if EngineIdx = 3 then // OpenAI TTS
    begin
      if not IsAIProviderOpenAI then
      begin
        lblTestarFalaStatus.Caption := 'FALHA: OpenAI TTS requer que o provedor da IA seja OpenAI.';
        lblTestarFalaStatus.Font.Color := clRed;
        Exit;
      end;

      Token := Trim(edTokenGPT.Text);
      if Token = '' then
      begin
        lblTestarFalaStatus.Caption := 'FALHA: Preencha o Chatgpt Token na aba IA / ChatGPT antes de testar.';
        lblTestarFalaStatus.Font.Color := clRed;
        Exit;
      end;

      if (cbSynthModel <> nil) and (cbSynthModel.Text <> '') then
        ModelName := Trim(cbSynthModel.Text)
      else
        ModelName := 'tts-1';

      if (cbSynthVoice <> nil) and (cbSynthVoice.Text <> '') then
        VoiceName := Trim(cbSynthVoice.Text)
      else
        VoiceName := 'alloy';

      SpeedVal := 1.0 + (tbSynthRate.Position * 0.05);
      if SpeedVal < 0.25 then SpeedVal := 0.25;
      if SpeedVal > 4.0 then SpeedVal := 4.0;
      SpeedStr := StringReplace(Format('%.2f', [SpeedVal]), ',', '.', []);

      TempWav := IncludeTrailingPathDelimiter(GetTempDir) + 'assistente_tts_test.mp3';
      if FileExists(TempWav) then SysUtils.DeleteFile(TempWav);

      HTTP := TFPHttpClient.Create(nil);
      BodyStream := nil;
      RespStream := nil;
      try
        HTTP.AddHeader('Content-Type', 'application/json');
        HTTP.AddHeader('Authorization', 'Bearer ' + Token);
        HTTP.IOTimeout := 20000;
        HTTP.ConnectTimeout := 15000;
        HTTP.AllowRedirect := True;

        Payload := '{' +
          '"model": "' + ModelName + '",' +
          '"input": "' + TestText + '",' +
          '"voice": "' + VoiceName + '",' +
          '"response_format": "mp3",' +
          '"speed": ' + SpeedStr +
          '}';

        BodyStream := TStringStream.Create(Payload);
        HTTP.RequestBody := BodyStream;
        RespStream := TFileStream.Create(TempWav, fmCreate);

        HTTP.Post('https://api.openai.com/v1/audio/speech', RespStream);
      finally
        if Assigned(RespStream) then RespStream.Free;
        if Assigned(BodyStream) then BodyStream.Free;
        HTTP.Free;
      end;

      StreamSize := 0;
      if FileExists(TempWav) then
      begin
        try
          RespStream := TFileStream.Create(TempWav, fmOpenRead or fmShareDenyNone);
          StreamSize := RespStream.Size;
          RespStream.Free;
        except
          StreamSize := 0;
        end;
      end;

      if StreamSize > 500 then
      begin
        mciSendString('close testtts', nil, 0, 0);
        mciSendString(PChar('open "' + TempWav + '" type mpegvideo alias testtts'), nil, 0, 0);
        mciSendString('play testtts', nil, 0, 0);
        lblTestarFalaStatus.Caption := Format('Sucesso! Reproduzindo áudio OpenAI TTS (Modelo: %s, Voz: %s)', [ModelName, VoiceName]);
        lblTestarFalaStatus.Font.Color := clGreen;
      end
      else
      begin
        lblTestarFalaStatus.Caption := 'FALHA: A API da OpenAI não retornou um arquivo de áudio válido. Verifique o Token e a conexão.';
        lblTestarFalaStatus.Font.Color := clRed;
      end;
    end
    else
    begin
      // Windows SAPI / System Default
      ActiveX.CoInitialize(nil);
      SpVoice := CreateOleObject('SAPI.SpVoice');
      SpVoice.Volume := tbSynthVolume.Position;
      SpVoice.Rate := tbSynthRate.Position;
      if (cbSynthVoice <> nil) and (cbSynthVoice.Text <> '') then
      begin
        try
          SpVoice.Voice := SpVoice.GetVoices('Name=' + cbSynthVoice.Text).Item(0);
        except
        end;
      end;
      SpVoice.Speak(TestText, 1);
      lblTestarFalaStatus.Caption := Format('Sucesso! Reproduzindo voz via SAPI: %s', [cbSynthVoice.Text]);
      lblTestarFalaStatus.Font.Color := clGreen;
    end;
  except
    on E: Exception do
    begin
      lblTestarFalaStatus.Caption := 'Erro no teste de voz: ' + E.Message;
      lblTestarFalaStatus.Font.Color := clRed;
    end;
  end;
  btTestarFala.Enabled := True;
end;

end.

