unit presentation_youtube;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses SysUtils, Classes, URIParser;
function TryYouTubeURL(const Link:string;out VideoID,CanonicalURL:string;out StartSeconds:Integer):Boolean;
function YouTubeTag(const Link:string):string;
function YouTubePlayerHTML(const VideoID:string;StartSeconds:Integer;Muted:Boolean=False):string;
const YouTubePlayerOrigin='https://assistente.maurinsoft.com.br';
implementation
function ValidID(const S:string):Boolean;
var C:Char;
begin
  Result:=Length(S)=11;if not Result then Exit;
  for C in S do if not (C in ['a'..'z','A'..'Z','0'..'9','_','-']) then Exit(False);
end;
function ParseSeconds(const S:string;out Seconds:Integer):Boolean;
var I,N,UnitValue,LastUnit:Integer;C:Char;Digits:Boolean;Total:Int64;
begin
  Result:=False;Seconds:=0;if S='' then Exit;N:=0;Total:=0;Digits:=False;LastUnit:=3601;
  for I:=1 to Length(S) do begin
    C:=S[I];
    if C in ['0'..'9'] then begin
      if N>359999 then Exit;N:=N*10+Ord(C)-48;Digits:=True;
    end else begin
      if not Digits then Exit;
      case C of 'h':UnitValue:=3600;'m':UnitValue:=60;'s':UnitValue:=1;else Exit;end;
      if UnitValue>=LastUnit then Exit;LastUnit:=UnitValue;
      Inc(Total,Int64(N)*UnitValue);N:=0;Digits:=False;
    end;
  end;
  if Digits then begin if LastUnit<>3601 then Exit;Inc(Total,N);end;
  if (Total<0) or (Total>359999) then Exit;
  Seconds:=Total;Result:=True;
