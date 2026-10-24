program movement_animation_tests;
{$mode objfpc}{$H+}
uses Classes,SysUtils,Math,fpjson,jsonparser,movement_animation,movement_timeline,movement_catalog;
var Root,Original,FileName:string;A,B:TMotionAnimation;T:TMovementTimeline;R:TMovementRuntime;
  L:TStringList;J:TJSONData;I,Count:Integer;Failed:Boolean;Q,Q2:TMQuaternion;V:TMVector;D:Double;C,N:Integer;
procedure Check(Value:Boolean;const Message:string);
begin if not Value then raise Exception.Create(Message);end;
procedure Put(const Name,Text:string);
begin L.Text:=Text;L.SaveToFile(Root+Name);end;
function Contents(const Name:string):string;
begin L.LoadFromFile(Name);Result:=L.Text;end;
begin
  Root:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));ForceDirectories(Root+'movimentos');
  L:=TStringList.Create;R:=TMovementRuntime.Create;Original:=MovementCatalogFile;
  try
    J:=GetJSON(Contents(Original));Count:=0;
    try
      for I:=0 to TJSONObject(J).Arrays['movements'].Count-1 do begin
        FileName:=TJSONObject(J).Arrays['movements'].Objects[I].Get('animation_file','');
        if FileName='' then Continue;
        A:=LoadMotionAnimation(ExtractFilePath(Original)+'movimentos'+PathDelim+FileName);
        T:=MotionTimeline(A);Check(Length(T.Tracks)=Length(A.Tracks),'Lost tracks');Inc(Count);
      end;
    finally J.Free;end;
    Check(Count=41,'Unexpected external animation count');
    A:=Default(TMotionAnimation);A.Name:='Round trip';A.DurationMS:=1000;A.Smooth:=True;
    SetLength(A.Tracks,1);A.Tracks[0].Bone:='finger1-1.R';A.Tracks[0].Axis:='z';SetLength(A.Tracks[0].Keys,2);
    A.Tracks[0].Keys[0].TimeMS:=0;A.Tracks[0].Keys[0].Angle:=-100;
    A.Tracks[0].Keys[1].TimeMS:=1000;A.Tracks[0].Keys[1].Angle:=100;
    FileName:=Root+'movimentos/test.json';SaveMotionAnimation(FileName,A);B:=LoadMotionAnimation(FileName);
    Check(B.Smooth and not B.ReturnToBase and not B.Looping,'Options changed during save');
    A.Looping:=True;SaveMotionAnimation(FileName,A);Check(FileExists(FileName+'.bak'),'Backup missing');
    B:=LoadMotionAnimation(FileName+'.bak');Check(not B.Looping,'Backup is not original');
    A.DurationMS:=50;Failed:=False;
    try SaveMotionAnimation(FileName,A);except Failed:=True;end;
    Check(Failed,'Invalid animation saved');B:=LoadMotionAnimation(FileName);Check(B.DurationMS=1000,'Invalid save replaced original');
    A.DurationMS:=1000;A.Looping:=False;
    Put('rig.gltf','{"nodes":[{"name":"root","children":[1,2]},{"name":"finger1-1.R"},{"name":"obstacle","translation":[0,5,0]}]}');
    Put('colisoes.json','{"version":1,"margin_height":0.001,"bodies":[{"id":"finger","start_bone":"finger1-1.R","radius_height":0.01},{"id":"body","start_bone":"obstacle","radius_height":0.1}]}');
    R.LoadRig(Root+'rig.gltf',Root+'colisoes.json',1);T:=MotionTimeline(A,0);R.Start(T);R.Advance(250);
    Q:=MQuaternion(0,0,MotionAngleAt(A.Tracks[0],250,True));
    Check(Abs(R.Pose[1].Rotation[2]-Q[2])<1E-7,'External interpolation differs from player');
    R.Advance(250);Check(Abs(R.Pose[1].Rotation[2])<1E-7,'Large angular range took the short arc');
    R.Advance(500);Check(not R.Running,'Nonlooping resource did not finish');
    A.Tracks[0].Keys[0].Angle:=0;A.Tracks[0].Keys[1].Angle:=20;A.ReturnToBase:=True;
    R.LoadRig(Root+'rig.gltf',Root+'colisoes.json',1);T:=MotionTimeline(A,100);R.Start(T);R.Advance(1200);
    Check(not R.Running and (Abs(R.Pose[1].Rotation[2])<1E-7),'Return did not restore incoming pose');
    A.Looping:=True;T:=MotionTimeline(A,100);R.Start(T);R.Advance(2500);
    Check(R.Running and (Abs(R.ElapsedMS-100)<1E-6),'Loop lost elapsed time');
    SaveMotionAnimation(FileName,A);
    Put('movimentos.json','{"version":1,"movements":[{"id":"external_test","tag":"external test","duration_ms":50,"transition_ms":0,"animation_file":"test.json"}]}');
    ReloadMovementCatalog(Root+'movimentos.json');
    Check(MovementAt(0).Duration=1000,'Catalog did not derive resource duration');
    Check(Length(MovementAt(0).Timeline.Tracks)=1,'External tag has no protected timeline');
    Put('movimentos.json','{"version":1,"movements":[{"id":"invalid","animation_file":"../escape.json"}]}');
    Failed:=False;try ReloadMovementCatalog(Root+'movimentos.json');except Failed:=True;end;
    Check(Failed and (MovementAt(0).ID='external_test'),'Invalid reload changed active catalog');

    // Full XYZ tracks preserve orientation, match protected playback and reject malformed files.
    A:=Default(TMotionAnimation);A.DurationMS:=1000;A.Smooth:=True;
    SetLength(A.Tracks,1);A.Tracks[0].Bone:='finger1-1.R';A.Tracks[0].Axis:=#0;
    SetLength(A.Tracks[0].Keys,2);A.Tracks[0].Keys[1].TimeMS:=1000;
    A.Tracks[0].Keys[0].Rotation:=MVector(-20,30,40);
    A.Tracks[0].Keys[1].Rotation:=MVector(25,-35,50);
    SaveMotionAnimation(FileName,A);B:=LoadMotionAnimation(FileName);
    Check((B.Tracks[0].Axis=#0) and (Abs(B.Tracks[0].Keys[1].Rotation[1]+35)<1E-8),'XYZ roundtrip lost components');
    R.LoadRig(Root+'rig.gltf',Root+'colisoes.json',1);R.Start(MotionTimeline(B,0));R.Advance(375);
    Q:=MotionRotationAt(B.Tracks[0],375,B.Smooth);Q2:=R.Pose[1].Rotation;D:=0;
    for C:=0 to 3 do D:=D+Q[C]*Q2[C];Check(Abs(Abs(D)-1)<1E-7,'XYZ scrub and player disagree');
    for N:=0 to 2000 do begin
      V:=MVector((N*17 mod 201)-100,(N*29 mod 201)-100,(N*47 mod 201)-100);
      Q:=MQuaternion(V[0],V[1],V[2]);V:=MEuler(Q);Q2:=MQuaternion(V[0],V[1],V[2]);D:=0;
      for C:=0 to 3 do D:=D+Q[C]*Q2[C];Check(Abs(Abs(D)-1)<1E-7,'XYZ Euler conversion changed rotation');
      Q2:=QMul(MInverse(Q),Q);Check(Abs(Q2[3]-1)<1E-7,'Inverse rotation failed');
    end;
    V:=MEuler(MQuaternion(0,100,0));Check(Abs(V[1]-100)<1E-6,'Rotation beyond 90 degrees lost valid representation');
    L.Text:=Contents(FileName);L.Text:=StringReplace(L.Text,'"rotation_deg"','"missing_xyz"',[rfReplaceAll]);L.SaveToFile(Root+'malformed.json');
    Failed:=False;try LoadMotionAnimation(Root+'malformed.json');except Failed:=True;end;Check(Failed,'Missing XYZ array accepted');
    A.Tracks[0].Keys[1].Rotation[2]:=101;Failed:=False;
    try SaveMotionAnimation(FileName,A);except Failed:=True;end;Check(Failed,'Out-of-limit XYZ saved');
    B:=LoadMotionAnimation(FileName);Check(Abs(B.Tracks[0].Keys[1].Rotation[2]-50)<1E-8,'Invalid XYZ save replaced valid file');
    WriteLn('PASS: 41 legacy resources, roundtrip/backup, invalid-save preservation, scalar and XYZ interpolation, loop/return, 2001 Euler/inverse cases, v2 validation, duration and atomic reload');
  finally ReloadMovementCatalog(Original);R.Free;L.Free;end;
end.
