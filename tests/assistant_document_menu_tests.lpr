program assistant_document_menu_tests;
{$mode objfpc}{$H+}{$codepage utf8}
uses Interfaces, Forms, Classes, SysUtils, Windows, main, setmain,
  assistant_menu, presentation_package;
var Directory, ConfigDirectory, Source, LoadedName: string; Config: TStringList;
  Menu: TAssistantMenu; P: TPVAPackage; Failed: Boolean; Started: QWord;
procedure Check(Value: Boolean; const Message: string);
begin if not Value then raise Exception.Create(Message);end;
procedure StopPresentation;
begin
  frmmain.CloseDocument;Started:=GetTickCount64;
  while frmmain.ApresentandoResposta and (GetTickCount64-Started<10000) do begin
    Application.ProcessMessages;Sleep(10);
  end;
  Check(not frmmain.ApresentandoResposta,'Cancelled speech did not finish');
end;
begin
  try
    if ParamCount<>1 then raise Exception.Create('Use assistant_document_menu_tests <fixture-directory>');
    Directory:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));ForceDirectories(Directory);
    ConfigDirectory:=Directory+'isolated-config';ForceDirectories(ConfigDirectory);
    SetEnvironmentVariable(PChar('ASSISTENTE_CONFIG_DIR'),PChar(ConfigDirectory));
    Config:=TStringList.Create;
    try
      Config.Add('CONTINUOUS_LISTENING:0');Config.Add('AUTOSPEAK:0');Config.Add('VISION_SOURCE:none');
      Config.Add('AVATAR3D_PROFILE:professor');Config.SaveToFile(ConfigDirectory+PathDelim+'Setmain.cfg');
    finally Config.Free;end;
    Application.Initialize;Application.ShowMainForm:=False;Application.CreateForm(Tfrmmain,frmmain);
    try
      Check(frmmain.Menu is TAssistantMenu,'Native main menu missing');Menu:=TAssistantMenu(frmmain.Menu);
      Check(Windows.IsMenu(Menu.Handle),'Main menu must expose a native Windows menu handle');
      Check(Assigned(Menu.OpenFile.OnClick) and Assigned(Menu.CloseFile.OnClick) and Assigned(Menu.PrintPDF.OnClick)
        and Assigned(Menu.FindText.OnClick) and Assigned(Menu.About.OnClick),'Unwired menu action');
      Check(frmmain.FindComponent('OpenFileButton')=nil,'Extra open button must not exist');
      Check(not Menu.CloseFile.Enabled and not Menu.PrintPDF.Enabled,'Initial document actions must be disabled');
      LoadedName:=Directory+'consulta.txt';WriteUTF8(LoadedName,'marcador-pesquisa-coração');
      frmmain.LoadDocument(LoadedName);Check(frmmain.LoadedDocument=LoadedName,'Open document');
      Check(Pos('marcador-pesquisa',frmmain.SearchableDocumentText)>0,'Search must include loaded document');
      Failed:=False;try frmmain.LoadDocument(Directory+'inexistente.txt');except on E:Exception do Failed:=True;end;
      Check(Failed and (frmmain.LoadedDocument=LoadedName),'Failed open must retain previous document');
      DeleteFile(LoadedName);Check(Pos('marcador-pesquisa',frmmain.SearchableDocumentText)>0,'Search must use loaded snapshot');
      frmmain.CloseDocument;
      Check((frmmain.LoadedDocument='') and (frmmain.LoadedFlow=nil),'Close must clear document and flow');
      Check(Pos('marcador-pesquisa',frmmain.SearchableDocumentText)=0,'Close must clear searchable document');
      Source:='[executar arquivo=assets/slide1.png]Texto principal. [{Detalhe}][FIM]'+
        '[BLOCO:{Detalhe}]Explicação com coração.[BLOCO:{Extra}]Resposta suplementar pesquisável.';
      LoadedName:=Directory+'menu-fixture.pva';P:=TPVAPackage.Create;
      try P.ExportFile(LoadedName,Source,Directory);finally P.Free;end;
      frmmain.StartPresentation(LoadedName);
      Check(frmmain.LoadedFlow<>nil,'Presentation flow missing');
      Check(Pos('Resposta suplementar',frmmain.SearchableDocumentText)>0,'Search must include unplayed blocks');
      DeleteFile(LoadedName);frmmain.SavePresentationPDF(Directory+'native-main.pdf');
      Check(FileExists(Directory+'native-main.pdf'),'PDF must export from loaded package after source is removed');
      StopPresentation;
      Check(frmmain.ActivePresentationMedia='','Close must remove presentation media');
      Check(not Menu.PrintPDF.Enabled,'Closed presentation must not remain printable');
      WriteLn('PASS: main menu wiring, open/close, failed-open preservation, searchable snapshot, all blocks, loaded-package PDF and presentation cancellation');
    finally frmmain.Free;end;
  except on E:Exception do begin WriteLn('FAIL: '+E.Message);Halt(1);end;end;
end.
