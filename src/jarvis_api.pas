unit jarvis_api;

{ Cliente Oficial da API REST Segura v1 do JARVIS Residencial
  Suporta conexões via Túnel Cloudflare HTTPS (com TLS 1.3) ou IP local (192.168.2.12).
  Autenticação Zero-Trust via Bearer Token. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, opensslsockets, fpjson, jsonparser, aibase;

type

  { TJarvisAPIClient }

  TJarvisAPIClient = class(TAIBaseComponent)
  private
    FBaseURL: string;
    FAPIKey: string;
    FIAMode: string;
    FTimeout: Integer;
    FLastHTTPStatus: Integer;
    FLastRawResponse: string;

    function InternalRequest(const AMethod, AEndpoint: string; const APayload: string; out AResponse: string): Boolean;
    function CleanBaseURL: string;
  public
    constructor Create(AOwner: TComponent); override;

    // Métodos de Conectividade e Status
    function TestarConexao(out AMsg: string): Boolean;
    function ObterStatus(out AResumo: string): Boolean;

    // Processamento Cognitivo e Ações Físicas
    function EnviarComando(const AComando: string; const AModo: string;
      out AResposta, AProvedor, AAcao, AAudioURL: string): Boolean;

    // Automação de Dispositivos e Relés
    function ListarDispositivos(out AJsonStr: string): Boolean;
    function AcionarDispositivo(AIdDevice: Integer; const AParametro, AValor: string; out AMsg: string): Boolean;

    // Telemetria e Clima
    function ObterClima(out ATemp, AUmidade, ADescricao: string; out AVaiChover: Boolean): Boolean;

    property BaseURL: string read FBaseURL write FBaseURL;
    property APIKey: string read FAPIKey write FAPIKey;
    property IAMode: string read FIAMode write FIAMode;
    property Timeout: Integer read FTimeout write FTimeout default 30;
    property LastHTTPStatus: Integer read FLastHTTPStatus;
    property LastRawResponse: string read FLastRawResponse;
  end;

implementation

{ TJarvisAPIClient }

constructor TJarvisAPIClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBaseURL := 'http://192.168.2.12';
  FAPIKey := '';
  FIAMode := 'auto';
  FTimeout := 30;
  FLastHTTPStatus := 0;
  FLastRawResponse := '';
  FCategory := ccAction;
end;

function TJarvisAPIClient.CleanBaseURL: string;
begin
  Result := Trim(FBaseURL);
  while (Length(Result) > 0) and (Result[Length(Result)] = '/') do
    Delete(Result, Length(Result), 1);
end;

function TJarvisAPIClient.InternalRequest(const AMethod, AEndpoint: string;
  const APayload: string; out AResponse: string): Boolean;
var
  HTTP: TFPHttpClient;
  FullURL: string;
  Ep: string;
  RequestBody: TStringStream;
  RespStream: TStringStream;
begin
  Result := False;
  AResponse := '';
  FLastHTTPStatus := 0;
  FLastRawResponse := '';
  ClearError;

  if Trim(FBaseURL) = '' then
  begin
    SetError('URL do servidor JARVIS não configurada.');
    Exit;
  end;

  Ep := Trim(AEndpoint);
  if (Length(Ep) > 0) and (Ep[1] = '/') then
    Delete(Ep, 1, 1);

  FullURL := CleanBaseURL + '/api/v1/' + Ep;

  HTTP := TFPHttpClient.Create(nil);
  RequestBody := nil;
  RespStream := TStringStream.Create('');
  try
    try
      HTTP.AllowRedirect := True;
      HTTP.IOTimeout := FTimeout * 1000;
      HTTP.AddHeader('User-Agent', 'JARVIS-WindowsClient/1.0');
      HTTP.AddHeader('Accept', 'application/json');

      if Trim(FAPIKey) <> '' then
        HTTP.AddHeader('Authorization', 'Bearer ' + Trim(FAPIKey));

      if UpperCase(AMethod) = 'POST' then
      begin
        HTTP.AddHeader('Content-Type', 'application/json');
        RequestBody := TStringStream.Create(APayload);
        HTTP.RequestBody := RequestBody;
        HTTP.Post(FullURL, RespStream);
      end
      else
      begin
        HTTP.Get(FullURL, RespStream);
      end;

      FLastHTTPStatus := HTTP.ResponseStatusCode;
      AResponse := RespStream.DataString;
      FLastRawResponse := AResponse;

      if (FLastHTTPStatus >= 200) and (FLastHTTPStatus < 300) then
      begin
        Result := True;
      end
      else
      begin
        SetError(Format('HTTP %d: %s', [FLastHTTPStatus, Copy(AResponse, 1, 200)]));
      end;
    except
      on E: Exception do
      begin
        SetError('Falha na comunicação com o JARVIS: ' + E.Message);
        Result := False;
      end;
    end;
  finally
    if Assigned(RequestBody) then
      RequestBody.Free;
    RespStream.Free;
    HTTP.Free;
  end;
end;

function TJarvisAPIClient.TestarConexao(out AMsg: string): Boolean;
var
  RawResp: string;
  JData: TJSONData;
  JObj: TJSONObject;
begin
  Result := False;
  AMsg := '';

  if not InternalRequest('GET', 'status', '', RawResp) then
  begin
    AMsg := LastError;
    Exit;
  end;

  try
    JData := GetJSON(RawResp);
    try
      if JData is TJSONObject then
      begin
        JObj := TJSONObject(JData);
        if JObj.Get('status', '') = 'sucesso' then
        begin
          AMsg := 'Conexão estabelecida com sucesso com o ' + JObj.Get('sistema', 'JARVIS') +
                  ' (API ' + JObj.Get('versao_api', 'v1') + ')';
          Result := True;
        end
        else
        begin
          AMsg := 'Resposta inesperada: ' + Copy(RawResp, 1, 150);
        end;
      end;
    finally
      JData.Free;
    end;
  except
    on E: Exception do
      AMsg := 'Erro ao interpretar resposta: ' + E.Message;
  end;
end;

function TJarvisAPIClient.ObterStatus(out AResumo: string): Boolean;
var
  RawResp: string;
  JData: TJSONData;
  JObj, JResumo, JTunel: TJSONObject;
begin
  Result := False;
  AResumo := '';

  if not InternalRequest('GET', 'status', '', RawResp) then
  begin
    AResumo := LastError;
    Exit;
  end;

  try
    JData := GetJSON(RawResp);
    try
      if JData is TJSONObject then
      begin
        JObj := TJSONObject(JData);
        JResumo := JObj.Get('resumo_residencia', TJSONObject(nil));
        JTunel := JObj.Get('tunel_externo', TJSONObject(nil));

        AResumo := '=== STATUS DA RESIDÊNCIA ===' + sLineBreak;
        if Assigned(JTunel) then
          AResumo := AResumo + 'Link Externo: ' + JTunel.Get('status', 'offline') + ' (' + JTunel.Get('url', '') + ')' + sLineBreak;

        if Assigned(JResumo) then
        begin
          AResumo := AResumo + Format('Dispositivos Ativos: %d' + sLineBreak +
                                      'Nós ARM Online: %d' + sLineBreak +
                                      'Sensores / Leituras: %d' + sLineBreak +
                                      'Firewall IPs Bloqueados: %d',
            [JResumo.Get('dispositivos_ativos', 0),
             JResumo.Get('nos_arm_online', 0),
             JResumo.Get('leituras_telemetria', 0),
             JResumo.Get('firewall_ips_bloqueados', 0)]);
        end;
        Result := True;
      end;
    finally
      JData.Free;
    end;
  except
    on E: Exception do
      AResumo := 'Erro no parse do status: ' + E.Message;
  end;
end;

function TJarvisAPIClient.EnviarComando(const AComando: string; const AModo: string;
  out AResposta, AProvedor, AAcao, AAudioURL: string): Boolean;
var
  JReq: TJSONObject;
  PayloadStr, RawResp: string;
  JData: TJSONData;
  JObj: TJSONObject;
  TargetMode: string;
begin
  Result := False;
  AResposta := '';
  AProvedor := '';
  AAcao := '';
  AAudioURL := '';

  TargetMode := AModo;
  if Trim(TargetMode) = '' then
    TargetMode := FIAMode;
  if Trim(TargetMode) = '' then
    TargetMode := 'auto';

  JReq := TJSONObject.Create;
  try
    JReq.Add('comando', AComando);
    JReq.Add('ia_mode', TargetMode);
    PayloadStr := JReq.AsJSON;
  finally
    JReq.Free;
  end;

  if not InternalRequest('POST', 'comando', PayloadStr, RawResp) then
  begin
    AResposta := 'Falha ao enviar comando para o JARVIS: ' + LastError;
    Exit;
  end;

  try
    JData := GetJSON(RawResp);
    try
      if JData is TJSONObject then
      begin
        JObj := TJSONObject(JData);
        AResposta := JObj.Get('resposta', '');
        AProvedor := JObj.Get('provedor_ia', 'JARVIS');
        AAcao := JObj.Get('acao_executada', '');
        AAudioURL := JObj.Get('audio_url', '');
        Result := True;
      end;
    finally
      JData.Free;
    end;
  except
    on E: Exception do
      AResposta := 'Erro ao interpretar resposta do JARVIS: ' + E.Message;
  end;
end;

function TJarvisAPIClient.ListarDispositivos(out AJsonStr: string): Boolean;
begin
  Result := InternalRequest('GET', 'dispositivos', '', AJsonStr);
end;

function TJarvisAPIClient.AcionarDispositivo(AIdDevice: Integer;
  const AParametro, AValor: string; out AMsg: string): Boolean;
var
  JReq: TJSONObject;
  PayloadStr, RawResp: string;
  JData: TJSONData;
  JObj: TJSONObject;
begin
  Result := False;
  AMsg := '';

  JReq := TJSONObject.Create;
  try
    JReq.Add('iddevice', AIdDevice);
    JReq.Add('parametro', AParametro);
    JReq.Add('valor', AValor);
    PayloadStr := JReq.AsJSON;
  finally
    JReq.Free;
  end;

  if not InternalRequest('POST', 'dispositivos/acionar', PayloadStr, RawResp) then
  begin
    AMsg := LastError;
    Exit;
  end;

  try
    JData := GetJSON(RawResp);
    try
      if JData is TJSONObject then
      begin
        JObj := TJSONObject(JData);
        AMsg := JObj.Get('mensagem', 'Dispositivo acionado.');
        Result := JObj.Get('status', '') = 'sucesso';
      end;
    finally
      JData.Free;
    end;
  except
    on E: Exception do
      AMsg := 'Erro ao parsear retorno: ' + E.Message;
  end;
end;

function TJarvisAPIClient.ObterClima(out ATemp, AUmidade, ADescricao: string;
  out AVaiChover: Boolean): Boolean;
var
  RawResp: string;
  JData: TJSONData;
  JObj, JClima: TJSONObject;
begin
  Result := False;
  ATemp := '--';
  AUmidade := '--';
  ADescricao := '';
  AVaiChover := False;

  if not InternalRequest('GET', 'clima', '', RawResp) then
    Exit;

  try
    JData := GetJSON(RawResp);
    try
      if JData is TJSONObject then
      begin
        JObj := TJSONObject(JData);
        JClima := JObj.Get('clima', TJSONObject(nil));
        if Assigned(JClima) then
        begin
          ATemp := JClima.Get('temperatura', '--');
          AUmidade := JClima.Get('umidade', '--');
          AVaiChover := JClima.Get('vai_chover', False);
          if AVaiChover then
            ADescricao := 'Atenção: Probabilidade de chuva detectada nas próximas horas.'
          else
            ADescricao := 'Condições climáticas estáveis.';
          Result := True;
        end;
      end;
    finally
      JData.Free;
    end;
  except
    // Mantém fallback
  end;
end;

end.
