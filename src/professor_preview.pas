unit professor_preview;
{$mode objfpc}{$H+}
interface
procedure ShowProfessorPreview(const AModel: string; AAutoIdle: Boolean);
implementation
uses Classes, SysUtils, Forms, ExtCtrls, Controls, StdCtrls,
  professor_view, professor_state, professor_commands;
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
begin
  if (FStep mod 10)<=5 then FView.ResetCommands;
  case FStep mod 10 of
    0: FView.SetActivity(psIdle);
    1: FView.SetActivity(psListening);
    2: FView.SetActivity(psThinking);
    3: FView.SetActivity(psSpeaking);
    4: begin FView.SetActivity(psIdle);FView.Gesture(psWave);end;
    5: begin FView.SetActivity(psIdle);FView.Gesture(psWalk);end;
    6: begin FView.SetActivity(psIdle);FView.ExecuteCommand(acSmile);end;
    7: FView.ExecuteCommand(acApplause);
    8: FView.ExecuteCommand(acRaiseRightHand);
    9: FView.ExecuteCommand(acLowerRightHand);
  end;
  FLabel.Caption := FView.ActivityLabel+' — reprodução contínua, sem áudio';
  Inc(FStep);
end;
procedure ShowProfessorPreview(const AModel: string; AAutoIdle: Boolean);
var F: TPreviewForm;
begin
  F := TPreviewForm.CreateNew(nil);
  try
    F.Caption := 'Professor 3D — movimentos contínuos';
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
