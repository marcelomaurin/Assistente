program motion_editor;
{$mode objfpc}{$H+}
uses Interfaces,Forms,SysUtils,Classes,Math,Controls,StdCtrls,ExtCtrls,ComCtrls,
  Dialogs,Spin,Graphics,Types,CastleKeysMouse,CastleImages,CastleURIUtils,LCLType,multisuite_controls,multisuite_icons,CastleVectors,CastleTransform,movement_animation,movement_timeline,
  presentation_joint_tags,professor_view,presentation_joints,motion_editor_view;
type
  TEditorForm=class(TForm)
  private
    View:TProfessorView;Editor:TMotionEditorView;BoneList:TListBox;
    XYZ:array[0..2] of TFloatSpinEdit;SelectedLabel,Status:TLabel;
    NameEdit:TEdit;TimeEdit,DurationEdit:TSpinEdit;Timeline:TTrackBar;
    ViewBox,ProjectionBox:TComboBox;Compass:TPaintBox;
    Tick:TTimer;Motion:TMotionAnimation;Path:string;FUpdating:Boolean;
    procedure LayoutMembers(Sender:TObject);
    procedure SetStatus(const S:string);
    procedure EditorChanged(Sender:TObject);
    procedure BoneChanged(Sender:TObject);
    procedure AngleChanged(Sender:TObject);
    procedure TimeChanged(Sender:TObject);
    procedure DurationChanged(Sender:TObject);
    procedure AddKeyClick(Sender:TObject);
    procedure OpenClick(Sender:TObject);
    procedure SaveClick(Sender:TObject);
    procedure PreviewClick(Sender:TObject);
    procedure StopClick(Sender:TObject);
    procedure ResetClick(Sender:TObject);
    procedure Poll(Sender:TObject);
    procedure CameraChanged(Sender:TObject);
    procedure CameraButton(Sender:TObject);
    procedure CompassPaint(Sender:TObject);
    procedure EditorKeyDown(Sender:TObject;var Key:Word;Shift:TShiftState);
    procedure SmokeTick(Sender:TObject);
    function TrackIndex(const Bone:string):Integer;
    function Candidate:TMotionAnimation;
  public
    constructor Create(AOwner:TComponent);override;
    destructor Destroy;override;
  end;
function MemberLabel(const Bone:string):string;
var S,Side:string;I:Integer;
const Fingers:array[1..5] of string=('Polegar','Indicador','Médio','Anelar','Mínimo');
begin
  S:=Bone;Side:='';if Pos('.L',S)>0 then Side:=' (E)' else if Pos('.R',S)>0 then Side:=' (D)';
  if Pos('upperarm',S)=1 then Result:='Braço'
  else if Pos('lowerarm',S)=1 then Result:='Antebraço'
  else if Pos('upperleg',S)=1 then Result:='Coxa'
  else if Pos('lowerleg',S)=1 then Result:='Perna'
  else if Pos('wrist',S)=1 then Result:='Mão'
  else if Pos('foot',S)=1 then Result:='Pé'
  else if Pos('clavicle',S)=1 then Result:='Clavícula'
  else if Pos('shoulder',S)=1 then Result:='Ombro'
  else if S='head' then Result:='Cabeça'
  else if Pos('neck',S)=1 then Result:='Pescoço '+Copy(S,5,2)
  else if Pos('spine',S)=1 then Result:='Coluna '+Copy(S,6,2)
  else if Pos('finger',S)=1 then begin
    I:=StrToIntDef(Copy(S,7,1),1);Result:=Fingers[EnsureRange(I,1,5)]+' '+Copy(S,9,1);
  end else Result:=S;
  Result:=Result+Side;
end;
constructor TEditorForm.Create(AOwner:TComponent);
var LeftPanel,BottomPanel,Host,ViewBar:TPanel;RightPanel:TScrollBox;I:Integer;L:TLabel;Header:TSuiteHeader;B:TSuiteButton;
  procedure LabelAt(const Text:string;P:TWinControl;Y:Integer);
  var C:TLabel;
  begin C:=TLabel.Create(Self);C.Parent:=P;C.SetBounds(12,Y,P.Width-24,22);C.Caption:=Text;C.Font.Color:=clSuiteMuted;end;
  procedure ButtonAt(const Text:string;P:TWinControl;Y:Integer;Handler:TNotifyEvent);
  var B:TSuiteButton;
  begin B:=TSuiteButton.Create(Self);B.Parent:=P;B.SetBounds(12,Y,P.Width-24,32);B.Caption:=Text;B.OnClick:=Handler;B.SetLook(sbsOutline,clSuitePrimary);
    if Handler=@SaveClick then B.SetLook(sbsSolid,clSuitePrimary,sikSave)
    else if Handler=@OpenClick then B.SetLook(sbsOutline,clSuitePrimary,sikFolder)
    else if Handler=@AddKeyClick then B.SetLook(sbsSolid,clSuiteSuccess,sikFlag)
    else if Handler=@PreviewClick then B.SetLook(sbsSolid,clSuitePrimary,sikPlay);end;
