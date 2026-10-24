//Objetivo construir os parametros de setup da classe principal
//Criado por Marcelo Maurin Martins
//Data:07/02/2021
//Atualizado com suporte a API Segura v1 do JARVIS Residencial

unit setmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, funcoes, graphics, aivoicecredentialstore, vision_types, assistant_integration_protocol;

const filename = 'Setmain.cfg';

type
  { How TSetMain.WriteLines renders the settings: the private Setmain.cfg,
    or a portable file for another installation (with or without secrets). }
  TSettingsWriteMode = (swStore, swExportWithSecrets, swExportWithoutSecrets);

{ Keys tied to this computer or window (never exported nor imported). }
function IsMachineSettingKey(const Key: string): Boolean;
{ Keys holding passwords, tokens or API keys. }
function IsSecretSettingKey(const Key: string): Boolean;


type
  { TSetMain }

  TSetMain = class(TObject)

  private
        FIntegration: TIntegrationConfig;
        FAvatar3DModel: string;
        FAvatar3DProfile: string;
        FAdminPIN: string;
        FAvatar3DAutoIdle: Boolean;
        FAvatar3DAutoBlink: Boolean;
        FAvatar3DLipSync: Boolean;
        FAvatar3DIntensity: Double;
        FAvatar3DQuality: string;
        arquivo :Tstringlist;
        ckdevice : boolean;
        FPosX : integer;
        FPosY : integer;
        FFixar : boolean;
        FStay : boolean;
        FLastFiles : String;
        FPATH : string;
        FHeight : integer;
        FWidth : integer;
        FFONT : TFont;
        FCHATGPT : string;
        FDllPath : string;
        FDllMyPath : string;
        FDllPostPath : string;

        FRunScript : string;    //Script de Compilação
        FDebugScript : string;  //Script de Debug
        FCleanScript : string;  //Script de Limpeza
        FInstall : string;      //Script de Instalacao
        FCompile : string;      //Script de Compilação

        FHostnameMy : String;
        FBancoMy : String;
        FUsernameMy : String;
        FPasswordMy : String;

        FHostnamePost : String;
        FBancoPOST : String;
        FUsernamePost: String;
        FPasswordPost : String;
        FSchemaPost: String;
        FToolsFalar : Boolean;

        // Configuração do componente TCHATGPT (unit chatgpt.pas)
        FChatGPTProvider : integer; // ordinal de TAIProvider (chatgpt.pas)
        FChatGPTModel : String;     // modelo customizado (TCHATGPT.CustomModel); vazio = padrão do provedor
        FChatGPTURL : String;       // endpoint customizado (TCHATGPT.URL); vazio = padrão do provedor

        // Configurações do JARVIS Residencial (API Segura v1)
        FJarvisURL : String;
        FJarvisAPIKey : String;
        FJarvisIAMode : String;
        FMinimizeToTray : Boolean;
        FAutoSpeak : Boolean;

        // Palavra/frase de ativação usada pelo ToolsOuvir
        FFrase : String;

        // Endereço do serviço externo de síntese de voz (ToolsFalar)
        FVoiceSynthIP : String;
        FVoiceSynthPort : integer;

        // Endereço do serviço externo de reconhecimento de voz (ToolsOuvir)
        FVoiceRecogIP : String;
        FVoiceRecogPort : integer;


        // Configurações do Output Voice (TAIVoiceSynthesizer)
        FSynthEngine : integer; // 0=seSystemDefault, 1=seSAPI, 2=seEspeak, 3=seOpenAI
        FSynthVoice : String;
        FSynthVolume : integer;
        FSynthRate : integer;
        FSynthAsync : boolean;

        // Provedor Remoto de Voz (TAIVoiceSynthesizer)
        FVoiceProvider : integer;
        FVoiceAPIToken : String;
        FVoiceModel : String;
        FVoiceEndpoint : String;
        FVoiceRemoteVoice : String;
        FVoiceLanguage : String;
        FVoiceOutputFormat : String;
        FVoiceSpeed : Double;

        // Configurações do Input Audio / Reconhecedor (TAIAudioInput / TAIVoiceRecognizer)
        FRecogEngine : integer; // 0=vreOpenAIWhisper, 1=vreSAPI, 2=vreSystemDefault, 3=vreChromeWebSpeech
        FRecogLanguage : String;
        FAudioSampleRate : integer;
        FAudioChannels : integer;
        FAudioDeviceIndex : integer; // -1 = Padrão (WAVE_MAPPER), 0, 1, ...
        FAudioDeviceName : String;

        { Kinect v1 / Percepcao }
        FVisionSource: TVisionSource;
        FKinectDeviceIndex: Integer;
        FCameraDevice: string;
        FKinectMinDistance : Double;
        FKinectMaxDistance : Double;
        FKinectSeatedMode : Boolean;
        FKinectTargetLeft : string;
        FKinectTargetRight : string;
        FKinectTargetCenter : string;

        { Escuta Continua & VAD (TAIContinuousListener) }
        FContinuousListening : Boolean;
        FVoiceThreshold : Double;
        FSilenceTimeoutMs : Integer;
        FMinSpeechMs : Integer;
        FMaxSpeechMs : Integer;
        FEchoSuppressionEnabled : Boolean;
        FSelfAudioCorrelationThreshold : Double;

        { STT Separado }
        FSTTToken : String;
        FSTTModel : String;
        FSTTEndpoint : String;
        FRAGInAnswers : Boolean;

        procedure SetDevice(const Value : Boolean);
        procedure SetPOSX(value : integer);
        procedure SetPOSY(value : integer);
        procedure SetFixar(value : boolean);
        procedure SetStay(value : boolean);
        procedure SetLastFiles(value : string);
        procedure SetFont(value : TFont);
        procedure SetCHATGPT(value : String);
        procedure SetDllPath( value : string);
        procedure SetDllMyPath( value : string);
        procedure SetDllPostPath( value : string);
        procedure SetToolsFalar(value : boolean);
        procedure Default();
  public
        constructor create();
        destructor Destroy(); override;
        property Integration: TIntegrationConfig read FIntegration write FIntegration;
        procedure SalvaContexto(flag : boolean);
        Procedure CarregaContexto();
        procedure IdentificaArquivo(flag : boolean);
        property device : boolean read ckdevice write SetDevice;
        property posx : integer read FPosX write SetPOSX;
        property posy : integer read FPosY write SetPOSY;
        property fixar : boolean read FFixar write SetFixar;
        property stay : boolean read FStay write SetStay;
        property lastfiles: string read FLastFiles write SetLastFiles;
        property Height: integer read FHeight write FHeight;
        property Width : integer read FWidth write FWidth;
        property RunScript : string read FRunScript write FRunScript;
        property DebugScript : string read FDebugScript write FDebugScript;
        property CleanScript : string read FCleanScript write FCleanScript;
        property Install : string read FInstall write FInstall;
        property Compile : string read FCompile write FCompile;
        property Font : TFont read FFont write SetFont;
        property CHATGPT: String read FCHATGPT write SetCHATGPT;
        property DLLPath : String read FDllPath write SetDllPath;
        property DLLMyPath : String read FDllMyPath write SetDllMyPath;
        property DLLPostPath : String read FDllPostPath write SetDllPostPath;

        property HostnameMy: string read FHostnameMy write FHostnameMy;
        property BancoMy : String read FBancoMy write FBancoMy;
        property UsernameMy : String read FUsernameMy write FUsernameMy;
        property PasswordMy : String read FPasswordMy write FPasswordMy;
        property HostnamePost : String read FHostnamePost write FHostnamePost;
        property BancoPOST : String read FBancoPOST write FBancoPOST;
        property UsernamePost: String read FUsernamePOST write FUsernamePost;
        property PasswordPost : String read FPasswordPost write FPasswordPost;
        property SchemaPost: String read FSchemaPost write FSchemaPost;
        property ToolsFalar : Boolean read FToolsFalar write SetToolsFalar;

        property ChatGPTProvider : integer read FChatGPTProvider write FChatGPTProvider;
        property ChatGPTModel : String read FChatGPTModel write FChatGPTModel;
        property ChatGPTURL : String read FChatGPTURL write FChatGPTURL;

        // JARVIS API v1
        property JarvisURL : String read FJarvisURL write FJarvisURL;
        property JarvisAPIKey : String read FJarvisAPIKey write FJarvisAPIKey;
        property JarvisIAMode : String read FJarvisIAMode write FJarvisIAMode;
        property MinimizeToTray : Boolean read FMinimizeToTray write FMinimizeToTray;
        property AutoSpeak : Boolean read FAutoSpeak write FAutoSpeak;

        property Frase : String read FFrase write FFrase;

        property VoiceSynthIP : String read FVoiceSynthIP write FVoiceSynthIP;
        property VoiceSynthPort : integer read FVoiceSynthPort write FVoiceSynthPort;
        property VoiceRecogIP : String read FVoiceRecogIP write FVoiceRecogIP;
        property VoiceRecogPort : integer read FVoiceRecogPort write FVoiceRecogPort;

        property SynthEngine : integer read FSynthEngine write FSynthEngine;
        property SynthVoice : String read FSynthVoice write FSynthVoice;
        property SynthVolume : integer read FSynthVolume write FSynthVolume;
        property SynthRate : integer read FSynthRate write FSynthRate;
        property SynthAsync : boolean read FSynthAsync write FSynthAsync;

        property VoiceProvider : integer read FVoiceProvider write FVoiceProvider;
        property VoiceAPIToken : String read FVoiceAPIToken write FVoiceAPIToken;
        property VoiceModel : String read FVoiceModel write FVoiceModel;
        property VoiceEndpoint : String read FVoiceEndpoint write FVoiceEndpoint;
        property VoiceRemoteVoice : String read FVoiceRemoteVoice write FVoiceRemoteVoice;
        property VoiceLanguage : String read FVoiceLanguage write FVoiceLanguage;
        property VoiceOutputFormat : String read FVoiceOutputFormat write FVoiceOutputFormat;
        property VoiceSpeed : Double read FVoiceSpeed write FVoiceSpeed;

        property RecogEngine : integer read FRecogEngine write FRecogEngine;
        property RecogLanguage : String read FRecogLanguage write FRecogLanguage;
        property AudioSampleRate : integer read FAudioSampleRate write FAudioSampleRate;
        property AudioChannels : integer read FAudioChannels write FAudioChannels;
        property AudioDeviceIndex : integer read FAudioDeviceIndex write FAudioDeviceIndex;
        property AudioDeviceName : String read FAudioDeviceName write FAudioDeviceName;
        property Avatar3DModel: string read FAvatar3DModel write FAvatar3DModel;
        property Avatar3DProfile: string read FAvatar3DProfile write FAvatar3DProfile;
        property AdminPIN: string read FAdminPIN write FAdminPIN;
        property Avatar3DAutoIdle: Boolean read FAvatar3DAutoIdle write FAvatar3DAutoIdle;
        property Avatar3DAutoBlink: Boolean read FAvatar3DAutoBlink write FAvatar3DAutoBlink;
        property Avatar3DLipSync: Boolean read FAvatar3DLipSync write FAvatar3DLipSync;
        property Avatar3DIntensity: Double read FAvatar3DIntensity write FAvatar3DIntensity;
        property Avatar3DQuality: string read FAvatar3DQuality write FAvatar3DQuality;

        { Kinect v1 / Percepcao }
        property VisionSource: TVisionSource read FVisionSource write FVisionSource;
        property KinectDeviceIndex: Integer read FKinectDeviceIndex write FKinectDeviceIndex;
        property CameraDevice: string read FCameraDevice write FCameraDevice;
        property KinectMinDistance : Double read FKinectMinDistance write FKinectMinDistance;
        property KinectMaxDistance : Double read FKinectMaxDistance write FKinectMaxDistance;
        property KinectSeatedMode : Boolean read FKinectSeatedMode write FKinectSeatedMode;
        property KinectTargetLeft : string read FKinectTargetLeft write FKinectTargetLeft;
        property KinectTargetRight : string read FKinectTargetRight write FKinectTargetRight;
        property KinectTargetCenter : string read FKinectTargetCenter write FKinectTargetCenter;

        { Escuta Continua & VAD }
        property ContinuousListening : Boolean read FContinuousListening write FContinuousListening;
        property VoiceThreshold : Double read FVoiceThreshold write FVoiceThreshold;
        property SilenceTimeoutMs : Integer read FSilenceTimeoutMs write FSilenceTimeoutMs;
        property MinSpeechMs : Integer read FMinSpeechMs write FMinSpeechMs;
        property MaxSpeechMs : Integer read FMaxSpeechMs write FMaxSpeechMs;
        property EchoSuppressionEnabled : Boolean read FEchoSuppressionEnabled write FEchoSuppressionEnabled;
        property SelfAudioCorrelationThreshold : Double read FSelfAudioCorrelationThreshold write FSelfAudioCorrelationThreshold;

        { STT }
        property STTToken : String read FSTTToken write FSTTToken;
        property STTModel : String read FSTTModel write FSTTModel;
        property STTEndpoint : String read FSTTEndpoint write FSTTEndpoint;
        { Use the RAG library documents as references in ordinary answers. }
        property RAGInAnswers : Boolean read FRAGInAnswers write FRAGInAnswers;
        { KEY:value lines of every setting (see TSettingsWriteMode). }
        procedure WriteLines(Lines: TStrings; Mode: TSettingsWriteMode);
        { Apply KEY:value lines from a portable configuration file. Keys that
          are absent keep their current value; machine keys are ignored. }
        procedure ImportLines(Lines: TStrings);

  end;

  function SafeParseFloat(const AText: string; ADefault: Double): Double;

  var
    FSetMain : TSetMain;

