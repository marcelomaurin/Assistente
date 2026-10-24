program movement_completion_probe;
{$mode objfpc}{$H+}
uses SysUtils,Math,movement_catalog,movement_timeline;
var R:TMovementRuntime;M:TMovementDefinition;T:TMovementTimeline;I,J,K,N,Total,Failed:Integer;
  Profile:string;Initial,P:TMPoseArray;Peak,D:Double;
begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);DefaultSystemCodePage:=CP_UTF8;DefaultFormatSettings.DecimalSeparator:='.';
    Profile:=ParamStr(1);R:=TMovementRuntime.Create;
    try
      R.LoadRig('AVATARES/'+Profile+'/modelo.gltf','AVATARES/colisoes.json',StrToFloat(ParamStr(2)));
      Failed:=0;
      for I:=0 to MovementCount-1 do begin
        M:=MovementAt(I);T:=MovementTimelineFor(M,Profile);R.Clear;
        if (ParamStr(3)<>'sequence') or (I=0) then R.Capture(R.RestPose);
        Initial:=Copy(R.Pose);Peak:=0;R.Start(T);Total:=T.TransitionMS+T.DurationMS;
        if T.ReturnToStart then Inc(Total,T.ReturnMS);
        for J:=1 to Ceil(Total/50)+1 do begin
          R.Advance(50);P:=R.Pose;
          for N:=0 to High(P) do begin
            for K:=0 to 3 do Peak:=Max(Peak,Abs(P[N].Rotation[K]-Initial[N].Rotation[K]));
            for K:=0 to 2 do begin Peak:=Max(Peak,Abs(P[N].Position[K]-Initial[N].Position[K]));Peak:=Max(Peak,Abs(P[N].Scale[K]-Initial[N].Scale[K]));end;
          end;
          if R.MinimumClearance < -1E-8 then raise Exception.Create('Overlap '+M.ID);
        end;
        if R.ElapsedMS<Total-0.01 then Inc(Failed);
        WriteLn(M.ID,'|',R.ElapsedMS:0:2,'/',Total,'|peak=',Peak:0:4,'|',R.BlockedPair);
      end;
      WriteLn('PROFILE ',Profile,' incomplete=',Failed);if Failed>0 then ExitCode:=1;
    finally R.Free;end;
  except on E:Exception do begin WriteLn('FAIL ',E.Message);Halt(1);end;end;
end.