begin
  inherited CreateNew(AOwner);
  Caption:='Assistente - Editor de Movimentos 3D (prévia)';Width:=1440;Height:=900;Position:=poScreenCenter;
  Constraints.MinWidth:=1200;Constraints.MinHeight:=600;Font.Name:=SUITE_FONT;Font.Size:=10;Color:=clSuiteSurface;
  KeyPreview:=True;OnKeyDown:=@EditorKeyDown;
  Header:=TSuiteHeader.Create(Self);Header.Parent:=Self;Header.Align:=alTop;Header.Height:=72;
  Header.Setup('Editor de Movimentos','Assistente • Pose, animação e navegação 3D',sikAssembly);
  Motion.DurationMS:=2400;Motion.ReturnToBase:=True;Motion.Smooth:=True;
  BottomPanel:=TPanel.Create(Self);BottomPanel.Parent:=Self;BottomPanel.Align:=alBottom;BottomPanel.Height:=105;BottomPanel.BevelOuter:=bvNone;BottomPanel.Color:=clSuiteCard;
  LeftPanel:=TPanel.Create(Self);LeftPanel.Parent:=Self;LeftPanel.Align:=alLeft;LeftPanel.Width:=214;LeftPanel.BevelOuter:=bvNone;LeftPanel.Color:=clSuiteCard;
  RightPanel:=TScrollBox.Create(Self);RightPanel.Parent:=Self;RightPanel.Align:=alRight;RightPanel.Width:=264;RightPanel.BorderStyle:=bsNone;RightPanel.Color:=clSuiteCard;
  RightPanel.VertScrollBar.Tracking:=True;RightPanel.HorzScrollBar.Visible:=False;
  Host:=TPanel.Create(Self);Host.Parent:=Self;Host.Align:=alClient;Host.BevelOuter:=bvNone;Host.Color:=clSuiteSurface;
  LabelAt('MOVIMENTO',LeftPanel,12);
  NameEdit:=TEdit.Create(Self);NameEdit.Parent:=LeftPanel;NameEdit.SetBounds(12,38,186,26);NameEdit.Text:='novo_movimento';
  ButtonAt('Abrir movimento',LeftPanel,76,@OpenClick);ButtonAt('Salvar movimento',LeftPanel,114,@SaveClick);
  LabelAt('MEMBROS DO AVATAR',LeftPanel,164);
  BoneList:=TListBox.Create(Self);BoneList.Parent:=LeftPanel;BoneList.SetBounds(12,190,186,Max(100,LeftPanel.ClientHeight-202));
  BoneList.ScrollWidth:=340;
  BoneList.Anchors:=[akLeft,akRight,akTop];BoneList.OnClick:=@BoneChanged;
  LeftPanel.OnResize:=@LayoutMembers;LayoutMembers(LeftPanel);
  LabelAt('ROTAÇÃO LOCAL (graus)',RightPanel,12);
  SelectedLabel:=TLabel.Create(Self);SelectedLabel.Parent:=RightPanel;SelectedLabel.SetBounds(12,40,225,36);SelectedLabel.Font.Style:=[fsBold];
  for I:=0 to 2 do begin
    LabelAt(Chr(Ord('X')+I),RightPanel,90+I*60);
    XYZ[I]:=TFloatSpinEdit.Create(Self);XYZ[I].Parent:=RightPanel;XYZ[I].SetBounds(44,84+I*60,190,32);
    XYZ[I].DecimalPlaces:=1;XYZ[I].Increment:=1;XYZ[I].MinValue:=-100;XYZ[I].MaxValue:=100;XYZ[I].OnChange:=@AngleChanged;
  end;
  LabelAt('Tempo da pose (ms)',RightPanel,275);
  TimeEdit:=TSpinEdit.Create(Self);TimeEdit.Parent:=RightPanel;TimeEdit.SetBounds(12,300,222,30);TimeEdit.MaxValue:=2400;TimeEdit.OnChange:=@TimeChanged;
  ButtonAt('Gravar pose neste tempo',RightPanel,345,@AddKeyClick);
  ButtonAt('Reproduzir movimento',RightPanel,390,@PreviewClick);
  ButtonAt('Parar / editar pose atual',RightPanel,428,@StopClick);
  ButtonAt('Restaurar pose do avatar',RightPanel,480,@ResetClick);
  LabelAt('Clique em um ponto do corpo.',RightPanel,538);
  LabelAt('Arraste um anel para girar.',RightPanel,562);
  LabelAt('Direito: deslocar a vista.',RightPanel,586);
  LabelAt('Arraste fora: orbitar. Roda: zoom.',RightPanel,610);
  LabelAt('Alt + meio: girar câmera em Z.',RightPanel,634);
  L:=TLabel.Create(Self);L.Parent:=BottomPanel;L.SetBounds(12,10,130,22);L.Caption:='Duração total (ms)';
  DurationEdit:=TSpinEdit.Create(Self);DurationEdit.Parent:=BottomPanel;DurationEdit.SetBounds(12,36,120,28);
  DurationEdit.MinValue:=50;DurationEdit.MaxValue:=60000;DurationEdit.Value:=2400;DurationEdit.OnEditingDone:=@DurationChanged;
  Timeline:=TTrackBar.Create(Self);Timeline.Parent:=BottomPanel;Timeline.SetBounds(145,14,Width-180,50);
  Timeline.Anchors:=[akLeft,akTop,akRight];Timeline.Min:=0;Timeline.Max:=2400;Timeline.OnChange:=@TimeChanged;
  Status:=TLabel.Create(Self);Status.Parent:=BottomPanel;Status.Align:=alBottom;Status.AutoSize:=False;Status.Height:=32;Status.WordWrap:=True;Status.Layout:=tlCenter;

  ViewBar:=TPanel.Create(Self);ViewBar.Parent:=Host;ViewBar.Align:=alTop;ViewBar.Height:=96;
  ViewBar.BevelOuter:=bvNone;ViewBar.Color:=clSuiteSurface;
  LabelAt('VISTA',ViewBar,8);
  ViewBox:=TComboBox.Create(Self);ViewBox.Parent:=ViewBar;ViewBox.SetBounds(12,30,164,30);ViewBox.Style:=csDropDownList;
  ViewBox.Items.Add('Frontal  ·  Ctrl+1');ViewBox.Items.Add('Traseira  ·  Ctrl+2');
  ViewBox.Items.Add('Esquerda  ·  Ctrl+3');ViewBox.Items.Add('Direita  ·  Ctrl+4');
  ViewBox.Items.Add('Superior  ·  Ctrl+5');ViewBox.Items.Add('Inferior  ·  Ctrl+6');
  ViewBox.Items.Add('Isométrica  ·  Ctrl+7');ViewBox.Items.Add('Perspectiva 3D');ViewBox.ItemIndex:=0;
  ViewBox.OnChange:=@CameraChanged;
  ProjectionBox:=TComboBox.Create(Self);ProjectionBox.Parent:=ViewBar;ProjectionBox.SetBounds(184,30,116,30);
  ProjectionBox.Style:=csDropDownList;ProjectionBox.Items.Add('Ortográfica');ProjectionBox.Items.Add('Perspectiva');ProjectionBox.ItemIndex:=0;
  ProjectionBox.OnChange:=@CameraChanged;
  for I:=0 to 4 do begin
    B:=TSuiteButton.Create(Self);B.Parent:=ViewBar;B.SetBounds(312+I*64,27,58,34);B.Tag:=I;B.OnClick:=@CameraButton;
    case I of
      0:begin B.Caption:='Ajustar';B.Hint:='Enquadrar avatar (Ctrl+0)';end;
      1:B.Caption:='+';2:B.Caption:='−';
      3:begin B.Caption:='Z −15°';B.Hint:='Rolar câmera -15°';end;
      4:begin B.Caption:='Z +15°';B.Hint:='Rolar câmera +15°';end;
    end;B.ShowHint:=True;B.SetLook(sbsOutline,clSuitePrimary);
  end;
  LabelAt('Arraste: órbita  •  Direito: deslocar  •  Roda: zoom  •  Anéis: girar membro',ViewBar,70);
  Compass:=TPaintBox.Create(Self);Compass.Parent:=ViewBar;Compass.SetBounds(674,2,96,90);
  Compass.Align:=alRight;Compass.Width:=96;Compass.OnPaint:=@CompassPaint;
  View:=TProfessorView.Create(Self,Host);if not View.LoadModel('',False) then raise Exception.Create(View.Diagnostic);
  View.SetOrthographic(True);View.Viewport.BackgroundColor:=Vector4(0.945,0.961,0.980,1);
  Editor:=TMotionEditorView.Create(Self,View);Editor.OnChange:=@EditorChanged;
  for I:=0 to Editor.Bones.Count-1 do BoneList.Items.Add(MemberLabel(Editor.Bones[I]));EditorChanged(nil);
  Tick:=TTimer.Create(Self);Tick.Interval:=40;Tick.OnTimer:=@Poll;
  SetStatus('Selecione um membro no avatar ou na lista. Ajuste os eixos e grave a pose.');
