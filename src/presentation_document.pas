unit presentation_document;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, presentation_paths, professor_commands, presentation_tags, presentation_joint_tags;
function WithoutMovements(const Source: string): string;
function AcceptGeneratedMovements(const Original, Generated: string): string;
procedure ValidatePresentationScript(const Source: string);
implementation
function WithoutMovements(const Source: string): string;
var Script: TAvatarScript; I,P,N: Integer;
begin
  Script:=ParseAvatarScript(Source,4096);Result:=Source;
  // Recognition keeps exactly the parser's handling of code, links and escapes.
  // Repeated passes also strip commands beyond the per-response avatar cap.
  for I:=High(Script.Steps) downto 0 do
    if (Script.Steps[I].Command<>acNone) or (Script.Steps[I].Joint.Bone<>'') then begin
      P:=Script.Steps[I].SourceStart;N:=Script.Steps[I].SourceLength;Delete(Result,P,N);
    end;
  if Script.CommandCount=4096 then
    if Result<>Source then Result:=WithoutMovements(Result);
end;
procedure ValidatePresentationScript(const Source: string);
var I,J: Integer; T: string; S: TAvatarScript; A: TPresentationTag; B: TJointTag;
begin
  if Length(Source)>1024*1024 then raise Exception.Create('Roteiro excede 1 MiB');
  if not ValidPresentationUTF8(Source) then raise Exception.Create('Roteiro deve ser UTF-8');
  S:=ParseAvatarScript(Source,4096);
  if S.CommandCount+S.PresentationCount+S.JointCount>=4096 then raise Exception.Create('Use menos de 4096 eventos por roteiro');
  if S.PresentationCount+S.JointCount>4096 then raise Exception.Create('Excesso de eventos');
  I:=1;
  while I<=Length(Source) do begin
    if Source[I]='[' then begin
      J:=I+1;while (J<=Length(Source)) and not (Source[J] in [']',#10,#13]) do Inc(J);
      T:=LowerCase(Trim(Copy(Source,I+1,J-I-1)));
      if (Pos('arquivo',T)>0) or (Pos('slide',T)>0) or (Pos('articulacao',T)=1) or (Pos('avatar',T)=1) or (Pos('voz',T)=1) or (Pos('fechar som',T)=1) then begin
        if (J>Length(Source)) or (Source[J]<>']') or
          not (TryParsePresentationTag(Copy(Source,I,J-I+1),A) or TryParseJointTag(Copy(Source,I,J-I+1),B)) then
          raise Exception.CreateFmt('Tag invalida na posicao %d',[I]);
      end;
      I:=J;
    end;
    Inc(I);
  end;
end;
function AcceptGeneratedMovements(const Original, Generated: string): string;
begin
  ValidatePresentationScript(Generated);
  if WithoutMovements(Original)<>WithoutMovements(Generated) then
    raise Exception.Create('IA alterou texto ou posicao de midia. Nenhuma alteracao aplicada.');
  Result:=Generated;
end;
end.