implementation

const
  MachineSettingKeys: array[0..18] of string = ('DEVICE','POSX','POSY','FIXAR','STAY','LASTFILES',
    'HEIGHT','WIDTH','FONT','RUNSCRIPT','DEBUGSCRIPT','CLEANSCRIPT','INSTALLSCRIPT','COMPILESCRIPT',
    'DLLPATH','DLLMYPATH','DLLPOSTPATH','AUDIODEVICEINDEX','KINECT_DEVICE_INDEX');
  SecretSettingKeys: array[0..5] of string = ('CHATGPT','JARVISAPIKEY','PASSWORDMY','PASSWORDPOST',
    'STT_TOKEN','INTEGRATION_TOKEN');

{ Line that starts with Ref ("KEY:"). funcoes.BuscaChave matches Ref anywhere
  in a line, so a value containing "POSX:" could be read as another key. }
function ChaveNoInicio(Lista: TStringList; const Ref: string; var Posicao: Integer): Boolean;
var I: Integer;
begin
  for I:=0 to Lista.Count-1 do
    if Copy(Lista[I],1,Length(Ref))=Ref then begin Posicao:=I;Exit(True);end;
  Result:=False;
end;

function IsMachineSettingKey(const Key: string): Boolean;
var I: Integer;
begin
  Result:=False;
  for I:=Low(MachineSettingKeys) to High(MachineSettingKeys) do
    if SameText(Key,MachineSettingKeys[I]) then Exit(True);
