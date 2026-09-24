//Objetivo construir os parametros de setup da classe principal
//Criado por Marcelo Maurin Martins
//Data:07/02/2021
//Atualizado com suporte a API Segura v1 do JARVIS Residencial

unit setmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, funcoes, graphics, aivoicecredentialstore, vision_types;

const filename = 'Setmain.cfg';


type
  { TSetMain }

  TSetMain = class(TObject)

  private
        FAvatar3DModel: string;
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
        FRecogEngine : integer; // 0=vreOpenAIWhisper, 1=vreSAPI, 2=vreSystemDefault
        FRecogLanguage : String;
        FAudioSampleRate : integer;
        FAudioChannels : integer;

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
        property Avatar3DModel: string read FAvatar3DModel write FAvatar3DModel;
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

  end;

  function SafeParseFloat(const AText: string; ADefault: Double): Double;

  var
    FSetMain : TSetMain;

implementation

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
    FAvatar3DModel := '';
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
    FKinectTargetLeft := 'ECG';
    FKinectTargetRight := 'Hemacias';
    FKinectTargetCenter := 'Robotinics';

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
    if  BuscaChave(arquivo,'DEVICE:',posicao) then
    begin
         ckdevice := iif(RetiraInfo(arquivo.Strings[posicao])='0',false,true);
    end;
    if  BuscaChave(arquivo,'POSX:',posicao) then
    begin
      FPOSX :=  strtoint(RetiraInfo(arquivo.Strings[posicao]));
    end;
    if  BuscaChave(arquivo,'POSY:',posicao) then
    begin
      FPOSY :=  strtoint(RetiraInfo(arquivo.Strings[posicao]));
    end;
    if  BuscaChave(arquivo,'FIXAR:',posicao) then
    begin
      FFixar :=  strtobool(RetiraInfo(arquivo.Strings[posicao]));
    end;
    if  BuscaChave(arquivo,'STAY:',posicao) then
    begin
      FStay :=  strtobool(RetiraInfo(arquivo.Strings[posicao]));
    end;
    if  BuscaChave(arquivo,'LASTFILES:',posicao) then
    begin
      FLastFiles := RetiraInfo(arquivo.Strings[posicao]);
    end;

    if  BuscaChave(arquivo,'HEIGHT:',posicao) then
    begin
      FHEIGHT := strtoint(RetiraInfo(arquivo.Strings[posicao]));
    end;

    if  BuscaChave(arquivo,'WIDTH:',posicao) then
    begin
      FWIDTH := strtoint(RetiraInfo(arquivo.Strings[posicao]));
    end;

    if  BuscaChave(arquivo,'RUNSCRIPT:',posicao) then
    begin
      FRunScript := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'DEBUGSCRIPT:',posicao) then
    begin
      FDebugScript := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'CLEANSCRIPT:',posicao) then
    begin
      FCleanScript := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'INSTALLSCRIPT:',posicao) then
    begin
      FInstall := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'COMPILESCRIPT:',posicao) then
    begin
      FCompile := RetiraInfo(arquivo.Strings[posicao]);
    end;

    if  BuscaChave(arquivo,'FONT:',posicao) then
    begin
      StringToFont(RetiraInfo(arquivo.Strings[posicao]),FFONT);
    end;
    if  BuscaChave(arquivo,'CHATGPT:',posicao) then
    begin
      FCHATGPT := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'DLLPATH:',posicao) then
    begin
      FDLLPATH := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'DLLMYPATH:',posicao) then
    begin
      FDLLMyPATH := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'DLLPOSTPATH:',posicao) then
    begin
      FDLLPOSTPATH := RetiraInfo(arquivo.Strings[posicao]);
    end;

    if  BuscaChave(arquivo,'HOSTNAMEMY:',posicao) then
    begin
      FHostnameMy := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'BANCOMY:',posicao) then
    begin
      FBancoMy := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'USERNAMEMY:',posicao) then
    begin
      FUsernameMy := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'PASSWORDMY:',posicao) then
    begin
      FPasswordMy := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'HOSTNAMEPOST:',posicao) then
    begin
      FHostnamePost := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'BANCOPOST:',posicao) then
    begin
      FBancoPost := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'USERNAMEPOST:',posicao) then
    begin
      FUsernamePost := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'PASSWORDPOST:',posicao) then
    begin
      FPasswordPost := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'SCHEMAPOST:',posicao) then
    begin
      FSchemaPost := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'TOOLSFALAR:',posicao) then
    begin
      FTOOLSFALAR := iif(RetiraInfo(arquivo.Strings[posicao])='0',false,true);
    end;

    if  BuscaChave(arquivo,'CHATGPTPROVIDER:',posicao) then
    begin
      FChatGPTProvider := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 0);
    end;
    if  BuscaChave(arquivo,'CHATGPTMODEL:',posicao) then
    begin
      FChatGPTModel := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'CHATGPTURL:',posicao) then
    begin
      FChatGPTURL := RetiraInfo(arquivo.Strings[posicao]);
    end;

    // Leitura JARVIS
    if  BuscaChave(arquivo,'JARVISURL:',posicao) then
    begin
      FJarvisURL := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'JARVISAPIKEY:',posicao) then
    begin
      FJarvisAPIKey := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'JARVISIAMODE:',posicao) then
    begin
      FJarvisIAMode := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'MINIMIZETOTRAY:',posicao) then
    begin
      FMinimizeToTray := (RetiraInfo(arquivo.Strings[posicao]) <> '0');
    end;
    if  BuscaChave(arquivo,'AUTOSPEAK:',posicao) then
    begin
      FAutoSpeak := (RetiraInfo(arquivo.Strings[posicao]) <> '0');
    end;

    if  BuscaChave(arquivo,'FRASE:',posicao) then
    begin
      FFrase := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'VOICESYNTHIP:',posicao) then
    begin
      FVoiceSynthIP := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'VOICESYNTHPORT:',posicao) then
    begin
      FVoiceSynthPort := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 8096);
    end;
    if  BuscaChave(arquivo,'VOICERECOGIP:',posicao) then
    begin
      FVoiceRecogIP := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'VOICERECOGPORT:',posicao) then
    begin
      FVoiceRecogPort := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 8097);
    end;

    if  BuscaChave(arquivo,'SYNTHENGINE:',posicao) then
    begin
      FSynthEngine := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 1);
    end;
    if  BuscaChave(arquivo,'SYNTHVOICE:',posicao) then
    begin
      FSynthVoice := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'SYNTHVOLUME:',posicao) then
    begin
      FSynthVolume := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 100);
    end;
    if  BuscaChave(arquivo,'SYNTHRATE:',posicao) then
    begin
      FSynthRate := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 0);
    end;
    if  BuscaChave(arquivo,'SYNTHASYNC:',posicao) then
    begin
      FSynthAsync := (RetiraInfo(arquivo.Strings[posicao]) <> '0');
    end;

    if  BuscaChave(arquivo,'VOICEPROVIDER:',posicao) then
      FVoiceProvider := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 0);
    if  BuscaChave(arquivo,'VOICEAPITOKEN:',posicao) then
      FVoiceAPIToken := TVoiceCredentialStore.UnprotectToken(RetiraInfo(arquivo.Strings[posicao]));
    if  BuscaChave(arquivo,'VOICEMODEL:',posicao) then
      FVoiceModel := RetiraInfo(arquivo.Strings[posicao]);
    if  BuscaChave(arquivo,'VOICEENDPOINT:',posicao) then
      FVoiceEndpoint := RetiraInfo(arquivo.Strings[posicao]);
    if  BuscaChave(arquivo,'VOICEREMOTEVOICE:',posicao) then
      FVoiceRemoteVoice := RetiraInfo(arquivo.Strings[posicao]);
    if  BuscaChave(arquivo,'VOICELANGUAGE:',posicao) then
      FVoiceLanguage := RetiraInfo(arquivo.Strings[posicao]);
    if  BuscaChave(arquivo,'VOICEOUTPUTFORMAT:',posicao) then
      FVoiceOutputFormat := RetiraInfo(arquivo.Strings[posicao]);
    if  BuscaChave(arquivo,'VOICESPEED:',posicao) then
      FVoiceSpeed := strtofloatdef(StringReplace(RetiraInfo(arquivo.Strings[posicao]), ',', '.', []), 1.0);

    // Migracao/fallback de configuracao antiga (tarefa 27)
    if (Trim(FVoiceAPIToken) = '') and (FSynthEngine = 3) and (Trim(FCHATGPT) <> '') then
    begin
      FVoiceAPIToken := FCHATGPT;
      FVoiceProvider := 1;
    end;

    if  BuscaChave(arquivo,'RECOGENGINE:',posicao) then
    begin
      FRecogEngine := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 0);
    end;
    if  BuscaChave(arquivo,'RECOGLANGUAGE:',posicao) then
    begin
      FRecogLanguage := RetiraInfo(arquivo.Strings[posicao]);
    end;
    if  BuscaChave(arquivo,'AUDIOSAMPLERATE:',posicao) then
    begin
      FAudioSampleRate := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 16000);
    end;
    if  BuscaChave(arquivo,'AUDIOCHANNELS:',posicao) then
    begin
      FAudioChannels := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 1);
    end;

    if BuscaChave(arquivo,'CONTINUOUS_LISTENING:',posicao) then
      FContinuousListening := (RetiraInfo(arquivo.Strings[posicao]) <> '0');
    if BuscaChave(arquivo,'VOICE_THRESHOLD:',posicao) then
      FVoiceThreshold := strtofloatdef(StringReplace(RetiraInfo(arquivo.Strings[posicao]), ',', '.', []), 0.015);
    if BuscaChave(arquivo,'SILENCE_TIMEOUT_MS:',posicao) then
      FSilenceTimeoutMs := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 900);
    if BuscaChave(arquivo,'MIN_SPEECH_MS:',posicao) then
      FMinSpeechMs := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 250);
    if BuscaChave(arquivo,'MAX_SPEECH_MS:',posicao) then
      FMaxSpeechMs := strtointdef(RetiraInfo(arquivo.Strings[posicao]), 15000);
    if BuscaChave(arquivo,'ECHO_SUPPRESSION:',posicao) then
      FEchoSuppressionEnabled := (RetiraInfo(arquivo.Strings[posicao]) <> '0');
    if BuscaChave(arquivo,'SELF_AUDIO_CORR_THRESH:',posicao) then
      FSelfAudioCorrelationThreshold := strtofloatdef(StringReplace(RetiraInfo(arquivo.Strings[posicao]), ',', '.', []), 0.70);

    if BuscaChave(arquivo,'STT_TOKEN:',posicao) then
      FSTTToken := TVoiceCredentialStore.UnprotectToken(RetiraInfo(arquivo.Strings[posicao]));
    if BuscaChave(arquivo,'STT_MODEL:',posicao) then
      FSTTModel := RetiraInfo(arquivo.Strings[posicao]);
    if BuscaChave(arquivo,'STT_ENDPOINT:',posicao) then
      FSTTEndpoint := RetiraInfo(arquivo.Strings[posicao]);

    if BuscaChave(arquivo,'VISION_SOURCE:',posicao) then
      FVisionSource := ParseVisionSource(RetiraInfo(arquivo.Strings[posicao]))
    else if BuscaChave(arquivo,'KINECT_ENABLED:',posicao) then
    begin
      if SameText(RetiraInfo(arquivo.Strings[posicao]), 'true') or
         (RetiraInfo(arquivo.Strings[posicao]) = '1') then FVisionSource := vsKinect
      else FVisionSource := vsNone;
    end;
    if BuscaChave(arquivo,'KINECT_DEVICE_INDEX:',posicao) then
      FKinectDeviceIndex := StrToIntDef(RetiraInfo(arquivo.Strings[posicao]), -1);
    if BuscaChave(arquivo,'CAMERA_DEVICE:',posicao) then
      FCameraDevice := RetiraInfo(arquivo.Strings[posicao]);
    if BuscaChave(arquivo,'KINECT_MINDIST:',posicao) then
      FKinectMinDistance := SafeParseFloat(RetiraInfo(arquivo.Strings[posicao]), 0.8);
    if BuscaChave(arquivo,'KINECT_MAXDIST:',posicao) then
      FKinectMaxDistance := SafeParseFloat(RetiraInfo(arquivo.Strings[posicao]), 3.5);
    if (FKinectMinDistance <= 0) or (FKinectMaxDistance <= 0) or (FKinectMinDistance >= FKinectMaxDistance) then
    begin
      FKinectMinDistance := 0.8;
      FKinectMaxDistance := 3.5;
    end;
    if BuscaChave(arquivo,'KINECT_SEATED:',posicao) then
      FKinectSeatedMode := StrToBoolDef(RetiraInfo(arquivo.Strings[posicao]), True);
    if BuscaChave(arquivo,'KINECT_TARGET_LEFT:',posicao) then
      FKinectTargetLeft := RetiraInfo(arquivo.Strings[posicao]);
    if BuscaChave(arquivo,'KINECT_TARGET_RIGHT:',posicao) then
      FKinectTargetRight := RetiraInfo(arquivo.Strings[posicao]);
    if BuscaChave(arquivo,'KINECT_TARGET_CENTER:',posicao) then
      FKinectTargetCenter := RetiraInfo(arquivo.Strings[posicao]);
    if Trim(FKinectTargetLeft) = '' then FKinectTargetLeft := 'ECG';
    if Trim(FKinectTargetRight) = '' then FKinectTargetRight := 'Hemacias';
    if Trim(FKinectTargetCenter) = '' then FKinectTargetCenter := 'Robotinics';

    // Fallback: se STTToken vazio, reaproveita FCHATGPT
    if (Trim(FSTTToken) = '') and (Trim(FCHATGPT) <> '') then
      FSTTToken := FCHATGPT;

