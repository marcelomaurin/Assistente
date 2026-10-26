program assistant_config_tests;
{ Configuration file export/import (Configurações > Exportar / Importar and
  assistente.exe --importar-config=<arquivo>). Usage: assistant_config_tests <work dir> }
{$mode objfpc}{$H+}
uses Interfaces, Classes, SysUtils, Windows, fpjson, jsonparser, setmain, assistant_config_file;
var Root,Plain,NoSecrets,Bad: string; A,B: TSetMain; J: TJSONData; S: TJSONObject; L: TStringList; N: Integer;
procedure Check(Value: Boolean; const Error: string);
begin if not Value then raise Exception.Create(Error);end;
function ReadJSON(const FileName: string): TJSONData;
var F: TStringList;
begin
  F:=TStringList.Create;
  try F.LoadFromFile(FileName);Result:=GetJSON(F.Text);finally F.Free;end;
end;
procedure Rejects(const FileName, Text, Expected: string);
var F: TStringList;
begin
  F:=TStringList.Create;
  try F.Text:=Text;F.SaveToFile(FileName);finally F.Free;end;
  try ImportAssistantConfig(B,FileName);raise Exception.Create('accepted: '+Text);
  except on E: Exception do Check(Pos(Expected,E.Message)>0,'unexpected error for '+Text+': '+E.Message);end;
end;
procedure UseConfigDir(const Name: string);
begin
  ForceDirectories(Root+PathDelim+Name);
  SetEnvironmentVariableW('ASSISTENTE_CONFIG_DIR',PWideChar(UTF8Decode(Root+PathDelim+Name)));
end;
begin
  try
    Root:=ExpandFileName(ParamStr(1));ForceDirectories(Root);
    UseConfigDir('origem');
    A:=TSetMain.Create;
    try
      A.ChatGPTProvider:=3;A.ChatGPTModel:='gpt-4o-mini';A.CHATGPT:='sk-teste-123';A.ChatGPTURL:='https://api.exemplo/v1';
      A.SynthVoice:='nova';A.SynthVolume:=80;A.RecogLanguage:='pt-BR';A.ContinuousListening:=True;
      A.JarvisAPIKey:='jarvis-segredo';A.PasswordMy:='senha-my';A.STTToken:='stt-segredo';
      A.Avatar3DProfile:='businesswoman';A.RAGInAnswers:=False;
      A.posx:=777;A.AudioDeviceIndex:=5;A.Frase:='Linha 1'+#10+'POSX:1';
      A.SalvaContexto(False);
      Plain:=Root+PathDelim+'com-segredos'+AssistantConfigExtension;
      NoSecrets:=Root+PathDelim+'sem-segredos'+AssistantConfigExtension;
      ExportAssistantConfig(A,Plain,True);ExportAssistantConfig(A,NoSecrets,False);
    finally A.Free;end;

    J:=ReadJSON(Plain);
    try
      Check(TJSONObject(J).Get('format','')=AssistantConfigFormat,'format');
      Check(TJSONObject(J).Get('contains_secrets',False),'contains_secrets flag');
      S:=TJSONObject(J).Objects['settings'];
      Check(S.Get('CHATGPT','')='sk-teste-123','plain secret missing');
      Check(S.Get('STT_TOKEN','')='stt-segredo','DPAPI secret not exported in clear');
      Check(S.Find('POSX')=nil,'window position exported');
      Check(S.Find('AUDIODEVICEINDEX')=nil,'device index exported');
      Check(S.Get('RAG_IN_ANSWERS','')='0','RAG option missing');
      Check(Pos(#10,S.Get('FRASE',''))=0,'line break kept in a value');
    finally J.Free;end;
    J:=ReadJSON(NoSecrets);
    try
      S:=TJSONObject(J).Objects['settings'];
      Check(not TJSONObject(J).Get('contains_secrets',True),'contains_secrets without secrets');
      Check((S.Find('CHATGPT')=nil) and (S.Find('JARVISAPIKEY')=nil) and (S.Find('PASSWORDMY')=nil) and
        (S.Find('STT_TOKEN')=nil) and (S.Find('INTEGRATION_TOKEN')=nil),'secret exported without permission');
      Check(S.Get('CHATGPTMODEL','')='gpt-4o-mini','ordinary setting missing');
    finally J.Free;end;

    // Another installation: defaults, then the file.
    UseConfigDir('destino');
    B:=TSetMain.Create;
    try
      Check(B.RAGInAnswers and (B.CHATGPT=''),'destination not at defaults');
      B.posx:=11;B.CHATGPT:='chave-local';
      N:=ImportAssistantConfig(B,NoSecrets);Check(N>20,'too few settings applied: '+IntToStr(N));
      Check((B.ChatGPTProvider=3) and (B.ChatGPTModel='gpt-4o-mini') and (B.SynthVoice='nova') and
        (B.SynthVolume=80) and (B.RecogLanguage='pt-BR') and B.ContinuousListening and
        (B.Avatar3DProfile='businesswoman') and not B.RAGInAnswers,'settings not applied');
      Check(B.CHATGPT='chave-local','missing secret erased the local key');
      Check(B.posx=11,'machine setting changed by import');
      ImportAssistantConfig(B,Plain);
      Check((B.CHATGPT='sk-teste-123') and (B.JarvisAPIKey='jarvis-segredo') and (B.PasswordMy='senha-my') and
        (B.STTToken='stt-segredo'),'secrets not applied');
      B.SalvaContexto(False);
      L:=TStringList.Create;
      try
        L.LoadFromFile(Root+PathDelim+'destino'+PathDelim+'Setmain.cfg');
        Check(Pos('STT_TOKEN:stt-segredo',L.Text)=0,'imported token stored without protection');
        Check(Pos('RAG_IN_ANSWERS:0',L.Text)>0,'RAG option not stored');
      finally L.Free;end;
      Bad:=Root+PathDelim+'invalido.json';
      Rejects(Bad,'nao e json','inválido');
      Rejects(Bad,'{"format":"outro","version":1,"settings":{}}','não é uma configuração');
      Rejects(Bad,'{"format":"assistente-config","version":9,"settings":{"A":"1"}}','Versão');
      Rejects(Bad,'{"format":"assistente-config","version":1}','settings');
      Rejects(Bad,'{"format":"assistente-config","version":1,"settings":{"POSX":"1"}}','Nenhuma configuração');
      Rejects(Bad,'{"format":"assistente-config","version":1,"settings":{"FRASE":"a\nCHATGPT:x"}}','quebra de linha');
      Rejects(Bad,'{"format":"assistente-config","version":1,"settings":{"CHATGPT":{"x":1}}}','Valor inválido');
      Check(B.CHATGPT='sk-teste-123','rejected file changed the settings');
    finally B.Free;end;
    WriteLn('PASS: configuration file export with/without secrets, machine keys excluded, import onto defaults, local secrets kept when absent, DPAPI storage after import, invalid files rejected without changes');
  except on E: Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
