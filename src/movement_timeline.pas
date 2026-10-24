unit movement_timeline;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Math,fpjson,jsonparser;
type
  TMVector=array[0..2] of Double;
  TMQuaternion=array[0..3] of Double;
  TMPose=record Rotation:TMQuaternion;Position,Scale:TMVector;end;
  TMPoseArray=array of TMPose;
  TMKey=record TimeMS:Integer;Angle:Double;Rotation:TMQuaternion;Position,Scale:TMVector;end;
  TMKeys=array of TMKey;
  TMTrack=record Bone:string;ScalarAxis:Char;StartMS,DurationMS:Integer;Keys:TMKeys;HasRotation,HasPosition,HasScale,CurrentRotation,CurrentPosition,CurrentScale:Boolean;end;
  TMTracks=array of TMTrack;
  TMovementTimeline=record Tracks:TMTracks;DurationMS,TransitionMS,ReturnMS:Integer;Smooth,ReturnToStart,Looping:Boolean;end;
  TMRigNode=record Name:string;Parent:Integer;Rest:TMPose;end;
  TMRigNodes=array of TMRigNode;
  TMCapsule=record ID,StartBone,EndBone:string;A,B:Integer;Radius,StartFraction,EndFraction:Double;StartOffset,EndOffset:TMVector;end;
  TMCapsules=array of TMCapsule;
  TMWorld=record Position:TMVector;Rotation:TMQuaternion;Scale:TMVector;end;
  TMWorldArray=array of TMWorld;
  TMovementRuntime=class
  private
    FNodes:TMRigNodes;FShapes:TMCapsules;FCurrent,FIncoming:TMPoseArray;
    FTimeline:TMovementTimeline;FIndexes:array of Integer;
    FElapsed:Double;FHasPose,FRunning:Boolean;FHeight,FMargin:Double;
    FBlocked:string;FBlocks:Integer;FIgnore,FTranslations:TStringList;

    procedure Capsule(const C:TMCapsule;const W:TMWorldArray;out A,B:TMVector);
    function Clearance(const Pose:TMPoseArray;out Pair:string):Double;
    function MotionBound(const A,B:TMPoseArray;Index:Integer;Offset:Double=0):Double;
    function CertifyInterval(const A,B,Mid:TMPoseArray;out Pair:string):Integer;
    function SafeInterval(const A,B:TMPoseArray;Depth:Integer;out Pair:string):Boolean;
    function SafeTimelineInterval(A,B:Double;Depth:Integer;out Pair:string):Boolean;
    function Evaluate(TimeMS:Double):TMPoseArray;
    function NextBoundary(TimeMS,Limit:Double):Double;
  public
    constructor Create;
    destructor Destroy;override;
    procedure LoadRig(const FileName,CollisionFile:string;Height:Double);
    function Worlds(const Pose:TMPoseArray):TMWorldArray;
    function NodeParent(Index:Integer):Integer;
    function NodeIndex(const Name:string):Integer;
    function NodeCount:Integer;
    function NodeName(Index:Integer):string;
    function RestPose:TMPoseArray;
    procedure Capture(const Pose:TMPoseArray);
    procedure Start(const Timeline:TMovementTimeline);
    procedure Advance(Milliseconds:Double);
    function Guard(const Candidate:TMPoseArray):Boolean;
    function MinimumClearance:Double;
    procedure Clear;
    property Pose:TMPoseArray read FCurrent;
    property HasPose:Boolean read FHasPose;
    property Running:Boolean read FRunning;
    property ElapsedMS:Double read FElapsed;
    property BlockedPair:string read FBlocked;
    property BlockCount:Integer read FBlocks;
  end;
function ParseMovementTimeline(O:TJSONObject):TMovementTimeline;
function MQuaternion(X,Y,Z:Double):TMQuaternion;
function MAxisAngle(X,Y,Z,Angle:Double):TMQuaternion;
procedure MToAxisAngle(const Q:TMQuaternion;out X,Y,Z,Angle:Double);
function MInterpolate(const A,B:TMQuaternion;T:Double):TMQuaternion;
function MVector(X,Y,Z:Double):TMVector;
function MSegmentDistance(const P1,Q1,P2,Q2:TMVector):Double;
function QMul(const A,B:TMQuaternion):TMQuaternion;
function MInverse(const Q:TMQuaternion):TMQuaternion;
function MEuler(const Q:TMQuaternion):TMVector;
implementation
function MInverse(const Q:TMQuaternion):TMQuaternion;
var I:Integer;N:Double;
begin N:=0;for I:=0 to 3 do N:=N+Sqr(Q[I]);
  if N<1E-15 then Exit(MQuaternion(0,0,0));
  for I:=0 to 2 do Result[I]:=-Q[I]/N;Result[3]:=Q[3]/N;end;
function MEuler(const Q:TMQuaternion):TMVector;
var S:Double;V:TMVector;I:Integer;
  function Wrap(A:Double):Double;
  begin Result:=A;while Result>180 do Result:=Result-360;while Result< -180 do Result:=Result+360;end;
begin
  S:=EnsureRange(2*(Q[3]*Q[1]-Q[2]*Q[0]),-1.0,1.0);
  Result[1]:=RadToDeg(ArcSin(S));
  if Abs(S)>0.99999999 then begin
    Result[0]:=Wrap(RadToDeg(2*ArcTan2(Q[0],Q[3])))/2;
    if S>0 then Result[2]:=-Result[0] else Result[2]:=Result[0];
  end else begin
    Result[0]:=RadToDeg(ArcTan2(2*(Q[3]*Q[0]+Q[1]*Q[2]),1-2*(Sqr(Q[0])+Sqr(Q[1]))));
    Result[2]:=RadToDeg(ArcTan2(2*(Q[3]*Q[2]+Q[0]*Q[1]),1-2*(Sqr(Q[1])+Sqr(Q[2]))));
  end;
  V:=MVector(Wrap(Result[0]+180),Wrap(180-Result[1]),Wrap(Result[2]+180));
  if Sqr(V[0])+Sqr(V[1])+Sqr(V[2])+1E-8<Sqr(Result[0])+Sqr(Result[1])+Sqr(Result[2]) then Result:=V;
  for I:=0 to 2 do if Abs(Result[I])<1E-10 then Result[I]:=0;
