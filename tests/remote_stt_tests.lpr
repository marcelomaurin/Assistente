program remote_stt_tests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, Sockets, remote_stt_server;
type
  TReceiver=class
    Count: Integer;
    Text: string;
    procedure Received(Sender: TObject; const AText: string);
  end;
var Server: TRemoteSTTServer; Receiver: TReceiver; Client: LongInt;
  Address: TInetSockAddr; Started: QWord; Payload: RawByteString;
procedure Check(B: Boolean; const Msg: string);
begin if not B then raise Exception.Create(Msg);end;
procedure TReceiver.Received(Sender: TObject; const AText: string);
begin
  Check(GetCurrentThreadID=MainThreadID,'Callback did not run on main thread');
  Inc(Count);Text:=AText;
end;
function ConnectClient: LongInt;
var Deadline: QWord;
begin
  Deadline:=GetTickCount64+3000;
  repeat
    Result:=fpSocket(AF_INET,SOCK_STREAM,0);
    Check(Result>=0,'Socket creation failed');
    if fpConnect(Result,@Address,SizeOf(Address))=0 then Exit;
    CloseSocket(Result);Sleep(10);
  until GetTickCount64>Deadline;
  raise Exception.Create('Server did not accept local connection');
end;
procedure SendText(const Text: RawByteString);
var Sent,N: Integer;
begin
  Client:=ConnectClient;Sent:=0;
  try
    while Sent<Length(Text) do
    begin
      N:=fpSend(Client,@Text[Sent+1],Length(Text)-Sent,0);
      Check(N>0,'Send failed');Inc(Sent,N);
    end;
  finally CloseSocket(Client);end;
end;
procedure WaitCount(Expected: Integer);
begin
  Started:=GetTickCount64;
  while (Receiver.Count<Expected) and (GetTickCount64-Started<3000) do CheckSynchronize(10);
  Check(Receiver.Count=Expected,'Unexpected delivered message count');
end;
begin
  FillChar(Address,SizeOf(Address),0);Address.sin_family:=AF_INET;
  Address.sin_port:=htons(20000+(GetTickCount64 mod 20000));
  Address.sin_addr:=StrToNetAddr('127.0.0.1');
  Receiver:=TReceiver.Create;
  Server:=TRemoteSTTServer.Create(ntohs(Address.sin_port));
  Server.OnText:=@Receiver.Received;Server.Start;
  try
    SendText('  Olá professor!  '+#10);WaitCount(1);
    Check(Receiver.Text='Olá professor!','UTF-8 text or trim changed');
    Payload:=StringOfChar('x',4097)+#10;SendText(Payload);
    SendText('Segunda pergunta'+#10);WaitCount(2);
    Check(Receiver.Text='Segunda pergunta','Did not recover after oversized text');
    Client:=ConnectClient;
    try
      Sleep(150);Started:=GetTickCount64;Server.Stop;
      Check(GetTickCount64-Started<1000,'Shutdown blocked on silent client');
    finally CloseSocket(Client);end;
    WriteLn('PASS: remote UTF-8 text on main thread, oversized rejection, recovery, shutdown with silent client');
  finally Server.Free;Receiver.Free;end;
end.
