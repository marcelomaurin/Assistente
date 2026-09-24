procedure Tfrmmain.InitReception;
var P: TPanel; B: TButton;
begin
  Caption := 'Assistente | Recepcao FATEC';
  Width := 1100; Height := 780;
  FDataDir := ReceptionDataDir;
  FRunID := FormatDateTime('yyyymmddhhnnsszzz', Now) + '-' + IntToStr(GetTickCount64);
  FMemory := TReceptionMemory.Create(FDataDir + 'history');
  FMicrophone := TReceptionMicrophone.Create(FDataDir + 'audio');
  FReceptionSettings := TIniFile.Create(FDataDir + 'reception.ini');
  FMicrophone.Threshold := FReceptionSettings.ReadInteger('audio', 'threshold', 450);
  FDuplex := FReceptionSettings.ReadBool('audio', 'headphones_barge_in', False);
  FCamera := TAICaptureSource.Create(Self);
  FCamera.CameraIndex := FReceptionSettings.ReadInteger('camera', 'index', 0);
  FCamera.CaptureInterval := 1000;
  FCamera.TempFolder := FDataDir + 'frames';
  FCamera.AutoDeleteTempFiles := True;
  FCamera.PreviewEnabled := False;
  FCamera.OnFrame := @ReceptionFrame;
  FCamera.OnError := @ReceptionCameraError;
  FConversationOrchestrator.SessionManager.CreateGuestSession;
  FConversationOrchestrator.Context.CurrentProject := '';
  pnlQuickBar.Visible := False;
  pnlSidebar.Visible := False;
  pnlTop.Visible := False;
  pnlHistoricoHeader.Visible := False;
  memHistorico.Visible := False;
  tmrCheckOnline.Enabled := False;
  trayIcon.Visible := False;
  FSetMain.MinimizeToTray := False;
  btAnexar.Caption := 'Documentos';
  btMic.Caption := 'Ouvir';
  btParar.Caption := 'Interromper';
  lblPergunta.Caption := 'Converse comigo ou escreva sua pergunta';
  P := TPanel.Create(Self); P.Parent := pnlChat; P.Align := alTop;
  P.Height := 56; P.BevelOuter := bvNone; P.Color := $00201912;
  FReceptionStatus := TLabel.Create(Self); FReceptionStatus.Parent := P;
  FReceptionStatus.Align := alClient; FReceptionStatus.Layout := tlCenter;
  FReceptionStatus.Font.Color := clWhite; FReceptionStatus.Font.Size := 13;
  FReceptionStatus.Caption := 'Ola! Sou a assistente virtual da FATEC.';
  B := TButton.Create(Self); B.Parent := P; B.Align := alRight; B.Width := 105;
  B.Caption := 'Administrar'; B.OnClick := @ReceptionAdmin;
  B := TButton.Create(Self); B.Parent := P; B.Align := alRight; B.Width := 95;
  B.Caption := 'Nova pessoa'; B.OnClick := @ReceptionNewGuest;
  FReceptionSubtitle := TLabel.Create(Self); FReceptionSubtitle.Parent := pnlChat;
  FReceptionSubtitle.Align := alBottom; FReceptionSubtitle.AutoSize := False;
  FReceptionSubtitle.Height := 130; FReceptionSubtitle.WordWrap := True;
  FReceptionSubtitle.Alignment := taCenter; FReceptionSubtitle.Layout := tlCenter;
  FReceptionSubtitle.Font.Size := 16; FReceptionSubtitle.Font.Color := clWhite;
  FReceptionSubtitle.Caption := 'Pode perguntar sobre os projetos. Estou aqui para conversar.';
  FAvatarView := TReceptionAvatar.Create(Self); FAvatarView.Parent := pnlChat;
  FAvatarView.Align := alClient; FAvatarView.Avatar := FAvatar3D;
  FModelView := TAI3DModelViewer.Create(Self); FModelView.Parent := pnlChat;
  FModelView.Align := alClient; FModelView.Model := FAvatar3D.Model;
  FModelView.BackgroundColor := $00201912;
  FModelView.Visible := FAvatar3D.Active;
  FAvatarView.Visible := not FModelView.Visible;
  FCameraPreview := TImage.Create(Self); FCameraPreview.Parent := pnlSidebar;
  FCameraPreview.Align := alBottom; FCameraPreview.Height := 150;
  FCameraPreview.Proportional := True; FCameraPreview.Stretch := True;
  FCamera.PreviewImage := FCameraPreview;
  FReceptionTimer := TTimer.Create(Self); FReceptionTimer.Interval := 60;
  FReceptionTimer.OnTimer := @ReceptionTick;
  FAutoStartPending := FReceptionSettings.ReadBool('reception', 'autostart', True);
  if FindCmdLineSwitch('smoke-test') then FAutoStartPending := False;