end;
function TMovementRuntime.NodeParent(Index:Integer):Integer;
begin Result:=FNodes[Index].Parent;end;
function MVector(X,Y,Z:Double):TMVector;
begin Result[0]:=X;Result[1]:=Y;Result[2]:=Z;end;
function Add(const A,B:TMVector):TMVector;
var I:Integer;begin for I:=0 to 2 do Result[I]:=A[I]+B[I];end;
function Sub(const A,B:TMVector):TMVector;
var I:Integer;begin for I:=0 to 2 do Result[I]:=A[I]-B[I];end;
function Mul(const A:TMVector;T:Double):TMVector;
var I:Integer;begin for I:=0 to 2 do Result[I]:=A[I]*T;end;
function Dot(const A,B:TMVector):Double;
begin Result:=A[0]*B[0]+A[1]*B[1]+A[2]*B[2];end;
function LengthV(const A:TMVector):Double;
begin Result:=Sqrt(Dot(A,A));end;
function QMul(const A,B:TMQuaternion):TMQuaternion;
begin
  Result[0]:=A[3]*B[0]+A[0]*B[3]+A[1]*B[2]-A[2]*B[1];
  Result[1]:=A[3]*B[1]-A[0]*B[2]+A[1]*B[3]+A[2]*B[0];
  Result[2]:=A[3]*B[2]+A[0]*B[1]-A[1]*B[0]+A[2]*B[3];
  Result[3]:=A[3]*B[3]-A[0]*B[0]-A[1]*B[1]-A[2]*B[2];
end;
function MAxisAngle(X,Y,Z,Angle:Double):TMQuaternion;
var N,S:Double;
begin
  N:=Sqrt(X*X+Y*Y+Z*Z);Result[0]:=0;Result[1]:=0;Result[2]:=0;Result[3]:=1;
  if N<1E-12 then Exit;S:=Sin(Angle/2)/N;
  Result[0]:=X*S;Result[1]:=Y*S;Result[2]:=Z*S;Result[3]:=Cos(Angle/2);
end;
function MQuaternion(X,Y,Z:Double):TMQuaternion;
begin Result:=QMul(QMul(MAxisAngle(0,0,1,DegToRad(Z)),MAxisAngle(0,1,0,DegToRad(Y))),MAxisAngle(1,0,0,DegToRad(X)));end;
procedure MToAxisAngle(const Q:TMQuaternion;out X,Y,Z,Angle:Double);
var N:Double;
begin N:=Sqrt(Sqr(Q[0])+Sqr(Q[1])+Sqr(Q[2]));
  if N<1E-10 then begin X:=0;Y:=0;Z:=1;Angle:=0;end
  else begin X:=Q[0]/N;Y:=Q[1]/N;Z:=Q[2]/N;Angle:=2*ArcTan2(N,Q[3]);end;
end;
function MInterpolate(const A,B:TMQuaternion;T:Double):TMQuaternion;
var D,Theta,S1,S2,N:Double;I:Integer;C:TMQuaternion;
begin
  C:=B;D:=0;for I:=0 to 3 do D:=D+A[I]*C[I];
  if D<0 then begin D:=-D;for I:=0 to 3 do C[I]:=-C[I];end;
  D:=EnsureRange(D,-1.0,1.0);
  if D>0.9995 then begin S1:=1-T;S2:=T;end
  else begin Theta:=ArcCos(D);S1:=Sin((1-T)*Theta)/Sin(Theta);S2:=Sin(T*Theta)/Sin(Theta);end;
  N:=0;for I:=0 to 3 do begin Result[I]:=A[I]*S1+C[I]*S2;N:=N+Sqr(Result[I]);end;
  N:=Sqrt(N);for I:=0 to 3 do Result[I]:=Result[I]/N;
end;
function QRotate(const Q:TMQuaternion;const V:TMVector):TMVector;
var U,T:TMVector;W:TMVector;
begin
  U:=MVector(Q[0],Q[1],Q[2]);
  T:=MVector(2*(U[1]*V[2]-U[2]*V[1]),2*(U[2]*V[0]-U[0]*V[2]),2*(U[0]*V[1]-U[1]*V[0]));
  W:=MVector(U[1]*T[2]-U[2]*T[1],U[2]*T[0]-U[0]*T[2],U[0]*T[1]-U[1]*T[0]);
  Result:=Add(V,Add(Mul(T,Q[3]),W));
end;
function MSegmentDistance(const P1,Q1,P2,Q2:TMVector):Double;
var D1,D2,R:TMVector;A,E,F,C,B,S,T,D:Double;
begin
  D1:=Sub(Q1,P1);D2:=Sub(Q2,P2);R:=Sub(P1,P2);A:=Dot(D1,D1);E:=Dot(D2,D2);F:=Dot(D2,R);
  if (A<1E-16) and (E<1E-16) then Exit(LengthV(R));
  if A<1E-16 then begin S:=0;T:=EnsureRange(F/E,0.0,1.0);end
  else begin
    C:=Dot(D1,R);
    if E<1E-16 then begin T:=0;S:=EnsureRange(-C/A,0.0,1.0);end
    else begin
      B:=Dot(D1,D2);D:=A*E-B*B;
      if D>1E-16 then S:=EnsureRange((B*F-C*E)/D,0.0,1.0) else S:=0;
      T:=(B*S+F)/E;
      if T<0 then begin T:=0;S:=EnsureRange(-C/A,0.0,1.0);end
      else if T>1 then begin T:=1;S:=EnsureRange((B-C)/A,0.0,1.0);end;
    end;
  end;
  Result:=LengthV(Sub(Add(P1,Mul(D1,S)),Add(P2,Mul(D2,T))));
