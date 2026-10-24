unit movement_preview;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes,SysUtils,Forms,Controls,StdCtrls,ExtCtrls,Graphics,professor_view,
  professor_catalog,presentation_joints;
procedure ShowMovementPreview(const AssistantPath,MovementID:string);
implementation
type
  TMovementPreview=class(TForm)
  private
    FCatalog:TAvatarCatalog;FView:TProfessorView;FPanel:TPanel;FStatus:TLabel;
    FAvatars,FSpeed:TComboBox;FPlay:TButton;FTimer:TTimer;FID:string;FPaused:Boolean;
    procedure Restart(Sender:TObject);
    procedure Toggle(Sender:TObject);
    procedure SpeedChanged(Sender:TObject);
    procedure Tick(Sender:TObject);
  public
    constructor CreatePreview(const AssistantPath,MovementID:string);
    destructor Destroy;override;
  end;
constructor TMovementPreview.CreatePreview(const AssistantPath,MovementID:string);
var Header,Footer:TPanel;B:TButton;I:Integer;
begin
  inherited CreateNew(nil);FID:=MovementID;Caption:='Prévia do movimento — JSON';
  Position:=poScreenCenter;SetBounds(100,70,780,760);Font.Name:='Segoe UI';Font.Size:=10;Color:=clWhite;
  Header:=TPanel.Create(Self);Header.Parent:=Self;Header.Align:=alTop;Header.Height:=52;Header.BevelOuter:=bvNone;
  FAvatars:=TComboBox.Create(Self);FAvatars.Parent:=Header;FAvatars.Style:=csDropDownList;FAvatars.SetBounds(12,12,210,28);FAvatars.OnChange:=@Restart;
  FSpeed:=TComboBox.Create(Self);FSpeed.Parent:=Header;FSpeed.Style:=csDropDownList;FSpeed.SetBounds(234,12,95,28);
  FSpeed.Items.Add('25%');FSpeed.Items.Add('50%');FSpeed.Items.Add('100%');FSpeed.ItemIndex:=2;FSpeed.OnChange:=@SpeedChanged;
  B:=TButton.Create(Self);B.Parent:=Header;B.Caption:='Reiniciar';B.SetBounds(340,10,100,32);B.OnClick:=@Restart;
  FPlay:=TButton.Create(Self);FPlay.Parent:=Header;FPlay.Caption:='Pausar';FPlay.SetBounds(450,10,100,32);FPlay.OnClick:=@Toggle;
  B:=TButton.Create(Self);B.Parent:=Header;B.Caption:='Fechar';B.SetBounds(560,10,100,32);B.ModalResult:=mrClose;
  Footer:=TPanel.Create(Self);Footer.Parent:=Self;Footer.Align:=alBottom;Footer.Height:=72;Footer.BevelOuter:=bvNone;
  FStatus:=TLabel.Create(Self);FStatus.Parent:=Footer;FStatus.Align:=alClient;FStatus.BorderSpacing.Around:=12;FStatus.WordWrap:=True;
  FPanel:=TPanel.Create(Self);FPanel.Parent:=Self;FPanel.Align:=alClient;FPanel.BevelOuter:=bvNone;
  FCatalog:=TAvatarCatalog.Create(ExtractFilePath(AssistantPath)+'AVATARES');
  for I:=0 to FCatalog.Count-1 do FAvatars.Items.Add(FCatalog[I].Name);
  if FCatalog.Count=0 then raise Exception.Create('Avatares nao encontrados junto do Assistente');
  FAvatars.ItemIndex:=FCatalog.IndexOfID('professor');if FAvatars.ItemIndex<0 then FAvatars.ItemIndex:=0;
  FView:=TProfessorView.Create(Self,FPanel);FTimer:=TTimer.Create(Self);FTimer.Interval:=50;FTimer.OnTimer:=@Tick;
  Restart(nil);
end;
destructor TMovementPreview.Destroy;
begin
  if FTimer<>nil then FTimer.Enabled:=False;FreeAndNil(FView);FreeAndNil(FCatalog);inherited;
end;
procedure TMovementPreview.Restart(Sender:TObject);
begin
  if FView=nil then Exit;
  try
  if not FView.LoadModel(FCatalog[FAvatars.ItemIndex].ModelFile,True) then raise Exception.Create(FView.Diagnostic);
  FPaused:=False;FView.SetRenderingActive(True);TPresentationScene(FView.Scene).PauseJoints(False);FPlay.Caption:='Pausar';
  SpeedChanged(nil);
  if not FView.ExecuteMovement(FID) then FStatus.Caption:='Nao foi possivel executar o movimento. Confira o avatar e o JSON.';
  except on E:Exception do begin FStatus.Font.Color:=clRed;FStatus.Caption:=E.Message;end;end;
end;
procedure TMovementPreview.Toggle(Sender:TObject);
begin
  FPaused:=not FPaused;TPresentationScene(FView.Scene).PauseJoints(FPaused);FView.SetRenderingActive(not FPaused);
  if FPaused then FPlay.Caption:='Continuar' else FPlay.Caption:='Pausar';
end;
procedure TMovementPreview.SpeedChanged(Sender:TObject);
begin
  if FView=nil then Exit;
  case FSpeed.ItemIndex of 0:FView.Scene.TimePlayingSpeed:=0.25;1:FView.Scene.TimePlayingSpeed:=0.5;else FView.Scene.TimePlayingSpeed:=1;end;
end;
procedure TMovementPreview.Tick(Sender:TObject);
var Scene:TPresentationScene;Blocked:string;
begin
  Scene:=TPresentationScene(FView.Scene);Blocked:=Scene.MovementBlocked;
  if Blocked<>'' then begin FStatus.Font.Color:=clRed;FStatus.Caption:='Parado antes do contato: '+Blocked+'. Ajuste os pontos intermediarios do JSON para contornar essa regiao.';end
  else begin FStatus.Font.Color:=clWindowText;FStatus.Caption:='Movimento definido no JSON. Use 25% para conferir o percurso; pausas preservam a posicao. '+FView.ActivityLabel;end;
end;
procedure ShowMovementPreview(const AssistantPath,MovementID:string);
var Preview:TMovementPreview;
begin Preview:=TMovementPreview.CreatePreview(AssistantPath,MovementID);try Preview.ShowModal;finally Preview.Free;end;end;
end.