end;

function IsSecretSettingKey(const Key: string): Boolean;
var I: Integer;
begin
  Result:=False;
  for I:=Low(SecretSettingKeys) to High(SecretSettingKeys) do
    if SameText(Key,SecretSettingKeys[I]) then Exit(True);
end;

function SafeParseFloat(const AText: string; ADefault: Double): Double;
var
  S: string;
begin
  S := Trim(AText);
  if S = '' then Exit(ADefault);
  if DefaultFormatSettings.DecimalSeparator = ',' then
    S := StringReplace(S, '.', ',', [rfReplaceAll])
  else
    S := StringReplace(S, ',', '.', [rfReplaceAll]);
  Result := StrToFloatDef(S, ADefault);
end;

procedure TSetMain.SetDevice(const Value : Boolean);
begin
    ckdevice := Value;
end;

procedure TSetMain.SetFont(value: TFont);
begin
  FFont.Assign(value);
end;

procedure TSetMain.SetCHATGPT(value: String);
begin
  FCHATGPT := value;
end;

procedure TSetMain.SetDllPath(value: string);
begin
  FDllPath := value;
end;

procedure TSetMain.SetDllMyPath(value: string);
begin
  FDllMyPath := value;
end;

procedure TSetMain.SetDllPostPath(value: string);
begin
  FDllPostPath := value;
end;

procedure TSetMain.SetToolsFalar(value: boolean);
begin
  FToolsFalar := value;
end;