end;
function Number(O:TJSONObject;const Name:string;Default,Minimum,Maximum:Double):Double;
var D:TJSONData;
begin
  D:=O.Find(Name);if D=nil then Exit(Default);
  if D.JSONType<>jtNumber then raise EConvertError.Create('Numero invalido: '+Name);
  Result:=D.AsFloat;if IsNan(Result) or IsInfinite(Result) or (Result<Minimum) or (Result>Maximum) then raise EConvertError.Create('Numero fora dos limites: '+Name);
end;
function Time(O:TJSONObject;const Name:string;Default:Integer):Integer;
var V:Double;
begin V:=Number(O,Name,Default,0,60000);if V<>Trunc(V) then raise EConvertError.Create('Tempo deve ser inteiro: '+Name);Result:=Round(V);end;
function VectorData(D:TJSONData;const Default:TMVector;Max:Double):TMVector;
var I:Integer;
begin
  Result:=Default;if D=nil then Exit;
  if not (D is TJSONArray) or (D.Count<>3) then raise EConvertError.Create('Vetor deve ter tres numeros');
  for I:=0 to 2 do begin
    if D.Items[I].JSONType<>jtNumber then raise EConvertError.Create('Componente invalido');
    Result[I]:=D.Items[I].AsFloat;
    if IsNan(Result[I]) or IsInfinite(Result[I]) or (Abs(Result[I])>Max) then raise EConvertError.Create('Vetor fora dos limites');
  end;
end;
function ReadRotation(O:TJSONObject;const Key:string):TMQuaternion;
var V:TMVector;
begin
  if O.Find(Key)=nil then raise EConvertError.Create('Rotacao obrigatoria: '+Key);
  V:=VectorData(O.Find(Key),MVector(0,0,0),360);Result:=MQuaternion(V[0],V[1],V[2]);
