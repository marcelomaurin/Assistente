unit presentation_tags;
{$mode objfpc}{$H+}
interface
uses SysUtils, presentation_paths;
type
  TPresentationAction = (paNone, paOpenFile, paCloseFile, paNextSlide,
    paPreviousSlide, paGoToSlide);
  TPresentationTag = record
    Action: TPresentationAction;
    Argument: string;
    Slide: Integer;
  end;
function TryParsePresentationTag(const TagText: string; out Tag: TPresentationTag): Boolean;
function PresentationTagHelp: string;
implementation
function TryParsePresentationTag(const TagText: string; out Tag: TPresentationTag): Boolean;
var S, Key, Value: string; P,N: Integer;
begin
  Tag:=Default(TPresentationTag);
  S:=Trim(TagText);
  if (Length(S)>=2) and (S[1]='[') and (S[Length(S)]=']') then S:=Trim(Copy(S,2,Length(S)-2));
  P:=Pos('=',S);
  if P>0 then begin Key:=LowerCase(Trim(Copy(S,1,P-1)));Value:=Trim(Copy(S,P+1,MaxInt));end
  else begin Key:=LowerCase(S);Value:='';end;
  if (Key='executar arquivo') or (Key='abrir arquivo') then begin
    if not SafePresentationPath(Value) or not SupportedPresentationMedia(Value) then Exit(False);
    Tag.Action:=paOpenFile;Tag.Argument:=Value;
  end else if (Key='fechar arquivo') and (P=0) then Tag.Action:=paCloseFile
  else if (Key='proximo slide') and (P=0) then Tag.Action:=paNextSlide
  else if (Key='slide anterior') and (P=0) then Tag.Action:=paPreviousSlide
  else if (Key='ir para slide') and TryStrToInt(Value,N) and (N>0) and (N<=10000) then begin
    Tag.Action:=paGoToSlide;Tag.Slide:=N;
  end;
  Result:=Tag.Action<>paNone;
end;
function PresentationTagHelp: string;
begin
  Result:='[executar arquivo=assets/figura.png], [fechar arquivo], '+
    '[proximo slide], [slide anterior], [ir para slide=3]';
end;
end.
