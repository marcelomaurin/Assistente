program modern_ui_tests;
{$mode objfpc}{$H+}{$codepage utf8}
uses Interfaces, Forms, FileUtil, Classes, SysUtils, Windows, ExtCtrls, Graphics, Controls, StdCtrls,
  Buttons, SynEdit, Types, fpjson, jsonparser, presentation_editor_ui, professor_view,
  professor_state, professor_commands, movement_catalog, reception_core, X3DNodes, presentation_joints;
type TRunner=class(TComponent)
public
  Editor:TPresentationEditor;View:TProfessorView;Host:TForm;Timer:TTimer;
  Started:QWord;OutDir,Original:string;Job:TReceptionJob;Delivered:Boolean;
  constructor Create(AOwner:TComponent);override;
  destructor Destroy;override;
  procedure Tick(Sender:TObject);
end;
var Runner:TRunner;Config:TReceptionConfig;
procedure Check(Value:Boolean;const Message:string);
begin if not Value then raise Exception.Create(Message);end;
procedure Snapshot(Form:TForm;const FileName:string);
var B:TBitmap;
begin B:=TBitmap.Create;try B.SetSize(Form.ClientWidth,Form.ClientHeight);Form.PaintTo(B.Canvas,0,0);B.SaveToFile(FileName);finally B.Free;end;end;
constructor TRunner.Create(AOwner:TComponent);
var I,FlowButtons:Integer;Edit:TSynEdit;Initial:string;Step:TAvatarScriptStep;
begin
  inherited;OutDir:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));ForceDirectories(OutDir);
  Original:=MovementCatalogFile;Check(FileUtil.CopyFile(ExtractFilePath(Original)+'colisoes.json',OutDir+'colisoes.json'),'Cannot copy isolated collision profile');ReloadMovementCatalog(OutDir+'movement-custom.json');
  Editor:=TPresentationEditor.Create(nil);Editor.Show;Edit:=nil;FlowButtons:=0;
  for I:=0 to Editor.ComponentCount-1 do begin
    if Editor.Components[I] is TSynEdit then Edit:=TSynEdit(Editor.Components[I]);
    if (Editor.Components[I] is TBitBtn) and (TBitBtn(Editor.Components[I]).Tag in [20..25]) then Inc(FlowButtons);
  end;
  Check((Edit<>nil) and (FlowButtons=6),'Flow actions disappeared in new layout');
  Check(Editor.MovementList.Count=MovementCount,'Editor library differs from shared JSON');
  Editor.MovementSearch.Text:='Saudação do JSON';
  Check(Editor.MovementList.Count=1,'Library search failed');
  Edit.Text:='Olá';Edit.CaretXY:=Point(1,1);Initial:=Edit.Text;Editor.InsertMovement('saudacao_nova');
  Check(Pos('[saudação especial]',Edit.Text)=1,'New JSON movement not inserted');
  Edit.Undo;Check(Edit.Text=Initial,'Movement insertion cannot be undone');Edit.Redo;
  Editor.CompiledScript;
  Editor.MovementSearch.Text:='mão';Editor.Width:=1024;Editor.Height:=720;Application.ProcessMessages;
  Check(TControl(Editor.FindComponent('PreviewButton')).Left+TControl(Editor.FindComponent('PreviewButton')).Width<=TControl(Editor.FindComponent('PreviewButton')).Parent.ClientWidth,'Editor preview button clipped');
  Check(TControl(Editor.FindComponent('BrowseAssistant')).Left+TControl(Editor.FindComponent('BrowseAssistant')).Width<=TControl(Editor.FindComponent('BrowseAssistant')).Parent.ClientWidth,'Assistant picker clipped');
  Snapshot(Editor,OutDir+'editor-1024.bmp');
  Editor.Width:=1240;Editor.Height:=820;Editor.MovementSearch.Text:='';Application.ProcessMessages;
  Snapshot(Editor,OutDir+'editor-1240.bmp');
  Host:=TForm.CreateNew(nil);Host.SetBounds(30,30,520,700);Host.Caption:='Validação de movimentos compartilhados';Host.Show;
  View:=TProfessorView.Create(Self,Host);Check(View.LoadModel(ExpandFileName(ParamStr(2)),False),View.Diagnostic);
  Check(View.ExecuteMovement('saudacao_nova'),'Renderer rejected a new JSON clip');
  Check(View.CurrentAnimation='idle','JSON clip selected incorrectly');
  View.SetActivity(psSpeaking);Check(View.CurrentAnimation='idle','Speaking replaced JSON pose');
  View.ResetCommands;Check(View.ExecuteMovement('pulso_json'),'Renderer rejected JSON joints');
  Config:=Default(TReceptionConfig);Config.EnableAvatarCommands:=True;Config.SilentPresentation:=True;
  Job:=TReceptionJob.Create(rjSpeak,Config,'[novo gesto] Olá','','json-regression');
  Started:=GetTickCount64;Timer:=TTimer.Create(Self);Timer.Interval:=50;Timer.OnTimer:=@Tick;
end;
destructor TRunner.Destroy;
begin Job.Free;Editor.Free;Host.Free;inherited;end;
procedure TRunner.Tick(Sender:TObject);
var Step:TAvatarScriptStep;Node:TTransformNode;
begin
  try
    if Job.TakeScriptCommand(Step) then begin
      Check((Step.Command=acCustom) and (Step.MovementID='saudacao_nova'),'Worker lost dynamic JSON movement');
      Delivered:=True;Job.ConfirmAvatarCommand;
    end;
    if GetTickCount64-Started>1500 then begin
      Node:=TTransformNode(View.Scene.RootNode.FindNodeByName(TTransformNode,'wrist.R',False));
      Check(Abs(Node.Rotation.W)>0.3,'JSON joint did not affect rendered wrist');
      Check(Delivered and Job.Done and Job.Success,'Dynamic script delivery failed');
      View.ResetCommands;ReloadMovementCatalog(Original);Timer.Enabled:=False;
      WriteLn('PASS: modern editor at 1024/1240, library search, JSON insertion/undo, flow controls, dynamic clip, rendered joints and speech mailbox');
      Application.Terminate;
    end;
  except on E:Exception do begin WriteLn('FAIL: '+E.Message);ExitCode:=1;Timer.Enabled:=False;Application.Terminate;end;end;
end;
begin
  try Application.Initialize;Runner:=TRunner.Create(nil);Application.Run;Runner.Free;
  except on E:Exception do begin WriteLn(StdErr,'FAIL: '+E.Message);Halt(1);end;end;
end.