end;
destructor TEditorForm.Destroy;
begin if Tick<>nil then Tick.Enabled:=False;FreeAndNil(Editor);FreeAndNil(View);inherited;end;
procedure TEditorForm.LayoutMembers(Sender:TObject);
begin
  if BoneList<>nil then BoneList.SetBounds(12,190,Max(80,BoneList.Parent.ClientWidth-24),Max(40,BoneList.Parent.ClientHeight-202));
end;
procedure TEditorForm.SetStatus(const S:string);
begin Status.Caption:='  '+S;end;
function TEditorForm.TrackIndex(const Bone:string):Integer;
var I:Integer;
begin for I:=0 to High(Motion.Tracks) do if Motion.Tracks[I].Bone=Bone then Exit(I);Result:=-1;end;
function TEditorForm.Candidate:TMotionAnimation;
begin Result:=Motion;Result.Name:=NameEdit.Text;Result.DurationMS:=DurationEdit.Value;end;
procedure TEditorForm.EditorChanged(Sender:TObject);
var V:TMVector;I:Integer;L:Double;
begin
  if FUpdating then Exit;FUpdating:=True;
  try
    SelectedLabel.Caption:=MemberLabel(Editor.Bone);BoneList.ItemIndex:=Editor.Bones.IndexOf(Editor.Bone);
    if (Sender<>BoneList) and (BoneList.ItemIndex>=0) then BoneList.MakeCurrentVisible;
    V:=Editor.Angles;L:=JointAngleLimit(Editor.Bone);
    for I:=0 to 2 do begin XYZ[I].MinValue:=-L;XYZ[I].MaxValue:=L;XYZ[I].Value:=V[I];end;
  finally FUpdating:=False;end;
  if TPresentationScene(View.Scene).MovementBlocked<>'' then SetStatus('Limite de colisão: '+TPresentationScene(View.Scene).MovementBlocked);
