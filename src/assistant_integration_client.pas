unit assistant_integration_client;
{$mode objfpc}{$H+}
interface
uses assistant_integration_protocol;
function AssistantIntegrationRequest(const Host:string;Port:Word;const Token:string;const Request:UTF8String;out Response:UTF8String):Boolean;
implementation
uses SysUtils, fpjson, jsonparser, WinSock2, assistant_integration_net;
function AssistantIntegrationRequest(const Host:string;Port:Word;const Token:string;const Request:UTF8String;out Response:UTF8String):Boolean;
var O:TJSONObject;S:TSocket;Data:RawByteString;IP:LongWord;D:TJSONData;
begin
  Result:=False;Response:='';
  if (Port=0) or not ParseIPv4(Host,IP) or not ValidIntegrationToken(Token) or not ParseIntegrationRequest(Request,O) then Exit;
  try
    if O.Find('token')<>nil then Exit;
    O.Add('token',Token);Data:=O.AsJSON+#10;
    if Length(Data)>IntegrationRequestLimit then Exit;
  finally O.Free;end;
  IntegrationNetworkStart;
  try
    S:=IntegrationConnect(Host,Port,3000);if S=INVALID_SOCKET then Exit;
    try
      if not IntegrationSend(S,Data,GetTickCount64+3000) then Exit;
      if not IntegrationReceive(S,IntegrationResponseLimit,GetTickCount64+15000,Data) then Exit;
      D:=nil;
      try
        if not IsValidUTF8(DecodeIntegrationBytes(Data)) then Exit;
        try D:=StrictIntegrationJSON(DecodeIntegrationBytes(Data));except Exit;end;
        if not (D is TJSONObject) then Exit;
        O:=TJSONObject(D);
        if (O.Find('v')=nil) or (O.Find('v').AsJSON<>'1') or
          (O.Find('ok')=nil) or (O.Find('ok').JSONType<>jtBoolean) then Exit;
        Response:=DecodeIntegrationBytes(Data);Result:=True;
      finally D.Free;end;
    finally closesocket(S);end;
  finally IntegrationNetworkStop;end;
end;
end.
