program integration_settings_check;
{$mode objfpc}{$H+}
uses Interfaces,Forms,SysUtils,Classes,Graphics,StdCtrls,Controls,frmconfig,setmain,
  professor_settings,assistant_integration_protocol;
var F:TfrmConfig;C:TSetMain;Config:TIntegrationConfig;Error,Previous:string;I:Integer;Image:TBitmap;
procedure Check(Value:Boolean;const Message:string);
begin if not Value then raise Exception.Create(Message);end;
begin
  Application.Initialize;C:=TSetMain.Create;F:=TfrmConfig.Create(nil);
  try
    LoadProfessorSettings(F,C);
    Check(F.IntegrationUI.Read(Config,Error) and not Config.Enabled,'Default must be disabled');
    F.IntegrationUI.Enabled.Checked:=True;
    Check(not F.IntegrationUI.Read(Config,Error),'Empty token accepted');
    for I:=0 to F.IntegrationUI.ComponentCount-1 do
      if F.IntegrationUI.Components[I] is TButton then TButton(F.IntegrationUI.Components[I]).Click;
    Check(ValidIntegrationToken(F.IntegrationUI.Token.Text),'Generate button did not create token');
    Previous:=F.IntegrationUI.Token.Text;
    for I:=0 to F.IntegrationUI.ComponentCount-1 do
      if F.IntegrationUI.Components[I] is TButton then TButton(F.IntegrationUI.Components[I]).Click;
    Check(F.IntegrationUI.Token.Text<>Previous,'Generator repeated token');
    Check(F.IntegrationUI.Token.EchoMode=emPassword,'Token displayed by default');
    F.IntegrationUI.Allowed.Text:='*';Check(not F.IntegrationUI.Read(Config,Error),'Wildcard accepted');
    F.IntegrationUI.Allowed.Text:='127.0.0.1'+LineEnding+'192.0.2.10';
    Check(F.IntegrationUI.Read(Config,Error),'Valid configuration rejected');
    SaveProfessorSettings(F,C);Check(C.Integration.Token=Config.Token,'Settings roundtrip lost token');
    Check(C.Integration.AllowedIPs='127.0.0.1;192.0.2.10','Settings roundtrip lost whitelist');
    F.IntegrationUI.Token.Text:='TOKEN DE DEMONSTRACAO';
    F.pcConfig.ActivePage:=F.IntegrationUI.Page;F.Show;Application.ProcessMessages;
    Check(F.IntegrationUI.Address.Left+F.IntegrationUI.Address.Width<=F.IntegrationUI.Address.Parent.ClientWidth,'Integration field exceeds form width');
    Check(F.IntegrationUI.Status.Parent.ClientHeight>0,'Integration scroll container missing');
    Image:=F.GetFormImage;
    try Image.SaveToFile(ExtractFilePath(ParamStr(0))+'integration-settings.bmp');finally Image.Free;end;
    WriteLn('PASS: configuration defaults, random token generation/masking, whitelist validation, load/save roundtrip and native tab layout');
    F.Close;
  finally F.Free;C.Free;end;
end.