end;

function Tfrmmain.ReceptionConfig: TReceptionConfig;
begin
  Result.Token := FSetMain.CHATGPT;
  Result.AudioToken := FReceptionSettings.ReadString('audio', 'token', GetEnvironmentVariable('OPENAI_API_KEY'));
  if (Result.AudioToken = '') and (FSetMain.ChatGPTProvider = 0) then Result.AudioToken := FSetMain.CHATGPT;
  Result.Provider := FSetMain.ChatGPTProvider;
  if (Result.Provider < 0) or (Result.Provider > Ord(High(TAIProvider))) then Result.Provider := 0;
  Result.Model := FSetMain.ChatGPTModel; Result.URL := FSetMain.ChatGPTURL;
  Result.Language := FSetMain.RecogLanguage;
  Result.RecogEngine := EnsureRange(FSetMain.RecogEngine, 0, 2);
  if Result.RecogEngine = 1 then Result.RecogEngine := 0;
  Result.SynthEngine := EnsureRange(FSetMain.SynthEngine, 0, 3);
  Result.Voice := FSetMain.SynthVoice;
  Result.Volume := FSetMain.SynthVolume; Result.Rate := FSetMain.SynthRate;
end;

function Tfrmmain.ReceptionPersonID: string;
begin
  if FConversationOrchestrator.SessionManager.ActiveSession = nil then
    FConversationOrchestrator.SessionManager.CreateGuestSession;
  Result := FConversationOrchestrator.SessionManager.ActiveSession.PersonID;
  if FConversationOrchestrator.SessionManager.ActiveSession.IsGuest then Result := FRunID + '-' + Result;
end;

procedure Tfrmmain.ReceptionNewGuest(Sender: TObject);
begin
  CancelReception;
  FPersonProfile := '';
  FConversationOrchestrator.Context.CurrentProject := '';
  FConversationOrchestrator.Context.CurrentPerson := '';
  FConversationOrchestrator.SessionManager.CreateGuestSession;
  FReceptionSubtitle.Caption := 'Ola! Sobre o que voce gostaria de conversar?';
end;

procedure Tfrmmain.CancelReception;
begin
  FPendingQuestion := '';
  FAutoGreet := False;
  if FReplyJob <> nil then FReplyJob.Cancel;
  if FTranscribeJob <> nil then FTranscribeJob.Cancel;
  if FSpeakJob <> nil then FSpeakJob.Cancel;
  if FMicrophone <> nil then FMicrophone.Stop;
  if FConversationOrchestrator <> nil then FConversationOrchestrator.StopSpeaking;
  if FAvatar3D <> nil then begin FAvatar3D.CancelGesture; FAvatar3D.SetState(avListening); end;
  FAguardandoResposta := False;
  btEnviar.Enabled := True;
end;

