unit movement_animation;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
type
  TMotionKeyframe = record
    TimeMS: Integer;
    Angle: Double;
  end;
  TMotionKeyframes = array of TMotionKeyframe;
  TMotionTrack = record
    Bone: string;
    Axis: Char;
    Keys: TMotionKeyframes;
  end;
  TMotionTracks = array of TMotionTrack;
  TMotionAnimation = record
    Name: string;
    DurationMS: Integer;
    Looping, ReturnToBase, Smooth: Boolean;
    Tracks: TMotionTracks;
  end;
function LoadMotionAnimation(const FileName: string): TMotionAnimation;
function MotionAngleAt(const Track: TMotionTrack; TimeMS: Integer; Smooth: Boolean): Double;
implementation
uses Math, fpjson, jsonparser, presentation_joint_tags;
function RequireObject(D: TJSONData; const LabelName: string): TJSONObject;
begin
  if not (D is TJSONObject) then raise EConvertError.Create(LabelName+' deve ser objeto');
  Result:=TJSONObject(D);
end;
function RequireArray(D: TJSONData; const LabelName: string): TJSONArray;
begin
  if not (D is TJSONArray) then raise EConvertError.Create(LabelName+' deve ser lista');
  Result:=TJSONArray(D);
end;
function StringValue(O: TJSONObject; const Key: string; const DefaultValue: string=''): string;
var D: TJSONData;
begin
  D:=O.Find(Key);if D=nil then Exit(DefaultValue);
  if D.JSONType<>jtString then raise EConvertError.Create('Texto invalido: '+Key);
  Result:=D.AsString;
end;
function IntegerValue(O: TJSONObject; const Key: string; MinValue, MaxValue: Integer): Integer;
var D: TJSONData; V: Double;
begin
  D:=O.Find(Key);
  if (D=nil) or (D.JSONType<>jtNumber) then raise EConvertError.Create('Numero ausente: '+Key);
  V:=D.AsFloat;
  if IsNan(V) or IsInfinite(V) or (V<MinValue) or (V>MaxValue) or (V<>Trunc(V)) then
    raise EConvertError.Create('Numero invalido: '+Key);
  Result:=Trunc(V);
end;
function BooleanValue(O: TJSONObject; const Key: string; DefaultValue: Boolean): Boolean;
var D: TJSONData;
begin
  D:=O.Find(Key);if D=nil then Exit(DefaultValue);
  if D.JSONType<>jtBoolean then raise EConvertError.Create('Booleano invalido: '+Key);
  Result:=D.AsBoolean;
end;
function LoadMotionAnimation(const FileName: string): TMotionAnimation;
var S: TStringList; Root,D: TJSONData; O,TOBJ,KO: TJSONObject;
  Tracks,Keys: TJSONArray; I,J,K,LastTime: Integer; Axis,Interp: string; A,Limit: Double;
begin
  Result:=Default(TMotionAnimation);
  if not FileExists(FileName) then raise EConvertError.Create('Animacao ausente: '+FileName);
  S:=TStringList.Create;Root:=nil;
  try
    if FileSize(FileName)>1024*1024 then raise EConvertError.Create('Animacao excede 1 MiB');
    S.LoadFromFile(FileName);Root:=GetJSON(S.Text);
    O:=RequireObject(Root,'Animacao');
    if StringValue(O,'format')<>'assistente-motion' then raise EConvertError.Create('Formato de animacao invalido');
    if IntegerValue(O,'version',1,1)<>1 then raise EConvertError.Create('Versao invalida');
    Result.Name:=StringValue(O,'name');
    Result.DurationMS:=IntegerValue(O,'duration_ms',50,60000);
    Result.Looping:=BooleanValue(O,'loop',False);
    Result.ReturnToBase:=BooleanValue(O,'return_to_base',True);
    Interp:=StringValue(O,'interpolation','smoothstep');
    if (Interp<>'smoothstep') and (Interp<>'linear') then raise EConvertError.Create('Interpolacao invalida');
    Result.Smooth:=Interp='smoothstep';
    Tracks:=RequireArray(O.Find('tracks'),'tracks');
    if (Tracks.Count=0) or (Tracks.Count>64) then raise EConvertError.Create('Quantidade de trilhas invalida');
    SetLength(Result.Tracks,Tracks.Count);
    for I:=0 to Tracks.Count-1 do begin
      TOBJ:=RequireObject(Tracks.Items[I],'trilha');
      Result.Tracks[I].Bone:=StringValue(TOBJ,'bone');
      Limit:=JointAngleLimit(Result.Tracks[I].Bone);
      if Limit<=0 then raise EConvertError.Create('Articulacao invalida: '+Result.Tracks[I].Bone);
      for K:=0 to I-1 do
        if Result.Tracks[K].Bone=Result.Tracks[I].Bone then
          raise EConvertError.Create('Articulacao duplicada');
      Axis:=StringValue(TOBJ,'axis');
      if (Length(Axis)<>1) or not (Axis[1] in ['x','y','z']) then
        raise EConvertError.Create('Eixo invalido');
      Result.Tracks[I].Axis:=Axis[1];
      Keys:=RequireArray(TOBJ.Find('keyframes'),'keyframes');
      if (Keys.Count<2) or (Keys.Count>256) then raise EConvertError.Create('Quadros-chave invalidos');
      SetLength(Result.Tracks[I].Keys,Keys.Count);
      LastTime:=-1;
      for J:=0 to Keys.Count-1 do begin
        KO:=RequireObject(Keys.Items[J],'quadro-chave');
        K:=IntegerValue(KO,'time_ms',0,Result.DurationMS);
        if K<=LastTime then raise EConvertError.Create('Tempos devem ser crescentes');
        LastTime:=K;
        D:=KO.Find('angle');
        if (D=nil) or (D.JSONType<>jtNumber) then raise EConvertError.Create('Angulo ausente');
        A:=D.AsFloat;
        if IsNan(A) or IsInfinite(A) or (Abs(A)>Limit) then
          raise EConvertError.Create('Angulo fora do limite');
        Result.Tracks[I].Keys[J].TimeMS:=K;
        Result.Tracks[I].Keys[J].Angle:=A;
      end;
    end;
  finally Root.Free;S.Free;end;
end;
function MotionAngleAt(const Track: TMotionTrack; TimeMS: Integer; Smooth: Boolean): Double;
var I: Integer; T: Double;
begin
  if Length(Track.Keys)=0 then Exit(0);
  if TimeMS<=Track.Keys[0].TimeMS then Exit(Track.Keys[0].Angle);
  for I:=1 to High(Track.Keys) do if TimeMS<=Track.Keys[I].TimeMS then begin
    T:=(TimeMS-Track.Keys[I-1].TimeMS)/(Track.Keys[I].TimeMS-Track.Keys[I-1].TimeMS);
    if Smooth then T:=T*T*(3-2*T);
    Exit(Track.Keys[I-1].Angle+(Track.Keys[I].Angle-Track.Keys[I-1].Angle)*T);
  end;
  Result:=Track.Keys[High(Track.Keys)].Angle;
end;
end.