procedure TSetMain.Default();
begin
    ckdevice := true;
    Fposx := 100;
    Fposy := 100;
    FFixar := false;
    FStay := false;
    FDllPath:= ExtractFilePath(ApplicationName);
    FDllMyPath:= ExtractFilePath(ApplicationName);
    FDllPostPath:= ExtractFilePath(ApplicationName);
    FHeight := 400;
    FWidth := 400;
    FRunScript := '';
    FDebugScript := '';
    FCleanScript := '';
    FInstall := '';
    FCompile := '';
    if FFont = nil then
      FFONT := TFont.create();

    FCHATGPT := '';
    FToolsFalar := false;

    FChatGPTProvider := 0;  // AIP_OPENAI
    FChatGPTModel := '';
    FChatGPTURL := '';

    FIntegration := DefaultIntegrationConfig;
    // JARVIS Defaults
    FJarvisURL := 'https://chorus-gazette-princeton-charter.trycloudflare.com';
    FJarvisAPIKey := 'jarvis_sec_v1_90a934713a4a1191e342ce5af0ffe9fe47b0a9a6b47bb915';
    FJarvisIAMode := 'auto';
    FMinimizeToTray := true;
    FAutoSpeak := true;

    FFrase := 'jarvis';

    FVoiceSynthIP := '127.0.0.1';
    FVoiceSynthPort := 8096;
    FVoiceRecogIP := '127.0.0.1';
    FVoiceRecogPort := 8097;

    FSynthEngine := 1; // seSAPI no Windows
    FSynthVoice := '';
    FSynthVolume := 100;
    FSynthRate := 0;
    FSynthAsync := true;

    FVoiceProvider := 0;
    FVoiceAPIToken := '';
    FVoiceModel := 'gpt-4o-mini-tts';
    FVoiceEndpoint := 'https://api.openai.com/v1/audio/speech';
    FVoiceRemoteVoice := 'alloy';
    FVoiceLanguage := 'pt-BR';
    FVoiceOutputFormat := 'mp3';
    FVoiceSpeed := 1.0;

    FRecogEngine := 0; // 0=vreOpenAIWhisper, 1=vreSAPI
    FRecogLanguage := 'pt';
    FAudioSampleRate := 16000;
    FAudioChannels := 1;
    FAudioDeviceIndex := -1;
    FAudioDeviceName := '';
    FAvatar3DModel := '';
    FAvatar3DProfile := 'professor';
    FAdminPIN := '';
    FAvatar3DAutoIdle := True;
    FAvatar3DAutoBlink := True;
    FAvatar3DLipSync := True;
    FAvatar3DIntensity := 0.8;
    FAvatar3DQuality := 'auto';

    FVisionSource := vsNone;
    FKinectDeviceIndex := -1;
    FCameraDevice := '';
    FKinectMinDistance := 0.8;
    FKinectMaxDistance := 3.5;
    FKinectSeatedMode := True;
    FKinectTargetLeft := '';
    FKinectTargetRight := '';
    FKinectTargetCenter := '';

    FContinuousListening := True;
    FVoiceThreshold := 0.015;
    FSilenceTimeoutMs := 900;
    FMinSpeechMs := 250;
    FMaxSpeechMs := 15000;
    FEchoSuppressionEnabled := True;
    FSelfAudioCorrelationThreshold := 0.70;
    FSTTToken := '';
    FSTTModel := 'whisper-1';
    FSTTEndpoint := 'https://api.openai.com/v1/audio/transcriptions';

end;

procedure TSetMain.SetPOSX(value: integer);
begin
    Fposx := value;
end;

procedure TSetMain.SetPOSY(value: integer);
begin
    FposY := value;
end;

procedure TSetMain.SetFixar(value: boolean);
begin
    FFixar := value;
end;

procedure TSetMain.SetStay(value: boolean);
begin
    FStay := value;
end;

procedure TSetMain.SetLastFiles(value: string);
begin
    FLastFiles := value;
end;

procedure TSetMain.CarregaContexto();
var
  posicao : integer;
