unit remote_stt_server;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Sockets;
type
  TRemoteTextEvent = procedure(Sender: TObject; const AText: string) of object;
  TRemoteSTTServer = class(TThread)
  private
    FPort: Word;
    FServer: LongInt;
    FText: string;
    FOnText: TRemoteTextEvent;
    procedure DispatchText;
  protected
    procedure Execute; override;
  public
    constructor Create(APort: Word);
    destructor Destroy; override;
    procedure Stop;
    property OnText: TRemoteTextEvent read FOnText write FOnText;
  end;
implementation
constructor TRemoteSTTServer.Create(APort: Word);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPort := APort;
  FServer := -1;
end;
destructor TRemoteSTTServer.Destroy;
begin
  Stop;
  inherited Destroy;
end;
procedure TRemoteSTTServer.Stop;
begin
  Terminate;
  { The listener is non-blocking; WaitFor finishes within the polling cycle. }
  WaitFor;
end;
procedure TRemoteSTTServer.DispatchText;
begin
  if Assigned(FOnText) then FOnText(Self, FText);
end;
procedure TRemoteSTTServer.Execute;
var
  Address, Peer: TInetSockAddr;
  PeerLen: TSockLen;
  Client, N, I: LongInt;
  Buf: array[0..1023] of Byte;
  Line: RawByteString;
  Ready: TFDSet;
  Timeout: TTimeVal;
  Deadline: QWord;
begin
  FServer := fpSocket(AF_INET, SOCK_STREAM, 0);
  if FServer < 0 then Exit;
  try
    FillChar(Address, SizeOf(Address), 0);
    Address.sin_family := AF_INET;
    Address.sin_port := htons(FPort);
    Address.sin_addr.s_addr := htonl(INADDR_ANY);
    if fpBind(FServer, @Address, SizeOf(Address)) <> 0 then Exit;
    if fpListen(FServer, 4) <> 0 then Exit;
    while not Terminated do
    begin
      fpFD_ZERO(Ready);
      fpFD_SET(FServer, Ready);
      Timeout.tv_sec := 0;
      Timeout.tv_usec := 200000;
      if fpSelect(FServer+1, @Ready, nil, nil, @Timeout) <= 0 then Continue;
      PeerLen := SizeOf(Peer);
      Client := fpAccept(FServer, @Peer, @PeerLen);
      if Client < 0 then Continue;
      try
        Line := '';
        Deadline := GetTickCount64 + 3000;
        while not Terminated and (GetTickCount64 < Deadline) and (Length(Line) <= 4096) do
        begin
          fpFD_ZERO(Ready);
          fpFD_SET(Client, Ready);
          Timeout.tv_sec := 0;
          Timeout.tv_usec := 100000;
          if fpSelect(Client+1, @Ready, nil, nil, @Timeout) <= 0 then Continue;
          N := fpRecv(Client, @Buf[0], SizeOf(Buf), 0);
          if N <= 0 then Break;
          for I := 0 to N-1 do
          begin
            if Buf[I] = 10 then Break;
            if (Buf[I] >= 32) or (Buf[I] = 9) then
              Line := Line + AnsiChar(Buf[I]);
          end;
          if (I < N) and (Buf[I] = 10) then Break;
        end;
        if (Length(Line) > 0) and (Length(Line) <= 4096) and
          (Pos(#0, Line) = 0) then
        begin
          FText := Trim(string(Line));
          if FText <> '' then Synchronize(@DispatchText);
        end;
      finally
        CloseSocket(Client);
      end;
    end;
  finally
    CloseSocket(FServer);
    FServer := -1;
  end;
end;
end.