end;
function ParseMovementTimeline(O:TJSONObject):TMovementTimeline;
var A,K:TJSONData;T,Key:TJSONObject;I,J,N,C:Integer;Seen:TStringList;S:string;V:TMVector;
begin
  Result:=Default(TMovementTimeline);A:=O.Find('members');if A=nil then Exit;
  if not (A is TJSONArray) or (A.Count<1) or (A.Count>192) then raise EConvertError.Create('members deve ter de 1 a 192 membros');
  Result.DurationMS:=Time(O,'duration_ms',1200);Result.TransitionMS:=Time(O,'transition_ms',320);Result.ReturnMS:=Time(O,'return_ms',320);
  if Result.DurationMS<50 then raise EConvertError.Create('Movimento deve durar ao menos 50 ms');
  S:=O.Get('interpolation','smooth');if (S<>'smooth') and (S<>'linear') then raise EConvertError.Create('Interpolacao invalida');Result.Smooth:=S='smooth';
  S:=O.Get('finish','hold');if (S<>'hold') and (S<>'return') then raise EConvertError.Create('Finalizacao invalida');Result.ReturnToStart:=S='return';
  if Result.ReturnToStart and (Result.ReturnMS<50) then raise EConvertError.Create('Retorno deve durar ao menos 50 ms');
  K:=O.Find('collision');if K<>nil then begin
    if not (K is TJSONObject) then raise EConvertError.Create('collision deve ser objeto');
    if not TJSONObject(K).Get('enabled',True) or (TJSONObject(K).Get('on_collision','stop_before_contact')<>'stop_before_contact') then raise EConvertError.Create('Movimentos exigem protecao contra colisao');
  end;
  SetLength(Result.Tracks,A.Count);Seen:=TStringList.Create;
  try
    Seen.CaseSensitive:=True;
    for I:=0 to A.Count-1 do begin
      if not (A.Items[I] is TJSONObject) then raise EConvertError.Create('Membro deve ser objeto');T:=TJSONObject(A.Items[I]);
      with Result.Tracks[I] do begin
        Bone:=T.Get('bone','');if (Bone='') or (Length(Bone)>100) or (Seen.IndexOf(Bone)>=0) then raise EConvertError.Create('Membro ausente ou repetido: '+Bone);Seen.Add(Bone);
        StartMS:=Time(T,'start_ms',0);DurationMS:=Time(T,'duration_ms',Result.DurationMS-StartMS);
        if (DurationMS<1) or (StartMS+DurationMS>Result.DurationMS) then raise EConvertError.Create('Tempo do membro fora do movimento');
        K:=T.Find('keyframes');
        HasRotation:=(T.Find('initial_rotation_deg')<>nil);HasPosition:=(T.Find('initial_position_height')<>nil);HasScale:=(T.Find('initial_scale')<>nil);
        if (K is TJSONArray) and (K.Count>0) and (K.Items[0] is TJSONObject) then begin
          HasRotation:=TJSONObject(K.Items[0]).Find('rotation_deg')<>nil;HasPosition:=TJSONObject(K.Items[0]).Find('position_height')<>nil;HasScale:=TJSONObject(K.Items[0]).Find('scale')<>nil;
        end;
        if not (HasRotation or HasPosition or HasScale) then raise EConvertError.Create('Membro sem rotacao, posicao ou escala');
        if K=nil then begin
          SetLength(Keys,2);Keys[0].TimeMS:=0;if HasRotation then begin CurrentRotation:=(T.Find('initial_rotation_deg').JSONType=jtString) and (T.Get('initial_rotation_deg','')='current');if CurrentRotation then Keys[0].Rotation:=MQuaternion(0,0,0) else Keys[0].Rotation:=ReadRotation(T,'initial_rotation_deg');end;
          Keys[1].TimeMS:=DurationMS;if HasRotation then Keys[1].Rotation:=ReadRotation(T,'final_rotation_deg');
          if HasPosition then begin
            if T.Find('final_position_height')=nil then raise EConvertError.Create('Posicao final obrigatoria');
            CurrentPosition:=(T.Find('initial_position_height').JSONType=jtString) and (T.Get('initial_position_height','')='current');if not CurrentPosition then Keys[0].Position:=VectorData(T.Find('initial_position_height'),MVector(0,0,0),1);Keys[1].Position:=VectorData(T.Find('final_position_height'),MVector(0,0,0),1);
          end;
          if HasScale then begin
            if T.Find('final_scale')=nil then raise EConvertError.Create('Escala final obrigatoria');
            CurrentScale:=(T.Find('initial_scale').JSONType=jtString) and (T.Get('initial_scale','')='current');if not CurrentScale then Keys[0].Scale:=VectorData(T.Find('initial_scale'),MVector(1,1,1),2);Keys[1].Scale:=VectorData(T.Find('final_scale'),MVector(1,1,1),2);
          end;
        end else begin
          if not (K is TJSONArray) or (K.Count<2) or (K.Count>1024) then raise EConvertError.Create('keyframes deve ter de 2 a 1024 pontos');
          SetLength(Keys,K.Count);
          for J:=0 to K.Count-1 do begin
            if not (K.Items[J] is TJSONObject) then raise EConvertError.Create('Ponto deve ser objeto');Key:=TJSONObject(K.Items[J]);
            Keys[J].TimeMS:=Time(Key,'time_ms',-1);if HasRotation then begin
              CurrentRotation:=(J=0) and (Key.Find('rotation_deg')<>nil) and (Key.Find('rotation_deg').JSONType=jtString) and (Key.Get('rotation_deg','')='current') or CurrentRotation;
              if (J=0) and CurrentRotation then Keys[J].Rotation:=MQuaternion(0,0,0) else Keys[J].Rotation:=ReadRotation(Key,'rotation_deg');
            end;
            if HasPosition then begin if Key.Find('position_height')=nil then raise EConvertError.Create('Posicao obrigatoria em todos os pontos');CurrentPosition:=((J=0) and (Key.Find('position_height').JSONType=jtString) and (Key.Get('position_height','')='current')) or CurrentPosition;if not ((J=0) and CurrentPosition) then Keys[J].Position:=VectorData(Key.Find('position_height'),MVector(0,0,0),1);end;
            if HasScale then begin if Key.Find('scale')=nil then raise EConvertError.Create('Escala obrigatoria em todos os pontos');CurrentScale:=((J=0) and (Key.Find('scale').JSONType=jtString) and (Key.Get('scale','')='current')) or CurrentScale;if not ((J=0) and CurrentScale) then Keys[J].Scale:=VectorData(Key.Find('scale'),MVector(1,1,1),2);end;
            if (Keys[J].TimeMS<0) or (Keys[J].TimeMS>DurationMS) or ((J>0) and (Keys[J].TimeMS<=Keys[J-1].TimeMS)) then raise EConvertError.Create('Pontos devem ter tempos crescentes');
          end;
          if (Keys[0].TimeMS<>0) or (Keys[High(Keys)].TimeMS<>DurationMS) then raise EConvertError.Create('Pontos devem incluir inicio e fim do membro');
        end;
        if HasScale then for N:=0 to High(Keys) do for C:=0 to 2 do
          if Keys[N].Scale[C]<=0 then begin
            if not ((N=0) and CurrentScale) then raise EConvertError.Create('Escala deve ser positiva');
          end;
      end;
    end;
  finally Seen.Free;end;
