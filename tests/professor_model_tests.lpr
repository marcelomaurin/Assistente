program professor_model_tests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, CastleScene, CastleURIUtils, CastleVectors, professor_state, movement_catalog;
var Scene: TCastleScene; S: TProfessorState; FileName, Clip: string; I: Integer; Movement: TMovementDefinition;
begin
  if ParamCount <> 1 then raise Exception.Create('Usage: professor_model_tests path/to/professor.gltf');
  FileName := ExpandFileName(ParamStr(1));
  Scene := TCastleScene.Create(nil);
  try
    Scene.Load(FilenameToURISafe(FileName));
    if Scene.BoundingBox.IsEmpty then raise Exception.Create('Empty geometry');
    for S := Low(TProfessorState) to High(TProfessorState) do
      if Scene.AnimationsList.IndexOf(AnimationName(S)) < 0 then
        raise Exception.Create('Missing clip: ' + AnimationName(S));
    for I:=0 to MovementCount-1 do begin
      Movement:=MovementAt(I);
      if (Movement.Clip<>'') and (Scene.AnimationsList.IndexOf(Movement.Clip)<0) then
        raise Exception.Create('Catalog clip missing: '+Movement.ID+' -> '+Movement.Clip);
      if (Movement.TalkingClip<>'') and (Scene.AnimationsList.IndexOf(Movement.TalkingClip)<0) then
        raise Exception.Create('Talking clip missing: '+Movement.ID);
    end;
    for I:=0 to Scene.AnimationsList.Count-1 do
    begin
      Clip:=Scene.AnimationsList[I];
      if not Scene.PlayAnimation(Clip, True) then raise Exception.Create('Cannot play: '+Clip);
      Scene.StopAnimation;
      if not Scene.ForceAnimationPose(Clip, 0.6, True) then raise Exception.Create('Cannot evaluate pose: '+Clip);
      WriteLn('PASS: ', Clip);
    end;
    WriteLn('PASS: real CGE glTF loader, nonempty geometry, ',Scene.AnimationsList.Count,' playable clips');
  finally Scene.Free; end;
end.
