unit assistant_integration_server;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, SyncObjs, fpjson, WinSock2, assistant_integration_protocol;
type
  TIntegrationRequestEvent=procedure(Sender:TObject;Request:TJSONObject;out Response:TJSONObject) of object;
  TAssistantIntegrationServer=class(TThread)
  private
    FConfig:TIntegrationConfig;
    FSocket:TSocket;
    FLock:TCriticalSection;
    FPending,FReply:UTF8String;
    FPendingReady,FReplyReady:Boolean;
    FSequence:QWord;
    FOnRequest:TIntegrationRequestEvent;
    FStartedNetwork:Boolean;
    function DispatchToHost(const Request:UTF8String):UTF8String;
    procedure HandleClient(Client:TSocket;const IP:string);
  protected
    procedure Execute;override;
  public
    constructor Create(const Config:TIntegrationConfig);
    destructor Destroy;override;
    procedure Pump;
    property OnRequest:TIntegrationRequestEvent read FOnRequest write FOnRequest;
  end;
implementation
uses assistant_integration_net;
constructor TAssistantIntegrationServer.Create(const Config:TIntegrationConfig);
var Error:string;Address:TSockAddrIn;IP:LongWord;
begin
  inherited Create(True);FreeOnTerminate:=False;FSocket:=INVALID_SOCKET;
  FLock:=TCriticalSection.Create;FConfig:=Config;
  if not ValidateIntegrationConfig(Config,Error) then raise Exception.Create(Error);
  IntegrationNetworkStart;FStartedNetwork:=True;
  FSocket:=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
  if FSocket=INVALID_SOCKET then raise Exception.Create('Falha ao criar socket');
  if not IntegrationNonBlocking(FSocket) then raise Exception.Create('Falha ao configurar socket');
  ParseIPv4(Config.BindIP,IP);FillChar(Address,SizeOf(Address),0);
  Address.sin_family:=AF_INET;Address.sin_port:=htons(Config.Port);Address.sin_addr.s_addr:=htonl(IP);
  if bind(FSocket,Address,SizeOf(Address))<>0 then raise Exception.Create('Endereco/porta de integracao indisponivel');
  if listen(FSocket,8)<>0 then raise Exception.Create('Falha ao escutar integracao');
end;
destructor TAssistantIntegrationServer.Destroy;
begin
  Terminate;
  if not Suspended then WaitFor;
  if FSocket<>INVALID_SOCKET then closesocket(FSocket);
  if FStartedNetwork then IntegrationNetworkStop;
  FLock.Free;FConfig.Token:='';inherited;
end;
function TAssistantIntegrationServer.DispatchToHost(const Request:UTF8String):UTF8String;
var Deadline:QWord;Done:Boolean;
begin
  FLock.Acquire;
  try Inc(FSequence);FPending:=Request;FPendingReady:=True;FReplyReady:=False;finally FLock.Release;end;
  Deadline:=GetTickCount64+10000;Result:='';
  while not Terminated and (GetTickCount64<Deadline) do begin
    FLock.Acquire;
    try Done:=FReplyReady;if Done then Result:=FReply;finally FLock.Release;end;
    if Done then Exit;Sleep(10);
  end;
  FLock.Acquire;try FPendingReady:=False;finally FLock.Release;end;
  with IntegrationError('dispatch_timeout') do try Result:=AsJSON;finally Free;end;
end;
procedure TAssistantIntegrationServer.Pump;
var Text:UTF8String;Request,Response:TJSONObject;Sequence:QWord;
begin
  // Called only by the LCL timer (or a console host's main loop). No
  // Synchronize/WaitFor dependency during shutdown or a modal settings form.
  FLock.Acquire;
  try if not FPendingReady then Exit;Text:=FPending;FPendingReady:=False;Sequence:=FSequence;
  finally FLock.Release;end;
  Request:=nil;Response:=nil;
  try
    if ParseIntegrationRequest(Text,Request) and Assigned(FOnRequest) then
      try FOnRequest(Self,Request,Response);except FreeAndNil(Response);Response:=IntegrationError('internal_error');end;
    if Response=nil then Response:=IntegrationError('unavailable');
    Text:=Response.AsJSON;
    if Length(Text)>IntegrationResponseLimit then begin Response.Free;Response:=IntegrationError('response_too_large');Text:=Response.AsJSON;end;
  finally Request.Free;Response.Free;end;
  FLock.Acquire;try if FSequence=Sequence then begin FReply:=Text;FReplyReady:=True;end;finally FLock.Release;end;
end;
procedure TAssistantIntegrationServer.HandleClient(Client:TSocket;const IP:string);
var Text,Reply:RawByteString;Decoded:UTF8String;Request,Error:TJSONObject;
begin
  Request:=nil;Error:=nil;
  try
    if not IntegrationIPAllowed(IP,FConfig.AllowedIPs) then Error:=IntegrationError('ip_not_allowed')
    else if not IntegrationReceive(Client,IntegrationRequestLimit,GetTickCount64+3000,Text) then Error:=IntegrationError('invalid_frame')
    else if not ParseIntegrationRequest(DecodeIntegrationBytes(Text),Request) then Error:=IntegrationError('invalid_request')
    else if not SecureTokenEqual(IntegrationString(Request,'token'),FConfig.Token) then Error:=IntegrationError('unauthorized');
    if Error<>nil then Reply:=Error.AsJSON
    else begin Request.Delete('token');Reply:=DispatchToHost(Request.AsJSON);end;
    if not Terminated then IntegrationSend(Client,Reply+#10,GetTickCount64+1000);
  finally Error.Free;Request.Free;end;
end;
procedure TAssistantIntegrationServer.Execute;
var Peer:TSockAddrIn;Size:Integer;Client:TSocket;IP:LongWord;Text:string;
begin
  while not Terminated do begin
    if not IntegrationWait(FSocket,False,100) then Continue;
    Size:=SizeOf(Peer);Client:=accept(FSocket,@Peer,@Size);
    if Client=INVALID_SOCKET then Continue;
    try
      if not IntegrationNonBlocking(Client) then Continue;
      IP:=ntohl(Peer.sin_addr.s_addr);
      Text:=Format('%d.%d.%d.%d',[IP shr 24,(IP shr 16) and 255,(IP shr 8) and 255,IP and 255]);
      HandleClient(Client,Text);
    finally closesocket(Client);end;
  end;
end;
end.