end;
procedure TEditorForm.BoneChanged(Sender:TObject);
begin if (not FUpdating) and (BoneList.ItemIndex>=0) then Editor.SelectBone(Editor.Bones[BoneList.ItemIndex]);end;
procedure TEditorForm.AngleChanged(Sender:TObject);
begin
  if FUpdating or (Editor=nil) then Exit;
  if Editor.SetAngles(MVector(XYZ[0].Value,XYZ[1].Value,XYZ[2].Value)) then SetStatus('Pose alterada. Clique em Gravar pose para incluir no movimento.');
end;
procedure TEditorForm.TimeChanged(Sender:TObject);
var T:Integer;
begin
  if FUpdating or (Editor=nil) then Exit;
  if Sender=Timeline then T:=Timeline.Position else T:=TimeEdit.Value;
  FUpdating:=True;try Timeline.Position:=T;TimeEdit.Value:=T;finally FUpdating:=False;end;
  Editor.Scrub(Motion,T);SetStatus('Pose no tempo '+IntToStr(T)+' ms.');
end;
procedure TEditorForm.DurationChanged(Sender:TObject);
var I,J:Integer;
begin
  if FUpdating or (Editor=nil) then Exit;
  for I:=0 to High(Motion.Tracks) do for J:=0 to High(Motion.Tracks[I].Keys) do
    if Motion.Tracks[I].Keys[J].TimeMS>DurationEdit.Value then begin
      FUpdating:=True;try DurationEdit.Value:=Motion.DurationMS;finally FUpdating:=False;end;
      SetStatus('A duração deve incluir todos os quadros gravados.');Exit;
    end;
  Motion.DurationMS:=DurationEdit.Value;Timeline.Max:=DurationEdit.Value;TimeEdit.MaxValue:=DurationEdit.Value;
