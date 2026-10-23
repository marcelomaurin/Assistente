program presentation_webview_tests;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Controls,ExtCtrls,Classes,SysUtils,ActiveX,presentation_webview;
var Window:TForm;Panel:TPanel;View:TPresentationWebView;Started:QWord;I:Integer;
procedure Check(B:Boolean;const Message:string);
begin if not B then raise Exception.Create(Message);end;
procedure Pump(MS:Integer);
var T:QWord;
begin T:=GetTickCount64;repeat Application.ProcessMessages;Sleep(5);until GetTickCount64-T>=QWord(MS);end;
begin
  try
  Application.Initialize;CoInitialize(nil);Window:=TForm.CreateNew(nil);
  try
    Window.SetBounds(0,0,800,600);Panel:=TPanel.Create(Window);Panel.Parent:=Window;Panel.Align:=alClient;
    View:=TPresentationWebView.Create(Panel,'M7lc1UVf-VE',0);
    try
      Started:=GetTickCount64;
      while not View.Ready do begin
        Pump(10);Check(View.ErrorText='',View.ErrorText);Check(GetTickCount64-Started<20000,'WebView initialization timed out');
      end;
      Check(not View.Finished,'Player finished without a click');
      View.Resize;View.SetPaused(True);View.SetPaused(False);
      // A local player fixture validates the HTML/COM/message path without
      // external requests, credentials or audible playback.
      View.ExecuteScript('window.YT={Player:function(id,o){this.playVideo=function(){};this.pauseVideo=function(){};this.stopVideo=function(){};this.getPlayerState=function(){return 1};window.fixtureOptions=o;}};start();');
      Pump(100);Check(not View.Finished,'Loading player completed presentation early');
      View.ExecuteScript('window.fixtureOptions.events.onStateChange({data:0});');
      Started:=GetTickCount64;
      while not View.Finished do begin Pump(10);Check(View.ErrorText='',View.ErrorText);Check(GetTickCount64-Started<3000,'YouTube end event did not reach host');end;
      Check(View.ErrorText='',View.ErrorText);
    finally View.Free;end;
    if ParamStr(1)='--online' then begin
      View:=TPresentationWebView.Create(Panel,'M7lc1UVf-VE',0,True);
      try
        Started:=GetTickCount64;
        while not View.Ready do begin Pump(10);Check(View.ErrorText='',View.ErrorText);Check(GetTickCount64-Started<20000,'Online WebView initialization timed out');end;
        View.ExecuteScript('start()');Started:=GetTickCount64;
        while View.PlayerState<>1 do begin
          Pump(10);Check(View.ErrorText='',View.ErrorText);Check(View.PlayerError='','YouTube player error '+View.PlayerError);
          Check(GetTickCount64-Started<45000,'YouTube did not start playback; last state '+IntToStr(View.PlayerState));
        end;
        WriteLn('PASS: live YouTube stream started inside WebView2, muted, with the application HTTPS origin');
      finally View.Free;end;
    end;
    for I:=1 to 3 do begin View:=TPresentationWebView.Create(Panel,'M7lc1UVf-VE',0);View.Free;Pump(100);end;
    Pump(300);
    WriteLn('PASS: real WebView2 child control, HTTPS virtual origin, local click/end fixture, pause, resize and safe asynchronous teardown');
  finally Window.Free;CoUninitialize;end;
  except on E:Exception do begin WriteLn(StdErr,'FAIL: '+E.ClassName+': '+E.Message);Halt(1);end;end;
end.
