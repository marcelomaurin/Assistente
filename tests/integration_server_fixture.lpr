program integration_server_fixture;
{$mode objfpc}{$H+}
uses Classes,SysUtils,Windows,fpjson,assistant_integration_protocol,assistant_integration_server;
type THost=class
  Count:Integer;Done:Boolean;
  procedure Request(Sender:TObject;Q:TJSONObject;out R:TJSONObject);
end;
var Host:THost;Server:TAssistantIntegrationServer;Config:TIntegrationConfig;Deadline:QWord;
procedure THost.Request(Sender:TObject;Q:TJSONObject;out R:TJSONObject);
begin
  Inc(Count);
  if IntegrationString(Q,'action')='stop_fixture' then Done:=True;
  R:=IntegrationOK(TJSONObject.Create(['action',IntegrationString(Q,'action'),'text',IntegrationString(Q,'text'),
    'count',Count,'main_thread',GetCurrentThreadID=MainThreadID,'token_removed',Q.Find('token')=nil]));
end;
begin
  Config:=DefaultIntegrationConfig;Config.Enabled:=True;Config.Port:=StrToInt(ParamStr(1));
  Config.Token:=SysUtils.GetEnvironmentVariable('ASSISTENTE_INTEGRATION_TOKEN');Config.AllowedIPs:=ParamStr(2);
  Host:=THost.Create;Server:=TAssistantIntegrationServer.Create(Config);
  try
    Server.OnRequest:=@Host.Request;Server.Start;WriteLn('READY');Flush(Output);
    Deadline:=GetTickCount64+StrToIntDef(ParamStr(3),120000);
    while not Host.Done and (GetTickCount64<Deadline) do begin Server.Pump;Sleep(5);end;
    Sleep(100);
  finally Server.Free;Host.Free;end;
end.
