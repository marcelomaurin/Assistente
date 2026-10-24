program presentation_rag_tests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, Windows, presentation_rag, presentation_package;
var Root,Published,Response,Path,Digest,Prompt,Old: string;
  Index: TPresentationRAG; Monitor: TPresentationRAGMonitor; P: TPVAPackage;
  Stream,OriginalBytes:TMemoryStream; Started: QWord;Stamp:TFileTime;Handle:THandle;
procedure Check(B: Boolean; const E: string);
begin if not B then raise Exception.Create(E);end;
procedure Rejected(const Value: string);
begin
  try Index.Resolve(Value,Path,Digest);raise Exception.Create('invalid selection accepted');
  except on E: Exception do Check(E.Message<>'invalid selection accepted',E.Message);end;
end;
begin
  try
    Root:=ExpandFileName(ParamStr(1));
    SetEnvironmentVariableW('ASSISTENTE_CONFIG_DIR',PWideChar(UTF8Decode(Root+PathDelim+'config')));
    Published:=PublishPresentation(Root+PathDelim+'energia solar.pva');
    Check(FileExists(Published),'publish missing');
    Check(ReadUTF8(ChangeFileExt(Published,'.res'))='Energia solar: geração elétrica limpa.'+LineEnding,'res contains tags or altered UTF8');
    Index:=TPresentationRAG.Create(PresentationRAGDirectory);
    try
      Index.Refresh;Check(Index.Count=1,'catalog count');
      Prompt:=Index.SelectionPrompt('Mostre energia solar','Conversa anterior');
      Check((Pos('geração',Prompt)>0) and (Pos('[avatar=',Prompt)=0),'selection content');
      Check(Index.Resolve('{"presentation":"1"}',Path,Digest) and (Path=Published),'selected package mapping');
      Check(not Index.Resolve('{"presentation":null}',Path,Digest),'null selected a package');
      Check(not Index.Resolve(#10+'```json'+#10+'{"presentation":null}'+#10+'```'+#10,Path,Digest),'fenced null selected package');
      Check(Index.Resolve('```'+#13#10+'{"presentation":"1"}'+#13#10+'```',Path,Digest) and (Path=Published),'fenced selection failed');
      Rejected('```json'+#10+'{"presentation":null}');
      Rejected('```json'+#10+'{"presentation":null}'+#10+'``` extra');
      Rejected('```python'+#10+'{"presentation":null}'+#10+'```');
      Rejected('Texto antes '+#10+'```json'+#10+'{"presentation":null}'+#10+'```');
      Rejected('```json'+#10+'{"presentation":"../../outside.pva"}'+#10+'```');
      Rejected('{"presentation":"../../outside.pva"}');Rejected('{"presentation":2}');
      Rejected('{"presentation":"99"}');Rejected('{"presentation":"01"}');Rejected('{"other":"1"}');
      WriteUTF8(ChangeFileExt(Published,'.res'),'texto manual incorreto');Index.Refresh;
      Check(Pos('Energia solar',ReadUTF8(ChangeFileExt(Published,'.res')))=1,'res was not regenerated');
      Monitor:=TPresentationRAGMonitor.Create(PresentationRAGDirectory);
      try
        Stream:=TMemoryStream.Create;
        try Stream.LoadFromFile(Root+PathDelim+'oceano.pva');Stream.SaveToFile(PresentationRAGDirectory+PathDelim+'oceano.pva');
        finally Stream.Free;end;
        Started:=GetTickCount64;
        while not FileExists(PresentationRAGDirectory+PathDelim+'oceano.res') do begin
          Check(GetTickCount64-Started<6000,'external copy monitor timeout');Sleep(50);
        end;
      finally Monitor.Free;end;
      WriteUTF8(PresentationRAGDirectory+PathDelim+'invalido.pva','not zip');
      WriteUTF8(PresentationRAGDirectory+PathDelim+'orfao.res','sem pacote');
      Index.Refresh;Check((Index.Count=2) and (Index.Errors.Count=1),'bad/orphan document entered catalog');
      Check(not FileExists(PresentationRAGDirectory+PathDelim+'invalido.res'),'bad package indexed');
      Prompt:=Index.SelectionPrompt('energia solar','');
      Check(Index.Resolve('{"presentation":"1"}',Path,Digest),'resolve original');Old:=Digest;
      P:=TPVAPackage.Create;
      try P.ExportFile(Published,'Conteudo atualizado',Root);finally P.Free;end;
      try ValidateRAGPlayback(Published,Old);raise Exception.Create('stale content accepted');
      except on E: Exception do Check(Pos('mudou',E.Message)>0,'stale package guard');end;
      Index.Refresh;Check(ReadUTF8(ChangeFileExt(Published,'.res'))='Conteudo atualizado','replacement not reindexed');
      Check(PublishPresentation(Published)=Published,'publish in place');
      // Same-size corruption with the exact timestamp must invalidate the cached entry.
      Handle:=CreateFileW(PWideChar(UTF8Decode(Published)),FILE_READ_ATTRIBUTES,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
      Check(Handle<>INVALID_HANDLE_VALUE,'Cannot read timestamp');
      try Check(GetFileTime(Handle,nil,nil,@Stamp),'Cannot get timestamp');finally CloseHandle(Handle);end;
      OriginalBytes:=TMemoryStream.Create;Stream:=TMemoryStream.Create;
      try
        OriginalBytes.LoadFromFile(Published);Stream.Size:=OriginalBytes.Size;FillChar(Stream.Memory^,Stream.Size,0);Stream.SaveToFile(Published);
        Handle:=CreateFileW(PWideChar(UTF8Decode(Published)),FILE_WRITE_ATTRIBUTES,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
        Check(Handle<>INVALID_HANDLE_VALUE,'Cannot restore timestamp');
        try Check(SetFileTime(Handle,nil,nil,@Stamp),'Cannot set timestamp');finally CloseHandle(Handle);end;
        Index.Refresh;Check(Index.Count=1,'Same-size same-timestamp corrupt package stayed eligible');
        OriginalBytes.SaveToFile(Published);Index.Refresh;Check(Index.Count=2,'Repaired package was not recovered');
      finally Stream.Free;OriginalBytes.Free;end;
      // Changing only media preserves the script but must invalidate the selection digest.
      ForceDirectories(Root+PathDelim+'assets');WriteUTF8(Root+PathDelim+'assets/check.png','IMAGE-A');
      P:=TPVAPackage.Create;
      try P.ExportFile(Published,'[abrir arquivo=assets/check.png]Conteudo atualizado',Root);finally P.Free;end;
      Index.Refresh;Prompt:=Index.SelectionPrompt('energia solar','');Check(Index.Resolve('{"presentation":"1"}',Path,Digest),'Cannot resolve media fixture');Old:=Digest;
      WriteUTF8(Root+PathDelim+'assets/check.png','IMAGE-B');P:=TPVAPackage.Create;
      try P.ExportFile(Published,'[abrir arquivo=assets/check.png]Conteudo atualizado',Root);finally P.Free;end;
      try ValidateRAGPlayback(Published,Old);raise Exception.Create('media-only replacement accepted');
      except on E:Exception do Check(Pos('mudou',E.Message)>0,'Media change bypassed package integrity');end;
      Index.Refresh;Check(ReadUTF8(ChangeFileExt(Published,'.res'))='Conteudo atualizado','Media-only replacement changed RES text');
      SysUtils.DeleteFile(Published);Index.Refresh;Check(Index.Count=1,'removed package still eligible');
      Check(FileExists(ChangeFileExt(Published,'.res')),'unpaired res unexpectedly deleted');
    finally Index.Free;end;
    WriteLn('PASS: RAG publish/plain UTF8 res, external copy monitor, invalid/orphan packages, strict selection, replacement/removal, same-size timestamp corruption and full-package media integrity');
  except on E: Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
