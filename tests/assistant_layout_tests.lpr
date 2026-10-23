program assistant_layout_tests;
{$mode objfpc}{$H+}{$codepage utf8}
uses Interfaces, Forms, Classes, SysUtils, Windows, ExtCtrls, StdCtrls, Graphics,
  Math, Types, Controls, main, professor_view, professor_ui, movement_catalog,
  CastleControl, CastleImages, CastleURIUtils;
type TRunner=class(TComponent)
public
  Timer:TTimer;View:TProfessorView;Control:TCastleControl;Selector:TComboBox;Index:Integer;OutDir:string;
  constructor Create(AOwner:TComponent);override;
  procedure Tick(Sender:TObject);
end;
var Runner:TRunner;Config:TStringList;Directory:string;
procedure Check(Value:Boolean;const Message:string);
begin if not Value then raise Exception.Create(Message);end;
constructor TRunner.Create(AOwner:TComponent);
var I:Integer;
begin
  inherited;OutDir:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));ForceDirectories(OutDir);
  for I:=0 to frmmain.ComponentCount-1 do begin
    if frmmain.Components[I] is TProfessorView then View:=TProfessorView(frmmain.Components[I]);
    if (frmmain.Components[I] is TComboBox) and (frmmain.Components[I].Name='MovementSelector') then Selector:=TComboBox(frmmain.Components[I]);
    if frmmain.Components[I] is TConversationView then begin
      TConversationView(frmmain.Components[I]).AddMessage('Quero testar os novos movimentos do avatar.',True);
      TConversationView(frmmain.Components[I]).AddMessage('Escolha um gesto na biblioteca. Os movimentos são compartilhados com o Editor de Apresentações.',False);
    end;
  end;
  Check((View<>nil) and (Selector<>nil),'Missing avatar or JSON movement selector');
  Check(Selector.Items.Count=MovementCount,'Assistant movement selector differs from JSON');
  for I:=0 to View.ComponentCount-1 do if View.Components[I] is TCastleControl then Control:=TCastleControl(View.Components[I]);
  Timer:=TTimer.Create(Self);Timer.Interval:=1000;Timer.OnTimer:=@Tick;
end;
procedure TRunner.Tick(Sender:TObject);
var Shot:TRGBImage;Frame:TBitmap;Picture:TPicture;Origin:TPoint;WidthValue,J:Integer;Chat:TConversationView;Card:TControl;
begin
  Timer.Enabled:=False;
  try
    if Index=0 then begin frmmain.Width:=1180;frmmain.Height:=780;end
    else begin frmmain.Width:=960;frmmain.Height:=680;end;
    Frame:=frmmain.GetFormImage;Frame.Free;
    frmmain.Realign;frmmain.pnlRoot.Realign;Application.ProcessMessages;frmmain.OnResize(nil);
    Check(frmmain.btConfig.Left+frmmain.btConfig.Width<=frmmain.ClientWidth,'Settings button clipped '+IntToStr(frmmain.btConfig.Left+frmmain.btConfig.Width)+' / '+IntToStr(frmmain.pnlHeader.ClientWidth));
    Check(frmmain.edPergunta.Width>200,'Composer collapsed');
    Card:=frmmain.edPergunta.Parent;
    Check(Card.Top+Card.Height<=Card.Parent.Height,'Composer extends below chat panel');
    for J:=0 to frmmain.ComponentCount-1 do if frmmain.Components[J] is TConversationView then begin
      Chat:=TConversationView(frmmain.Components[J]);
      if Chat.ControlCount>0 then Check(Chat.Controls[0].Left+Chat.Controls[0].Width<=Chat.Width,'Conversation card clipped after resize');
    end;
    Check(Selector.Left>=0,'Movement selector outside avatar');
    if ParamStr(2)='--hidden-layout' then begin
      Inc(Index);
      if Index=2 then begin WriteLn('PASS: hidden 1180/960 layout, composer inside chat, conversation cards reflowed and JSON selector');Application.Terminate;end
      else Timer.Enabled:=True;Exit;
    end;
    Shot:=Control.Container.SaveScreen;
    try SaveImage(Shot,FilenameToURISafe(OutDir+'avatar.png'));finally Shot.Free;end;
    Frame:=frmmain.GetFormImage;Picture:=TPicture.Create;
    try
      Picture.LoadFromFile(OutDir+'avatar.png');Origin:=frmmain.ScreenToClient(Control.ClientToScreen(Point(0,0)));
      Frame.Canvas.Draw(Origin.X,Origin.Y,Picture.Graphic);
      WidthValue:=frmmain.Width;Frame.SaveToFile(OutDir+'assistente-'+IntToStr(WidthValue)+'.bmp');
    finally Picture.Free;Frame.Free;end;
    Inc(Index);
    if Index=2 then begin WriteLn('PASS: Assistant at 1180/960, visible settings/composer, native avatar, conversation and shared movement selector');Application.Terminate;end
    else Timer.Enabled:=True;
  except on E:Exception do begin WriteLn('FAIL: '+E.Message);ExitCode:=1;Application.Terminate;end;end;
end;
begin
  Directory:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)))+'isolated-config';ForceDirectories(Directory);
  SetEnvironmentVariable(PChar('ASSISTENTE_CONFIG_DIR'),PChar(Directory));Config:=TStringList.Create;
  try
    Config.Add('CONTINUOUS_LISTENING:0');Config.Add('AUTOSPEAK:0');Config.Add('VISION_SOURCE:none');
    Config.Add('AVATAR3D_PROFILE:professor');Config.Add('AVATAR3D_AUTO_IDLE:1');Config.SaveToFile(Directory+PathDelim+'Setmain.cfg');
  finally Config.Free;end;
  RequireDerivedFormResource:=True;Application.Initialize;Application.CreateForm(Tfrmmain,frmmain);
  if ParamStr(2)='--hidden-layout' then Application.ShowMainForm:=False else frmmain.Show;Runner:=TRunner.Create(frmmain);Application.Run;frmmain.Free;
end.