end;
constructor TMovementRuntime.Create;
begin inherited;FIgnore:=TStringList.Create;FIgnore.CaseSensitive:=True;FTranslations:=TStringList.Create;FTranslations.CaseSensitive:=True;end;
destructor TMovementRuntime.Destroy;
begin FIgnore.Free;FTranslations.Free;inherited;end;
function TMovementRuntime.NodeIndex(const Name:string):Integer;
var I:Integer;begin for I:=0 to High(FNodes) do if FNodes[I].Name=Name then Exit(I);Result:=-1;end;
function TMovementRuntime.NodeCount:Integer;begin Result:=Length(FNodes);end;
function TMovementRuntime.NodeName(Index:Integer):string;begin Result:=FNodes[Index].Name;end;
function TMovementRuntime.RestPose:TMPoseArray;
var I:Integer;begin Result:=nil;SetLength(Result,Length(FNodes));for I:=0 to High(FNodes) do Result[I]:=FNodes[I].Rest;end;
procedure TMovementRuntime.LoadRig(const FileName,CollisionFile:string;Height:Double);
var L:TStringList;R,C:TJSONData;Nodes,Bodies,Pairs:TJSONArray;O:TJSONObject;I,J,P:Integer;D:TJSONData;Q:TMQuaternion;N:Double;Pair:string;W:TMWorldArray;
begin
  FHeight:=Height;R:=nil;C:=nil;L:=TStringList.Create;FIgnore.Clear;FTranslations.Clear;Clear;
  try
    L.LoadFromFile(FileName);R:=GetJSON(L.Text);Nodes:=TJSONObject(R).Arrays['nodes'];
    if Nodes.Count>4096 then raise EConvertError.Create('Esqueleto grande demais');SetLength(FNodes,Nodes.Count);
    for I:=0 to High(FNodes) do begin
      O:=TJSONObject(Nodes[I]);FNodes[I].Name:=O.Get('name','');FNodes[I].Parent:=-1;
      if O.Find('matrix')<>nil then raise EConvertError.Create('Rig com matrizes nao suportado pelo protetor de movimentos');
      FNodes[I].Rest.Position:=VectorData(O.Find('translation'),MVector(0,0,0),10000);
      FNodes[I].Rest.Scale:=VectorData(O.Find('scale'),MVector(1,1,1),100);
      for J:=0 to 2 do if Abs(FNodes[I].Rest.Scale[J]-1)>1E-6 then raise EConvertError.Create('Rig escalonado exige normalizacao antes da protecao de movimentos');
      Q:=MQuaternion(0,0,0);D:=O.Find('rotation');
      if D<>nil then begin
        if not (D is TJSONArray) or (D.Count<>4) then raise EConvertError.Create('Quaternion invalido');
        N:=0;for J:=0 to 3 do begin Q[J]:=D.Items[J].AsFloat;N:=N+Sqr(Q[J]);end;
        if IsNan(N) or IsInfinite(N) or (N<1E-16) then raise EConvertError.Create('Quaternion invalido');
        for J:=0 to 3 do Q[J]:=Q[J]/Sqrt(N);
      end;
      FNodes[I].Rest.Rotation:=Q;
    end;
    for I:=0 to Nodes.Count-1 do begin
      D:=TJSONObject(Nodes[I]).Find('children');if D=nil then Continue;
      for J:=0 to D.Count-1 do begin P:=D.Items[J].AsInteger;if (P<0) or (P>=Length(FNodes)) or (FNodes[P].Parent>=0) then raise EConvertError.Create('Hierarquia invalida');FNodes[P].Parent:=I;end;
    end;
    for I:=0 to High(FNodes) do begin P:=I;J:=0;while P>=0 do begin Inc(J);if J>Length(FNodes) then raise EConvertError.Create('Ciclo no esqueleto');P:=FNodes[P].Parent;end;end;
    L.LoadFromFile(CollisionFile);C:=GetJSON(L.Text);O:=TJSONObject(C);
    if O.Get('version',0)<>1 then raise EConvertError.Create('Perfil de colisao invalido');
    D:=O.Find('reference_heights');if D<>nil then begin
      if not (D is TJSONObject) then raise EConvertError.Create('reference_heights deve ser um objeto');
      Height:=Number(TJSONObject(D),ExtractFileName(ExtractFileDir(FileName)),Height,0.01,10000);
      FHeight:=Height;
    end;
    D:=O.Find('translatable_members');if D<>nil then for I:=0 to D.Count-1 do FTranslations.Add(D.Items[I].AsString);
    FMargin:=Number(O,'margin_height',0.002,0.0005,0.02)*Height;Bodies:=O.Arrays['bodies'];
    if (Bodies.Count<1) or (Bodies.Count>64) then raise EConvertError.Create('Perfil exige de 1 a 64 volumes');SetLength(FShapes,Bodies.Count);
    for I:=0 to Bodies.Count-1 do begin
      O:=TJSONObject(Bodies[I]);with FShapes[I] do begin
        ID:=O.Get('id','');StartBone:=O.Get('start_bone','');EndBone:=O.Get('end_bone',StartBone);A:=NodeIndex(StartBone);B:=NodeIndex(EndBone);
        if (ID='') or (A<0) or (B<0) then raise EConvertError.Create('Volume sem osso: '+ID);
        Radius:=Number(O,'radius_height',0,0.001,0.25)*Height;if Radius<=0 then raise EConvertError.Create('Raio obrigatorio: '+ID);
        StartFraction:=Number(O,'start_fraction',0,0,1);EndFraction:=Number(O,'end_fraction',1,0,1);
        StartOffset:=Mul(VectorData(O.Find('start_offset_height'),MVector(0,0,0),1),Height);
        EndOffset:=Mul(VectorData(O.Find('end_offset_height'),MVector(0,0,0),1),Height);
      end;
    end;
    D:=TJSONObject(C).Find('ignored_pairs');if D<>nil then for I:=0 to D.Count-1 do begin
      if not (D.Items[I] is TJSONArray) or (D.Items[I].Count<>2) then raise EConvertError.Create('Par ignorado invalido');
      FIgnore.Add(D.Items[I].Items[0].AsString+'|'+D.Items[I].Items[1].AsString);
      FIgnore.Add(D.Items[I].Items[1].AsString+'|'+D.Items[I].Items[0].AsString);
    end;
    FCurrent:=RestPose;
    if Clearance(FCurrent,Pair)<0 then raise EConvertError.Create('Volumes sobrepostos na pose inicial: '+Pair);
  finally L.Free;R.Free;C.Free;end;
end;
function TMovementRuntime.Worlds(const Pose:TMPoseArray):TMWorldArray;
var Done:array of Boolean;I:Integer;
  procedure Visit(N:Integer);
  var P,K:Integer;V:TMVector;
  begin
    if Done[N] then Exit;P:=FNodes[N].Parent;
    if P<0 then begin Result[N].Position:=Pose[N].Position;Result[N].Rotation:=Pose[N].Rotation;Result[N].Scale:=Pose[N].Scale;end
    else begin
      Visit(P);V:=Pose[N].Position;for K:=0 to 2 do V[K]:=V[K]*Result[P].Scale[K];
      Result[N].Position:=Add(Result[P].Position,QRotate(Result[P].Rotation,V));
      Result[N].Rotation:=QMul(Result[P].Rotation,Pose[N].Rotation);
      for K:=0 to 2 do Result[N].Scale[K]:=Result[P].Scale[K]*Pose[N].Scale[K];
    end;Done[N]:=True;
  end;
