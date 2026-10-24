program movement_catalog_tests;
{$mode objfpc}{$H+}{$codepage utf8}
uses Classes, SysUtils, fpjson, jsonparser, movement_catalog, professor_commands,
  presentation_document;
var Original,Fixture,BadFile:string;J:TJSONData;O,Bad:TJSONObject;A:TJSONArray;
  S:TAvatarScript;M:TMovementDefinition;Before,I:Integer;L:TStringList;Rejected:Boolean;
procedure Check(Condition:Boolean;const Message:string);
begin if not Condition then raise Exception.Create(Message);end;
procedure WriteJSON(const FileName:string;Data:TJSONData);
var T:TStringList;
begin T:=TStringList.Create;try T.Text:=Data.FormatJSON(AsCompressedJSON);T.SaveToFile(FileName);finally T.Free;end;end;
procedure Reject(const Message:string);
begin
  WriteJSON(BadFile,Bad);Rejected:=False;
  try ReloadMovementCatalog(BadFile);except on E:Exception do Rejected:=True;end;
  Check(Rejected,Message);Check(MovementCount=Before,'Failed reload replaced the valid catalog');
end;
begin
  Original:=MovementCatalogFile;Before:=MovementCount;
  Fixture:=ExpandFileName(ParamStr(1))+PathDelim+'movement-custom.json';BadFile:=Fixture+'.bad';
  ForceDirectories(ExtractFilePath(Fixture));L:=TStringList.Create;J:=nil;
  try
    L.LoadFromFile(Original);J:=GetJSON(L.Text);A:=TJSONObject(J).Arrays['movements'];
    O:=TJSONObject.Create(['id','saudacao_nova','tag','saudação especial','title','Saudação do JSON',
      'description','Movimento criado durante o teste, sem recompilar','mode','pose','clip','idle']);
    O.Add('aliases',TJSONArray.Create(['novo gesto']));A.Add(O);
    O:=TJSONObject.Create(['id','pulso_json','tag','pulso personalizado','mode','pose']);
    O.Add('joints',TJSONArray.Create([TJSONObject.Create(['bone','wrist.R','axis','y','angle',25,'duration_ms',150]),
      TJSONObject.Create(['bone','finger3-2.R','axis','x','angle',35,'duration_ms',150])]));A.Add(O);
    WriteJSON(Fixture,J);ReloadMovementCatalog(Fixture);Before:=MovementCount;
    Check(FindMovement('NOVO_GESTO',M) and (M.ID='saudacao_nova'),'Dynamic alias did not load');
    S:=ParseAvatarScript('[saudação especial] Olá [pulso personalizado]');
    Check((S.CommandCount=2) and (S.Steps[0].Command=acCustom) and
      (S.Steps[0].MovementID='saudacao_nova') and (S.Steps[2].MovementID='pulso_json'),'Dynamic IDs lost in parser');
    Check(S.PlainText=' Olá ','Dynamic tags leaked into speech');
    Check(Pos('[saudação especial]',AvatarInstructionText)>0,'AI ignored JSON vocabulary');
    Check(WithoutMovements('[novo gesto]Olá')='Olá','Editor did not strip dynamic movements');
    Check(AcceptGeneratedMovements('Olá','[novo gesto]Olá')='[novo gesto]Olá','Editor rejected new movement');
    S:=ParseAvatarScript('`[novo gesto]` [novo gesto](https://example.test) \[novo gesto]');
    Check(S.CommandCount=0,'Custom commands bypassed literal protections');
    Check(FindMovement('pulso_json',M) and (Length(M.Joints)=2),'Joint resource did not load');
    Bad:=TJSONObject(J.Clone);try Bad.Integers['version']:=3;Reject('Unsupported schema accepted');finally Bad.Free;end;
    Bad:=TJSONObject(J.Clone);try
      Bad.Arrays['movements'].Add(TJSONObject.Create(['id','duplicado','tag','novo gesto','mode','pose','clip','idle']));
      Reject('Alias collision accepted');
    finally Bad.Free;end;
    Bad:=TJSONObject(J.Clone);try
      TJSONObject(Bad.Arrays['movements'].Items[0]).Integers['duration_ms']:=0;Reject('Invalid duration accepted');
    finally Bad.Free;end;
    Bad:=TJSONObject(J.Clone);try
      TJSONObject(Bad.Arrays['movements'].Items[A.Count-1]).Arrays['joints'].Objects[0].Strings['bone']:='jaw';
      Reject('Unsupported jaw joint accepted');
    finally Bad.Free;end;
    Bad:=TJSONObject(J.Clone);try
      TJSONObject(Bad.Arrays['movements'].Items[A.Count-1]).Arrays['joints'].Objects[1].Integers['angle']:=101;
      Reject('Out-of-range finger angle accepted');
    finally Bad.Free;end;
    L.Text:='{';L.SaveToFile(BadFile);Rejected:=False;
    try ReloadMovementCatalog(BadFile);except on E:Exception do Rejected:=True;end;
    Check(Rejected and FindMovement('novo gesto',M),'Broken JSON damaged current catalog');
    ReloadMovementCatalog(Original);
    WriteLn('PASS: runtime JSON additions, aliases, AI vocabulary, editor validation, literals, joint bounds and atomic reload');
  finally J.Free;L.Free;end;
end.