begin
    if  ChaveNoInicio(arquivo,'DEVICE:',posicao) then
    begin
         ckdevice := iif(RetiraInfo(arquivo.Strings[posicao])='0',false,true);
    end;
    if  ChaveNoInicio(arquivo,'POSX:',posicao) then
    begin
      FPOSX :=  strtoint(RetiraInfo(arquivo.Strings[posicao]));
    end;
    if  ChaveNoInicio(arquivo,'POSY:',posicao) then
    begin
      FPOSY :=  strtoint(RetiraInfo(arquivo.Strings[posicao]));
    end;
    if  ChaveNoInicio(arquivo,'FIXAR:',posicao) then
    begin
      FFixar :=  strtobool(RetiraInfo(arquivo.Strings[posicao]));
    end;
    if  ChaveNoInicio(arquivo,'STAY:',posicao) then
    begin
      FStay :=  strtobool(RetiraInfo(arquivo.Strings[posicao]));
    end;
    if  ChaveNoInicio(arquivo,'LASTFILES:',posicao) then
    begin
      FLastFiles := RetiraInfo(arquivo.Strings[posicao]);
    end;

    if  ChaveNoInicio(arquivo,'HEIGHT:',posicao) then
    begin
      FHEIGHT := strtoint(RetiraInfo(arquivo.Strings[posicao]));
    end;

    if  ChaveNoInicio(arquivo,'WIDTH:',posicao) then
    begin
      FWIDTH := strtoint(RetiraInfo(arquivo.Strings[posicao]));
    end;

    if  ChaveNoInicio(arquivo,'RUNSCRIPT:',posicao) then
    begin
      FRunScript := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'DEBUGSCRIPT:',posicao) then
    begin
      FDebugScript := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'CLEANSCRIPT:',posicao) then
    begin
      FCleanScript := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'INSTALLSCRIPT:',posicao) then
    begin
      FInstall := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'COMPILESCRIPT:',posicao) then
    begin
      FCompile := RetiraInfo(arquivo.Strings[posicao]);
    end;

    if  ChaveNoInicio(arquivo,'FONT:',posicao) then
    begin
      StringToFont(RetiraInfo(arquivo.Strings[posicao]),FFONT);
    end;
    if  ChaveNoInicio(arquivo,'CHATGPT:',posicao) then
    begin
      FCHATGPT := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'DLLPATH:',posicao) then
    begin
      FDLLPATH := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'DLLMYPATH:',posicao) then
    begin
      FDLLMyPATH := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'DLLPOSTPATH:',posicao) then
    begin
      FDLLPOSTPATH := RetiraInfo(arquivo.Strings[posicao]);
    end;

    if  ChaveNoInicio(arquivo,'HOSTNAMEMY:',posicao) then
    begin
      FHostnameMy := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'BANCOMY:',posicao) then
    begin
      FBancoMy := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'USERNAMEMY:',posicao) then
    begin
      FUsernameMy := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'PASSWORDMY:',posicao) then
    begin
      FPasswordMy := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'HOSTNAMEPOST:',posicao) then
    begin
      FHostnamePost := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'BANCOPOST:',posicao) then
    begin
      FBancoPost := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'USERNAMEPOST:',posicao) then
    begin
      FUsernamePost := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'PASSWORDPOST:',posicao) then
    begin
      FPasswordPost := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'SCHEMAPOST:',posicao) then
    begin
      FSchemaPost := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'TOOLSFALAR:',posicao) then
    begin
      FTOOLSFALAR := iif(RetiraInfo(arquivo.Strings[posicao])='0',false,true);
    end;

    if  ChaveNoInicio(arquivo,'CHATGPTPROVIDER:',posicao) then
    begin
      FChatGPTProvider := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 0);
    end;
    if  ChaveNoInicio(arquivo,'CHATGPTMODEL:',posicao) then
    begin
      FChatGPTModel := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'CHATGPTURL:',posicao) then
    begin
      FChatGPTURL := RetiraInfo(arquivo.Strings[posicao]);
    end;

    // Leitura JARVIS
    if  ChaveNoInicio(arquivo,'JARVISURL:',posicao) then
    begin
      FJarvisURL := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'JARVISAPIKEY:',posicao) then
    begin
      FJarvisAPIKey := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'JARVISIAMODE:',posicao) then
    begin
      FJarvisIAMode := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'MINIMIZETOTRAY:',posicao) then
    begin
      FMinimizeToTray := (RetiraInfo(arquivo.Strings[posicao]) <> '0');
    end;
    if  ChaveNoInicio(arquivo,'AUTOSPEAK:',posicao) then
    begin
      FAutoSpeak := (RetiraInfo(arquivo.Strings[posicao]) <> '0');
    end;

    if  ChaveNoInicio(arquivo,'FRASE:',posicao) then
    begin
      FFrase := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'VOICESYNTHIP:',posicao) then
    begin
      FVoiceSynthIP := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'VOICESYNTHPORT:',posicao) then
    begin
      FVoiceSynthPort := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 8096);
    end;
    if  ChaveNoInicio(arquivo,'VOICERECOGIP:',posicao) then
    begin
      FVoiceRecogIP := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'VOICERECOGPORT:',posicao) then
    begin
      FVoiceRecogPort := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 8097);
    end;

    if  ChaveNoInicio(arquivo,'SYNTHENGINE:',posicao) then
    begin
      FSynthEngine := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 1);
    end;
    if  ChaveNoInicio(arquivo,'SYNTHVOICE:',posicao) then
    begin
      FSynthVoice := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'SYNTHVOLUME:',posicao) then
    begin
      FSynthVolume := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 100);
    end;
    if  ChaveNoInicio(arquivo,'SYNTHRATE:',posicao) then
    begin
      FSynthRate := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 0);
    end;
    if  ChaveNoInicio(arquivo,'SYNTHASYNC:',posicao) then
    begin
      FSynthAsync := (RetiraInfo(arquivo.Strings[posicao]) <> '0');
    end;

    if  ChaveNoInicio(arquivo,'VOICEPROVIDER:',posicao) then
      FVoiceProvider := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 0);
    if  ChaveNoInicio(arquivo,'VOICEAPITOKEN:',posicao) then
      FVoiceAPIToken := TVoiceCredentialStore.UnprotectToken(RetiraInfo(arquivo.Strings[posicao]));
    if  ChaveNoInicio(arquivo,'VOICEMODEL:',posicao) then
      FVoiceModel := RetiraInfo(arquivo.Strings[posicao]);
    if  ChaveNoInicio(arquivo,'VOICEENDPOINT:',posicao) then
      FVoiceEndpoint := RetiraInfo(arquivo.Strings[posicao]);
    if  ChaveNoInicio(arquivo,'VOICEREMOTEVOICE:',posicao) then
      FVoiceRemoteVoice := RetiraInfo(arquivo.Strings[posicao]);
    if  ChaveNoInicio(arquivo,'VOICELANGUAGE:',posicao) then
      FVoiceLanguage := RetiraInfo(arquivo.Strings[posicao]);
    if  ChaveNoInicio(arquivo,'VOICEOUTPUTFORMAT:',posicao) then
      FVoiceOutputFormat := RetiraInfo(arquivo.Strings[posicao]);
    if  ChaveNoInicio(arquivo,'VOICESPEED:',posicao) then
      FVoiceSpeed := strtofloatdef(StringReplace(RetiraInfo(arquivo.Strings[posicao]), ',', '.', []), 1.0);

    // Migracao/fallback de configuracao antiga (tarefa 27)
    if (Trim(FVoiceAPIToken) = '') and (FSynthEngine = 3) and (Trim(FCHATGPT) <> '') then
    begin
      FVoiceAPIToken := FCHATGPT;
      FVoiceProvider := 1;
    end;

    if  ChaveNoInicio(arquivo,'RECOGENGINE:',posicao) then
    begin
      FRecogEngine := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 0);
    end;
    if  ChaveNoInicio(arquivo,'RECOGLANGUAGE:',posicao) then
    begin
      FRecogLanguage := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  ChaveNoInicio(arquivo,'AUDIOSAMPLERATE:',posicao) then
    begin
      FAudioSampleRate := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 16000);
    end;
    if  ChaveNoInicio(arquivo,'AUDIOCHANNELS:',posicao) then
    begin
      FAudioChannels := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 1);
    end;
    if  ChaveNoInicio(arquivo,'AUDIODEVICEINDEX:',posicao) then
    begin
      FAudioDeviceIndex := strtointdef(RetiraInfo(arquivo.Strings[posicao]), -1);
    end;
    if  ChaveNoInicio(arquivo,'AUDIODEVICENAME:',posicao) then
    begin
      FAudioDeviceName := RetiraInfo(arquivo.Strings[posicao]);
    end;

    if ChaveNoInicio(arquivo,'CONTINUOUS_LISTENING:',posicao) then
      FContinuousListening := (RetiraInfo(arquivo.Strings[posicao]) <> '0');
    if ChaveNoInicio(arquivo,'VOICE_THRESHOLD:',posicao) then
      FVoiceThreshold := strtofloatdef(StringReplace(RetiraInfo(arquivo.Strings[posicao]), ',', '.', []), 0.015);
    if ChaveNoInicio(arquivo,'SILENCE_TIMEOUT_MS:',posicao) then
      FSilenceTimeoutMs := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 900);
    if ChaveNoInicio(arquivo,'MIN_SPEECH_MS:',posicao) then
      FMinSpeechMs := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 250);
    if ChaveNoInicio(arquivo,'MAX_SPEECH_MS:',posicao) then
      FMaxSpeechMs := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 15000);
    if ChaveNoInicio(arquivo,'ECHO_SUPPRESSION:',posicao) then
      FEchoSuppressionEnabled := (RetiraInfo(arquivo.Strings[posicao]) <> '0');
    if ChaveNoInicio(arquivo,'SELF_AUDIO_CORR_THRESH:',posicao) then
      FSelfAudioCorrelationThreshold := strtofloatdef(StringReplace(RetiraInfo(arquivo.Strings[posicao]), ',', '.', []), 0.70);

    // Sanitize values to prevent 0-value deadlocks in voice recognition & synthesis
    if FSilenceTimeoutMs <= 0 then FSilenceTimeoutMs := 900;
    if FMinSpeechMs <= 0 then FMinSpeechMs := 250;
    if FMaxSpeechMs <= 0 then FMaxSpeechMs := 15000;
    if FVoiceThreshold <= 0.0001 then FVoiceThreshold := 0.015;
    if FSelfAudioCorrelationThreshold <= 0.0001 then FSelfAudioCorrelationThreshold := 0.70;
    if (Trim(FVoiceModel) = '') or (FVoiceModel = 'gpt-4o-mini-tts') then
      FVoiceModel := 'tts-1';

    if ChaveNoInicio(arquivo,'STT_TOKEN:',posicao) then
      FSTTToken := TVoiceCredentialStore.UnprotectToken(RetiraInfo(arquivo.Strings[posicao]));
    if ChaveNoInicio(arquivo,'STT_MODEL:',posicao) then
      FSTTModel := RetiraInfo(arquivo.Strings[posicao]);
    if ChaveNoInicio(arquivo,'STT_ENDPOINT:',posicao) then
      FSTTEndpoint := RetiraInfo(arquivo.Strings[posicao]);

    if ChaveNoInicio(arquivo,'AVATAR3D_PROFILE:',posicao) then
      FAvatar3DProfile := RetiraInfo(arquivo.Strings[posicao]);
    if ChaveNoInicio(arquivo,'AVATAR3D_MODEL:',posicao) then
      FAvatar3DModel := RetiraInfo(arquivo.Strings[posicao]);
    if ChaveNoInicio(arquivo,'AVATAR3D_AUTO_IDLE:',posicao) then
      FAvatar3DAutoIdle := StrToBoolDef(RetiraInfo(arquivo.Strings[posicao]), True);
    if ChaveNoInicio(arquivo,'VISION_SOURCE:',posicao) then
      FVisionSource := ParseVisionSource(RetiraInfo(arquivo.Strings[posicao]))
    else if ChaveNoInicio(arquivo,'KINECT_ENABLED:',posicao) then
    begin
      if SameText(RetiraInfo(arquivo.Strings[posicao]), 'true') or
         (RetiraInfo(arquivo.Strings[posicao]) = '1') then FVisionSource := vsKinect
      else FVisionSource := vsNone;
    end;
    if ChaveNoInicio(arquivo,'KINECT_DEVICE_INDEX:',posicao) then
      FKinectDeviceIndex := StrToIntDef(RetiraInfo(arquivo.Strings[posicao]), -1);
    if ChaveNoInicio(arquivo,'CAMERA_DEVICE:',posicao) then
      FCameraDevice := RetiraInfo(arquivo.Strings[posicao]);
    if ChaveNoInicio(arquivo,'KINECT_MINDIST:',posicao) then
      FKinectMinDistance := SafeParseFloat(RetiraInfo(arquivo.Strings[posicao]), 0.8);
    if ChaveNoInicio(arquivo,'KINECT_MAXDIST:',posicao) then
      FKinectMaxDistance := SafeParseFloat(RetiraInfo(arquivo.Strings[posicao]), 3.5);
    if (FKinectMinDistance <= 0) or (FKinectMaxDistance <= 0) or (FKinectMinDistance >= FKinectMaxDistance) then
    begin
      FKinectMinDistance := 0.8;
      FKinectMaxDistance := 3.5;
    end;
    if ChaveNoInicio(arquivo,'KINECT_SEATED:',posicao) then
      FKinectSeatedMode := StrToBoolDef(RetiraInfo(arquivo.Strings[posicao]), True);
    if ChaveNoInicio(arquivo,'KINECT_TARGET_LEFT:',posicao) then
      FKinectTargetLeft := RetiraInfo(arquivo.Strings[posicao]);
    if ChaveNoInicio(arquivo,'KINECT_TARGET_RIGHT:',posicao) then
      FKinectTargetRight := RetiraInfo(arquivo.Strings[posicao]);
    if ChaveNoInicio(arquivo,'KINECT_TARGET_CENTER:',posicao) then
      FKinectTargetCenter := RetiraInfo(arquivo.Strings[posicao]);


    if ChaveNoInicio(arquivo,'INTEGRATION_ENABLED:',posicao) then
      FIntegration.Enabled := Trim(RetiraInfo(arquivo.Strings[posicao]))='1';
    if ChaveNoInicio(arquivo,'INTEGRATION_BIND:',posicao) then FIntegration.BindIP:=Trim(RetiraInfo(arquivo.Strings[posicao]));
    if ChaveNoInicio(arquivo,'INTEGRATION_PORT:',posicao) then FIntegration.Port:=StrToIntDef(RetiraInfo(arquivo.Strings[posicao]),0);
    if ChaveNoInicio(arquivo,'INTEGRATION_TOKEN:',posicao) then FIntegration.Token:=TVoiceCredentialStore.UnprotectToken(RetiraInfo(arquivo.Strings[posicao]));
    if ChaveNoInicio(arquivo,'INTEGRATION_ALLOWED_IPS:',posicao) then FIntegration.AllowedIPs:=RetiraInfo(arquivo.Strings[posicao]);
    if ChaveNoInicio(arquivo,'RAG_IN_ANSWERS:',posicao) then
      FRAGInAnswers := Trim(RetiraInfo(arquivo.Strings[posicao]))<>'0';

    // Consulte o token da IA ao transcrever, sem persistir uma copia obsoleta.

