program integration_dll_probe;
{$mode objfpc}{$H+}{$codepage utf8}
uses SysUtils,Dynlibs,assistant_integration_protocol;
type TVersion=function:LongWord;cdecl;
     TRequest=function(Host:PAnsiChar;Port:Word;Token,Request:PAnsiChar;Output:PAnsiChar;Capacity:LongWord;Required:PLongWord):LongInt;cdecl;
var Lib:TLibHandle;Version:TVersion;Request:TRequest;Buffer:AnsiString;Needed:LongWord;Code:LongInt;Token,Query:UTF8String;
begin
  Lib:=LoadLibrary(ExpandFileName(ParamStr(1)));if Lib=NilHandle then Halt(2);
  try
    Pointer(Version):=GetProcedureAddress(Lib,'AssistenteApiVersion');Pointer(Request):=GetProcedureAddress(Lib,'AssistenteRequestV1');
    if not Assigned(Version) or not Assigned(Request) or (Version()<>$10000) then Halt(3);
    Token:=GetEnvironmentVariable('ASSISTENTE_INTEGRATION_TOKEN');Query:='{"v":1,"action":"dll_probe","text":"Olá 世界"}';
    Code:=Request('127.0.0.1',StrToInt(ParamStr(2)),PAnsiChar(Token),PAnsiChar(Query),nil,0,@Needed);
    if (Code<>1) or (Needed<>IntegrationBufferBytes) then Halt(4);
    SetLength(Buffer,IntegrationBufferBytes);
    Code:=Request('127.0.0.1',StrToInt(ParamStr(2)),PAnsiChar(Token),PAnsiChar(Query),PAnsiChar(Buffer),Length(Buffer),@Needed);
    if Code<>0 then Halt(5);
    WriteLn(PAnsiChar(Buffer));
  finally UnloadLibrary(Lib);end;
end.
