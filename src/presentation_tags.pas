unit presentation_tags;
{$mode objfpc}{$H+}
interface
uses SysUtils, presentation_paths, presentation_youtube;
type
  TPresentationAction = (paNone, paOpenFile, paCloseFile, paNextSlide,
    paPreviousSlide, paGoToSlide, paSelectAvatar, paSelectVoice, paCloseSound, paEndTask, paYouTube, paAsk, paContinue, paMenu);
  TPresentationTag = record
    Action: TPresentationAction;
    Argument: string;
    Slide: Integer;
    HasStart: Boolean;
    StartMS: Integer;
  end;
function TryParsePresentationTag(const TagText: string; out Tag: TPresentationTag): Boolean;
function TryParsePresentationTime(const Text: string; out Milliseconds: Integer): Boolean;
function PresentationMediaTag(const Path, StartTime: string): string;
function PresentationTagHelp: string;
implementation
function TryParsePresentationTime(const Text: string; out Milliseconds: Integer): Boolean;
var I,H,M,S: Integer;
begin
  Result:=False;Milliseconds:=0;
  if (Length(Text)<>8) or (Text[3]<>':') or (Text[6]<>':') then Exit;
  for I:=1 to 8 do if not (I in [3,6]) and not (Text[I] in ['0'..'9']) then Exit;
  H:=StrToInt(Copy(Text,1,2));M:=StrToInt(Copy(Text,4,2));S:=StrToInt(Copy(Text,7,2));
  if (M>59) or (S>59) then Exit;
  Milliseconds:=((H*60+M)*60+S)*1000;Result:=True;
end;
function ValidSelection(const Value: string): Boolean;
var I: Integer;
begin
  Result:=False;
  if (Trim(Value)='') or (Length(Value)>160) or not ValidPresentationUTF8(Value) then Exit;
  for I:=1 to Length(Value) do if (Ord(Value[I])<32) or (Value[I] in ['[',']','|','=']) then Exit;
  Result:=True;
end;
function TryParsePresentationTag(const TagText: string; out Tag: TPresentationTag): Boolean;
var S,Key,Value,Path,Option,VideoID,URL: string; P,N,Q: Integer; Parsed: TPresentationTag;
begin
  Result:=False;Tag:=Default(TPresentationTag);Parsed:=Tag;S:=Trim(TagText);
  if (Length(S)>=2) and (S[1]='[') and (S[Length(S)]=']') then S:=Trim(Copy(S,2,Length(S)-2));
  if (Pos('youtube:',LowerCase(S))=1) then S:='youtube='+Copy(S,9,MaxInt);
  P:=Pos('=',S);
  if P>0 then begin Key:=LowerCase(Trim(Copy(S,1,P-1)));Value:=Trim(Copy(S,P+1,MaxInt));end
  else begin Key:=LowerCase(S);Value:='';end;
  if ((Key='youtube') or (Key='youtybe')) and TryYouTubeURL(Value,VideoID,URL,N) then begin
    Parsed.Action:=paYouTube;Parsed.Argument:=URL;Parsed.StartMS:=N*1000;Parsed.HasStart:=N>0;
  end else if (Key='executar arquivo') or (Key='abrir arquivo') then begin
    Path:=Value;Q:=Pos('|',Value);
    if Q>0 then begin
      Path:=Trim(Copy(Value,1,Q-1));Option:=Copy(Value,Q+1,MaxInt);
      if Copy(Option,1,7)<>'inicio=' then Exit;
      if not TimedPresentationMedia(Path) or not TryParsePresentationTime(Copy(Option,8,MaxInt),Parsed.StartMS) then Exit;
      Parsed.HasStart:=True;
    end;
    if not SafePresentationPath(Path) or not SupportedPresentationMedia(Path) then Exit;
    Parsed.Action:=paOpenFile;Parsed.Argument:=Path;
  end else if (Key='fechar arquivo') and (P=0) then Parsed.Action:=paCloseFile
  else if (Key='perguntar') and (P=0) then Parsed.Action:=paAsk
  else if (Key='menu') and (P=0) then Parsed.Action:=paMenu
  else if (Key='continuar') and (P=0) then Parsed.Action:=paContinue
  else if (Key='fim') and (P=0) then Parsed.Action:=paEndTask
  else if (Key='fechar som') and (P=0) then Parsed.Action:=paCloseSound
  else if (Key='proximo slide') and (P=0) then Parsed.Action:=paNextSlide
  else if (Key='slide anterior') and (P=0) then Parsed.Action:=paPreviousSlide
  else if (Key='ir para slide') and TryStrToInt(Value,N) and (N>0) and (N<=10000) then begin
    Parsed.Action:=paGoToSlide;Parsed.Slide:=N;
  end else if (Key='avatar') and ValidSelection(Value) then begin Parsed.Action:=paSelectAvatar;Parsed.Argument:=Value;end
  else if (Key='voz') and ValidSelection(Value) then begin Parsed.Action:=paSelectVoice;Parsed.Argument:=Value;end;
  Result:=Parsed.Action<>paNone;if Result then Tag:=Parsed;
end;
function PresentationMediaTag(const Path, StartTime: string): string;
var Tag: TPresentationTag;
begin
  Result:='[executar arquivo='+Path;
  if StartTime<>'' then Result:=Result+'|inicio='+StartTime;
  Result:=Result+']';
  if not TryParsePresentationTag(Result,Tag) then raise Exception.Create('Recurso ou inicio invalido; use hh:mm:ss para audio/video');
end;
function PresentationTagHelp: string;
begin
  Result:='[executar arquivo=assets/filme.mp4|inicio=00:01:30], '+
    '[executar arquivo=assets/som.wav|inicio=00:00:10], [fechar arquivo], [fechar som], '+
    '[PERGUNTAR], [CONTINUAR], [MENU], [youtube=https://www.youtube.com/watch?v=VIDEO_ID], [avatar=professor], [voz=padrao], [proximo slide], [slide anterior], [ir para slide=3]';
end;
end.
