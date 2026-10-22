library assistente_integration;
{$mode objfpc}{$H+}
uses SysUtils, assistant_integration_protocol, assistant_integration_client;
function AssistenteApiVersion:LongWord;cdecl;
begin Result:=$00010000;end;
function BoundedString(P:PAnsiChar;Limit:LongWord;out Text:UTF8String):Boolean;
var I:LongWord;
begin
  Result:=False;Text:='';if P=nil then Exit;
  for I:=0 to Limit do if P[I]=#0 then begin SetString(Text,P,I);Exit(True);end;
end;
function AssistenteRequestV1(Host:PAnsiChar;Port:Word;Token,Request:PAnsiChar;
  Output:PAnsiChar;Capacity:LongWord;Required:PLongWord):LongInt;cdecl;
var H,T,Q,R:UTF8String;
begin
  Result:=2;
  try
    if Required=nil then Exit;
    Required^:=IntegrationBufferBytes;
    // Reject small buffers BEFORE executing the operation. No size-probe
    // roundtrip can accidentally submit a conversation or speak twice.
    if (Output=nil) or (Capacity<IntegrationBufferBytes) then Exit(1);
    Output[0]:=#0;
    if not BoundedString(Host,15,H) or not BoundedString(Token,64,T) or
      not BoundedString(Request,IntegrationRequestLimit,Q) then Exit;
    if not AssistantIntegrationRequest(H,Port,T,Q,R) then Exit(3);
    Required^:=Length(R)+1;
    if Length(R)>0 then Move(R[1],Output^,Length(R));
    Output[Length(R)]:=#0;Result:=0;
  except Result:=3;end;
end;
exports AssistenteApiVersion name 'AssistenteApiVersion',AssistenteRequestV1 name 'AssistenteRequestV1';
begin IsMultiThread:=True;end.
