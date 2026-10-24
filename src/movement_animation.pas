unit movement_animation;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, movement_timeline;
type
  TMotionKeyframe = record
    TimeMS: Integer;
    Angle: Double;
    Rotation:TMVector; { Degrees XYZ when track.Axis = #0 (format v2). }
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
procedure SaveMotionAnimation(const FileName: string; const Animation: TMotionAnimation);
function LoadMotionAnimation(const FileName: string): TMotionAnimation;
function MotionTimeline(const Animation: TMotionAnimation; TransitionMS: Integer = 320): TMovementTimeline;
function MotionAngleAt(const Track: TMotionTrack; TimeMS: Integer; Smooth: Boolean): Double;
function MotionRotationAt(const Track:TMotionTrack;TimeMS:Integer;Smooth:Boolean):TMQuaternion;
function MotionEulerAt(const Track:TMotionTrack;TimeMS:Integer;Smooth:Boolean):TMVector;
implementation
uses {$IFDEF MSWINDOWS}Windows,{$ENDIF} Math, fpjson, jsonparser, presentation_joint_tags;
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
  Tracks,Keys,Angles: TJSONArray; I,J,K,C,Version,LastTime: Integer; Axis,Interp: string; A,Limit: Double;
begin
  Result:=Default(TMotionAnimation);
  if not FileExists(FileName) then raise EConvertError.Create('Animacao ausente: '+FileName);
  S:=TStringList.Create;Root:=nil;
  try
    S.LoadFromFile(FileName);
    if Length(S.Text)>1024*1024 then raise EConvertError.Create('Animacao excede 1 MiB');
    Root:=GetJSON(S.Text);
    O:=RequireObject(Root,'Animacao');
    if StringValue(O,'format')<>'assistente-motion' then raise EConvertError.Create('Formato de animacao invalido');
    Version:=IntegerValue(O,'version',1,2);
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
      if (Version=2) and (Axis='xyz') then Result.Tracks[I].Axis:=#0
      else begin
        if (Length(Axis)<>1) or not (Axis[1] in ['x','y','z']) then raise EConvertError.Create('Eixo invalido');
        Result.Tracks[I].Axis:=Axis[1];
      end;
      Keys:=RequireArray(TOBJ.Find('keyframes'),'keyframes');
      if (Keys.Count<2) or (Keys.Count>256) then raise EConvertError.Create('Quadros-chave invalidos');
      SetLength(Result.Tracks[I].Keys,Keys.Count);
      LastTime:=-1;
      for J:=0 to Keys.Count-1 do begin
        KO:=RequireObject(Keys.Items[J],'quadro-chave');
        K:=IntegerValue(KO,'time_ms',0,Result.DurationMS);
        if K<=LastTime then raise EConvertError.Create('Tempos devem ser crescentes');
        LastTime:=K;
        Result.Tracks[I].Keys[J].TimeMS:=K;
        if Result.Tracks[I].Axis=#0 then begin
          Angles:=RequireArray(KO.Find('rotation_deg'),'rotation_deg');
          if Angles.Count<>3 then raise EConvertError.Create('Rotacao XYZ exige tres angulos');
          for C:=0 to 2 do begin
            D:=Angles.Items[C];
            if D.JSONType<>jtNumber then raise EConvertError.Create('Angulo XYZ invalido');
            A:=D.AsFloat;
            if IsNan(A) or IsInfinite(A) or (Abs(A)>Limit) then raise EConvertError.Create('Angulo fora do limite');
            Result.Tracks[I].Keys[J].Rotation[C]:=A;
          end;
          Continue;
        end;
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
procedure SaveMotionAnimation(const FileName: string; const Animation: TMotionAnimation);
var Root,Track,Key:TJSONObject;Tracks,Keys,Angles:TJSONArray;I,J,C,Version:Integer;
  Text:TStringList;TempName:string;ID:TGUID;Source,Backup:TFileStream;
begin
  CreateGUID(ID);TempName:=FileName+'.'+GUIDToString(ID)+'.tmp';
  Root:=TJSONObject.Create;Text:=TStringList.Create;
  try
    Version:=1;for I:=0 to High(Animation.Tracks) do if Animation.Tracks[I].Axis=#0 then Version:=2;
    Root.Add('format','assistente-motion');Root.Add('version',Version);Root.Add('name',Animation.Name);
    Root.Add('duration_ms',Animation.DurationMS);Root.Add('loop',Animation.Looping);
    Root.Add('return_to_base',Animation.ReturnToBase);
    if Animation.Smooth then Root.Add('interpolation','smoothstep') else Root.Add('interpolation','linear');
    Tracks:=TJSONArray.Create;Root.Add('tracks',Tracks);
    for I:=0 to High(Animation.Tracks) do begin
      Track:=TJSONObject.Create;Tracks.Add(Track);Track.Add('bone',Animation.Tracks[I].Bone);
      if Animation.Tracks[I].Axis=#0 then Track.Add('axis','xyz') else Track.Add('axis',string(Animation.Tracks[I].Axis));
      Keys:=TJSONArray.Create;Track.Add('keyframes',Keys);
      for J:=0 to High(Animation.Tracks[I].Keys) do begin
        Key:=TJSONObject.Create;Keys.Add(Key);Key.Add('time_ms',Animation.Tracks[I].Keys[J].TimeMS);
        if Animation.Tracks[I].Axis=#0 then begin
          Angles:=TJSONArray.Create;Key.Add('rotation_deg',Angles);
          for C:=0 to 2 do Angles.Add(Animation.Tracks[I].Keys[J].Rotation[C]);
        end else Key.Add('angle',Animation.Tracks[I].Keys[J].Angle);
      end;
    end;
    Text.Text:=Root.FormatJSON;Text.SaveToFile(TempName);
    LoadMotionAnimation(TempName); // Validate the complete file before touching the destination.
    if FileExists(FileName) then begin
      Source:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
      try
        Backup:=TFileStream.Create(FileName+'.bak',fmCreate);
        try Backup.CopyFrom(Source,0);finally Backup.Free;end;
      finally Source.Free;end;
    end;
    {$IFDEF MSWINDOWS}
    if not MoveFileEx(PChar(TempName),PChar(FileName),MOVEFILE_REPLACE_EXISTING or $8 { MOVEFILE_WRITE_THROUGH }) then
      RaiseLastOSError;
    {$ELSE}
    if not RenameFile(TempName,FileName) then raise EInOutError.Create('Falha ao finalizar gravacao');
    {$ENDIF}
  finally
    if FileExists(TempName) then SysUtils.DeleteFile(TempName);
    Text.Free;Root.Free;
  end;
end;
function MotionTimeline(const Animation: TMotionAnimation; TransitionMS: Integer): TMovementTimeline;
var I,J: Integer;
begin
  Result:=Default(TMovementTimeline);
  Result.DurationMS:=Animation.DurationMS;Result.TransitionMS:=TransitionMS;
  Result.ReturnMS:=Max(50,TransitionMS);Result.ReturnToStart:=Animation.ReturnToBase;
  Result.Smooth:=Animation.Smooth;Result.Looping:=Animation.Looping;
  SetLength(Result.Tracks,Length(Animation.Tracks));
  for I:=0 to High(Animation.Tracks) do begin
    Result.Tracks[I].Bone:=Animation.Tracks[I].Bone;Result.Tracks[I].ScalarAxis:=Animation.Tracks[I].Axis;
    Result.Tracks[I].DurationMS:=Animation.DurationMS;Result.Tracks[I].HasRotation:=True;
    SetLength(Result.Tracks[I].Keys,Length(Animation.Tracks[I].Keys)+2);
    for J:=0 to High(Result.Tracks[I].Keys) do begin
      if J=0 then Result.Tracks[I].Keys[J].TimeMS:=0
      else if J=High(Result.Tracks[I].Keys) then Result.Tracks[I].Keys[J].TimeMS:=Animation.DurationMS
      else Result.Tracks[I].Keys[J].TimeMS:=Animation.Tracks[I].Keys[J-1].TimeMS;
      Result.Tracks[I].Keys[J].Angle:=MotionAngleAt(Animation.Tracks[I],Result.Tracks[I].Keys[J].TimeMS,Animation.Smooth);
      Result.Tracks[I].Keys[J].Rotation:=MotionRotationAt(Animation.Tracks[I],Result.Tracks[I].Keys[J].TimeMS,Animation.Smooth);
    end;
    if Animation.Tracks[I].Keys[0].TimeMS=0 then begin
      Delete(Result.Tracks[I].Keys,0,1);
    end;
    J:=High(Result.Tracks[I].Keys);
    if Result.Tracks[I].Keys[J-1].TimeMS=Animation.DurationMS then SetLength(Result.Tracks[I].Keys,J);
  end;
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
function MotionRotationAt(const Track:TMotionTrack;TimeMS:Integer;Smooth:Boolean):TMQuaternion;
var I:Integer;T:Double;V:TMVector;
  function Rot(N:Integer):TMQuaternion;
  begin V:=Track.Keys[N].Rotation;Result:=MQuaternion(V[0],V[1],V[2]);end;
begin
  if Track.Axis<>#0 then begin
    V:=MVector(0,0,0);case Track.Axis of
      'x':V[0]:=MotionAngleAt(Track,TimeMS,Smooth);
      'y':V[1]:=MotionAngleAt(Track,TimeMS,Smooth);
      'z':V[2]:=MotionAngleAt(Track,TimeMS,Smooth);
    end;Exit(MQuaternion(V[0],V[1],V[2]));
  end;
  if Length(Track.Keys)=0 then Exit(MQuaternion(0,0,0));
  if TimeMS<=Track.Keys[0].TimeMS then Exit(Rot(0));
  for I:=1 to High(Track.Keys) do if TimeMS<=Track.Keys[I].TimeMS then begin
    T:=(TimeMS-Track.Keys[I-1].TimeMS)/(Track.Keys[I].TimeMS-Track.Keys[I-1].TimeMS);
    if Smooth then T:=T*T*(3-2*T);
    Exit(MInterpolate(Rot(I-1),Rot(I),T));
  end;
  Result:=Rot(High(Track.Keys));
end;
function MotionEulerAt(const Track:TMotionTrack;TimeMS:Integer;Smooth:Boolean):TMVector;
begin Result:=MEuler(MotionRotationAt(Track,TimeMS,Smooth));end;

end.
