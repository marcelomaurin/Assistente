program presentation_editor;
{$mode objfpc}{$H+}
uses Interfaces, Forms, presentation_editor_ui;
var Editor: TPresentationEditor;
begin
  RequireDerivedFormResource:=False;Application.Scaled:=True;Application.Initialize;
  Application.CreateForm(TPresentationEditor,Editor);Application.Run;
end.
