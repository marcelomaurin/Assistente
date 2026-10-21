program professor_catalog_tests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, professor_catalog;
var Root, Folder: string; C: TAvatarCatalog; S: TStringList; G: TGUID;
procedure Check(B: Boolean; const Msg: string);
begin if not B then raise Exception.Create(Msg); end;
procedure Put(const FileName, Value: string);
begin S.Text:=Value; S.SaveToFile(FileName); end;
begin
  if ParamCount<>1 then raise Exception.Create('Provide a scratch directory');
  CreateGUID(G);
  Root:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)))+GUIDToString(G);
  Folder:=IncludeTrailingPathDelimiter(Root)+'extra';
  ForceDirectories(Folder);
  S:=TStringList.Create;
  try
    Put(Folder+PathDelim+'modelo.gltf','{}');
    Put(Folder+PathDelim+'avatar.json','{"id":"extra","name":"Avatar extra","model":"modelo.gltf"}');
    Put(Root+PathDelim+'avulso.glb','fixture');
    C:=TAvatarCatalog.Create(Root);
    try
      Check(C.Count=2,'manifest model must not be counted twice');
      Check(C.IndexOfID('extra')>=0,'stable manifest ID');
      Check(C[C.IndexOfID('extra')].Name='Avatar extra','display name');
      Put(Root+PathDelim+'novo.gltf','{}');
      C.Refresh;
      Check(C.Count=3,'new model discovered on refresh');
      Put(Folder+PathDelim+'avatar.json','invalid json');
      C.Refresh;
      Check(C.Count=3,'bad manifest must not hide other models');
      Check(C.Diagnostic<>'','bad manifest diagnostic');
      WriteLn('PASS: dynamic catalog, manifest names, refresh, deduplication, malformed metadata');
    finally C.Free; end;
  finally S.Free; end;
end.
