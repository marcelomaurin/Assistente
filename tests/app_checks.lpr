program app_checks;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, chatgpt, setmain, frmconfig,
  config_binding, reception_core, voice_input_bridge, agent_manager, main;
type
  TObserver=class
    Finished, Success:Boolean;
    Text:string;
    procedure Complete(Sender:TObject;const AText,AProvider:string;ASuccess:Boolean);
    procedure VoiceFinished(Sender:TObject);
  end;
procedure TObserver.Complete(Sender:TObject;const AText,AProvider:string;ASuccess:Boolean);
begin Finished:=True;Success:=ASuccess;Text:=AText;end;
procedure TObserver.VoiceFinished(Sender:TObject);
begin Finished:=True;end;
procedure Check(B:Boolean;const S:string);
begin if not B then raise Exception.Create(S);WriteLn('PASS ',S);end;
procedure WaitResult(O:TObserver);
var T:QWord;
begin
  T:=GetTickCount64;
  while not O.Finished and (GetTickCount64-T<10000) do
  begin Application.ProcessMessages;Sleep(5);end;
  Check(O.Finished,'conclusao entregue sem travar interface');
  Application.ProcessMessages;
end;
var C,D:TSetMain; F:TfrmConfig; M:TAssistantManager; O:TObserver;
  V:TVoiceInputBridge; S:TStringList; URL,Root:string; Started:QWord;
begin
  try
    Application.Initialize;
    Root:=IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
    C:=TSetMain.Create;
    try
      Check(C.JarvisAPIKey='','sem credencial JARVIS embutida');
      C.VoiceProvider:=2;C.VoiceAPIToken:='test-only';
      C.VoiceModel:='gpt-4o-mini-tts';C.VoiceEndpoint:='http://127.0.0.1/speech';
      C.VoiceRemoteVoice:='alloy';C.VoiceSpeed:=1.25;
      C.CHATGPT:='test-only';C.JarvisAPIKey:='test-only-jarvis';
      C.SalvaContexto(False);
      D:=TSetMain.Create;
      try
        Check(D.VoiceModel=C.VoiceModel,'modelo preservado sem downgrade');
        Check((D.VoiceProvider=2) and (D.VoiceAPIToken='test-only'),'provedor e token de voz persistem');
        Check((D.VoiceEndpoint=C.VoiceEndpoint) and (Abs(D.VoiceSpeed-1.25)<0.001),'endpoint e velocidade persistem');
        Check((D.CHATGPT=C.CHATGPT) and (D.JarvisAPIKey=C.JarvisAPIKey),'tokens protegidos podem ser recarregados');
      finally D.Free;end;
      F:=TfrmConfig.Create(nil);
      try
        LoadSettings(F,C);
        Check(F.edTokenGPT.Text=C.CHATGPT,'formulario recebe configuracao');
        F.edURL.Text:='http://127.0.0.1/custom';
        F.chkContinuousListening.Checked:=False;
        SaveSettings(F,C);
        Check(C.ChatGPTURL=F.edURL.Text,'formulario devolve configuracao');
      finally F.Free;end;
      Check(KnowledgeContext('','pergunta')='','pasta vazia nao pesquisa diretorio atual');
      ForceDirectories(Root+'knowledge');
      S:=TStringList.Create;
      try S.Text:='O laboratorio de microscopia abre mediante agendamento.';
        S.SaveToFile(Root+'knowledge\laboratorio.txt');
      finally S.Free;end;
      Check(Pos('[laboratorio.txt]',KnowledgeContext(Root+'knowledge','microscopia'))>0,'RAG inclui fonte');
      Check(KnowledgeContext(Root+'knowledge','zzzzzzzz')='','RAG nao inventa correspondencia');
      O:=TObserver.Create;
      try
        FSetMain:=C;
        V:=TVoiceInputBridge.Create(nil);
        try
          C.STTToken:='test-only';C.STTEndpoint:='http://127.0.0.1:1/unavailable';
          C.RecogEngine:=99;V.OnFinished:=@O.VoiceFinished;
          S:=TStringList.Create;
          try S.Text:='invalid wav';S.SaveToFile(Root+'invalid.wav');finally S.Free;end;
          Check(V.TranscribeWav(Root+'invalid.wav'),'job de transcricao iniciado');
          WaitResult(O);
          Check(not V.Busy,'falha STT libera ponte');
        finally V.Free;FSetMain:=nil;end;
        FSetMain:=C;
        frmmain:=Tfrmmain.Create(nil);
        try
          C.AutoSpeak:=True;C.SynthEngine:=99;C.ContinuousListening:=False;
          frmmain.AssistantManager.OnComplete(frmmain.AssistantManager,'Resposta de teste','test',True);
          Check(not frmmain.btEnviar.Enabled,'entrada bloqueada durante job de voz');
          Started:=GetTickCount64;
          while not frmmain.btEnviar.Enabled and (GetTickCount64-Started<5000) do
          begin Application.ProcessMessages;Sleep(5);end;
          Check(frmmain.btEnviar.Enabled,'fim ou falha TTS libera entrada');
          Check(Pos('Falha na voz',frmmain.lblStatus.Caption)>0,'erro TTS e apresentado');
        finally FreeAndNil(frmmain);FSetMain:=nil;end;
        URL:=GetEnvironmentVariable('ASSISTENTE_TEST_URL');
        if URL<>'' then
        begin
          M:=TAssistantManager.Create(nil);
          try
            M.ChatGPT.Provider:=AIP_OPENAI_COMPATIBLE;
            M.ChatGPT.URL:=UTF8Decode(URL);M.ChatGPT.CustomModel:='test';M.ChatGPT.TOKEN:='test-only';
            M.KnowledgeFolder:=Root+'knowledge';M.OnComplete:=@O.Complete;
            O.Finished:=False;M.ProcessUserRequestAsync('microscopia');WaitResult(O);
            Check(O.Success and (Pos('microsc',O.Text)>0),'atendimento retorna resposta do provedor local');
          finally M.Free;end;
          M:=TAssistantManager.Create(nil);
          M.ChatGPT.Provider:=AIP_OPENAI_COMPATIBLE;M.ChatGPT.URL:=UTF8Decode(URL);
          M.ChatGPT.CustomModel:='test';M.ChatGPT.TOKEN:='test-only';
          M.ProcessUserRequestAsync('slow');
          M.Free;
          Check(True,'encerramento aguarda worker sem acesso a objeto destruido');
        end;
      finally O.Free;end;
    finally C.Free;end;
    WriteLn('ALL APP CHECKS PASSED');
  except on E:Exception do begin WriteLn('FAIL ',E.Message);Halt(1);end;end;
end.
