program presentation_youtube_tests;
{$mode objfpc}{$H+}{$codepage utf8}
uses Classes,SysUtils,presentation_youtube,presentation_tags,professor_commands,
  presentation_document,presentation_package,reception_core,presentation_paths;
var ID,URL,Root,Script:string;Start,I:Integer;Tag:TPresentationTag;S:TAvatarScript;
  Package:TPVAPackage;Config:TReceptionConfig;Job:TReceptionJob;Step:TAvatarScriptStep;Started:QWord;
procedure Check(B:Boolean;const Message:string);
begin if not B then raise Exception.Create(Message);end;
procedure Accept(const Link:string;Seconds:Integer);
begin
  Check(TryYouTubeURL(Link,ID,URL,Start),'Valid video rejected: '+Link);
  Check((ID='M7lc1UVf-VE') and (Start=Seconds),'Wrong video/start');
  Check(TryParsePresentationTag(YouTubeTag(Link),Tag) and (Tag.Action=paYouTube),'Generated tag rejected');
end;
procedure Reject(const Link:string);
var Failed:Boolean;
begin
  Check(not TryYouTubeURL(Link,ID,URL,Start),'Unsafe/invalid video accepted: '+Link);
  Failed:=False;try ValidatePresentationScript('[youtube='+Link+']');except Failed:=True;end;
  Check(Failed,'Invalid YouTube tag was left in spoken text');
end;
begin
  Root:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));ForceDirectories(Root);
  Check(ValidPresentationUTF8(YouTubePlayerHTML('M7lc1UVf-VE',0)),'Player HTML is not UTF-8');
  Accept('https://www.youtube.com:443/watch?v=M7lc1UVf-VE',0);
  Accept('https://www.youtube.com/watch?v=M7lc1UVf-VE',0);
  Accept('https://youtu.be/M7lc1UVf-VE?si=abc&t=1m30s',90);
  Accept('https://youtube.com/shorts/M7lc1UVf-VE',0);
  Accept('https://www.youtube.com/embed/M7lc1UVf-VE?start=15',15);
  Accept('{https://m.youtube.com/watch?v=M7lc1UVf-VE#t=20}',20);
  Check(TryParsePresentationTag('[youtube:{https://youtu.be/M7lc1UVf-VE}]',Tag) and (Tag.Action=paYouTube),'Colon/braced form rejected');
  Check(TryParsePresentationTag('[youtybe=https://youtu.be/M7lc1UVf-VE]',Tag),'Compatibility spelling rejected');
  Reject('https://youtube.com.evil.test/watch?v=M7lc1UVf-VE');
  Reject('https://youtube.com@evil.test/watch?v=M7lc1UVf-VE');
  Reject('javascript:alert(1)');Reject('file:///C:/Windows/win.ini');
  Reject('https://www.youtube.com/playlist?list=123');Reject('https://youtu.be/short');
  Reject('https://youtu.be/M7lc1UVf-VE?t=-1');Reject('https://youtu.be/M7lc1UVf-VE?t=1&t=2');
  Script:='Antes [youtube:https://youtu.be/M7lc1UVf-VE] Depois [fechar arquivo]';
  S:=ParseAvatarScript(Script);Check((S.PresentationCount=2) and (S.PlainText='Antes  Depois '),'Video tag reached speech');
  S:=ParseAvatarScript('[youtube=https://youtu.be/M7lc1UVf-VE?si='+StringOfChar('a',1200)+']');
  Check((S.PresentationCount=1) and (S.PlainText=''),'Long shared URL reached speech');
  S:=ParseAvatarScript('`[youtube=https://youtu.be/M7lc1UVf-VE]`');Check(S.PresentationCount=0,'Code literal executed');
  ValidatePresentationScript(Script);Check(AcceptGeneratedMovements(Script,Script)=Script,'AI validation rejected video');
  Package:=TPVAPackage.Create;
  try Package.ExportFile(Root+'youtube.pva',Script,Root);finally Package.Free;end;
  Package:=TPVAPackage.Create;
  try Package.Load(Root+'youtube.pva');Check(Package.Script=Script,'Video link lost during PVA roundtrip');finally Package.Free;end;
  Config:=Default(TReceptionConfig);Config.EnableAvatarCommands:=True;
  Config.EnablePresentationCommands:=True;Config.SilentPresentation:=True;
  Job:=TReceptionJob.Create(rjSpeak,Config,'[youtube=https://youtu.be/M7lc1UVf-VE][fechar arquivo]','','youtube');
  try
    Started:=GetTickCount64;
    while not Job.TakeScriptCommand(Step) do begin Check(GetTickCount64-Started<2000,'No video event');Sleep(5);end;
    Check(Step.Presentation.Action=paYouTube,'Wrong first event');Sleep(300);
    Check(not Job.Done,'Worker did not await video completion');
    Check(not Job.TakeScriptCommand(Step),'Following tag overtook video');
    Job.ConfirmAvatarCommand;Started:=GetTickCount64;
    while not Job.TakeScriptCommand(Step) do begin Check(GetTickCount64-Started<2000,'No close event');Sleep(5);end;
    Check(Step.Presentation.Action=paCloseFile,'Missing close event');Job.ConfirmAvatarCommand;
    Job.WaitFor;Check(Job.Success,Job.ErrorText);
  finally Job.Free;end;
  Config.SilentPresentation:=False;Config.SynthEngine:=3;Config.URL:='http://127.0.0.1:1';
  Job:=TReceptionJob.Create(rjSpeak,Config,'[youtube=https://youtu.be/M7lc1UVf-VE]Texto depois do video.','','youtube-before-tts');
  try
    Started:=GetTickCount64;
    while not Job.TakeScriptCommand(Step) do begin Check(not Job.Done,'Synthesis ran before the video');Check(GetTickCount64-Started<2000,'Video waited for speech synthesis');Sleep(5);end;
    Check(Step.Presentation.Action=paYouTube,'Video boundary lost');Job.Cancel;Job.WaitFor;
    Check(not Job.Success,'Cancelled video interaction succeeded');
  finally Job.Free;end;
  WriteLn('PASS: YouTube URLs, timestamps, standard and colon tags, rejected links, clean speech, PVA roundtrip and ordered completion');
end.