end;
function TryYouTubeURL(const Link:string;out VideoID,CanonicalURL:string;out StartSeconds:Integer):Boolean;
var S,H,P,Key,Value,Query:string;U:TURI;Parts:TStringList;I,K,StartValue:Integer;SeenV,SeenStart:Boolean;C:Char;
begin
  Result:=False;VideoID:='';CanonicalURL:='';StartSeconds:=0;S:=Trim(Link);
  if (Length(S)>=2) and (S[1]='{') and (S[Length(S)]='}') then S:=Trim(Copy(S,2,Length(S)-2));
  if (S='') or (Length(S)>2048) then Exit;
  for C in S do if (Ord(C)<=32) or (C in ['[',']','{','}','|','\','"',#39,'<','>']) then Exit;
  try U:=ParseURI(S,False);except Exit;end;
  H:=LowerCase(U.Host);
  if (LowerCase(U.Protocol)<>'https') or not U.HasAuthority or (U.Username<>'') or (U.Password<>'') or
    ((U.Port<>0) and (U.Port<>443)) then Exit;
  if (H<>'youtube.com') and (H<>'www.youtube.com') and (H<>'m.youtube.com') and
    (H<>'music.youtube.com') and (H<>'youtu.be') and (H<>'www.youtu.be') and
    (H<>'www.youtube-nocookie.com') and (H<>'youtube-nocookie.com') then Exit;
  P:=U.Path+U.Document;SeenV:=False;SeenStart:=False;
  if (H='youtu.be') or (H='www.youtu.be') then VideoID:=Copy(P,2,MaxInt)
  else if (Copy(P,1,7)='/embed/') then VideoID:=Copy(P,8,MaxInt)
  else if (Copy(P,1,8)='/shorts/') then VideoID:=Copy(P,9,MaxInt)
  else if (Copy(P,1,6)='/live/') then VideoID:=Copy(P,7,MaxInt)
  else if P<>'/watch' then Exit;
  Parts:=TStringList.Create;
  try
    Parts.StrictDelimiter:=True;Parts.Delimiter:='&';Parts.DelimitedText:=U.Params;
    for I:=0 to Parts.Count-1 do begin
      Query:=Parts[I];K:=Pos('=',Query);if K=0 then Continue;
      Key:=Copy(Query,1,K-1);Value:=Copy(Query,K+1,MaxInt);
      if Key='v' then begin
        if SeenV or (VideoID<>'') then Exit;SeenV:=True;VideoID:=Value;
      end else if (Key='t') or (Key='start') then begin
        if SeenStart or not ParseSeconds(Value,StartValue) then Exit;
        StartSeconds:=StartValue;SeenStart:=True;
      end;
    end;
    if (U.Bookmark<>'') and (Copy(U.Bookmark,1,2)='t=') then begin
      if SeenStart or not ParseSeconds(Copy(U.Bookmark,3,MaxInt),StartSeconds) then Exit;
    end;
    if not ValidID(VideoID) then Exit;
    CanonicalURL:='https://www.youtube.com/watch?v='+VideoID;
    if StartSeconds>0 then CanonicalURL:=CanonicalURL+'&t='+IntToStr(StartSeconds);
    Result:=True;
  finally Parts.Free;end;
end;
function YouTubeTag(const Link:string):string;
var ID,URL:string;Start:Integer;
begin
  if not TryYouTubeURL(Link,ID,URL,Start) then raise Exception.Create('Link do YouTube invalido. Cole um link HTTPS de um video.');
  Result:='[youtube='+URL+']';
end;
function YouTubePlayerHTML(const VideoID:string;StartSeconds:Integer;Muted:Boolean):string;
var MuteScript,Page:UnicodeString;
begin
  if not ValidID(VideoID) or (StartSeconds<0) or (StartSeconds>359999) then raise Exception.Create('Video invalido');
  MuteScript:='';if Muted then MuteScript:='e.target.mute();';
  Page:='<!doctype html><html lang="pt-BR"><meta charset="utf-8">'+
    '<meta name="viewport" content="width=device-width,initial-scale=1">'+
    '<meta name="referrer" content="strict-origin-when-cross-origin">'+
    '<style>html,body{margin:0;height:100%;background:#101923;color:#eef3f9;font:16px Segoe UI,sans-serif}'+
    'body{display:flex;flex-direction:column}header{padding:14px 18px;display:flex;align-items:center;gap:14px}'+
    'header span{flex:1}button{border:0;border-radius:8px;padding:12px 18px;cursor:pointer;font:inherit}'+
    '#play{background:#f14538;color:white;font-size:20px}main{position:relative;flex:1;min-height:200px;display:grid;place-items:center}'+
    '#player{position:absolute;inset:0;width:100%;height:100%}#status{padding:8px 18px;min-height:24px}</style>'+
    '<header><span>Vídeo do YouTube</span><button id="skip" onclick="finish()">Continuar apresentação</button></header>'+
    '<main><div id="player" hidden></div><button id="play" onclick="start()">▶ Reproduzir vídeo</button></main>'+
    '<div id="status" role="status">Clique para assistir dentro do Assistente.</div><script>'+
    'let player=null,appPaused=false,resumeAfterPause=false,started=false,finished=false;'+
    'const send=m=>{if(window.chrome&&chrome.webview)chrome.webview.postMessage(m)};'+
    'function setPlayerStatus(t){document.getElementById("status").textContent=t}'+
    'function finish(){finished=true;if(player&&player.stopVideo)player.stopVideo();send("done")}'+
    'function start(){if(appPaused||started)return;started=true;document.getElementById("play").hidden=true;'+
    'document.getElementById("player").hidden=false;setPlayerStatus("Carregando vídeo...");'+
    'if(window.YT&&YT.Player)onYouTubeIframeAPIReady();else{let s=document.createElement("script");'+
    's.src="https://www.youtube.com/iframe_api";s.onerror=()=>setPlayerStatus("Não foi possível conectar ao YouTube. Verifique a internet ou continue a apresentação.");document.head.appendChild(s)}}'+
    'function onYouTubeIframeAPIReady(){if(finished)return;player=new YT.Player("player",{videoId:"'+UnicodeString(VideoID)+'",'+
    'playerVars:{autoplay:1,playsinline:1,start:'+UnicodeString(IntToStr(StartSeconds))+',origin:"'+YouTubePlayerOrigin+'"},events:{'+
    'onReady:e=>{'+MuteScript+'send("ready");if(appPaused)e.target.pauseVideo();else e.target.playVideo()},'+
    'onStateChange:e=>{send("state:"+e.data);if(e.data===0){setPlayerStatus("Vídeo encerrado.");send("done")}'+
    'else if(e.data===1){if(appPaused)e.target.pauseVideo();else setPlayerStatus("Reproduzindo vídeo")}else if(e.data===2)setPlayerStatus("Vídeo pausado")},'+
    'onError:e=>{setPlayerStatus("O YouTube não permitiu reproduzir este vídeo (código "+e.data+"). Você pode continuar a apresentação.");send("error:"+e.data)},'+
    'onAutoplayBlocked:()=>setPlayerStatus("Clique no botão de reprodução do YouTube para iniciar.")}})}'+
    'function setAppPaused(p){appPaused=p;document.getElementById("play").disabled=p;'+
    'if(player&&player.getPlayerState){if(p){resumeAfterPause=player.getPlayerState()===1;player.pauseVideo()}'+
    'else if(resumeAfterPause){resumeAfterPause=false;player.playVideo()}}}'+
    'send("loaded");</script></html>';
  Result:=UTF8Encode(Page);
end;
end.
