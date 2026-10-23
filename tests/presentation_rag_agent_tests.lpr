program presentation_rag_agent_tests;
{$mode objfpc}{$H+}
uses Interfaces, Classes, SysUtils, Windows, agent_manager, presentation_rag;
type
  TObserver = class
    Done,Success: Boolean;
    Text: string;
    procedure Complete(Sender: TObject; const Response,Provider: string; OK: Boolean);
  end;
procedure TObserver.Complete(Sender: TObject; const Response,Provider: string; OK: Boolean);
begin Done:=True;Success:=OK;Text:=Response;end;
var Manager: TAssistantManager; Observer: TObserver; Root,Mode: string; Started: QWord;
procedure Check(B: Boolean; const E: string);
begin if not B then raise Exception.Create(E);end;
begin
  try
    Root:=ExpandFileName(ParamStr(1));Mode:=ParamStr(3);
    SetEnvironmentVariableW('ASSISTENTE_CONFIG_DIR',PWideChar(UTF8Decode(Root+PathDelim+'agent-config')));
    PublishPresentation(Root+PathDelim+'energia solar.pva');
    Manager:=TAssistantManager.Create(nil);Observer:=TObserver.Create;
    try
      Manager.ChatGPT.TOKEN:='local-test';Manager.ChatGPT.CustomModel:='local-test';
      Manager.ChatGPT.URL:=UTF8Decode(ParamStr(2));Manager.ChatGPT.Timeout:=5000;
      Manager.OnComplete:=@Observer.Complete;
      Manager.ProcessUserRequestAsync('Contexto: o usuario estuda fontes de energia.','Mostre a apresentação de energia solar');
      Started:=GetTickCount64;
      while not Observer.Done do begin
        Check(GetTickCount64-Started<15000,'agent timeout');CheckSynchronize(10);
        if (Mode='cancel') and (GetTickCount64-Started>150) then Manager.CancelExecution;
      end;
      if Mode='selected' then begin
        Check(Observer.Success,Observer.Text);
        Check(ExtractFileName(Manager.SelectedPresentation)='energia solar.pva','agent selected wrong package');
        Check(Manager.SelectedPresentationDigest<>'','missing selection digest');
        // A second question must clear the previous selection before making a request.
        Observer.Done:=False;Manager.ChatGPT.URL:=UTF8Decode(ParamStr(4));
        // Completion synchronizes before the thread returns. Wait until it has returned.
        Sleep(100);Manager.ProcessUserRequestAsync('Responda sem apresentação');
        Check(Manager.SelectedPresentation='','selection leaked into next question');
        Started:=GetTickCount64;
        while not Observer.Done do begin Check(GetTickCount64-Started<15000,'second request timeout');CheckSynchronize(10);end;
        Check(Observer.Success and (Manager.SelectedPresentation=''),'normal answer after presentation');
      end else if Mode='none' then
        Check(Observer.Success and (Manager.SelectedPresentation='') and (Pos('Resposta comum',Observer.Text)>0),'no-match did not answer normally')
      else Check(not Observer.Success and (Manager.SelectedPresentation=''),'invalid/cancelled selection executed');
      WriteLn('PASS: real agent RAG ',Mode);
    finally Manager.Free;Observer.Free;end;
  except on E: Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
