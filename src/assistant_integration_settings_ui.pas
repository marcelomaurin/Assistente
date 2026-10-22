unit assistant_integration_settings_ui;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, ComCtrls, StdCtrls, Controls, Forms, assistant_integration_protocol;
type
  TIntegrationSettingsUI=class(TComponent)
  private
    procedure GenerateClick(Sender:TObject);
    procedure ShowTokenClick(Sender:TObject);
  public
    Page:TTabSheet;
    Enabled:TCheckBox;
    Address,Port,Token:TEdit;
    Allowed:TMemo;
    Status:TLabel;
    ShowToken:TCheckBox;
    constructor CreateFor(AOwner:TComponent;Pages:TPageControl);
    procedure Load(const Config:TIntegrationConfig);
    function Read(out Config:TIntegrationConfig;out Error:string):Boolean;
  end;
implementation
constructor TIntegrationSettingsUI.CreateFor(AOwner:TComponent;Pages:TPageControl);
var Button:TButton;Content:TScrollBox;
  procedure LabelAt(const Text:string;Y:Integer);
  var L:TLabel;
  begin L:=TLabel.Create(Self);L.Parent:=Content;L.Caption:=Text;L.AutoSize:=False;L.WordWrap:=True;L.SetBounds(16,Y,335,34);end;
  function EditAt(Y:Integer):TEdit;
  begin Result:=TEdit.Create(Self);Result.Parent:=Content;Result.SetBounds(16,Y,335,25);end;
begin
  inherited Create(AOwner);Page:=TTabSheet.Create(Self);Page.PageControl:=Pages;Page.Caption:='Integração externa';
  Content:=TScrollBox.Create(Self);Content.Parent:=Page;Content.Align:=alClient;Content.BorderStyle:=bsNone;Content.HorzScrollBar.Visible:=False;
  Enabled:=TCheckBox.Create(Self);Enabled.Parent:=Content;Enabled.Caption:='Permitir integração por DLL e socket';Enabled.SetBounds(16,12,335,28);
  LabelAt('Endereço IPv4 de escuta (127.0.0.1: somente este computador)',52);Address:=EditAt(88);
  LabelAt('Porta',124);Port:=EditAt(150);Port.Width:=120;
  LabelAt('Token de autenticação (somente ferramentas permitidas)',186);Token:=EditAt(222);Token.EchoMode:=emPassword;
  Button:=TButton.Create(Self);Button.Parent:=Content;Button.Caption:='Gerar novo token';Button.SetBounds(16,258,160,28);Button.OnClick:=@GenerateClick;
  ShowToken:=TCheckBox.Create(Self);ShowToken.Parent:=Content;ShowToken.Caption:='Mostrar token';ShowToken.SetBounds(188,258,150,28);ShowToken.OnClick:=@ShowTokenClick;
  LabelAt('IPs permitidos: um por linha. Inclua 127.0.0.1 para ferramentas locais.',304);
  Allowed:=TMemo.Create(Self);Allowed.Parent:=Content;Allowed.SetBounds(16,340,335,92);Allowed.ScrollBars:=ssVertical;
  LabelAt('DLL usa o mesmo acesso autenticado. TCP: utilize rede privada ou VPN.',448);
  Status:=TLabel.Create(Self);Status.Parent:=Content;Status.AutoSize:=False;Status.SetBounds(16,496,335,68);Status.WordWrap:=True;
end;
procedure TIntegrationSettingsUI.GenerateClick(Sender:TObject);
begin Token.Text:=GenerateIntegrationToken;Status.Caption:='Token alterado. Salve para aplicar e atualizar as ferramentas autorizadas.';end;
procedure TIntegrationSettingsUI.ShowTokenClick(Sender:TObject);
begin if ShowToken.Checked then Token.EchoMode:=emNormal else Token.EchoMode:=emPassword;end;
procedure TIntegrationSettingsUI.Load(const Config:TIntegrationConfig);
begin
  Enabled.Checked:=Config.Enabled;Address.Text:=Config.BindIP;Port.Text:=IntToStr(Config.Port);Token.Text:=Config.Token;
  Allowed.Text:=StringReplace(Config.AllowedIPs,';',LineEnding,[rfReplaceAll]);
  Status.Caption:='As alterações são aplicadas ao salvar. Integração desativada por padrão.';
end;
function TIntegrationSettingsUI.Read(out Config:TIntegrationConfig;out Error:string):Boolean;
begin
  Config.Enabled:=Enabled.Checked;Config.BindIP:=Trim(Address.Text);Config.Port:=StrToIntDef(Trim(Port.Text),0);
  Config.Token:=Trim(Token.Text);Config.AllowedIPs:=Trim(StringReplace(StringReplace(Allowed.Text,#13,'',[rfReplaceAll]),#10,';',[rfReplaceAll]));
  Error:='';Result:=not Config.Enabled;if not Result then Result:=ValidateIntegrationConfig(Config,Error);
end;
end.
