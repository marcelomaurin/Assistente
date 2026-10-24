program motion_editor;
{$mode objfpc}{$H+}
uses Interfaces, Forms, SysUtils, Classes, Controls, StdCtrls, ExtCtrls, ComCtrls,
  Dialogs, Spin, FileUtil, fpjson, movement_animation, presentation_joint_tags, professor_view;
type
  TEditorForm = class(TForm)
  private
    View: TProfessorView;
    BoneBox, AxisBox: TComboBox;
    AngleEdit, TimeEdit, DurationEdit: TSpinEdit;
    NameEdit: TEdit;
    Timeline: TTrackBar;
    Status: TLabel;
    Motion: TMotionAnimation;
    Path: string;
    procedure OpenClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure AddKeyClick(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    procedure TimeChanged(Sender: TObject);
    procedure BoneChanged(Sender: TObject);
    procedure SetStatus(const S: string);
    function TrackIndex(const Bone: string): Integer;
  public
    constructor Create(AOwner: TComponent); override;
  end;
constructor TEditorForm.Create(AOwner: TComponent);
var LeftPanel,RightPanel,BottomPanel,Host: TPanel; B: TButton; I: Integer;
const Bones: array[0..25] of string = ('head','neck01','neck02','neck03','spine01','spine02','spine03','spine04','spine05',
'upperarm01.L','upperarm01.R','lowerarm01.L','lowerarm01.R','wrist.L','wrist.R','clavicle.L','clavicle.R',
'shoulder01.L','shoulder01.R','upperleg01.L','upperleg01.R','lowerleg01.L','lowerleg01.R','foot.L','foot.R','finger2-1.R');
  procedure LabelAt(const Text: string; ParentControl: TWinControl);
  var L: TLabel;
  begin L:=TLabel.Create(Self);L.Parent:=ParentControl;L.Align:=alTop;L.Caption:=Text;L.Height:=22;end;
  function ButtonAt(const Text: string; ParentControl: TWinControl; Handler: TNotifyEvent): TButton;
  begin Result:=TButton.Create(Self);Result.Parent:=ParentControl;Result.Align:=alTop;Result.Caption:=Text;Result.Height:=32;Result.OnClick:=Handler;end;
begin
  inherited Create(AOwner);
  Caption:='Assistente - Editor de Movimentos (protótipo)';
  Width:=1220;Height:=740;Position:=poScreenCenter;
  LeftPanel:=TPanel.Create(Self);LeftPanel.Parent:=Self;LeftPanel.Align:=alLeft;LeftPanel.Width:=250;
  RightPanel:=TPanel.Create(Self);RightPanel.Parent:=Self;RightPanel.Align:=alRight;RightPanel.Width:=260;
  BottomPanel:=TPanel.Create(Self);BottomPanel.Parent:=Self;BottomPanel.Align:=alBottom;BottomPanel.Height:=110;
  Host:=TPanel.Create(Self);Host.Parent:=Self;Host.Align:=alClient;
  LabelAt('Nome do movimento',LeftPanel);
  NameEdit:=TEdit.Create(Self);NameEdit.Parent:=LeftPanel;NameEdit.Align:=alTop;NameEdit.Text:='novo_movimento';
  ButtonAt('Abrir JSON',LeftPanel,@OpenClick);
  ButtonAt('Salvar JSON',LeftPanel,@SaveClick);
  LabelAt('Articulação',RightPanel);
  BoneBox:=TComboBox.Create(Self);BoneBox.Parent:=RightPanel;BoneBox.Align:=alTop;BoneBox.Style:=csDropDownList;
  for I:=Low(Bones) to High(Bones) do BoneBox.Items.Add(Bones[I]);
  BoneBox.ItemIndex:=9;BoneBox.OnChange:=@BoneChanged;
  LabelAt('Eixo',RightPanel);
  AxisBox:=TComboBox.Create(Self);AxisBox.Parent:=RightPanel;AxisBox.Align:=alTop;AxisBox.Style:=csDropDownList;
  AxisBox.Items.Add('x');AxisBox.Items.Add('y');AxisBox.Items.Add('z');AxisBox.ItemIndex:=2;
  LabelAt('Ângulo (graus)',RightPanel);
  AngleEdit:=TSpinEdit.Create(Self);AngleEdit.Parent:=RightPanel;AngleEdit.Align:=alTop;
  AngleEdit.MinValue:=-90;AngleEdit.MaxValue:=90;
  LabelAt('Tempo do quadro (ms)',RightPanel);
  TimeEdit:=TSpinEdit.Create(Self);TimeEdit.Parent:=RightPanel;TimeEdit.Align:=alTop;TimeEdit.MinValue:=0;TimeEdit.MaxValue:=60000;
  ButtonAt('Gravar quadro-chave',RightPanel,@AddKeyClick);
  ButtonAt('Prévia no avatar',RightPanel,@PreviewClick);
  LabelAt('Duração total (ms)',BottomPanel);
  DurationEdit:=TSpinEdit.Create(Self);DurationEdit.Parent:=BottomPanel;DurationEdit.Align:=alLeft;DurationEdit.Width:=100;
  DurationEdit.MinValue:=50;DurationEdit.MaxValue:=60000;DurationEdit.Value:=2400;
  Timeline:=TTrackBar.Create(Self);Timeline.Parent:=BottomPanel;Timeline.Align:=alClient;Timeline.Min:=0;Timeline.Max:=2400;
  Timeline.OnChange:=@TimeChanged;
  Status:=TLabel.Create(Self);Status.Parent:=BottomPanel;Status.Align:=alBottom;Status.Height:=25;
  View:=TProfessorView.Create(Self,Host);
  View.LoadModel('',False);
  SetStatus('Abra um JSON ou grave dois quadros-chave para iniciar.');
end;
procedure TEditorForm.SetStatus(const S: string);
begin Status.Caption:=S;end;
function TEditorForm.TrackIndex(const Bone: string): Integer;
var I: Integer;
begin for I:=0 to High(Motion.Tracks) do if Motion.Tracks[I].Bone=Bone then Exit(I);Result:=-1;end;
procedure TEditorForm.BoneChanged(Sender: TObject);
var L: Integer;
begin L:=Round(JointAngleLimit(BoneBox.Text));AngleEdit.MinValue:=-L;AngleEdit.MaxValue:=L;end;
procedure TEditorForm.TimeChanged(Sender: TObject);
var I: Integer;
begin TimeEdit.Value:=Timeline.Position;
  for I:=0 to High(Motion.Tracks) do
    if Motion.Tracks[I].Bone=BoneBox.Text then begin
      AngleEdit.Value:=Round(MotionAngleAt(Motion.Tracks[I],TimeEdit.Value,Motion.Smooth));Break;
    end;
end;
procedure TEditorForm.AddKeyClick(Sender: TObject);
var I,J,K: Integer; Bone: string; Key: TMotionKeyframe;
begin
  Bone:=BoneBox.Text;
  if Bone='' then Exit;
  I:=TrackIndex(Bone);
  if I<0 then begin I:=Length(Motion.Tracks);SetLength(Motion.Tracks,I+1);Motion.Tracks[I].Bone:=Bone;Motion.Tracks[I].Axis:=AxisBox.Text[1];end;
  if Motion.Tracks[I].Axis<>AxisBox.Text[1] then begin ShowMessage('Um osso não pode ter dois eixos no formato atual.');Exit;end;
  Key.TimeMS:=TimeEdit.Value;Key.Angle:=AngleEdit.Value;
  for J:=0 to High(Motion.Tracks[I].Keys) do
    if Motion.Tracks[I].Keys[J].TimeMS=Key.TimeMS then begin Motion.Tracks[I].Keys[J]:=Key;SetStatus('Quadro atualizado.');Exit;end;
  J:=Length(Motion.Tracks[I].Keys);SetLength(Motion.Tracks[I].Keys,J+1);
  while (J>0) and (Motion.Tracks[I].Keys[J-1].TimeMS>Key.TimeMS) do begin
    Motion.Tracks[I].Keys[J]:=Motion.Tracks[I].Keys[J-1];Dec(J);
  end;
  Motion.Tracks[I].Keys[J]:=Key;SetStatus('Quadro gravado.');
end;
procedure TEditorForm.OpenClick(Sender: TObject);
var D: TOpenDialog; I: Integer;
begin
  D:=TOpenDialog.Create(Self);
  try
    D.Filter:='Animações JSON|*.json';
    if not D.Execute then Exit;
    try
      Motion:=LoadMotionAnimation(D.FileName);Path:=D.FileName;
      NameEdit.Text:=Motion.Name;DurationEdit.Value:=Motion.DurationMS;
      Timeline.Max:=Motion.DurationMS;Timeline.Position:=0;
      SetStatus('Carregado: '+ExtractFileName(Path)+' ('+IntToStr(Length(Motion.Tracks))+' trilhas)');
    except on E: Exception do ShowMessage('Erro ao abrir: '+E.Message);end;
  finally D.Free;end;
end;
procedure TEditorForm.SaveClick(Sender: TObject);
var D: TSaveDialog; Root,Track,Key: TJSONObject; Tracks,Keys: TJSONArray;
  I,J: Integer; S: TStringList; FileName: string;
begin
  if Length(Motion.Tracks)=0 then begin ShowMessage('Adicione quadros-chave antes de salvar.');Exit;end;
  for I:=0 to High(Motion.Tracks) do
    if Length(Motion.Tracks[I].Keys)<2 then begin ShowMessage('Cada trilha exige pelo menos dois quadros-chave.');Exit;end;
  D:=TSaveDialog.Create(Self);Root:=TJSONObject.Create;S:=TStringList.Create;
  try
    D.Filter:='Animações JSON|*.json';D.DefaultExt:='json';D.FileName:=Path;
    if not D.Execute then Exit;
    FileName:=D.FileName;
    Root.Add('format','assistente-motion');Root.Add('version',1);Root.Add('name',NameEdit.Text);
    Root.Add('duration_ms',DurationEdit.Value);Root.Add('loop',False);
    Root.Add('return_to_base',True);Root.Add('interpolation','smoothstep');
    Tracks:=TJSONArray.Create;Root.Add('tracks',Tracks);
    for I:=0 to High(Motion.Tracks) do begin
      Track:=TJSONObject.Create;Tracks.Add(Track);
      Track.Add('bone',Motion.Tracks[I].Bone);Track.Add('axis',string(Motion.Tracks[I].Axis));
      Keys:=TJSONArray.Create;Track.Add('keyframes',Keys);
      for J:=0 to High(Motion.Tracks[I].Keys) do begin
        if Motion.Tracks[I].Keys[J].TimeMS>DurationEdit.Value then raise Exception.Create('Quadro fora da duração');
        Key:=TJSONObject.Create;Keys.Add(Key);
        Key.Add('time_ms',Motion.Tracks[I].Keys[J].TimeMS);Key.Add('angle',Motion.Tracks[I].Keys[J].Angle);
      end;
    end;
    S.Text:=Root.FormatJSON;
    S.SaveToFile(FileName+'.tmp');
    try
      Motion:=LoadMotionAnimation(FileName+'.tmp');
      if FileExists(FileName) then begin
        if MessageDlg('Substituir arquivo existente?',mtConfirmation,[mbYes,mbNo],0)<>mrYes then Exit;
        if not FileUtil.CopyFile(FileName,FileName+'.bak') then raise Exception.Create('Falha ao criar backup');
        DeleteFile(FileName);
      end;
      if not RenameFile(FileName+'.tmp',FileName) then raise Exception.Create('Falha ao finalizar gravação');
      Path:=FileName;SetStatus('Salvo: '+Path);
    finally if FileExists(FileName+'.tmp') then DeleteFile(FileName+'.tmp');end;
  except on E: Exception do ShowMessage('Erro ao salvar: '+E.Message);
  end;
  S.Free;Root.Free;D.Free;
end;
procedure TEditorForm.PreviewClick(Sender: TObject);
begin
  SetStatus('Prévia de quadros-chave ainda não conectada ao rig 3D. Use o Assistente para reproduzir o JSON salvo.');
end;
var F: TEditorForm;
begin
  Application.Initialize;
  Application.CreateForm(TEditorForm,F);
  Application.Run;
end.
