unit presentation_joint_tags;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Math;
type TJointTag = record
  Bone: string; Axis: Char; Angle: Double; Duration: Integer; Smooth: Boolean;
end;
function TryParseJointTag(const Text: string; out Tag: TJointTag): Boolean;
function JointAngleLimit(const Bone: string): Double;
implementation
function JointAngleLimit(const Bone: string): Double;
begin
  // Explicit allowlist for the bundled MakeHuman rig. Face and mouth are excluded.
  if (Bone='head') or (Bone='neck01') or (Bone='neck02') or (Bone='neck03') then Exit(25);
  if (Bone='spine01') or (Bone='spine02') or (Bone='spine03') or (Bone='spine04') or (Bone='spine05') then Exit(15);
  if (Bone='upperarm01.L') or (Bone='upperarm01.R') then Exit(90);
  if (Bone='lowerarm01.L') or (Bone='lowerarm01.R') then Exit(90);
  if (Bone='wrist.L') or (Bone='wrist.R') then Exit(35);
  if (Length(Bone)=11) and (Copy(Bone,1,6)='finger') and (Bone[7] in ['1'..'5']) and (Bone[8]='-') and (Bone[9] in ['1'..'3']) and (Bone[10]='.') and (Bone[11] in ['L','R']) then Exit(100);
  if (Bone='clavicle.L') or (Bone='clavicle.R') or (Bone='shoulder01.L') or (Bone='shoulder01.R') then Exit(35);
  if (Bone='upperleg01.L') or (Bone='upperleg01.R') then Exit(60);
  if (Bone='lowerleg01.L') or (Bone='lowerleg01.R') then Exit(100);
  if (Bone='foot.L') or (Bone='foot.R') then Exit(45);
  Result:=0;
end;
function TryParseJointTag(const Text: string; out Tag: TJointTag): Boolean;
var S: string; L: TStringList; FS: TFormatSettings;
begin
  Result:=False;Tag:=Default(TJointTag);S:=Trim(Text);
  if (Length(S)>1) and (S[1]='[') and (S[Length(S)]=']') then S:=Copy(S,2,Length(S)-2);
  if Copy(S,1,12)<>'articulacao=' then Exit;
  L:=TStringList.Create;
  try
    L.StrictDelimiter:=True;L.Delimiter:=',';L.DelimitedText:=Copy(S,13,MaxInt);
    if L.Count<>5 then Exit;
    Tag.Bone:=Trim(L[0]);S:=LowerCase(Trim(L[1]));
    if (Length(S)<>1) or not (S[1] in ['x','y','z']) then Exit;
    Tag.Axis:=S[1];FS:=DefaultFormatSettings;FS.DecimalSeparator:='.';
    if not TryStrToFloat(Trim(L[2]),Tag.Angle,FS) or IsNan(Tag.Angle) or IsInfinite(Tag.Angle) then Exit;
    if (JointAngleLimit(Tag.Bone)=0) or (Abs(Tag.Angle)>JointAngleLimit(Tag.Bone)) then Exit;
    if not TryStrToInt(Trim(L[3]),Tag.Duration) or (Tag.Duration<50) or (Tag.Duration>10000) then Exit;
    S:=Trim(L[4]);if (S<>'linear') and (S<>'suave') then Exit;
    Tag.Smooth:=S='suave';Result:=True;
  finally L.Free;end;
end;
end.
