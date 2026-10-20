unit professor_preview;
{$mode objfpc}{$H+}
interface
procedure ShowProfessorPreview(const AModel: string; AAutoIdle: Boolean);
implementation
uses Classes, SysUtils, Forms, ExtCtrls, Controls, StdCtrls,
  professor_view, professor_state;
type
  TPreviewForm = class(TForm)
  private
    FView: TProfessorView;
    FTimer: TTimer;
    FLabel: TLabel;
    FStep: Integer;
    procedure NextState(Sender: TObject);
  end;
procedure TPreviewForm.NextState(Sender: TObject);
var S: TProfessorState;
begin
  S := TProfessorState(FStep mod 6);
  if S in [psWave, psWalk] then
  begin FView.SetActivity(psIdle); FView.Gesture(S); end
  else FView.SetActivity(S);
  FLabel.Caption := 'Prévia visual: ' + AnimationName(S) + ' (sem áudio)';
  Inc(FStep);
end;
procedure ShowProfessorPreview(const AModel: string; AAutoIdle: Boolean);
var F: TPreviewForm;
begin
  F := TPreviewForm.CreateNew(nil);
  try
    F.Caption := 'Professor 3D — prévia das animações';
    F.SetBounds(0, 0, 460, 640);
    F.Position := poScreenCenter;
    F.FLabel := TLabel.Create(F);
    F.FLabel.Parent := F;
    F.FLabel.Align := alTop;
    F.FView := TProfessorView.Create(F, F);
    F.FView.LoadModel(AModel, AAutoIdle);
    F.FTimer := TTimer.Create(F);
    F.FTimer.Interval := 2800;
    F.FTimer.OnTimer := @F.NextState;
    F.NextState(nil);
    F.ShowModal;
    F.FTimer.Enabled := False;
    F.FView.Free;
  finally F.Free; end;
end;
end.
