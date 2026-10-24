unit motion_editor_view;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Math,Controls,CastleScene,CastleTransform,CastleVectors,
  CastleTransformManipulate,CastleRenderOptions,professor_view,presentation_joints,movement_timeline,
  movement_animation,presentation_joint_tags;
type
  { Rotation-only FK editing: never changes bone length, scale or rest transforms. }
  TMotionEditorView=class(TComponent)
  private
    FView:TProfessorView;FScene:TPresentationScene;
    FProxy:TCastleTransform;FManipulator:TCastleTransformManipulate;
    FMarkers:array of TCastleSphere;FNames:TStringList;FSelected:Integer;
    FDownX,FDownY,FLastX,FLastY:Integer;FDragged,FOrbitDrag,FPanDrag,FRollDrag:Boolean;
    FOnChange:TNotifyEvent;FDragEvents:Integer;
    procedure Modified(Sender:TObject);
    procedure FitView(Sender:TObject);
    procedure MouseDown(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
    procedure MouseMove(Sender:TObject;Shift:TShiftState;X,Y:Integer);
    procedure MouseUp(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
    function GetBone:string;
  public
    constructor Create(AOwner:TComponent;AView:TProfessorView);reintroduce;
    destructor Destroy;override;
    procedure Refresh;
    procedure SelectBone(const BoneName:string);
    function SelectAt(X,Y:Integer):Boolean;
    function GizmoAt(X,Y:Integer):Boolean;
    function BoneScreen(const BoneName:string):TVector2;
    function Angles:TMVector;
    function SetAngles(const V:TMVector):Boolean;
    procedure Scrub(const Motion:TMotionAnimation;TimeMS:Integer);
    procedure ResetPose;
    property DragEvents:Integer read FDragEvents;
    property Bone:string read GetBone;
    property Bones:TStringList read FNames;
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
  end;
implementation
constructor TMotionEditorView.Create(AOwner:TComponent;AView:TProfessorView);
var I:Integer;M:TCastleSphere;
begin
  inherited Create(AOwner);FSelected:=-1;FView:=AView;FScene:=TPresentationScene(FView.Scene);
  FNames:=TStringList.Create;FScene.BeginEditing;
  SetLength(FMarkers,FScene.EditorRig.NodeCount);
  for I:=0 to FScene.EditorRig.NodeCount-1 do
    if JointAngleLimit(FScene.EditorRig.NodeName(I))>0 then begin

      { Fingers remain selectable in the list; body markers avoid overlapping hands. }
      if Pos('finger',FScene.EditorRig.NodeName(I))=1 then Continue;
      FNames.Add(FScene.EditorRig.NodeName(I));
      M:=TCastleSphere.Create(Self);M.Radius:=FView.ModelHeight*0.009;
      M.Color:=Vector4(0.08,0.75,0.85,1);M.Collides:=False;M.Pickable:=False;
      M.RenderLayer:=rlFront;M.CastShadows:=False;M.InternalExcludeFromParentBoundingVolume:=True;
      FView.Viewport.Items.Add(M);FMarkers[I]:=M;
    end;
  for I:=0 to FScene.EditorRig.NodeCount-1 do
    if (JointAngleLimit(FScene.EditorRig.NodeName(I))>0) and (Pos('finger',FScene.EditorRig.NodeName(I))=1) then FNames.Add(FScene.EditorRig.NodeName(I));
  FProxy:=TCastleTransform.Create(Self);FProxy.Collides:=False;
  FProxy.InternalExcludeFromParentBoundingVolume:=True;
  { A finite anchor keeps the proxy renderable: the gizmo excludes its own bounds. }
  M:=TCastleSphere.Create(Self);M.Radius:=FView.ModelHeight*0.009;
  M.Color:=Vector4(1,0.65,0.05,1);M.Pickable:=False;M.Collides:=False;M.RenderLayer:=rlFront;
  FProxy.Add(M);FView.Viewport.Items.Add(FProxy);
  FManipulator:=TCastleTransformManipulate.Create(Self);FManipulator.Mode:=mmRotate;
  FManipulator.OnTransformModified:=@Modified;
  FView.Control.OnMouseDown:=@MouseDown;FView.Control.OnMouseMove:=@MouseMove;FView.Control.OnMouseUp:=@MouseUp;
  FView.EditorNavigation:=True;FView.Control.OnDblClick:=@FitView;
  FView.Control.Hint:='Pontos: selecionar. Anéis: girar membro. Arraste fora dos anéis: orbitar. Direito: deslocar. Roda: zoom. Alt+meio: rolar câmera.';
  SelectBone('upperarm01.L');
end;
destructor TMotionEditorView.Destroy;
begin
  FView.Control.OnDblClick:=nil;FView.Control.OnMouseDown:=nil;FView.Control.OnMouseMove:=nil;FView.Control.OnMouseUp:=nil;
  FManipulator.Free;FProxy.Free;FNames.Free;inherited;
end;
function TMotionEditorView.GetBone:string;
begin if FSelected<0 then Exit('');Result:=FScene.EditorRig.NodeName(FSelected);end;
procedure TMotionEditorView.Refresh;
var W:TMWorldArray;I:Integer;X,Y,Z,A:Double;
begin
  W:=FScene.EditorRig.Worlds(FScene.EditorPose);
  for I:=0 to High(FMarkers) do if FMarkers[I]<>nil then begin
    FMarkers[I].Translation:=Vector3(W[I].Position[0],W[I].Position[1],W[I].Position[2]);
    if I=FSelected then FMarkers[I].Color:=Vector4(1,0.65,0.05,1)
    else FMarkers[I].Color:=Vector4(0.08,0.75,0.85,1);
  end;
  if FSelected>=0 then begin
    FProxy.Translation:=Vector3(W[FSelected].Position[0],W[FSelected].Position[1],W[FSelected].Position[2]);
    MToAxisAngle(W[FSelected].Rotation,X,Y,Z,A);FProxy.Rotation:=Vector4(X,Y,Z,A);
  end;
  for I:=0 to FProxy.Count-1 do if FProxy[I] is TCastleScene then TCastleScene(FProxy[I]).InternalCameraChanged;
  FManipulator.Pickable:=not FScene.MovementRunning;
end;
procedure TMotionEditorView.SelectBone(const BoneName:string);
var N:Integer;
begin
  N:=FScene.EditorRig.NodeIndex(BoneName);
  if (N<0) or (JointAngleLimit(BoneName)<=0) then Exit;
  FSelected:=N;FManipulator.SetSelected([FProxy]);Refresh;
  if Assigned(FOnChange) then FOnChange(Self);
end;
function TMotionEditorView.BoneScreen(const BoneName:string):TVector2;
var N:Integer;W:TMWorldArray;V:TVector2;
begin
  N:=FScene.EditorRig.NodeIndex(BoneName);Result:=Vector2(-1000,-1000);if N<0 then Exit;
  W:=FScene.EditorRig.Worlds(FScene.EditorPose);
  V:=FView.Viewport.PositionFromWorld(Vector3(W[N].Position[0],W[N].Position[1],W[N].Position[2]));
  Result:=Vector2(V.X*FView.Control.Width/Max(1,FView.Viewport.EffectiveWidth),
    FView.Control.Height-1-V.Y*FView.Control.Height/Max(1,FView.Viewport.EffectiveHeight));
end;
function TMotionEditorView.SelectAt(X,Y:Integer):Boolean;
var I,N:Integer;D,Best:Double;P:TVector2;
begin
  N:=-1;Best:=Sqr(15);
  for I:=0 to High(FMarkers) do if FMarkers[I]<>nil then begin
    P:=BoneScreen(FScene.EditorRig.NodeName(I));D:=Sqr(P.X-X)+Sqr(P.Y-Y);
    if D<Best then begin Best:=D;N:=I;end;
  end;
  Result:=N>=0;if Result then SelectBone(FScene.EditorRig.NodeName(N));
end;
function TMotionEditorView.Angles:TMVector;
var P,R:TMPoseArray;
begin
  Result:=MVector(0,0,0);if FSelected<0 then Exit;
  P:=FScene.EditorPose;R:=FScene.EditorRig.RestPose;
  Result:=MEuler(QMul(MInverse(R[FSelected].Rotation),P[FSelected].Rotation));
end;
function TMotionEditorView.SetAngles(const V:TMVector):Boolean;
var P,R:TMPoseArray;C:TMVector;I:Integer;L:Double;
begin
  Result:=False;if FSelected<0 then Exit;
  C:=V;L:=JointAngleLimit(Bone);for I:=0 to 2 do begin
    if IsNan(C[I]) or IsInfinite(C[I]) then Exit;C[I]:=EnsureRange(C[I],-L,L);
  end;
  P:=FScene.EditorPose;R:=FScene.EditorRig.RestPose;
  P[FSelected].Rotation:=QMul(R[FSelected].Rotation,MQuaternion(C[0],C[1],C[2]));
  Result:=FScene.EditorApply(P);Refresh;if Assigned(FOnChange) then FOnChange(Self);
end;
procedure TMotionEditorView.Modified(Sender:TObject);
var W:TMWorldArray;R:TMPoseArray;Q:TMQuaternion;N:Integer;
begin
  Inc(FDragEvents);if FSelected<0 then Exit;
  W:=FScene.EditorRig.Worlds(FScene.EditorPose);R:=FScene.EditorRig.RestPose;
  Q:=MAxisAngle(FProxy.Rotation.X,FProxy.Rotation.Y,FProxy.Rotation.Z,FProxy.Rotation.W);
  N:=FScene.EditorRig.NodeParent(FSelected);if N>=0 then Q:=QMul(MInverse(W[N].Rotation),Q);
  SetAngles(MEuler(QMul(MInverse(R[FSelected].Rotation),Q)));
end;
procedure TMotionEditorView.Scrub(const Motion:TMotionAnimation;TimeMS:Integer);
var P,R:TMPoseArray;I,N:Integer;
begin
  R:=FScene.EditorRig.RestPose;P:=Copy(R);
  for I:=0 to High(Motion.Tracks) do begin
    N:=FScene.EditorRig.NodeIndex(Motion.Tracks[I].Bone);
    if N<0 then raise Exception.Create('Membro ausente: '+Motion.Tracks[I].Bone);
    P[N].Rotation:=QMul(R[N].Rotation,MotionRotationAt(Motion.Tracks[I],TimeMS,Motion.Smooth));
  end;
  FScene.EditorApply(P);Refresh;if Assigned(FOnChange) then FOnChange(Self);
end;
procedure TMotionEditorView.ResetPose;
begin FScene.EditorApply(FScene.EditorRig.RestPose);Refresh;if Assigned(FOnChange) then FOnChange(Self);end;
procedure TMotionEditorView.FitView(Sender:TObject);
begin FView.FitCamera;end;
function TMotionEditorView.GizmoAt(X,Y:Integer):Boolean;
var Hit:TCastleTransform;
begin
  Hit:=FView.Viewport.TransformHit(Vector2(X,FView.Control.Height-1-Y),True);Result:=False;
  while Hit<>nil do begin if Hit=FProxy then Exit(True);Hit:=Hit.Parent;end;
end;
procedure TMotionEditorView.MouseDown(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
var OnGizmo:Boolean;
begin
  FDownX:=X;FDownY:=Y;FLastX:=X;FLastY:=Y;FDragged:=False;OnGizmo:=GizmoAt(X,Y);
  FRollDrag:=(Button=mbMiddle) and (ssAlt in Shift);
  FPanDrag:=(Button=mbRight) or ((Button=mbMiddle) and (ssShift in Shift));
  FOrbitDrag:=(not FRollDrag) and (not FPanDrag) and
    ((Button=mbMiddle) or ((Button=mbLeft) and not OnGizmo));
end;
procedure TMotionEditorView.MouseMove(Sender:TObject;Shift:TShiftState;X,Y:Integer);
begin
  if Abs(X-FDownX)+Abs(Y-FDownY)>5 then FDragged:=True;
  if FRollDrag then FView.RollBy((X-FLastX)*0.6)
  else if FPanDrag then FView.PanBy(X-FLastX,Y-FLastY)
  else if FOrbitDrag then FView.OrbitBy(X-FLastX,Y-FLastY);
  FLastX:=X;FLastY:=Y;
end;
procedure TMotionEditorView.MouseUp(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
begin
  FOrbitDrag:=False;FPanDrag:=False;FRollDrag:=False;
  if (Button=mbLeft) and not FDragged then SelectAt(X,Y);
end;
end.
