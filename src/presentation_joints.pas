unit presentation_joints;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Math, CastleScene, CastleTransform, CastleVectors, X3DNodes,
  presentation_joint_tags;
type
  TJointMotion = record
    Node: TTransformNode; Base: TVector4;
    Axis: Char; StartAngle, Target, Angle: Double; Started: QWord; Duration: Integer; Smooth: Boolean;
  end;
  TPresentationScene = class(TCastleScene)
  private
    FMotions: array of TJointMotion;
    FJaw: TTransformNode;FJawRest: TVector4;FVoicePhase: Double;FSpeaking: Boolean;
    FPaused: Boolean; FPausedAt: QWord;
  public
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure ExecuteJoint(const ATag: TJointTag);
    procedure ResetJoints;
    procedure PrepareSpeechMouth;
    procedure ForgetRig;
    property Speaking: Boolean read FSpeaking write FSpeaking;
    procedure PauseJoints(Value: Boolean);
  end;
implementation
procedure TPresentationScene.ForgetRig;
begin ResetJoints;FJaw:=nil;FSpeaking:=False;end;
function SpeechJawRotation(const Base: TVector4; Angle: Double): TVector4;
var X,Y,Z,W,S,C,B,N: Double;
begin
  S:=Sin(Angle/2);C:=Cos(Angle/2);B:=Sin(Base.W/2);
  X:=Cos(Base.W/2)*S+Base.X*B*C;
  Y:=Base.Y*B*C+Base.Z*B*S;
  Z:=Base.Z*B*C-Base.Y*B*S;
  W:=Cos(Base.W/2)*C-Base.X*B*S;
  N:=Sqrt(X*X+Y*Y+Z*Z);
  if N<1E-8 then Result:=Vector4(0,0,1,0)
  else Result:=Vector4(X/N,Y/N,Z/N,2*ArcTan2(N,W));
end;
procedure TPresentationScene.PrepareSpeechMouth;
var N: TX3DNode;
begin
  FJaw:=nil;FSpeaking:=False;FVoicePhase:=0;
  if RootNode=nil then Exit;
  N:=RootNode.FindNodeByName(TTransformNode,'jaw',False);
  if N is TTransformNode then begin FJaw:=TTransformNode(N);FJawRest:=FJaw.Rotation;end;
end;
procedure TPresentationScene.ExecuteJoint(const ATag: TJointTag);
var I,N: Integer; BoneNode: TX3DNode;
begin
  if (RootNode=nil) or (JointAngleLimit(ATag.Bone)=0) then raise Exception.Create('Articulacao nao suportada');
  BoneNode:=RootNode.FindNodeByName(TTransformNode,ATag.Bone,False);
  if not (BoneNode is TTransformNode) then raise Exception.Create('Osso ausente no avatar: '+ATag.Bone);
  N:=-1;for I:=0 to High(FMotions) do if FMotions[I].Node=BoneNode then begin N:=I;Break;end;
  if N<0 then begin
    N:=Length(FMotions);SetLength(FMotions,N+1);FMotions[N].Node:=TTransformNode(BoneNode);
    FMotions[N].Base:=TTransformNode(BoneNode).Rotation;
  end;
  with FMotions[N] do begin
    Axis:=ATag.Axis;StartAngle:=Angle;Target:=ATag.Angle;Duration:=ATag.Duration;Smooth:=ATag.Smooth;Started:=GetTickCount64;
  end;
end;
procedure TPresentationScene.ResetJoints;
var I: Integer;
begin
  for I:=0 to High(FMotions) do FMotions[I].Node.Rotation:=FMotions[I].Base;
  SetLength(FMotions,0);FPaused:=False;
end;
procedure TPresentationScene.PauseJoints(Value: Boolean);
var I: Integer; Delta: QWord;
begin
  if Value=FPaused then Exit;
  if Value then FPausedAt:=GetTickCount64
  else begin Delta:=GetTickCount64-FPausedAt;for I:=0 to High(FMotions) do Inc(FMotions[I].Started,Delta);end;
  FPaused:=Value;
end;
procedure TPresentationScene.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var I: Integer; T,A,H,S,C,BH,BS,BC,Norm: Double; Q: array[0..3] of Double;
  V: TVector4; NowTick: QWord;
begin
  inherited Update(SecondsPassed,RemoveMe);
  if FJaw<>nil then begin
    if FSpeaking and not FPaused then FVoicePhase:=FVoicePhase+SecondsPassed;
    if FSpeaking then FJaw.Rotation:=SpeechJawRotation(FJawRest,0.09*(1+Sin(FVoicePhase*18)))
    else FJaw.Rotation:=FJawRest;
  end;
  if FPaused then NowTick:=FPausedAt else NowTick:=GetTickCount64;
  for I:=0 to High(FMotions) do with FMotions[I] do begin
    T:=Min(1,Max(0,(Int64(NowTick)-Int64(Started))/Duration));if Smooth then T:=T*T*(3-2*T);
    Angle:=StartAngle+(Target-StartAngle)*T;A:=DegToRad(Angle);
    // Compose the rig's rest quaternion with a local-axis offset.
    H:=A/2;S:=Sin(H);C:=Cos(H);BH:=Base.W/2;BS:=Sin(BH);BC:=Cos(BH);
    V:=Vector4(0,0,0,0);
    case Axis of 'x':V.X:=S;'y':V.Y:=S;'z':V.Z:=S;end;
    Q[0]:=BC*V.X+Base.X*BS*C+Base.Y*BS*V.Z-Base.Z*BS*V.Y;
    Q[1]:=BC*V.Y-Base.X*BS*V.Z+Base.Y*BS*C+Base.Z*BS*V.X;
    Q[2]:=BC*V.Z+Base.X*BS*V.Y-Base.Y*BS*V.X+Base.Z*BS*C;
    Q[3]:=BC*C-Base.X*BS*V.X-Base.Y*BS*V.Y-Base.Z*BS*V.Z;
    Norm:=Sqrt(Sqr(Q[0])+Sqr(Q[1])+Sqr(Q[2]));
    if Norm<1E-8 then V:=Vector4(0,0,1,0)
    else V:=Vector4(Q[0]/Norm,Q[1]/Norm,Q[2]/Norm,2*ArcTan2(Norm,Q[3]));
    Node.Rotation:=V;
  end;
end;
end.