begin
  Result:=nil;SetLength(Result,Length(FNodes));SetLength(Done,Length(FNodes));for I:=0 to High(FNodes) do Visit(I);
end;
procedure TMovementRuntime.Capsule(const C:TMCapsule;const W:TMWorldArray;out A,B:TMVector);
var D:TMVector;
begin
  D:=Sub(W[C.B].Position,W[C.A].Position);
  A:=Add(Add(W[C.A].Position,Mul(D,C.StartFraction)),QRotate(W[C.A].Rotation,C.StartOffset));
  B:=Add(Add(W[C.A].Position,Mul(D,C.EndFraction)),QRotate(W[C.B].Rotation,C.EndOffset));
end;
function TMovementRuntime.Clearance(const Pose:TMPoseArray;out Pair:string):Double;
var W:TMWorldArray;I,J:Integer;A,B,C,D:TMVector;Distance:Double;
begin
  W:=Worlds(Pose);Result:=1E20;Pair:='';
  for I:=0 to High(FShapes) do for J:=I+1 to High(FShapes) do begin
    if FIgnore.IndexOf(FShapes[I].ID+'|'+FShapes[J].ID)>=0 then Continue;
    Capsule(FShapes[I],W,A,B);Capsule(FShapes[J],W,C,D);
    Distance:=MSegmentDistance(A,B,C,D)-FShapes[I].Radius-FShapes[J].Radius-FMargin;
    if Distance<Result then begin Result:=Distance;Pair:=FShapes[I].ID+' / '+FShapes[J].ID;end;
  end;
end;
function TMovementRuntime.MotionBound(const A,B:TMPoseArray;Index:Integer;Offset:Double):Double;
var N,K:Integer;D,Angle,Reach,Scale,NormA,NormB:Double;
begin
  Result:=0;Reach:=Offset;N:=Index;Scale:=1;
  while N>=0 do begin
    D:=0;NormA:=0;NormB:=0;for K:=0 to 3 do begin D:=D+A[N].Rotation[K]*B[N].Rotation[K];NormA:=NormA+Sqr(A[N].Rotation[K]);NormB:=NormB+Sqr(B[N].Rotation[K]);end;D:=Abs(D)/Sqrt(NormA*NormB);if D>1-1E-14 then Angle:=0 else Angle:=2*ArcCos(EnsureRange(D,0.0,1.0));
    Result:=Result+Angle*Reach+LengthV(Sub(A[N].Position,B[N].Position))*Scale;
    Reach:=Reach+Max(LengthV(A[N].Position),LengthV(B[N].Position))*Scale;
    for K:=0 to 2 do Scale:=Max(Scale,Max(Abs(A[N].Scale[K]),Abs(B[N].Scale[K])));
    N:=FNodes[N].Parent;
  end;
end;
function BlendPose(const A,B:TMPoseArray;T:Double):TMPoseArray;
var I,K:Integer;
begin
  Result:=Copy(A);for I:=0 to High(Result) do begin Result[I].Rotation:=MInterpolate(A[I].Rotation,B[I].Rotation,T);
    for K:=0 to 2 do begin Result[I].Position[K]:=A[I].Position[K]+(B[I].Position[K]-A[I].Position[K])*T;Result[I].Scale[K]:=A[I].Scale[K]+(B[I].Scale[K]-A[I].Scale[K])*T;end;
  end;
end;
function TMovementRuntime.CertifyInterval(const A,B,Mid:TMPoseArray;out Pair:string):Integer;
var WM,WE:TMWorldArray;Bounds:array of Double;MA,MB,MC,MD,EA,EB,EC,ED:TMVector;
  I,J:Integer;Gap,EndGap:Double;
begin
  WM:=Worlds(Mid);WE:=Worlds(B);SetLength(Bounds,Length(FShapes));
  for I:=0 to High(FShapes) do Bounds[I]:=Max(MotionBound(A,B,FShapes[I].A,Max(LengthV(FShapes[I].StartOffset),LengthV(FShapes[I].EndOffset))),MotionBound(A,B,FShapes[I].B,Max(LengthV(FShapes[I].StartOffset),LengthV(FShapes[I].EndOffset))));
  Result:=1;Pair:='';
  for I:=0 to High(FShapes) do for J:=I+1 to High(FShapes) do begin
    if FIgnore.IndexOf(FShapes[I].ID+'|'+FShapes[J].ID)>=0 then Continue;
    Capsule(FShapes[I],WM,MA,MB);Capsule(FShapes[J],WM,MC,MD);
    Capsule(FShapes[I],WE,EA,EB);Capsule(FShapes[J],WE,EC,ED);
    Gap:=MSegmentDistance(MA,MB,MC,MD)-FShapes[I].Radius-FShapes[J].Radius-FMargin;
    EndGap:=MSegmentDistance(EA,EB,EC,ED)-FShapes[I].Radius-FShapes[J].Radius-FMargin;
    if (Gap<0) or (EndGap<0) then begin Pair:=FShapes[I].ID+' / '+FShapes[J].ID;Exit(0);end;
    if Gap<=Bounds[I]+Bounds[J] then begin Pair:=FShapes[I].ID+' / '+FShapes[J].ID;Result:=-1;end;
  end;
