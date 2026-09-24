program reception_tests;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Math, Graphics,
  reception_core, reception_audio, chatgpt, main;
var
  Root, Text, URL: string;
  Memory: TReceptionMemory;
  A, B: TMemoryStream;
  S: SmallInt;
  I: Integer;
  RMS: Double;
  Config: TReceptionConfig;
  Job: TReceptionJob;
  Started: QWord;
  Log: TStringList;
  Bitmap: TBitmap;
procedure Check(Value: Boolean; const Msg: string);
begin
  if not Value then raise Exception.Create(Msg);
  Log.Add('PASS ' + Msg);
end;
procedure AwaitJob;
begin
  Started := GetTickCount64;
  while not Job.Done and (GetTickCount64 - Started < 10000) do Sleep(20);
  Check(Job.Done, 'worker termina sem sincronizacao com a UI');
end;
begin
  Root := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'test-output' + PathDelim;
  ForceDirectories(Root);
  Log := TStringList.Create;
  try
    Application.Initialize;
    Memory := TReceptionMemory.Create(Root + IntToStr(GetTickCount64));
    try
      Memory.Append('pessoa-a', 'user', 'Somente Ana conhece o microscópio.');
      Memory.Append('pessoa-b', 'user', 'Bruno perguntou sobre robótica.');
      Text := Memory.Context('pessoa-b');
      Check(Pos('Ana', Text) = 0, 'historico isolado entre pessoas');
      Check(Pos('robótica', Text) > 0, 'historico preserva UTF-8');
      Memory.Append('pessoa-a', 'assistant', 'Resposta nova.');
      Check(Pos('microscópio', Memory.Context('pessoa-a')) > 0, 'persistencia atomica preserva mensagens anteriores');
      Memory.Append('../pessoa', 'user', 'caminho isolado');
      Check(Memory.Context('.._pessoa') = '', 'identificadores nao colidem nem escapam da pasta');
    finally Memory.Free; end;
    A := TMemoryStream.Create; B := TMemoryStream.Create;
    try
      for I := 1 to 16000 do begin S := Round(1200 * Sin(I / 15)); A.WriteBuffer(S, 2); end;
      WritePCM16(Root+'speech.wav', A);
      Check(ReadPCM16(Root+'speech.wav', B, RMS), 'leitura WAV PCM16 mono 16kHz');
      Check((RMS > 800) and (RMS < 900), 'energia de voz calculada corretamente');
      Check(A.Size = B.Size, 'segmentacao preserva todas as amostras');
    finally A.Free; B.Free; end;
    ForceDirectories(Root+'knowledge');
    Log.SaveToFile(Root+'knowledge'+PathDelim+'placeholder.txt');
    with TStringList.Create do
    try Text := 'O projeto Hemacias analisa imagens de microscopia.'; SaveToFile(Root+'knowledge'+PathDelim+'hemacias.txt');
    finally Free; end;
    Check(Pos('microscopia', KnowledgeContext(Root+'knowledge','Hemacias microscopia')) > 0, 'RAG recupera documento pela biblioteca CHATGPT');
    URL := GetEnvironmentVariable('RECEPTION_TEST_URL');
    if URL <> '' then
    begin
      Config.Token := 'test-only'; Config.AudioToken := '';
      Config.Provider := Ord(AIP_OPENAI_COMPATIBLE); Config.URL := URL; Config.Model := 'test';
      Job := TReceptionJob.Create(rjReply, Config, 'Explique o microscópio.', 'Historico somente de Ana.', 'ana');
      try
        AwaitJob;
        Check(Job.Success, 'TAIAgent responde via provedor configurado: '+Job.ErrorText);
        Check(Pos('microscópio', Job.Text) > 0, 'fala extraida do contrato do agente, com acentos');
        Check(Job.PersonID = 'ana', 'resposta permanece vinculada a sessao de origem');
      finally Job.Free; end;
      Job := TReceptionJob.Create(rjReply, Config, 'slow', '', 'ana');
      try
        Sleep(100); Job.Cancel; AwaitJob;
        Check(Job.Cancelled, 'cancelamento nao entrega resposta atrasada');
      finally Job.Free; end;
      Job := TReceptionJob.Create(rjReply, Config, 'invalid', '', 'ana');
      try AwaitJob; Check(not Job.Success, 'resposta sem fala nao e apresentada como sucesso');
      finally Job.Free; end;
    end;
    Application.CreateForm(Tfrmmain, frmmain);
    try
      frmmain.SetBounds(0,0,1100,780);
      frmmain.HandleNeeded;
      Check(Pos('Recepcao', frmmain.Caption) > 0, 'formulario inicia como recepcao');
      Check(not frmmain.tmrCheckOnline.Enabled, 'recepcao independe do JARVIS');
      Check(not frmmain.pnlQuickBar.Visible, 'automacao residencial fora do atendimento');
      Bitmap := TBitmap.Create;
      try
        Bitmap.SetSize(frmmain.Width,frmmain.Height);
        frmmain.PaintTo(Bitmap.Canvas,0,0);
        Bitmap.SaveToFile(Root+'reception.bmp');
      finally Bitmap.Free; end;
    finally FreeAndNil(frmmain); end;
    Log.Add('ALL TESTS PASSED');
    Log.SaveToFile(Root+'results.txt');
  except
    on E: Exception do
    begin Log.Add('FAIL '+E.Message); Log.SaveToFile(Root+'results.txt'); Log.Free; Halt(1); end;
  end;
  Log.Free;
end.