end;

procedure TSetMain.IdentificaArquivo(flag: boolean);
begin
  Fpath := GetAppConfigDir(false);
  if GetEnvironmentVariable('ASSISTENTE_CONFIG_DIR') <> '' then
    Fpath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('ASSISTENTE_CONFIG_DIR'));
  if not(FileExists(FPATH)) then
  begin
     createdir(fpath);
  end;
  if (FileExists(fpath+filename)) then
  begin
    arquivo.LoadFromFile(fpath+filename);
    CarregaContexto();
  end
  else
  begin
    default();
  end;
end;

constructor TSetMain.create();
begin
    inherited create();
    arquivo := TStringList.create();
    FFONT := TFont.create();
    FAvatar3DProfile := 'professor';
    FAvatar3DAutoIdle := True;
    FVisionSource := vsNone;
    FKinectDeviceIndex := -1;
    FKinectMinDistance := 0.8;
    FKinectMaxDistance := 3.5;
    FKinectSeatedMode := True;
    FKinectTargetLeft := '';
    FKinectTargetRight := '';
    FKinectTargetCenter := '';
    FIntegration := DefaultIntegrationConfig;
    FRAGInAnswers := True;
    IdentificaArquivo(true);
end;

procedure TSetMain.WriteLines(Lines: TStrings; Mode: TSettingsWriteMode);
  procedure Put(const Key, Value: string);
  var V: string;
  begin
    V:=Value;
    if Mode<>swStore then begin
      if IsMachineSettingKey(Key) then Exit;
      if IsSecretSettingKey(Key) and (Mode=swExportWithoutSecrets) then Exit;
    end else if (Key='STT_TOKEN') or (Key='INTEGRATION_TOKEN') then
      V:=TVoiceCredentialStore.ProtectToken(V);
    { One setting per line: a line break would inject another key. }
    V:=StringReplace(StringReplace(V,#13,' ',[rfReplaceAll]),#10,' ',[rfReplaceAll]);
    Lines.Append(Key+':'+V);
  end;
begin
  Put('DEVICE',iif(ckdevice,'1','0'));
  Put('POSX',inttostr(FPOSX));
  Put('POSY',inttostr(FPOSY));
  Put('FIXAR',booltostr(FFixar));
  Put('STAY',booltostr(FStay));
  Put('LASTFILES',FLastFiles);
  Put('HEIGHT',inttostr(FHEIGHT));
  Put('WIDTH',inttostr(FWIDTH));
  Put('RUNSCRIPT',FRunScript);
  Put('DEBUGSCRIPT',FDebugScript);
  Put('CLEANSCRIPT',FCleanScript);
  Put('INSTALLSCRIPT',FInstall);
  Put('COMPILESCRIPT',FCompile);
  Put('FONT',FontToString(FFONT));
  Put('CHATGPT',FCHATGPT);
  Put('DLLPATH',FDLLPATH);
  Put('DLLMYPATH',FDLLMYPATH);
  Put('DLLPOSTPATH',FDLLPOSTPATH);

  Put('HOSTNAMEMY',FHostnameMy);
  Put('BANCOMY',FBancoMy);
  Put('USERNAMEMY',FUsernameMy);
  Put('PASSWORDMY',FPasswordMy);

  Put('HOSTNAMEPOST',FHostnamePOST);
  Put('BANCOPOST',FBancoPOST);
  Put('USERNAMEPOST',FUsernamePOST);
  Put('PASSWORDPOST',FPasswordPOST);
  Put('SCHEMAPOST',FSchemaPost);
  Put('TOOLSFALAR',iif(FToolsFalar,'1','0'));

  Put('CHATGPTPROVIDER',inttostr(FChatGPTProvider));
  Put('CHATGPTMODEL',FChatGPTModel);
  Put('CHATGPTURL',FChatGPTURL);

  // Salva JARVIS
  Put('JARVISURL',FJarvisURL);
  Put('JARVISAPIKEY',FJarvisAPIKey);
  Put('JARVISIAMODE',FJarvisIAMode);
  Put('MINIMIZETOTRAY',iif(FMinimizeToTray, '1', '0'));
  Put('AUTOSPEAK',iif(FAutoSpeak, '1', '0'));

  Put('FRASE',FFrase);
  Put('VOICESYNTHIP',FVoiceSynthIP);
  Put('VOICESYNTHPORT',inttostr(FVoiceSynthPort));
  Put('VOICERECOGIP',FVoiceRecogIP);
  Put('VOICERECOGPORT',inttostr(FVoiceRecogPort));

  Put('SYNTHENGINE',inttostr(FSynthEngine));
  Put('SYNTHVOICE',FSynthVoice);
  Put('VOICEMODEL',FVoiceModel);
  Put('SYNTHVOLUME',inttostr(FSynthVolume));
  Put('SYNTHRATE',inttostr(FSynthRate));
  Put('SYNTHASYNC',iif(FSynthAsync, '1', '0'));

  Put('RECOGENGINE',inttostr(FRecogEngine));
  Put('RECOGLANGUAGE',FRecogLanguage);
  Put('AUDIOSAMPLERATE',inttostr(FAudioSampleRate));
  Put('AUDIOCHANNELS',inttostr(FAudioChannels));
  Put('AUDIODEVICEINDEX',inttostr(FAudioDeviceIndex));
  Put('AUDIODEVICENAME',FAudioDeviceName);

  Put('AVATAR3D_PROFILE',FAvatar3DProfile);
  Put('AVATAR3D_MODEL',FAvatar3DModel);
  Put('AVATAR3D_AUTO_IDLE',iif(FAvatar3DAutoIdle, '1', '0'));
  Put('VISION_SOURCE',VisionSourceName(FVisionSource));
  Put('KINECT_DEVICE_INDEX',IntToStr(FKinectDeviceIndex));
  Put('CAMERA_DEVICE',FCameraDevice);
  Put('KINECT_MINDIST',FloatToStr(FKinectMinDistance));
  Put('KINECT_MAXDIST',FloatToStr(FKinectMaxDistance));
  Put('KINECT_SEATED',iif(FKinectSeatedMode, '1', '0'));
  Put('KINECT_TARGET_LEFT',FKinectTargetLeft);
  Put('KINECT_TARGET_RIGHT',FKinectTargetRight);
  Put('KINECT_TARGET_CENTER',FKinectTargetCenter);

  Put('CONTINUOUS_LISTENING',iif(FContinuousListening, '1', '0'));
  Put('VOICE_THRESHOLD',FloatToStr(FVoiceThreshold));
  Put('SILENCE_TIMEOUT_MS',inttostr(FSilenceTimeoutMs));
  Put('MIN_SPEECH_MS',inttostr(FMinSpeechMs));
  Put('MAX_SPEECH_MS',inttostr(FMaxSpeechMs));
  Put('ECHO_SUPPRESSION',iif(FEchoSuppressionEnabled, '1', '0'));
  Put('SELF_AUDIO_CORR_THRESH',FloatToStr(FSelfAudioCorrelationThreshold));

  Put('STT_TOKEN',FSTTToken);
  Put('STT_MODEL',FSTTModel);
  Put('STT_ENDPOINT',FSTTEndpoint);

  Put('INTEGRATION_ENABLED',iif(FIntegration.Enabled,'1','0'));
  Put('INTEGRATION_BIND',FIntegration.BindIP);
  Put('INTEGRATION_PORT',IntToStr(FIntegration.Port));
  Put('INTEGRATION_TOKEN',FIntegration.Token);
  Put('INTEGRATION_ALLOWED_IPS',FIntegration.AllowedIPs);
  Put('RAG_IN_ANSWERS',iif(FRAGInAnswers,'1','0'));
end;

procedure TSetMain.ImportLines(Lines: TStrings);
var Saved,Accepted: TStringList; I,P: Integer; Key: string;
begin
  Accepted:=TStringList.Create;
  try
    for I:=0 to Lines.Count-1 do begin
      P:=Pos(':',Lines[I]);if P<2 then Continue;
      Key:=UpperCase(Trim(Copy(Lines[I],1,P-1)));
      if IsMachineSettingKey(Key) then Continue;
      Accepted.Append(Key+':'+Copy(Lines[I],P+1,MaxInt));
    end;
    Saved:=arquivo;arquivo:=Accepted;
    try CarregaContexto;finally arquivo:=Saved;end;
  finally Accepted.Free;end;
end;

procedure TSetMain.SalvaContexto(flag: boolean);
begin
  if (flag) then
  begin
    IdentificaArquivo(false);
  end;
  if (FIntegration.Token<>'') and (Copy(TVoiceCredentialStore.ProtectToken(FIntegration.Token),1,6)<>'dpapi:') then
    raise Exception.Create('Nao foi possivel proteger o token de integracao com DPAPI.');
  arquivo.Clear;
  WriteLines(arquivo,swStore);
  arquivo.SaveToFile(fpath+filename);
end;

destructor TSetMain.Destroy;
begin
  arquivo.free;
  arquivo := nil;
  FFONT.free;
  inherited Destroy;
end;

end.
