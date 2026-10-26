program settings_rag_preview;
{ Opens Configurações on the "Documentos (RAG)" tab with two documents and
  saves a screenshot. Usage: settings_rag_preview <work dir> <output.bmp> <documents...> }
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Windows, Graphics, ComCtrls, frmconfig;
var F: TfrmConfig; Files: TStringList; I: Integer; Shot: TBitmap;
begin
  SetEnvironmentVariableW('ASSISTENTE_CONFIG_DIR',PWideChar(UTF8Decode(ExpandFileName(ParamStr(1)))));
  Application.Initialize;
  F:=TfrmConfig.Create(nil);Files:=TStringList.Create;Shot:=TBitmap.Create;
  try
    for I:=3 to ParamCount do Files.Add(ParamStr(I));
    F.Show;F.RAGUI.RefreshList;
    if Files.Count>0 then
      if F.RAGUI.AddFiles(Files)<>Files.Count then raise Exception.Create('AddFiles: '+F.RAGUI.Status.Caption);
    F.pcConfig.ActivePage:=F.RAGUI.Page;
    if F.RAGUI.List.Items.Count>0 then F.RAGUI.List.Items[0].Selected:=True;
    for I:=1 to 30 do begin Application.ProcessMessages;Sleep(30);end;
    Shot.Assign(F.GetFormImage);Shot.SaveToFile(ParamStr(2));
    WriteLn('PASS: settings RAG tab with ',F.RAGUI.List.Items.Count,' documents; ',F.RAGUI.Status.Caption);
    Flush(Output);
    { Keep the window up for an external screen capture. }
    if SysUtils.GetEnvironmentVariable('PREVIEW_HOLD')<>'' then
      for I:=1 to 300 do begin Application.ProcessMessages;Sleep(30);end;
  finally Shot.Free;Files.Free;F.Free;end;
end.
