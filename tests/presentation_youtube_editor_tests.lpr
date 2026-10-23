program presentation_youtube_editor_tests;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Controls,Classes,SysUtils,SynEdit,Buttons,presentation_editor_ui,presentation_package;
var Editor:TPresentationEditor;Edit:TSynEdit;I:Integer;ButtonFound:Boolean;P:TPVAPackage;Root,Initial:string;
procedure Check(B:Boolean;const Message:string);
begin if not B then raise Exception.Create(Message);end;
begin
  try
    Application.Initialize;Root:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));ForceDirectories(Root);
    Editor:=TPresentationEditor.Create(nil);
    try
      Edit:=nil;ButtonFound:=False;
      for I:=0 to Editor.ComponentCount-1 do begin
        if Editor.Components[I] is TSynEdit then Edit:=TSynEdit(Editor.Components[I]);
        if Editor.Components[I] is TBitBtn then ButtonFound:=ButtonFound or (TBitBtn(Editor.Components[I]).Tag=26);
      end;
      Check((Edit<>nil) and ButtonFound,'YouTube media action missing');
      Edit.Text:='';Editor.InsertYouTube('https://youtu.be/M7lc1UVf-VE?t=30');
      Check(Pos('[youtube=https://www.youtube.com/watch?v=M7lc1UVf-VE&t=30]',Edit.Text)=1,'Wrong inserted tag');
      Initial:=Edit.Text;Edit.Undo;Check(Trim(Edit.Text)='','Insertion cannot be undone');Edit.Redo;
      Editor.SavePackage(Root+'editor-youtube.pva');Editor.LoadPackage(Root+'editor-youtube.pva');
      Check(Edit.Text=Initial,'YouTube tag lost while saving/reopening');
      P:=TPVAPackage.Create;try P.Load(Root+'editor-youtube.pva');Check(P.Script=Edit.Text,'Export mismatch');finally P.Free;end;
      WriteLn('PASS: YouTube toolbar action, standard tag insertion, undo/redo, save and reopen');
    finally Editor.Free;end;
  except on E:Exception do begin WriteLn(StdErr,'FAIL: '+E.Message);Halt(1);end;end;
end.