procedure Tfrmmain.StartReceptionQuestion(const AQuestion: string);
var Context, Knowledge, Person: string;
begin
  if Trim(AQuestion) = '' then Exit;
  CancelReception;
  { A cancelled network request owns its snapshot until it exits. Queue the
    latest utterance rather than sharing the LLM or freeing live objects. }
  if FReplyJob <> nil then begin FPendingQuestion := AQuestion; Exit; end;
  Person := ReceptionPersonID;
  Context := 'IDENTIDADE CONFIRMADA NESTA SESSAO: ' +
    FConversationOrchestrator.SessionManager.ActiveSession.Name + LineEnding + FPersonProfile;
  Context := Context + LineEnding + 'HISTORICO DESTA PESSOA:' + LineEnding + FMemory.Context(Person);
  Knowledge := KnowledgeContext(ExtractFilePath(Application.ExeName) + 'knowledge', AQuestion);
  Knowledge := Knowledge + KnowledgeContext(FDataDir + 'knowledge', AQuestion);
  Context := Context + LineEnding + 'DOCUMENTOS DE REFERENCIA:' + LineEnding + Knowledge;
  if FConversationOrchestrator.Context.CurrentProject <> '' then
    Context := Context + LineEnding + 'Projeto em foco: ' + FConversationOrchestrator.Context.CurrentProject;
  FMemory.Append(Person, 'user', AQuestion);
  FConversationOrchestrator.SessionManager.ActiveSession.AddMessage('user', AQuestion);
  AdicionaMensagemHistorico('Voce', AQuestion);
  FAvatar3D.SetState(avThinking);
  FReceptionStatus.Caption := 'Pensando na sua pergunta...';
  FReplyJob := TReceptionJob.Create(rjReply, ReceptionConfig, AQuestion, Context, Person);
  FAguardandoResposta := True;
end;