end;
function TMovementRuntime.SafeInterval(const A,B:TMPoseArray;Depth:Integer;out Pair:string):Boolean;
var Mid:TMPoseArray;Certified:Integer;
begin
  Mid:=BlendPose(A,B,0.5);Certified:=CertifyInterval(A,B,Mid,Pair);
  if Certified=1 then Exit(True);if (Certified=0) or (Depth>=16) then Exit(False);
  Result:=SafeInterval(A,Mid,Depth+1,Pair) and SafeInterval(Mid,B,Depth+1,Pair);
end;
function TMovementRuntime.MinimumClearance:Double;
var Pair:string;
begin Result:=Clearance(FCurrent,Pair);end;
procedure TMovementRuntime.Capture(const Pose:TMPoseArray);
var Pair:string;
begin
  if Length(Pose)<>Length(FNodes) then raise EConvertError.Create('Pose incompleta');
  if Clearance(Pose,Pair)<0 then raise EConvertError.Create('Pose inicial em colisao: '+Pair);
  FCurrent:=Copy(Pose);
end;
function TMovementRuntime.Guard(const Candidate:TMPoseArray):Boolean;
var Pair:string;Lo,Hi,M:Double;I:Integer;Test:TMPoseArray;
begin
  Result:=SafeInterval(FCurrent,Candidate,0,Pair);
  if Result then begin FCurrent:=Copy(Candidate);Exit;end;
  Lo:=0;Hi:=1;
  for I:=1 to 12 do begin M:=(Lo+Hi)/2;Test:=BlendPose(FCurrent,Candidate,M);if SafeInterval(FCurrent,Test,0,Pair) then Lo:=M else Hi:=M;end;
  FBlocked:=Pair;Inc(FBlocks);FCurrent:=BlendPose(FCurrent,Candidate,Lo);
end;
procedure TMovementRuntime.Start(const Timeline:TMovementTimeline);
var I,J,P,K:Integer;Inv:TMQuaternion;
begin
  if Length(FNodes)=0 then raise EConvertError.Create('Protetor de movimentos nao preparado');
  FTimeline:=Timeline;FTimeline.Tracks:=Copy(Timeline.Tracks);
  for I:=0 to High(FTimeline.Tracks) do FTimeline.Tracks[I].Keys:=Copy(Timeline.Tracks[I].Keys);
  SetLength(FIndexes,Length(Timeline.Tracks));
  for I:=0 to High(FIndexes) do begin
    FIndexes[I]:=NodeIndex(Timeline.Tracks[I].Bone);if FIndexes[I]<0 then raise EConvertError.Create('Membro ausente: '+Timeline.Tracks[I].Bone);
    if Timeline.Tracks[I].HasPosition and (FTranslations.IndexOf(Timeline.Tracks[I].Bone)<0) then raise EConvertError.Create('Translacao proibida para preservar o comprimento do membro: '+Timeline.Tracks[I].Bone);
    if Timeline.Tracks[I].HasScale then for J:=0 to High(FShapes) do begin
      P:=FShapes[J].A;while P>=0 do begin if P=FIndexes[I] then raise EConvertError.Create('Escala de membro protegido proibida');P:=FNodes[P].Parent;end;
      P:=FShapes[J].B;while P>=0 do begin if P=FIndexes[I] then raise EConvertError.Create('Escala de membro protegido proibida');P:=FNodes[P].Parent;end;
    end;
  end;
  for I:=0 to High(FIndexes) do begin
    P:=FIndexes[I];
    if FTimeline.Tracks[I].CurrentRotation then begin
      Inv:=FNodes[P].Rest.Rotation;for K:=0 to 2 do Inv[K]:=-Inv[K];FTimeline.Tracks[I].Keys[0].Rotation:=QMul(Inv,FCurrent[P].Rotation);
    end;
    for K:=0 to 2 do begin
      if FTimeline.Tracks[I].CurrentPosition then FTimeline.Tracks[I].Keys[0].Position[K]:=(FCurrent[P].Position[K]-FNodes[P].Rest.Position[K])/FHeight;
      if FTimeline.Tracks[I].CurrentScale then FTimeline.Tracks[I].Keys[0].Scale[K]:=FCurrent[P].Scale[K];
    end;
  end;
  FIncoming:=Copy(FCurrent);FElapsed:=0;FHasPose:=True;FRunning:=True;FBlocked:='';FBlocks:=0;
  if Timeline.TransitionMS=0 then if not Guard(Evaluate(0)) then FRunning:=False;