end;
procedure TEditorForm.AddKeyClick(Sender:TObject);
var I,J,K,N:Integer;P,R:TMPoseArray;V:TMVector;Key:TMotionKeyframe;BoneName:string;Recorded:Boolean;
begin
  if TPresentationScene(View.Scene).MovementRunning then StopClick(nil);
  P:=TPresentationScene(View.Scene).EditorPose;R:=TPresentationScene(View.Scene).EditorRig.RestPose;
  Recorded:=False;
  for N:=0 to Editor.Bones.Count-1 do begin
    BoneName:=Editor.Bones[N];K:=TPresentationScene(View.Scene).EditorRig.NodeIndex(BoneName);
    V:=MEuler(QMul(MInverse(R[K].Rotation),P[K].Rotation));I:=TrackIndex(BoneName);
    if (I<0) and (Abs(V[0])+Abs(V[1])+Abs(V[2])<0.001) and (BoneName<>Editor.Bone) then Continue;
    if I<0 then begin
      I:=Length(Motion.Tracks);SetLength(Motion.Tracks,I+1);Motion.Tracks[I].Bone:=BoneName;
      SetLength(Motion.Tracks[I].Keys,2);Motion.Tracks[I].Keys[1].TimeMS:=DurationEdit.Value;
      Motion.Tracks[I].Keys[1].Rotation:=V;Motion.Tracks[I].Axis:=#0;
    end else if Motion.Tracks[I].Axis<>#0 then begin
      for J:=0 to High(Motion.Tracks[I].Keys) do
        Motion.Tracks[I].Keys[J].Rotation:=MotionEulerAt(Motion.Tracks[I],Motion.Tracks[I].Keys[J].TimeMS,Motion.Smooth);
      Motion.Tracks[I].Axis:=#0;
    end;
    Key:=Default(TMotionKeyframe);Key.TimeMS:=TimeEdit.Value;Key.Rotation:=V;
    K:=-1;for J:=0 to High(Motion.Tracks[I].Keys) do if Motion.Tracks[I].Keys[J].TimeMS=Key.TimeMS then K:=J;
    if K>=0 then Motion.Tracks[I].Keys[K]:=Key else begin
      J:=Length(Motion.Tracks[I].Keys);SetLength(Motion.Tracks[I].Keys,J+1);
      while (J>0) and (Motion.Tracks[I].Keys[J-1].TimeMS>Key.TimeMS) do begin Motion.Tracks[I].Keys[J]:=Motion.Tracks[I].Keys[J-1];Dec(J);end;
      Motion.Tracks[I].Keys[J]:=Key;
    end;Recorded:=True;
  end;
  if Recorded then SetStatus('Pose XYZ gravada em '+IntToStr(TimeEdit.Value)+' ms. '+IntToStr(Length(Motion.Tracks))+' membros no movimento.');
end;
procedure TEditorForm.OpenClick(Sender:TObject);
var D:TOpenDialog;A:TMotionAnimation;
begin
  D:=TOpenDialog.Create(Self);try D.Filter:='Movimentos JSON|*.json';if not D.Execute then Exit;
    try A:=LoadMotionAnimation(D.FileName);Editor.ResetPose;Motion:=A;Path:=D.FileName;
      FUpdating:=True;try NameEdit.Text:=A.Name;DurationEdit.Value:=A.DurationMS;Timeline.Max:=A.DurationMS;
        TimeEdit.MaxValue:=A.DurationMS;Timeline.Position:=0;TimeEdit.Value:=0;finally FUpdating:=False;end;
      Editor.Scrub(Motion,0);SetStatus('Carregado: '+ExtractFileName(Path));
    except on E:Exception do ShowMessage('Erro ao abrir: '+E.Message);end;
  finally D.Free;end;
end;
procedure TEditorForm.SaveClick(Sender:TObject);
var D:TSaveDialog;
begin
  D:=TSaveDialog.Create(Self);try D.Filter:='Movimentos JSON|*.json';D.DefaultExt:='json';D.FileName:=Path;
    if not D.Execute then Exit;
    if FileExists(D.FileName) and (MessageDlg('Substituir arquivo existente?',mtConfirmation,[mbYes,mbNo],0)<>mrYes) then Exit;
    try SaveMotionAnimation(D.FileName,Candidate);Motion:=Candidate;Path:=D.FileName;SetStatus('Salvo: '+Path);
    except on E:Exception do ShowMessage('Erro ao salvar: '+E.Message);end;
  finally D.Free;end;
end;
procedure TEditorForm.PreviewClick(Sender:TObject);
var A:TMotionAnimation;TempName:string;ID:TGUID;
begin
  CreateGUID(ID);TempName:=GetTempDir+'motion-preview-'+GUIDToString(ID)+'.json';
  try
    try A:=Candidate;SaveMotionAnimation(TempName,A);A:=LoadMotionAnimation(TempName);
      Editor.ResetPose;TPresentationScene(View.Scene).ExecuteTimeline(MotionTimeline(A));
      SetStatus('Reproduzindo com proteção de colisão.');
    except on E:Exception do ShowMessage('Erro na prévia: '+E.Message);end;
  finally DeleteFile(TempName);end;