procedure Tfrmmain.ReceptionTick(Sender: TObject);
var AudioFile, Question, Reply: string; SpeechStart: Boolean;
begin
  if FClosing then Exit;
  try
    FAvatar3D.Update(0.06);
    if (FSpeakJob <> nil) and not FSpeakJob.Cancelled then
    begin
      FAvatar3D.SetState(avSpeaking);
      if FSetMain.Avatar3DLipSync then FAvatar3D.LipSync.ProcessAudioLevel(0.35 + 0.25 * Sin(GetTickCount64 / 90));
    end;
    if FModelView.Visible then FModelView.Invalidate else FAvatarView.Invalidate;
    PollVision;
    if FAutoGreet and (FReplyJob = nil) then
    begin
      FAutoGreet := False;
      Question := FPendingQuestion; FPendingQuestion := '';
      StartReceptionQuestion(Question);
    end;
    if FAutoStartPending then
    begin
      FAutoStartPending := False;
      StartVision;
      FVoiceActive := True;
    end;
    if (FReplyJob <> nil) and FReplyJob.Done then
    begin
      try
        if not FReplyJob.Cancelled and (FReplyJob.PersonID = ReceptionPersonID) then
        begin
          if FReplyJob.Success then
          begin
            Reply := FReplyJob.Text;
            FMemory.Append(FReplyJob.PersonID, 'assistant', Reply);
            FConversationOrchestrator.SessionManager.ActiveSession.AddMessage('assistant', Reply);
            FReceptionSubtitle.Caption := Reply;
            AdicionaMensagemHistorico('Assistente', Reply);
            if FReplyJob.Emotion = 'happy' then FAvatar3D.SetEmotion(aeHappy)
            else FAvatar3D.SetEmotion(aeNeutral);
            if FReplyJob.Gesture = 'wave' then FAvatar3D.PlayGesture(agWave)
            else if FReplyJob.Gesture = 'nod' then FAvatar3D.PlayGesture(agNod)
            else if FReplyJob.Gesture = 'explain' then FAvatar3D.PlayGesture(agExplain);
            FalaTexto(Reply);
            if FSpeakJob = nil then FAvatar3D.SetState(avListening);
            FReceptionStatus.Caption := 'Pode continuar a conversa.';
          end
          else
          begin
            FReceptionStatus.Caption := 'Nao consegui consultar a IA. Verifique a configuracao.';
            FReceptionSubtitle.Caption := 'Tente novamente em instantes. A resposta nao foi gerada.';
            AdicionaMensagemHistorico('Erro IA', FReplyJob.ErrorText);
            FAvatar3D.SetState(avError);
          end;
        end;
      finally FreeAndNil(FReplyJob); FAguardandoResposta := False; end;
      if FPendingQuestion <> '' then
      begin Question := FPendingQuestion; FPendingQuestion := ''; StartReceptionQuestion(Question); end;
    end;
    if (FSpeakJob <> nil) and FSpeakJob.Done then
    begin
      if FSpeakJob.ErrorText <> '' then AdicionaMensagemHistorico('Erro voz', FSpeakJob.ErrorText);
      FreeAndNil(FSpeakJob);
      FConversationOrchestrator.StopSpeaking;
      if FReplyJob = nil then FAvatar3D.SetState(avListening);
      FResumeMicAt := GetTickCount64 + 500;
    end;
    if (FTranscribeJob <> nil) and FTranscribeJob.Done then
    begin
      Question := '';
      if not FTranscribeJob.Cancelled and (FTranscribeJob.PersonID = ReceptionPersonID) then
      begin
        if FTranscribeJob.Success then Question := Trim(FTranscribeJob.Text)
        else begin
          FVoiceActive := False;
          FReceptionStatus.Caption := 'Reconhecimento de voz indisponivel. Pode escrever sua pergunta.';
          AdicionaMensagemHistorico('Erro microfone', FTranscribeJob.ErrorText);
        end;
      end;
      FreeAndNil(FTranscribeJob);
      if Question <> '' then StartReceptionQuestion(Question);
    end;
    if FVoiceActive and (FTranscribeJob = nil) and (GetTickCount64 >= FResumeMicAt) and
       ((FSpeakJob = nil) or FDuplex) then
    begin
      if not FMicrophone.Start then
      begin
        FVoiceActive := False;
        FReceptionStatus.Caption := 'Microfone indisponivel. Pode escrever sua pergunta.';
        AdicionaMensagemHistorico('Microfone', FMicrophone.LastError);
      end
      else
      begin
        if FMicrophone.Poll(AudioFile, SpeechStart) then
        begin
          FMicrophone.Stop;
          FTranscribeJob := TReceptionJob.Create(rjTranscribe, ReceptionConfig, AudioFile, '', ReceptionPersonID);
          FReceptionStatus.Caption := 'Entendendo o que voce disse...';
        end;
        if SpeechStart then
        begin
          if FSpeakJob <> nil then FSpeakJob.Cancel;
          if FReplyJob <> nil then FReplyJob.Cancel;
          FConversationOrchestrator.NotifySpeechStart;
          FAvatar3D.SetState(avListening);
        end;
      end;
    end;
    if FVoiceActive then btMic.Caption := 'Pausar escuta' else btMic.Caption := 'Ouvir';
  except
    on E: Exception do
    begin
      FVoiceActive := False;
      FMicrophone.Stop;
      FReceptionStatus.Caption := 'Verifique o diagnostico em Administrar.';
      AdicionaMensagemHistorico('Erro recepcao', E.Message);
    end;
  end;
end;

procedure Tfrmmain.StartVision;
var Python, Script, Models: string;
begin
  if FVisionProcess <> nil then Exit;
  Python := FReceptionSettings.ReadString('vision', 'python', 'python');
  Script := ExpandFileName(ExtractFilePath(Application.ExeName) + '..' + PathDelim + 'runtime' + PathDelim + 'reception_vision.py');
  Models := ExtractFilePath(Script) + 'models';
  FVisionProcess := TProcess.Create(nil);
  FVisionProcess.Executable := Python;
  FVisionProcess.Parameters.Add('-u'); FVisionProcess.Parameters.Add(Script);
  FVisionProcess.Parameters.Add('--models'); FVisionProcess.Parameters.Add(Models);
  FVisionProcess.Parameters.Add('--data'); FVisionProcess.Parameters.Add(FDataDir + 'people');
  FVisionProcess.Options := [poUsePipes, poNoConsole];
  try
    FVisionProcess.Execute;
    FVisionStarted := GetTickCount64;
  except
    on E: Exception do begin AdicionaMensagemHistorico('Visao', E.Message); FreeAndNil(FVisionProcess); end;
  end;
