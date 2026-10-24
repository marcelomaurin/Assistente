program movement_scene_tests;
{$mode objfpc}{$H+}
uses Classes,SysUtils,CastleURIUtils,CastleTransform,CastleVectors,presentation_joints,movement_catalog,movement_timeline;
var Scene:TPresentationScene;M:TMovementDefinition;Timeline:TMovementTimeline;I,J:Integer;RemoveMe:TRemoveType;ID,Profile:string;Count,Blocked,Total:Integer;
const IDs:array[0..7] of string=('cruzar_bracos','levantar_mao_esquerda','gesticular_ok','bocejar','coracao_com_as_maos','levantar_pe_direito','abrir_olhos','sorriso');
procedure Check(B:Boolean;const Message:string);
begin if not B then raise Exception.Create(Message);end;
begin
  try
    Scene:=TPresentationScene.Create(nil);
    try
      Scene.Load(FilenameToURISafe(ExpandFileName(ParamStr(1))));Scene.PrepareSpeechMouth;
      Scene.PrepareMovementRig(ExpandFileName(ParamStr(1)),ExpandFileName(ParamStr(2)),Scene.BoundingBox.Size.Y);
      Profile:=ExtractFileName(ExtractFileDir(ExpandFileName(ParamStr(1))));Count:=0;Blocked:=0;RemoveMe:=rtNone;
      Check(MovementCount=53,'Catalog count changed unexpectedly');
      for ID in IDs do begin
        Check(FindMovement(ID,M),'Movement not found: '+ID);Timeline:=MovementTimelineFor(M,Profile);
        Scene.TimePlaying:=True;Scene.ClearTimeline;Scene.ExecuteTimeline(Timeline);
        for J:=1 to 100 do begin Scene.Update(0.05,RemoveMe);Check(Scene.MovementClearance>=-1E-8,'Protected volumes overlap: '+ID);end;
        Check(Scene.MovementBlocked='','Movement stopped: '+ID+' / '+Scene.MovementBlocked);
        Total:=Timeline.DurationMS+Timeline.TransitionMS;if Timeline.ReturnToStart then Inc(Total,Timeline.ReturnMS);
        Check(Scene.MovementElapsed>=Total-0.01,'Movement did not finish: '+ID);
        Inc(Count);
      end;
      WriteLn('PASS: ',Profile,' ',Count,' JSON movements through the real 3D scene; limited: ',Blocked);
    finally Scene.Free;end;
  except on E:Exception do begin WriteLn(StdErr,'FAIL: '+E.ClassName+': '+E.Message);Halt(1);end;end;
end.