end;
procedure TEditorForm.StopClick(Sender:TObject);
begin TPresentationScene(View.Scene).BeginEditing;Editor.Refresh;EditorChanged(nil);SetStatus('Reprodução parada. Pose disponível para edição.');end;
procedure TEditorForm.ResetClick(Sender:TObject);
begin Editor.ResetPose;SetStatus('Pose restaurada. Grave para atualizar o movimento.');end;
procedure TEditorForm.Poll(Sender:TObject);
var S:TPresentationScene;
begin
  S:=TPresentationScene(View.Scene);Editor.Refresh;Compass.Invalidate;
  if S.MovementRunning then begin
    FUpdating:=True;try Timeline.Position:=Min(Timeline.Max,Max(0,Round(S.MovementElapsed-320)));TimeEdit.Value:=Timeline.Position;finally FUpdating:=False;end;
    EditorChanged(nil);
  end;
  if S.MovementBlocked<>'' then SetStatus('Movimento limitado por colisão: '+S.MovementBlocked);
end;
procedure TEditorForm.CameraChanged(Sender:TObject);
begin
  if View=nil then Exit;
  if Sender=ViewBox then begin
    if ViewBox.ItemIndex=7 then begin View.SetCameraView(acIsometric);ProjectionBox.ItemIndex:=1;end
    else begin View.SetCameraView(TAvatarCameraView(ViewBox.ItemIndex));ProjectionBox.ItemIndex:=0;end;
  end;
  View.SetOrthographic(ProjectionBox.ItemIndex=0);Editor.Refresh;Compass.Invalidate;
end;
procedure TEditorForm.CameraButton(Sender:TObject);
begin
  case TComponent(Sender).Tag of
    0:View.FitCamera;1:View.ZoomBy(1);2:View.ZoomBy(-1);3:View.RollBy(-15);4:View.RollBy(15);
  end;Compass.Invalidate;
end;
procedure TEditorForm.EditorKeyDown(Sender:TObject;var Key:Word;Shift:TShiftState);
begin
  if not (ssCtrl in Shift) then Exit;
  if Key=Ord('0') then begin View.FitCamera;Key:=0;end
  else if (Key>=Ord('1')) and (Key<=Ord('7')) then begin
    ViewBox.ItemIndex:=Key-Ord('1');CameraChanged(ViewBox);Key:=0;
  end;
end;
procedure TEditorForm.CompassPaint(Sender:TObject);
var Pos,Dir,Up,Right,Axis:TVector3;I,X,Y:Integer;C:TCanvas;AxisColor:TColor;
begin
  if View=nil then Exit;
  C:=Compass.Canvas;C.Brush.Color:=clSuiteSurface;C.FillRect(Compass.ClientRect);
  View.Viewport.Camera.GetWorldView(Pos,Dir,Up);Right:=TVector3.CrossProduct(Dir,Up);
  for I:=0 to 2 do begin
    case I of 0:Axis:=Vector3(1,0,0);1:Axis:=Vector3(0,1,0);else Axis:=Vector3(0,0,1);end;
    X:=46+Round(28*TVector3.DotProduct(Axis,Right));Y:=45-Round(28*TVector3.DotProduct(Axis,Up));
    case I of 0:AxisColor:=clSuiteAxisX;1:AxisColor:=clSuiteAxisY;else AxisColor:=clSuiteAxisZ;end;
    C.Pen.Color:=AxisColor;C.Pen.Width:=2;C.Line(46,45,X,Y);C.Font.Color:=AxisColor;C.Font.Style:=[fsBold];
    C.TextOut(X+3,Y-6,Chr(Ord('X')+I));
  end;
end;
procedure TEditorForm.SmokeTick(Sender:TObject);
var S:TPresentationScene;RemoveMe:TRemoveType;Report:TStringList;P:TVector2;
  BeforeW,AfterW:TMWorldArray;V:TMVector;N:Integer;A:TMotionAnimation;FileName:string;
  Shot:TRGBImage;Layout:TBitmap;Avatar:TPicture;Origin:TPoint;CameraPos,CameraDir,CameraUp,OldPos,OldDir,OldUp:TVector3;I,GX,GY,GizmoHits,HandledPresses:Integer;GizmoDragged:Boolean;StartV:TMVector;FromP,DragEnd:TVector2;
  procedure Check(B:Boolean;const Msg:string);
  begin if not B then raise Exception.Create(Msg);end;
