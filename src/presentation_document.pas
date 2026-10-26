unit presentation_document;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, presentation_paths, professor_commands, presentation_tags, presentation_joint_tags, presentation_flow;
function WithoutMovements(const Source: string): string;
function AcceptGeneratedMovements(const Original, Generated: string): string;
procedure ValidatePresentationScript(const Source: string);
procedure ValidateRuntimeScript(const Source: string);
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
procedure ValidateRuntimeScript(const Source: string);
var S: TAvatarScript;
begin
  if Length(Source)>1024*1024 then raise Exception.Create('Execucao expandida excede 1 MiB');
  S:=ParseAvatarScript(Source,4096);
  if S.CommandCount+S.PresentationCount+S.JointCount>=4096 then
    raise Exception.Create('Execucao deve ter menos de 4096 eventos');
end;
procedure ValidatePresentationScript(const Source: string);
var I,J: Integer; T,Clean: string; Flow: TFlowProgram; S: TAvatarScript;
  Token: TFlowToken; A: TPresentationTag; B: TJointTag;
begin
  if Length(Source)>1024*1024 then raise Exception.Create('Roteiro excede 1 MiB');
  if not ValidPresentationUTF8(Source) then raise Exception.Create('Roteiro deve ser UTF-8');
  Flow:=TFlowProgram.Create(Source);
  try
    ValidateRuntimeScript(Flow.Compile);Clean:=Flow.WithoutFlowTags;
    S:=ParseAvatarScript(Clean,4096);
    if S.CommandCount+S.PresentationCount+S.JointCount>=4096 then raise Exception.Create('Use menos de 4096 eventos por roteiro');
    for I:=0 to Flow.TokenCount-1 do begin
      Token:=Flow.TokenAt(I);if Token.Action<>faNone then Continue;
      J:=Token.Start+Token.Size-1;T:=LowerCase(Trim(Copy(Source,Token.Start+1,Token.Size-2)));
      if (Pos('arquivo',T)>0) or (Pos('slide',T)>0) or (Pos('articulacao',T)=1) or
        (Pos('youtube',T)=1) or (Pos('youtybe',T)=1) or (Pos('avatar',T)=1) or (Pos('voz',T)=1) or (Pos('fechar som',T)=1) or (Pos('perguntar',T)=1) or (Pos('continuar',T)=1) or (Pos('menu',T)=1) then begin
        if (J>Length(Source)) or (Source[J]<>']') or
          not (TryParsePresentationTag(Copy(Source,Token.Start,Token.Size),A) or TryParseJointTag(Copy(Source,Token.Start,Token.Size),B)) then
          raise Exception.CreateFmt('Tag invalida na posicao %d',[Token.Start]);
      end;
    end;
  finally Flow.Free;end;
end;
function AcceptGeneratedMovements(const Original, Generated: string): string;
begin
  ValidatePresentationScript(Generated);
  if WithoutMovements(Original)<>WithoutMovements(Generated) then
    raise Exception.Create('IA alterou texto ou posicao de midia. Nenhuma alteracao aplicada.');
  Result:=Generated;
end;
end.