end;
function TMovementRuntime.Evaluate(TimeMS:Double):TMPoseArray;
var I,J,N,K:Integer;T,Local,ReturnT,EntryT:Double;V:TMVector;Q:TMQuaternion;Track:TMTrack;
begin
  Result:=Copy(FIncoming);T:=TimeMS-FTimeline.TransitionMS;
  ReturnT:=0;if T>FTimeline.DurationMS then begin if FTimeline.ReturnMS>0 then ReturnT:=EnsureRange((T-FTimeline.DurationMS)/FTimeline.ReturnMS,0.0,1.0);T:=FTimeline.DurationMS;end;
  for I:=0 to High(FTimeline.Tracks) do begin
    Track:=FTimeline.Tracks[I];Local:=EnsureRange(T-Track.StartMS,0.0,Double(Track.DurationMS));
    J:=0;while (J<High(Track.Keys)-1) and (Track.Keys[J+1].TimeMS<Local) do Inc(J);
    Local:=(Local-Track.Keys[J].TimeMS)/(Track.Keys[J+1].TimeMS-Track.Keys[J].TimeMS);
    if FTimeline.Smooth then Local:=Local*Local*(3-2*Local);
    N:=FIndexes[I];EntryT:=1;if TimeMS<FTimeline.TransitionMS then EntryT:=TimeMS/FTimeline.TransitionMS;
    if Track.HasRotation then begin
      if Track.ScalarAxis in ['x','y','z'] then begin
        EntryT:=Track.Keys[J].Angle+(Track.Keys[J+1].Angle-Track.Keys[J].Angle)*Local;
        case Track.ScalarAxis of
          'x':Q:=MQuaternion(EntryT,0,0);'y':Q:=MQuaternion(0,EntryT,0);'z':Q:=MQuaternion(0,0,EntryT);
        end;
        EntryT:=1;if TimeMS<FTimeline.TransitionMS then EntryT:=TimeMS/FTimeline.TransitionMS;
      end else Q:=MInterpolate(Track.Keys[J].Rotation,Track.Keys[J+1].Rotation,Local);
      Q:=QMul(FNodes[N].Rest.Rotation,Q);
      Q:=MInterpolate(FIncoming[N].Rotation,Q,EntryT);
      if FTimeline.ReturnToStart and (ReturnT>0) then Q:=MInterpolate(Q,FIncoming[N].Rotation,ReturnT);Result[N].Rotation:=Q;
    end;
    for K:=0 to 2 do begin
      if Track.HasPosition then begin
        V[K]:=FNodes[N].Rest.Position[K]+FHeight*(Track.Keys[J].Position[K]+(Track.Keys[J+1].Position[K]-Track.Keys[J].Position[K])*Local);
        V[K]:=FIncoming[N].Position[K]+(V[K]-FIncoming[N].Position[K])*EntryT;
        if FTimeline.ReturnToStart then V[K]:=V[K]+(FIncoming[N].Position[K]-V[K])*ReturnT;Result[N].Position[K]:=V[K];
      end;
      if Track.HasScale then begin
        V[K]:=Track.Keys[J].Scale[K]+(Track.Keys[J+1].Scale[K]-Track.Keys[J].Scale[K])*Local;
        V[K]:=FIncoming[N].Scale[K]+(V[K]-FIncoming[N].Scale[K])*EntryT;
        if FTimeline.ReturnToStart then V[K]:=V[K]+(FIncoming[N].Scale[K]-V[K])*ReturnT;Result[N].Scale[K]:=V[K];
      end;
    end;
  end;
end;
function TMovementRuntime.NextBoundary(TimeMS,Limit:Double):Double;
var I,J:Integer;T:Double;
begin
  Result:=Limit;T:=FTimeline.TransitionMS;if (T>TimeMS+1E-7) and (T<Result) then Result:=T;
  for I:=0 to High(FTimeline.Tracks) do for J:=0 to High(FTimeline.Tracks[I].Keys) do begin
    T:=FTimeline.TransitionMS+FTimeline.Tracks[I].StartMS+FTimeline.Tracks[I].Keys[J].TimeMS;
    if (T>TimeMS+1E-7) and (T<Result) then Result:=T;
  end;
  T:=FTimeline.TransitionMS+FTimeline.DurationMS;if (T>TimeMS+1E-7) and (T<Result) then Result:=T;
end;
function TMovementRuntime.SafeTimelineInterval(A,B:Double;Depth:Integer;out Pair:string):Boolean;
var PA,PB,PM:TMPoseArray;Certified:Integer;
begin
  PA:=Evaluate(A);PB:=Evaluate(B);PM:=Evaluate((A+B)/2);Certified:=CertifyInterval(PA,PB,PM,Pair);
  if Certified=1 then Exit(True);if (Certified=0) or (Depth>=16) then Exit(False);
  Result:=SafeTimelineInterval(A,(A+B)/2,Depth+1,Pair) and SafeTimelineInterval((A+B)/2,B,Depth+1,Pair);
end;
procedure TMovementRuntime.Advance(Milliseconds:Double);
var Limit,Next,Total,Lo,Hi,Mid,Remaining:Double;Candidate:TMPoseArray;Pair:string;I:Integer;
begin
  if not FRunning or (Milliseconds<=0) then Exit;
  Total:=FTimeline.DurationMS+FTimeline.TransitionMS;if FTimeline.ReturnToStart then Total:=Total+FTimeline.ReturnMS;
  Remaining:=Milliseconds;
  repeat
  Limit:=Min(Total,FElapsed+Remaining);Remaining:=Max(0,Remaining-(Limit-FElapsed));
  while FElapsed<Limit-1E-7 do begin
    Next:=NextBoundary(FElapsed,Min(Limit,FElapsed+10));Candidate:=Evaluate(Next);
    if not SafeTimelineInterval(FElapsed,Next,0,Pair) then begin
      FBlocked:=Pair;Inc(FBlocks);Lo:=FElapsed;Hi:=Next;
      for I:=1 to 12 do begin Mid:=(Lo+Hi)/2;if SafeTimelineInterval(FElapsed,Mid,0,Pair) then Lo:=Mid else Hi:=Mid;end;
      FElapsed:=Max(FElapsed,Lo-0.1);FCurrent:=Evaluate(FElapsed);FRunning:=False;Exit;
    end;
    FCurrent:=Candidate;FElapsed:=Next;
  end;
  if FElapsed>=Total-1E-7 then begin
    if FTimeline.Looping then begin
      FElapsed:=0;
      if not Guard(Evaluate(0)) then begin FRunning:=False;Exit;end;
    end else FRunning:=False;
  end;
  until (Remaining<1E-7) or not FRunning;
end;
procedure TMovementRuntime.Clear;
begin FHasPose:=False;FRunning:=False;FElapsed:=0;FBlocked:='';FBlocks:=0;FTimeline:=Default(TMovementTimeline);end;
end.
