program professor_model_tests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, CastleScene, CastleURIUtils, CastleVectors, professor_state;
var Scene: TCastleScene; S: TProfessorState; FileName: string;
begin
  if ParamCount <> 1 then raise Exception.Create('Usage: professor_model_tests path/to/professor.gltf');
  FileName := ExpandFileName(ParamStr(1));
  Scene := TCastleScene.Create(nil);
  try
    Scene.Load(FilenameToURISafe(FileName));
    if Scene.BoundingBox.IsEmpty then raise Exception.Create('Empty geometry');
    for S := Low(TProfessorState) to High(TProfessorState) do
    begin
      if Scene.AnimationsList.IndexOf(AnimationName(S)) < 0 then
        raise Exception.Create('Missing clip: ' + AnimationName(S));
      if not Scene.PlayAnimation(AnimationName(S), True) then
        raise Exception.Create('Cannot play: ' + AnimationName(S));
      if not Scene.ForceAnimationPose(AnimationName(S), 0.6, True) then
        raise Exception.Create('Cannot evaluate pose: ' + AnimationName(S));
      WriteLn('PASS: ', AnimationName(S));
    end;
    WriteLn('PASS: real CGE glTF loader, nonempty geometry, six playable clips');
  finally Scene.Free; end;
end.