end;

procedure Tfrmmain.ReceptionCameraError(Sender: TObject; const AError: string);
begin
  AdicionaMensagemHistorico('Camera', AError);
  FReceptionStatus.Caption := 'Camera indisponivel; atendimento por voz e texto.';
end;

procedure Tfrmmain.ReceptionFrame(Sender: TObject; const AFrameFile: string);
var J: TJSONObject; S: UTF8String;
begin
  if (FVisionProcess = nil) or not FVisionReady or FVisionBusy then Exit;
  if not FVisionProcess.Running then Exit;
  FLastFrame := FDataDir + 'vision-input.bmp';
  if not CopyFile(AFrameFile, FLastFrame) then Exit;
  J := TJSONObject.Create(['command', 'recognize', 'frame', FLastFrame]);
  try
    S := J.AsJSON + #10;
    FVisionProcess.Input.WriteBuffer(S[1], Length(S));
    FVisionBusy := True; FVisionStarted := GetTickCount64;
  finally J.Free; end;
end;

procedure Tfrmmain.PollVision;
var Buffer: array[0..4095] of Byte; N, P, Count: Integer;
    Chunk, Line, ID, PersonName: string; J: TJSONData; O: TJSONObject;
begin
  if FVisionProcess = nil then Exit;
  while FVisionProcess.Output.NumBytesAvailable > 0 do
  begin
    N := FVisionProcess.Output.Read(Buffer, SizeOf(Buffer));
    if N <= 0 then Break;
    SetString(Chunk, PChar(@Buffer[0]), N);
    FVisionBuffer := FVisionBuffer + Chunk;
  end;
  P := Pos(#10, FVisionBuffer);
  while P > 0 do
  begin
    Line := Copy(FVisionBuffer, 1, P-1); Delete(FVisionBuffer, 1, P);
    J := GetJSON(Line);
    try
      if J is TJSONObject then
      begin
        O := TJSONObject(J); FVisionBusy := False;
        if not O.Get('ok', False) then
          AdicionaMensagemHistorico('Visao', O.Get('error', 'Erro desconhecido'))
        else if O.Get('ready', False) then
        begin
          FVisionReady := True;
          if not FCamera.StartCapture then ReceptionCameraError(Self, FCamera.LastError);
        end
        else if O.Get('enrolled', False) then
          AdicionaMensagemHistorico('Cadastro', O.Get('name', '') + ': amostras salvas = ' + IntToStr(O.Get('samples', 0)))
        else
        begin
          Count := O.Get('count', 0); ID := O.Get('id', ''); PersonName := O.Get('name', '');
          if Count = 0 then
          begin
            if (FLastPersonSeen > 0) and (GetTickCount64 - FLastPersonSeen > 10000) then
            begin ReceptionNewGuest(Self); FLastPersonSeen := 0; FVisualCandidate := ''; end;
          end
          else
          begin
            FLastPersonSeen := GetTickCount64;
            if (ID <> FVisualCandidate) or ((Count <> 1) and not FConversationOrchestrator.SessionManager.ActiveSession.IsGuest) then
            begin
              FVisualCandidate := ID;
              ReceptionNewGuest(Self);
            end;
            if (Count = 1) and (ID <> '') then
            begin
              { SFace applies cosine threshold and ambiguity margin. The suite
                receives a confirmed candidate, then requires temporal stability. }
              FConversationOrchestrator.NotifyVisualRecognition(ID, PersonName, 1.0);
              if not FConversationOrchestrator.SessionManager.ActiveSession.IsGuest then
                FPersonProfile := 'Nome: ' + PersonName + LineEnding + 'Cargo: ' + O.Get('role', '') + LineEnding + 'Descricao: ' + O.Get('bio', '');
            end;
            if (ID = '') or (Count <> 1) then
              FConversationOrchestrator.SessionManager.FeedVisualRecognition('', '', 0);
          end;
        end;
      end;
    finally J.Free; end;
    P := Pos(#10, FVisionBuffer);
  end;
  if not FVisionProcess.Running or
     ((not FVisionReady or FVisionBusy) and (GetTickCount64 - FVisionStarted > 15000)) then
  begin
    AdicionaMensagemHistorico('Visao', 'Reconhecimento indisponivel. Verifique Python, OpenCV e os modelos em runtime/models.');
    FCamera.StopCapture; FVisionReady := False;
    if FVisionProcess.Running then FVisionProcess.Terminate(0);
    FreeAndNil(FVisionProcess);
  end;
end;

procedure Tfrmmain.ReceptionEnroll(Sender: TObject);
var ID, PersonName, Role, Bio: string; J: TJSONObject; S: UTF8String;
begin
  if (FVisionProcess = nil) or not FVisionReady or FVisionBusy or not FileExists(FLastFrame) then
  begin ShowMessage('Aguarde a camera e o reconhecimento ficarem prontos.'); Exit; end;
  ID := ''; PersonName := ''; Role := ''; Bio := '';
  if not InputQuery('Cadastro de pessoa', 'Identificador unico (letras e numeros):', ID) then Exit;
  if not InputQuery('Cadastro de pessoa', 'Nome:', PersonName) then Exit;
  if not InputQuery('Cadastro de pessoa', 'Cargo ou funcao:', Role) then Exit;
  if not InputQuery('Cadastro de pessoa', 'Descricao para o atendimento:', Bio) then Exit;
  { Modal dialogs pump timers: obtain a NEW frame after data entry. }
  if FVisionBusy then begin ShowMessage('Aguarde a leitura atual e tente novamente.'); Exit; end;
  if not FCamera.CaptureToFile(FLastFrame) then begin ShowMessage('Camera sem imagem atual.'); Exit; end;
  J := TJSONObject.Create(['command', 'enroll', 'frame', FLastFrame, 'id', ID,
    'name', PersonName, 'role', Role, 'bio', Bio]);
  try
    S := J.AsJSON + #10;
    FVisionProcess.Input.WriteBuffer(S[1], Length(S));
    FVisionBusy := True; FVisionStarted := GetTickCount64;
  finally J.Free; end;
end;

procedure Tfrmmain.ReceptionAdmin(Sender: TObject);
var D: TForm; B: TButton; L: TLabel; EdPython, EdCamera, EdThreshold, EdAudioToken: TEdit;
    Duplex, AutoStart: TCheckBox;
begin
  D := TForm.CreateNew(Self);
  try
    D.Caption := 'Administracao da recepcao'; D.SetBounds(0,0,540,520); D.Position := poScreenCenter;
    L := TLabel.Create(D); L.Parent := D; L.SetBounds(20,15,500,30);
    L.Caption := 'Camera, identidade e escuta continua';
    L := TLabel.Create(D); L.Parent := D; L.SetBounds(20,55,490,20); L.Caption := 'Executavel Python (com OpenCV instalado)';
    EdPython := TEdit.Create(D); EdPython.Parent := D; EdPython.SetBounds(20,80,490,28);
    EdPython.Text := FReceptionSettings.ReadString('vision','python','python');
    L := TLabel.Create(D); L.Parent := D; L.SetBounds(20,120,220,20); L.Caption := 'Indice da camera';
    EdCamera := TEdit.Create(D); EdCamera.Parent := D; EdCamera.SetBounds(20,145,100,28); EdCamera.Text := IntToStr(FCamera.CameraIndex);
    L := TLabel.Create(D); L.Parent := D; L.SetBounds(180,120,300,20); L.Caption := 'Limiar de voz (menor = mais sensivel)';
    EdThreshold := TEdit.Create(D); EdThreshold.Parent := D; EdThreshold.SetBounds(180,145,120,28); EdThreshold.Text := IntToStr(FMicrophone.Threshold);
    Duplex := TCheckBox.Create(D); Duplex.Parent := D; Duplex.SetBounds(20,190,490,25);
    Duplex.Caption := 'Ouvir durante a fala (usar fone ou cancelamento de eco)'; Duplex.Checked := FDuplex;
    AutoStart := TCheckBox.Create(D); AutoStart.Parent := D; AutoStart.SetBounds(20,225,490,25);
    AutoStart.Caption := 'Iniciar camera e microfone ao abrir'; AutoStart.Checked := FReceptionSettings.ReadBool('reception','autostart',True);
    B := TButton.Create(D); B.Parent := D; B.SetBounds(20,270,150,34); B.Caption := 'IA e voz'; B.OnClick := @btAbrirConfigClick;
    B := TButton.Create(D); B.Parent := D; B.SetBounds(180,270,150,34); B.Caption := 'Cadastrar rosto'; B.OnClick := @ReceptionEnroll;
    B := TButton.Create(D); B.Parent := D; B.SetBounds(340,270,170,34); B.Caption := 'Diagnostico'; B.OnClick := @ReceptionLogs;
    L := TLabel.Create(D); L.Parent := D; L.SetBounds(20,320,490,40); L.WordWrap := True; L.AutoSize := False;
    L.Caption := 'Cadastre varias amostras com o mesmo identificador. Alteracoes de camera e Python valem na proxima abertura.';
    L := TLabel.Create(D); L.Parent := D; L.SetBounds(20,370,490,20); L.Caption := 'Chave OpenAI para voz (vazio: ambiente ou chave da IA OpenAI)';
    EdAudioToken := TEdit.Create(D); EdAudioToken.Parent := D; EdAudioToken.SetBounds(20,395,490,28); EdAudioToken.EchoMode := emPassword;
    EdAudioToken.Text := FReceptionSettings.ReadString('audio','token','');
    B := TButton.Create(D); B.Parent := D; B.SetBounds(340,450,170,34); B.Caption := 'Salvar'; B.ModalResult := mrOk;
    if D.ShowModal = mrOk then
    begin
      FReceptionSettings.WriteString('vision','python',Trim(EdPython.Text));
      FReceptionSettings.WriteString('audio','token',Trim(EdAudioToken.Text));
      FReceptionSettings.WriteInteger('camera','index',Max(0,StrToIntDef(EdCamera.Text,0)));
      FMicrophone.Threshold := EnsureRange(StrToIntDef(EdThreshold.Text,450),100,10000);
      FReceptionSettings.WriteInteger('audio','threshold',FMicrophone.Threshold);
      FDuplex := Duplex.Checked;
      FReceptionSettings.WriteBool('audio','headphones_barge_in',FDuplex);
      FReceptionSettings.WriteBool('reception','autostart',AutoStart.Checked);
      FReceptionSettings.UpdateFile;
    end;
  finally D.Free; end;
end;

procedure Tfrmmain.ReceptionLogs(Sender: TObject);
begin
  memHistorico.Visible := not memHistorico.Visible;
  if memHistorico.Visible then begin memHistorico.Align := alRight; memHistorico.Width := 340; end;
  pnlSidebar.Visible := memHistorico.Visible;
end;

destructor Tfrmmain.Destroy;
begin
  FClosing := True;
  if FReceptionTimer <> nil then FReceptionTimer.Enabled := False;
  if FCamera <> nil then FCamera.StopCapture;
  CancelReception;
  FreeAndNil(FReplyJob); FreeAndNil(FTranscribeJob); FreeAndNil(FSpeakJob);
  if FVisionProcess <> nil then
  begin
    if FVisionProcess.Running then FVisionProcess.Terminate(0);
    FreeAndNil(FVisionProcess);
  end;
  FMicrophone.Free; FMemory.Free; FReceptionSettings.Free;
  if FLastFrame <> '' then DeleteFile(FLastFrame);
  inherited Destroy;
end;
