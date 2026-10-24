program audio_path_tests;
{$mode objfpc}{$H+}
uses Classes,SysUtils,aiaudioplayback;
var Player:TAIAudioPlayer;Started:QWord;
begin
  Player:=TAIAudioPlayer.Create(nil);
  try
    if not Player.Play(ParamStr(1)) then raise Exception.Create(Player.LastError);
    Started:=GetTickCount64;
    while Player.Playing do begin
      if GetTickCount64-Started>3000 then raise Exception.Create('Audio did not finish');Sleep(5);
    end;
    if Player.LastError<>'' then raise Exception.Create(Player.LastError);
    if GetTickCount64-Started<100 then raise Exception.Create('Playback returned early');
    Player.Stop;WriteLn('PASS: real audio playback from a long path, completion and cleanup');
  finally Player.Free;end;
end.