begin
  TTimer(Sender).Enabled:=False;Tick.Enabled:=False;Report:=TStringList.Create;
  FileName:=GetTempDir+'motion-editor-3d-smoke-'+IntToStr(GetTickCount64)+'.json';
  try
    try
      S:=TPresentationScene(View.Scene);Check(not S.BoundingBox.IsEmpty and S.SafetyReady,'Avatar indisponivel');
      Check(Visible and Showing and View.Control.IsVisible,'Janela ou viewport invisivel');
      Shot:=View.Control.Container.SaveScreen;
      try SaveImage(Shot,FilenameToURISafe(ExtractFilePath(ParamStr(0))+'motion-editor-avatar.png'));finally Shot.Free;end;
      Layout:=GetFormImage;Avatar:=TPicture.Create;
      try
        Avatar.LoadFromFile(ExtractFilePath(ParamStr(0))+'motion-editor-avatar.png');
        Origin:=ScreenToClient(View.Control.ClientToScreen(Point(0,0)));
        Layout.Canvas.Draw(Origin.X,Origin.Y,Avatar.Graphic);
        Layout.SaveToFile(ExtractFilePath(ParamStr(0))+'motion-editor-layout.bmp');
      finally Avatar.Free;Layout.Free;end;

      // All limbs remain reachable in a short window; the controls scroll too.
      Height:=600;Application.ProcessMessages;
      BoneList.TopIndex:=BoneList.Count-1;Application.ProcessMessages;
      Check(BoneList.TopIndex>0,'Lista de membros nao rolou');
      Check(BoneList.Top+BoneList.Height<=BoneList.Parent.ClientHeight,'Lista saiu da area visivel');
      Check(TScrollBox(XYZ[0].Parent).VertScrollBar.Range>XYZ[0].Parent.ClientHeight,'Painel de controles sem rolagem');
      TScrollBox(XYZ[0].Parent).VertScrollBar.Position:=200;Application.ProcessMessages;
      Check(TScrollBox(XYZ[0].Parent).VertScrollBar.Position>0,'Painel nao deslocou');
      Height:=900;TScrollBox(XYZ[0].Parent).VertScrollBar.Position:=0;Application.ProcessMessages;
      // Standard views use non-degenerate camera bases, including exact poles.
      for I:=0 to 6 do begin
        View.SetCameraView(TAvatarCameraView(I));View.Viewport.Camera.GetWorldView(CameraPos,CameraDir,CameraUp);
        Check(Abs(TVector3.DotProduct(CameraDir,CameraUp))<1E-5,'Camera perdeu ortogonalidade');
        case I of
          0:Check(CameraDir.Z< -0.99,'Vista frontal incorreta');
          1:Check(CameraDir.Z>0.99,'Vista traseira incorreta');
          2:Check(CameraDir.X>0.99,'Vista esquerda incorreta');
          3:Check(CameraDir.X< -0.99,'Vista direita incorreta');
          4:Check(CameraDir.Y< -0.99,'Vista superior incorreta');
          5:Check(CameraDir.Y>0.99,'Vista inferior incorreta');
        end;
      end;
      View.SetCameraView(acFront);View.Viewport.Camera.GetWorldView(OldPos,OldDir,OldUp);
      View.PanBy(30,20);View.Viewport.Camera.GetWorldView(CameraPos,CameraDir,CameraUp);
      Check((CameraPos-OldPos).Length>0.001,'Pan nao deslocou camera');
      Check((CameraDir-OldDir).Length<1E-5,'Pan alterou orientacao');
      View.RollBy(30);View.Viewport.Camera.GetWorldView(CameraPos,CameraDir,CameraUp);
      Check((CameraDir-OldDir).Length<1E-5,'Rolagem mudou direcao');Check((CameraUp-OldUp).Length>0.1,'Rolagem Z nao funcionou');
      View.OrbitBy(20,10);View.Viewport.Camera.GetWorldView(CameraPos,CameraDir,CameraUp);
      Check((CameraDir-OldDir).Length>0.1,'Orbita nao funcionou');
      View.SetCameraView(acFront);View.FitCamera;
      P:=Editor.BoneScreen('head');
      Check((P.X>View.Control.Width*0.2) and (P.X<View.Control.Width*0.8) and (P.Y>0) and (P.Y<View.Control.Height),'Avatar fora do enquadramento');
            P:=Editor.BoneScreen('lowerarm01.L');Check(Editor.SelectAt(Round(P.X),Round(P.Y)),'Selecao visual falhou');
      Check(Editor.Bone='lowerarm01.L','Selecao visual incorreta');

      Editor.SelectBone('upperarm01.L');Editor.Refresh;View.Control.Repaint;
      // Exercise actual engine hit testing and drag events through the same container as LCL.
      P:=Editor.BoneScreen(Editor.Bone);GizmoDragged:=False;GizmoHits:=0;HandledPresses:=0;
      for GX:=Round(P.X)-100 to Round(P.X)+100 do begin
        if (GX mod 4)<>0 then Continue;
        for GY:=Round(P.Y)-100 to Round(P.Y)+100 do begin
          if ((GY mod 4)<>0) or (GX<0) or (GY<0) or (GX>=View.Control.Width) or (GY>=View.Control.Height) then Continue;
          if not Editor.GizmoAt(GX,GY) then Continue;
          Inc(GizmoHits);StartV:=Editor.Angles;FromP:=Vector2(GX,View.Control.Height-1-GY);DragEnd:=FromP+Vector2(12,9);
          View.Control.Container.EventMotion(InputMotion(View.Control.Container.MousePosition,FromP,[],0));
          if View.Control.Container.EventPress(InputMouseButton(FromP,CastleKeysMouse.buttonLeft,0,[])) then Inc(HandledPresses);
          View.Control.Container.EventMotion(InputMotion(FromP,DragEnd,[CastleKeysMouse.buttonLeft],0));
          View.Control.Container.EventUpdate;
          View.Control.Container.EventMotion(InputMotion(DragEnd,DragEnd+Vector2(2,1),[CastleKeysMouse.buttonLeft],0));
          View.Control.Container.EventRelease(InputMouseButton(DragEnd+Vector2(2,1),CastleKeysMouse.buttonLeft,0,[]));
          V:=Editor.Angles;
          GizmoDragged:=Abs(V[0]-StartV[0])+Abs(V[1]-StartV[1])+Abs(V[2]-StartV[2])>0.01;
          if GizmoDragged then Break;
        end;
        if GizmoDragged then Break;
      end;
      Check(GizmoDragged,'Aneis 3D nao receberam arraste: hits='+IntToStr(GizmoHits)+' handled='+IntToStr(HandledPresses)+' events='+IntToStr(Editor.DragEvents)+' blocked='+S.MovementBlocked);Editor.ResetPose;
      BeforeW:=S.EditorRig.Worlds(S.EditorPose);
      Check(Editor.SetAngles(MVector(3,4,5)),'Pose XYZ rejeitada');V:=Editor.Angles;
      Check((Abs(V[0]-3)+Abs(V[1]-4)+Abs(V[2]-5))<0.01,'XYZ nao chegou ao esqueleto');
      AfterW:=S.EditorRig.Worlds(S.EditorPose);N:=S.EditorRig.NodeIndex('wrist.L');
      Check(Abs(BeforeW[N].Position[0]-AfterW[N].Position[0])+Abs(BeforeW[N].Position[1]-AfterW[N].Position[1])+Abs(BeforeW[N].Position[2]-AfterW[N].Position[2])>0.0001,'Filho nao acompanhou o membro');
      RemoveMe:=rtNone;S.Update(0.2,RemoveMe);V:=Editor.Angles;
      Check(Abs(V[0]-3)<0.01,'Pose de edicao foi sobrescrita pelo idle');
      FUpdating:=True;TimeEdit.Value:=1200;FUpdating:=False;AddKeyClick(nil);
      SaveMotionAnimation(FileName,Candidate);A:=LoadMotionAnimation(FileName);
      Check(A.Tracks[0].Axis=#0,'Pose nao gravou XYZ');
      Editor.ResetPose;Editor.Scrub(A,1200);V:=Editor.Angles;
      Check(Abs(V[0]-3)+Abs(V[1]-4)+Abs(V[2]-5)<0.01,'Scrub diverge da pose gravada');
      PreviewClick(nil);Check(S.MovementRunning,'Previa nao iniciou');S.Update(4,RemoveMe);
      Check(not S.MovementRunning and (S.MovementBlocked='') and (S.MovementClearance>=0),'Previa nao concluiu com seguranca');
      Report.Add('PASS: real avatar, screen selection, XYZ rotation, child hierarchy, static pose, v2 save/load, scrub, protected playback, seven views, pan, orbit, roll and visible centered viewport and real gizmo hit/drag events');
    except on E:Exception do begin Report.Add('FAIL: '+E.Message);ExitCode:=1;end;end;
    Report.SaveToFile(ExtractFilePath(ParamStr(0))+'motion-editor-smoke-result.txt');
  finally DeleteFile(FileName);Report.Free;end;
  Application.Terminate;
end;
var F:TEditorForm;SmokeTimer:TTimer;
begin
  Application.Initialize;Application.CreateForm(TEditorForm,F);F.Show;
  if (ParamCount>0) and (ParamStr(1)='--smoke-test') then begin
    SmokeTimer:=TTimer.Create(F);SmokeTimer.Interval:=1500;SmokeTimer.OnTimer:=@F.SmokeTick;
  end;
  Application.Run;
end.
