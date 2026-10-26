program avatar_import_preview;
{$mode objfpc}{$H+}
uses Interfaces,Forms,Classes,SysUtils,ExtCtrls,CastleImages,CastleURIUtils,
  professor_view,professor_state;
type
  TPreview=class(TComponent)
  public
    Window:TForm;View:TProfessorView;Timer:TTimer;Step:Integer;OutDir:string;
    procedure Tick(Sender:TObject);
    procedure Capture(const FileStem:string);
  end;
procedure TPreview.Capture(const FileStem:string);
var Shot:TRGBImage;
begin
  Shot:=View.Control.Container.SaveScreen;
  try SaveImage(Shot,FilenameToURISafe(OutDir+FileStem+'.png'));finally Shot.Free;end;
end;
procedure TPreview.Tick(Sender:TObject);
begin
  try
    case Step of
      0:begin Capture('front-rest');View.SetCameraView(acRight);View.FitCamera;end;
      1:begin Capture('side-rest');View.SetCameraView(acFront);View.FitCamera;
        if not View.Scene.ForceAnimationPose('wave',0.6,True) then raise Exception.Create('Wave pose unavailable');end;
      2:begin Capture('front-wave');Timer.Enabled:=False;
        WriteLn('PASS: imported avatar rendered in front/side views and evaluated wave pose');Application.Terminate;end;
    end;
    Inc(Step);
  except on E:Exception do begin WriteLn('FAIL: '+E.Message);ExitCode:=1;Timer.Enabled:=False;Application.Terminate;end;end;
end;
var Preview:TPreview;
begin
  Application.Initialize;Application.ShowMainForm:=False;
  Preview:=TPreview.Create(nil);
  try
    Preview.OutDir:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(2)));ForceDirectories(Preview.OutDir);
    Preview.Window:=TForm.CreateNew(nil);Preview.Window.Caption:='Validacao de avatar importado';Preview.Window.SetBounds(20,20,680,820);
    try
      Preview.View:=TProfessorView.Create(Preview.Window,Preview.Window);
      if not Preview.View.LoadModel(ExpandFileName(ParamStr(1)),False) then raise Exception.Create(Preview.View.Diagnostic);
      Preview.View.SetCameraView(acFront);Preview.View.FitCamera;
      Preview.Timer:=TTimer.Create(Preview.Window);Preview.Timer.Interval:=1500;Preview.Timer.OnTimer:=@Preview.Tick;
      Preview.Window.Show;Application.Run;
    finally Preview.Window.Free;end;
  finally Preview.Free;end;
end.