end;

procedure TSetMain.IdentificaArquivo(flag: boolean);
begin
  Fpath := GetAppConfigDir(false);
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
    FVisionSource := vsNone;
    FKinectDeviceIndex := -1;
    FKinectMinDistance := 0.8;
    FKinectMaxDistance := 3.5;
    FKinectSeatedMode := True;
    FKinectTargetLeft := 'ECG';
    FKinectTargetRight := 'Hemacias';
    FKinectTargetCenter := 'Robotinics';
    IdentificaArquivo(true);
end;

procedure TSetMain.SalvaContexto(flag: boolean);
begin
  if (flag) then
  begin
    IdentificaArquivo(false);
  end;
  arquivo.Clear;
  arquivo.Append('DEVICE:'+iif(ckdevice,'1','0'));
  arquivo.Append('POSX:'+inttostr(FPOSX));
  arquivo.Append('POSY:'+inttostr(FPOSY));
  arquivo.Append('FIXAR:'+booltostr(FFixar));
  arquivo.Append('STAY:'+booltostr(FStay));
  arquivo.Append('LASTFILES:'+FLastFiles);
  arquivo.Append('HEIGHT:'+inttostr(FHEIGHT));
  arquivo.Append('WIDTH:'+inttostr(FWIDTH));
  arquivo.Append('RUNSCRIPT:'+FRunScript);
  arquivo.Append('DEBUGSCRIPT:'+FDebugScript);
  arquivo.Append('CLEANSCRIPT:'+FCleanScript);
  arquivo.Append('INSTALLSCRIPT:'+FInstall);
  arquivo.Append('COMPILESCRIPT:'+FCompile);
  arquivo.Append('FONT:'+FontToString(FFONT));
  arquivo.Append('CHATGPT:'+FCHATGPT);
  arquivo.Append('DLLPATH:'+FDLLPATH);
  arquivo.Append('DLLMYPATH:'+FDLLMYPATH);
  arquivo.Append('DLLPOSTPATH:'+FDLLPOSTPATH);

  arquivo.Append('HOSTNAMEMY:'+FHostnameMy);
  arquivo.Append('BANCOMY:'+FBancoMy);
  arquivo.Append('USERNAMEMY:'+FUsernameMy);
  arquivo.Append('PASSWORDMY:'+FPasswordMy);

  arquivo.Append('HOSTNAMEPOST:'+FHostnamePOST);
  arquivo.Append('BANCOPOST:'+FBancoPOST);
  arquivo.Append('USERNAMEPOST:'+FUsernamePOST);
  arquivo.Append('PASSWORDPOST:'+FPasswordPOST);
  arquivo.Append('SCHEMAPOST:'+FSchemaPost);
  arquivo.Append('TOOLSFALAR:'+iif(FToolsFalar,'1','0'));

  arquivo.Append('CHATGPTPROVIDER:'+inttostr(FChatGPTProvider));
  arquivo.Append('CHATGPTMODEL:'+FChatGPTModel);
  arquivo.Append('CHATGPTURL:'+FChatGPTURL);

  // Salva JARVIS
  arquivo.Append('JARVISURL:'+FJarvisURL);
  arquivo.Append('JARVISAPIKEY:'+FJarvisAPIKey);
  arquivo.Append('JARVISIAMODE:'+FJarvisIAMode);
  arquivo.Append('MINIMIZETOTRAY:'+iif(FMinimizeToTray, '1', '0'));
  arquivo.Append('AUTOSPEAK:'+iif(FAutoSpeak, '1', '0'));

  arquivo.Append('FRASE:'+FFrase);
  arquivo.Append('VOICESYNTHIP:'+FVoiceSynthIP);
  arquivo.Append('VOICESYNTHPORT:'+inttostr(FVoiceSynthPort));
  arquivo.Append('VOICERECOGIP:'+FVoiceRecogIP);
  arquivo.Append('VOICERECOGPORT:'+inttostr(FVoiceRecogPort));

  arquivo.Append('SYNTHENGINE:'+inttostr(FSynthEngine));
  arquivo.Append('SYNTHVOICE:'+FSynthVoice);
  arquivo.Append('SYNTHVOLUME:'+inttostr(FSynthVolume));
  arquivo.Append('SYNTHRATE:'+inttostr(FSynthRate));
  arquivo.Append('SYNTHASYNC:'+iif(FSynthAsync, '1', '0'));

  arquivo.Append('RECOGENGINE:'+inttostr(FRecogEngine));
  arquivo.Append('RECOGLANGUAGE:'+FRecogLanguage);
  arquivo.Append('AUDIOSAMPLERATE:'+inttostr(FAudioSampleRate));
  arquivo.Append('AUDIOCHANNELS:'+inttostr(FAudioChannels));

  arquivo.Append('VISION_SOURCE:'+VisionSourceName(FVisionSource));
  arquivo.Append('KINECT_DEVICE_INDEX:'+IntToStr(FKinectDeviceIndex));
  arquivo.Append('CAMERA_DEVICE:'+FCameraDevice);
  arquivo.Append('KINECT_MINDIST:'+FloatToStr(FKinectMinDistance));
  arquivo.Append('KINECT_MAXDIST:'+FloatToStr(FKinectMaxDistance));
  arquivo.Append('KINECT_SEATED:'+iif(FKinectSeatedMode, '1', '0'));
  arquivo.Append('KINECT_TARGET_LEFT:'+FKinectTargetLeft);
  arquivo.Append('KINECT_TARGET_RIGHT:'+FKinectTargetRight);
  arquivo.Append('KINECT_TARGET_CENTER:'+FKinectTargetCenter);

  arquivo.Append('CONTINUOUS_LISTENING:'+iif(FContinuousListening, '1', '0'));
  arquivo.Append('VOICE_THRESHOLD:'+FloatToStr(FVoiceThreshold));
  arquivo.Append('SILENCE_TIMEOUT_MS:'+inttostr(FSilenceTimeoutMs));
  arquivo.Append('MIN_SPEECH_MS:'+inttostr(FMinSpeechMs));
  arquivo.Append('MAX_SPEECH_MS:'+inttostr(FMaxSpeechMs));
  arquivo.Append('ECHO_SUPPRESSION:'+iif(FEchoSuppressionEnabled, '1', '0'));
  arquivo.Append('SELF_AUDIO_CORR_THRESH:'+FloatToStr(FSelfAudioCorrelationThreshold));

  arquivo.Append('STT_TOKEN:'+TVoiceCredentialStore.ProtectToken(FSTTToken));
  arquivo.Append('STT_MODEL:'+FSTTModel);
  arquivo.Append('STT_ENDPOINT:'+FSTTEndpoint);

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
