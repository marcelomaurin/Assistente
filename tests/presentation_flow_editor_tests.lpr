program presentation_flow_editor_tests;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Types,Classes,SysUtils,Windows,StdCtrls,Buttons,SynEdit,presentation_editor_ui,presentation_flow,presentation_rag,presentation_package;
var Editor: TPresentationEditor; Edit: TSynEdit; I,FlowButtons: Integer; Before,After: string;
procedure Check(B: Boolean; const E: string);
begin if not B then raise Exception.Create(E);end;
begin
  try
    SetEnvironmentVariableW('ASSISTENTE_CONFIG_DIR',PWideChar(UTF8Decode(ExpandFileName(ParamStr(1))+PathDelim+'flow-editor-config')));
    RequireDerivedFormResource:=True;Application.Initialize;Editor:=TPresentationEditor.Create(nil);
    try
      Editor.Show;Application.ProcessMessages;Edit:=nil;FlowButtons:=0;
      for I:=0 to Editor.ComponentCount-1 do begin
        if Editor.Components[I] is TSynEdit then Edit:=TSynEdit(Editor.Components[I]);
        if (Editor.Components[I] is TBitBtn) and (TBitBtn(Editor.Components[I]).Tag in [20..25]) then Inc(FlowButtons);
      end;
      Check((Edit<>nil) and (FlowButtons=6),'editor flow controls missing');
      for I:=0 to Editor.ComponentCount-1 do
        if (Editor.Components[I] is TBitBtn) and (TBitBtn(Editor.Components[I]).Tag in [27,28,29]) then begin
          Edit.Clear;TBitBtn(Editor.Components[I]).Click;
          case TBitBtn(Editor.Components[I]).Tag of
            27:Check(Pos('[PERGUNTAR]',Edit.Text)>0,'PERGUNTAR control');
            28:Check(Pos('[CONTINUAR]',Edit.Text)>0,'CONTINUAR control');
            29:Check(Pos('[MENU]',Edit.Text)>0,'MENU control');
          end;
        end;
      Edit.Text:='Inicio ';Edit.CaretXY:=Types.Point(8,1);Before:=Edit.Text;
      Editor.InsertFlowDirective(faCall,'A');After:=Edit.Text;
      Check(Pos('[{A}]',After)>0,'call insertion');Edit.Undo;Check(Edit.Text=Before,'flow undo');Edit.Redo;Check(Edit.Text=After,'flow redo');
      Edit.Text:='Inicio [{A}] fim[FIM][BLOCO:{A}]Texto [sorriso]';
      Check(StringReplace(Editor.CompiledScript,LineEnding,'',[rfReplaceAll])='Inicio Texto [sorriso] fim[FIM]','editor compiled call does not return');
      Check(StringReplace(Editor.CompiledScript('A'),LineEnding,'',[rfReplaceAll])='Texto [sorriso][FIM]','editor block preview');
      Editor.SavePackage(ExpandFileName(ParamStr(1))+PathDelim+'flow-editor.pva');
      Check(Pos('BLOCO',ReadUTF8(PresentationRAGDirectory+PathDelim+'flow-editor.res'))=0,'flow marker indexed');
      Edit.Modified:=False;
      WriteLn('PASS: editor first; six flow controls, insert/undo/redo, compile main/block, save and flow-free res');
    finally Editor.Free;end;
  except on E: Exception do begin WriteLn(StdErr,E.Message);Halt(1);end;end;
end.
