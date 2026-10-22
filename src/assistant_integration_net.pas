unit assistant_integration_net;
{$mode objfpc}{$H+}
interface
uses SysUtils, WinSock2;
procedure IntegrationNetworkStart;
procedure IntegrationNetworkStop;
function IntegrationNonBlocking(S:TSocket):Boolean;
function IntegrationWait(S:TSocket;Writing:Boolean;Timeout:Integer):Boolean;
function IntegrationConnect(const IP:string;Port:Word;Timeout:Integer):TSocket;
function IntegrationSend(S:TSocket;const Data:RawByteString;Deadline:QWord):Boolean;
function IntegrationReceive(S:TSocket;Limit:Integer;Deadline:QWord;out Data:RawByteString):Boolean;
implementation
uses assistant_integration_protocol;
procedure IntegrationNetworkStart;
var Data:TWSAData;
begin if WSAStartup($0202,Data)<>0 then raise Exception.Create('Winsock indisponivel');end;
procedure IntegrationNetworkStop;
begin WSACleanup;end;
function IntegrationNonBlocking(S:TSocket):Boolean;
var Mode:u_long;
begin Mode:=1;Result:=ioctlsocket(S,LongInt(FIONBIO),Mode)=0;end;
function IntegrationWait(S:TSocket;Writing:Boolean;Timeout:Integer):Boolean;
var Ready:TFDSet;Wait:TTimeVal;
begin
  FD_ZERO(Ready);FD_SET(S,Ready);Wait.tv_sec:=Timeout div 1000;Wait.tv_usec:=(Timeout mod 1000)*1000;
  if Writing then Result:=select(0,nil,@Ready,nil,@Wait)>0
  else Result:=select(0,@Ready,nil,nil,@Wait)>0;
end;
function IntegrationConnect(const IP:string;Port:Word;Timeout:Integer):TSocket;
var Address:TSockAddrIn;Value:Integer;Len:Integer;Parsed:LongWord;
begin
  Result:=INVALID_SOCKET;
  if not ParseIPv4(IP,Parsed) then Exit;
  Result:=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
  if Result=INVALID_SOCKET then Exit;
  if not IntegrationNonBlocking(Result) then begin closesocket(Result);Exit(INVALID_SOCKET);end;
  FillChar(Address,SizeOf(Address),0);Address.sin_family:=AF_INET;Address.sin_port:=htons(Port);Address.sin_addr.s_addr:=htonl(Parsed);
  if connect(Result,Address,SizeOf(Address))=0 then Exit;
  if (WSAGetLastError=WSAEWOULDBLOCK) and IntegrationWait(Result,True,Timeout) then
  begin
    Len:=SizeOf(Value);Value:=-1;
    if (getsockopt(Result,SOL_SOCKET,SO_ERROR,PChar(@Value),Len)=0) and (Value=0) then Exit;
  end;
  closesocket(Result);Result:=INVALID_SOCKET;
end;
function IntegrationSend(S:TSocket;const Data:RawByteString;Deadline:QWord):Boolean;
var Offset,N:Integer;
begin
  Offset:=1;Result:=False;
  while (Offset<=Length(Data)) and (GetTickCount64<Deadline) do
  begin
    if not IntegrationWait(S,True,50) then Continue;
    N:=send(S,Data[Offset],Length(Data)-Offset+1,0);
    if N>0 then Inc(Offset,N)
    else if (N=0) or (WSAGetLastError<>WSAEWOULDBLOCK) then Exit;
  end;
  Result:=Offset>Length(Data);
end;
function IntegrationReceive(S:TSocket;Limit:Integer;Deadline:QWord;out Data:RawByteString):Boolean;
var Buf:array[0..1023] of Char;N,I:Integer;
begin
  Result:=False;Data:='';
  while GetTickCount64<Deadline do
  begin
    if not IntegrationWait(S,False,50) then Continue;
    N:=recv(S,Buf,SizeOf(Buf),0);
    if N<=0 then begin if (N<0) and (WSAGetLastError=WSAEWOULDBLOCK) then Continue;Exit;end;
    for I:=0 to N-1 do begin
      if Buf[I]=#10 then Exit(True);
      if (Buf[I]=#0) or (Length(Data)>=Limit) then Exit;
      Data:=Data+Buf[I];
    end;
  end;
end;
end.
