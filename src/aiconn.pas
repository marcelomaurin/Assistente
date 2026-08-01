unit aiconn;

{ Wrapper de conveniência sobre o TAISocketTCP (unit aisockets.pas, vendo
  do AI Component Suite - https://github.com/marcelomaurin/CHATGPT).

  TAISocketTCP, como a suíte fornece, só despacha OnDataReceived sozinho
  quando está em modo servidor (Mode = smServer), porque ali usa uma thread
  dedicada para aceitar conexões. Em modo cliente ele só expõe métodos
  síncronos (Connect / SendText / ReceiveText) para chamada manual.

  ToolsFalar, ToolsOuvir e ToolsVer precisam continuar recebendo mensagens
  empurradas pelo serviço externo (voz/visão) a qualquer momento, sem travar
  a interface - exatamente o que o TLTCPComponent (lNet) fazia antes. Por
  isso o TAIConnClient roda uma thread própria bloqueada em ReceiveText e
  repassa cada mensagem recebida para a thread principal via Synchronize,
  mantendo o mesmo comportamento assíncrono de antes, mas usando o socket da
  suíte no lugar do componente de terceiros. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, aisockets;

type
  TAIConnDataEvent = procedure(Sender: TObject; const AData: string) of object;
  TAIConnNotifyEvent = procedure(Sender: TObject) of object;

  { TAIConnReceiverThread }

  TAIConnReceiverThread = class(TThread)
  private
    FSocket: TAISocketTCP;
    FOwnerComp: TComponent;
    FOnDataReceived: TAIConnDataEvent;
    FOnDisconnected: TAIConnNotifyEvent;
    FPendingData: string;
    procedure DoDataReceived;
    procedure DoDisconnected;
  protected
    procedure Execute; override;
  public
    constructor Create(ASocket: TAISocketTCP; AOwnerComp: TComponent;
      AOnDataReceived: TAIConnDataEvent; AOnDisconnected: TAIConnNotifyEvent);
  end;

  { TAIConnClient }

  TAIConnClient = class(TComponent)
  private
    FSocket: TAISocketTCP;
    FReceiver: TAIConnReceiverThread;
    FHost: string;
    FPort: Integer;
    FOnDataReceived: TAIConnDataEvent;
    FOnDisconnected: TAIConnNotifyEvent;
    function GetConnected: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Connect(const AHost: string; APort: Integer): Boolean;
    procedure Disconnect;
    function SendText(const AText: string): Boolean;
    property Connected: Boolean read GetConnected;
    property Host: string read FHost;
    property Port: Integer read FPort;
    property OnDataReceived: TAIConnDataEvent read FOnDataReceived write FOnDataReceived;
    property OnDisconnected: TAIConnNotifyEvent read FOnDisconnected write FOnDisconnected;
  end;

implementation

{ TAIConnReceiverThread }

constructor TAIConnReceiverThread.Create(ASocket: TAISocketTCP;
  AOwnerComp: TComponent; AOnDataReceived: TAIConnDataEvent;
  AOnDisconnected: TAIConnNotifyEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FSocket := ASocket;
  FOwnerComp := AOwnerComp;
  FOnDataReceived := AOnDataReceived;
  FOnDisconnected := AOnDisconnected;
end;

procedure TAIConnReceiverThread.DoDataReceived;
begin
  if Assigned(FOnDataReceived) then
    FOnDataReceived(FOwnerComp, FPendingData);
end;

procedure TAIConnReceiverThread.DoDisconnected;
begin
  if Assigned(FOnDisconnected) then
    FOnDisconnected(FOwnerComp);
end;

procedure TAIConnReceiverThread.Execute;
var
  Texto: string;
begin
  while not Terminated do
  begin
    if not FSocket.ReceiveText(Texto) then
      Break; // socket fechado ou erro de leitura -> encerra a thread

    if Terminated then
      Break;

    if Texto <> '' then
    begin
      FPendingData := Texto;
      Synchronize(@DoDataReceived);
    end;
  end;

  // Só notifica "desconectado" quando a queda não foi pedida por nós mesmos
  // (Disconnect já marca Terminated antes de fechar o socket).
  if not Terminated then
    Synchronize(@DoDisconnected);
end;

{ TAIConnClient }

constructor TAIConnClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSocket := TAISocketTCP.Create(nil);
  FSocket.Mode := smClient;
  FReceiver := nil;
  FHost := '127.0.0.1';
  FPort := 9000;
end;

destructor TAIConnClient.Destroy;
begin
  Disconnect;
  FSocket.Free;
  inherited Destroy;
end;

function TAIConnClient.GetConnected: Boolean;
begin
  Result := Assigned(FSocket) and FSocket.Active;
end;

function TAIConnClient.Connect(const AHost: string; APort: Integer): Boolean;
begin
  Disconnect; // garante que não sobra thread/socket de uma conexão anterior

  FHost := AHost;
  FPort := APort;
  FSocket.Host := AHost;
  FSocket.Port := APort;

  Result := FSocket.Connect;
  if Result then
  begin
    FReceiver := TAIConnReceiverThread.Create(FSocket, Self, FOnDataReceived, FOnDisconnected);
    FReceiver.Start;
  end;
end;

procedure TAIConnClient.Disconnect;
begin
  if Assigned(FReceiver) then
  begin
    FReceiver.Terminate;
    FSocket.Disconnect; // fecha o socket para destravar o ReceiveText da thread
    FReceiver.WaitFor;
    FreeAndNil(FReceiver);
  end
  else
    FSocket.Disconnect;
end;

function TAIConnClient.SendText(const AText: string): Boolean;
begin
  Result := Assigned(FSocket) and FSocket.SendText(AText);
end;

end.
