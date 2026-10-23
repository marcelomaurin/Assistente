program pva_tool;
{$mode objfpc}{$H+}
uses presentation_cli, SysUtils, Classes, presentation_package, presentation_document, presentation_paths,
  professor_commands, presentation_tags, presentation_joint_tags, movement_catalog;
var P: TPVAPackage;
procedure Check(B: Boolean; const S: string);
begin if not B then raise Exception.Create(S);end;
procedure SelfTest;
var S: TAvatarScript; T: TPresentationTag; J: TJointTag; M: TMemoryStream; X: string; Definition:TMovementDefinition; I,K,MS: Integer;
begin
  for I:=0 to MovementCount-1 do begin
    Definition:=MovementAt(I);S:=ParseAvatarScript('['+Definition.Tag+']');
    Check((S.CommandCount=1) and (S.Steps[0].MovementID=Definition.ID),'catalog command lost: '+Definition.Tag);
    for K:=0 to High(Definition.Aliases) do begin
      S:=ParseAvatarScript('['+Definition.Aliases[K]+']');
      Check((S.CommandCount=1) and (S.Steps[0].MovementID=Definition.ID),'catalog alias lost: '+Definition.Aliases[K]);
    end;
  end;
  Check(not SafePresentationPath('../escape.png'),'traversal');
  Check(not SafePresentationPath('assets/CON.png'),'device name');
  Check(not SafePresentationPath('assets/a.png:stream'),'ADS');
  Check(not SafePresentationPath('assets//a.png'),'empty component');
  Check(not SafePresentationPath('assets/a. /b.png'),'trailing space');
  Check(TryParsePresentationTag('[abrir arquivo=assets/a.png]',T),'open tag');
  Check(not TryParsePresentationTag('[abrir arquivo=../a.png]',T),'unsafe tag');
  Check(not TryParsePresentationTag('[ir para slide=0]',T),'slide zero');
  Check(TryParsePresentationTime('01:02:03',MS) and (MS=3723000),'hh:mm:ss');
  Check(TryParsePresentationTime('99:59:59',MS) and (MS=359999000),'time upper bound');
  Check(not TryParsePresentationTime('00:60:00',MS),'minutes limit');
  Check(not TryParsePresentationTime('1:02:03',MS),'time shape');
  Check(TryParsePresentationTag('[abrir arquivo=assets/video.mp4|inicio=00:01:30]',T) and
    T.HasStart and (T.StartMS=90000) and (T.Argument='assets/video.mp4'),'video offset');
  Check(TryParsePresentationTag('[abrir arquivo=assets/som.wav|inicio=00:00:01]',T) and (T.StartMS=1000),'audio offset');
  Check(not TryParsePresentationTag('[abrir arquivo=assets/a.png|inicio=00:00:01]',T),'image offset rejected');
  Check(not TryParsePresentationTag('[abrir arquivo=assets/a.mp4|inicio=00:00:01|inicio=00:00:02]',T),'duplicate offset');
  Check(not TryParsePresentationTag('[abrir arquivo=assets/a.wav|inicio=00:00:99]',T),'seconds limit');
  Check(TryParsePresentationTag('[avatar=engenheiro]',T) and (T.Action=paSelectAvatar),'avatar tag');
  Check(TryParsePresentationTag('[voz=Microsoft Maria Desktop]',T) and (T.Action=paSelectVoice),'voice spaces');
  Check(not TryParsePresentationTag('[voz=]',T),'empty voice');
  Check(not TryParsePresentationTag('[avatar=]',T),'empty avatar');
  Check(TryParsePresentationTag('[fechar som]',T) and (T.Action=paCloseSound),'close sound');
  S:=ParseAvatarScript('[avatar=professor][voz=nova]Ola[abrir arquivo=assets/som.mp3|inicio=00:00:01]');
  Check((S.PlainText='Ola') and (S.PresentationCount=3),'new tags not spoken');
  Check(TryParseJointTag('[articulacao=head,y,20,1000,suave]',J),'joint');
  Check(not TryParseJointTag('[articulacao=jaw,y,20,1000,suave]',J),'mouth forbidden');
  Check(not TryParseJointTag('[articulacao=head,y,90,1000,suave]',J),'joint limit');
  S:=ParseAvatarScript('[sorriso]Oi[abrir arquivo=assets/a.png] A[proximo slide] B[fechar arquivo]');
  Check((S.CommandCount=1) and (S.PresentationCount=3) and (S.PlainText='Oi A B'),'mixed parser');
  S:=ParseAvatarScript('`[abrir arquivo=assets/a.png]` [sorriso](x) \[fechar arquivo]');
  Check((S.CommandCount=0) and (S.PresentationCount=0),'literal code/link/escape');
  X:='Olá [abrir arquivo=assets/a.png]mundo.';
  Check(AcceptGeneratedMovements(X,'[aceno]'+X)= '[aceno]'+X,'AI accepted');
  try AcceptGeneratedMovements(X,'Olá mundo.[abrir arquivo=assets/a.png]');raise Exception.Create('accepted changed media');
  except on E: Exception do Check(Pos('IA alterou',E.Message)=1,'AI must reject');end;
  M:=TMemoryStream.Create;
  try
    X:='abc';M.WriteBuffer(X[1],3);
    Check(PresentationSHA256(M)='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad','SHA256 vector');
  finally M.Free;end;
  WriteLn('PASS: mixed parser, traversal, joints, AI preservation, SHA256');
end;
begin
  try
    if PresentationParam(1)='selftest' then begin SelfTest;Halt(0);end;
    P:=TPVAPackage.Create;
    try
      if (PresentationParam(1)='pack') and (ParamCount=4) then begin
        ValidatePresentationScript(ReadUTF8(PresentationParam(2)));
        P.ExportFile(PresentationParam(4),ReadUTF8(PresentationParam(2)),PresentationParam(3));WriteLn('PASS: exported');
      end else if (PresentationParam(1)='verify') and (ParamCount in [2,3]) then begin
        P.Load(PresentationParam(2));ValidatePresentationScript(P.Script);
        if ParamCount=3 then P.ExtractTo(PresentationParam(3));
        WriteLn('PASS: valid PVA, ',P.Count,' files');
      end else raise Exception.Create('Uso: pva_tool selftest | pack roteiro.txt pasta arquivo.pva | verify arquivo.pva [pasta-nova]');
    finally P.Free;end;
  except on E: Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
