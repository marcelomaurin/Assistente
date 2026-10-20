unit professor_view;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Controls, ExtCtrls, StdCtrls, IniFiles,
  CastleControl, CastleViewport, CastleScene, CastleCameras, CastleVectors, CastleTransform,
  CastleURIUtils, LazFileUtils, professor_state, professor_catalog, Math;

type
  TProfessorZoomEvent = procedure(Steps: Single) of object;
  TProfessorControl = class(TCastleControl)
  public
    OnZoom: TProfessorZoomEvent;
    procedure CloseContext;
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  end;
  { Native LCL OpenGL surface. All methods are called on the LCL thread. }
  TProfessorView = class(TComponent)
  private
    FControl: TProfessorControl;
    FViewport: TCastleViewport;
    FScene: TCastleScene;
    FNotice: TLabel;
    FMachine: TProfessorStateMachine;
    FTimer: TTimer;
    FLastAnimation, FDiagnostic, FModelFile: string;
    FAnimations: array[TProfessorState] of string;
    FAutoIdle: Boolean;
    FZoom, FModelHeight: Single;
    procedure TimerTick(Sender: TObject);
    procedure ApplyAnimation;
    function DefaultModel: string;
    function GetState: TProfessorState;
    procedure ResetView(Sender: TObject);
    procedure FrameCamera;
  public
    constructor Create(AOwner: TComponent; AParent: TWinControl); reintroduce;
    destructor Destroy; override;
    function LoadModel(const AFileName: string; AAutoIdle: Boolean): Boolean;
    procedure SetActivity(AState: TProfessorState);
    procedure Gesture(AState: TProfessorState);
    procedure ZoomBy(Steps: Single);
    property Zoom: Single read FZoom;
    property Diagnostic: string read FDiagnostic;
    property Scene: TCastleScene read FScene;
    property ModelFile: string read FModelFile;
    property State: TProfessorState read GetState;
  end;

implementation

constructor TProfessorView.Create(AOwner: TComponent; AParent: TWinControl);
var KeyLight, FillLight: TCastleDirectionalLight;
begin
  inherited Create(AOwner);
  FMachine := TProfessorStateMachine.Create;
  FControl := TProfessorControl.Create(Self);
  FControl.MultiSampling := 4;
  FControl.Align := alClient;
  FControl.Parent := AParent;
  FControl.TabStop := False;
  FControl.AutoFocus := False;
  FControl.OnZoom := @ZoomBy;
  FControl.OnDblClick := @ResetView;
  FControl.Hint := 'Roda do mouse: aproximar/afastar. Duplo clique: enquadrar.';
  FControl.ShowHint := True;
  FViewport := TCastleViewport.Create(Self);
  FViewport.FullSize := True;
  KeyLight := TCastleDirectionalLight.Create(Self);
  KeyLight.Intensity := 2.8;
  FViewport.Camera.Add(KeyLight);
  FillLight := TCastleDirectionalLight.Create(Self);
  FillLight.Intensity := 1.4;
  FillLight.Rotation := Vector4(1, 0, 0, -0.65);
  FViewport.Camera.Add(FillLight);
  FViewport.Camera.Perspective.FieldOfViewAxis := faVertical;
  FViewport.Camera.Perspective.FieldOfView := 0.6283185;
  FViewport.AutoCamera := True;
  FViewport.BackgroundColor := Vector4(1, 1, 1, 1);
  FControl.Container.Controls.InsertFront(FViewport);
  FScene := TCastleScene.Create(Self);
  FViewport.Items.Add(FScene);
  FNotice := TLabel.Create(Self);
  FNotice.Parent := AParent;
  FNotice.Align := alBottom;
  FNotice.AutoSize := False;
  FNotice.Height := 42;
  FNotice.WordWrap := True;
  FNotice.Font.Color := $00404040;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 40;
  FTimer.OnTimer := @TimerTick;
end;

destructor TProfessorView.Destroy;
begin
  if Assigned(FTimer) then FTimer.Enabled := False;
  { Close the GL context while the viewport and its scenes still exist. }
  if Assigned(FControl) then FControl.CloseContext;
  FreeAndNil(FControl);
  FMachine.Free;
  inherited Destroy;
end;

function TProfessorView.DefaultModel: string;
begin
  Result := IncludeTrailingPathDelimiter(AvatarRoot) + 'professor' + PathDelim + 'modelo.gltf';
end;

function TProfessorView.LoadModel(const AFileName: string; AAutoIdle: Boolean): Boolean;
var S: TProfessorState; Ini: TIniFile; Missing, Requested: string;
begin
  Result := False;
  FDiagnostic := '';
  FAutoIdle := AAutoIdle;
  Requested := Trim(AFileName);
  if Requested = '' then Requested := DefaultModel
  else if not FilenameIsAbsolute(Requested) then
    Requested := ExpandFileName(ExtractFilePath(ParamStr(0)) + Requested);
  try
    if not FileExists(Requested) then
      raise Exception.Create('Modelo ausente: ' + Requested);
    FScene.Load(FilenameToURISafe(Requested));
    FModelFile := Requested;
    Result := True;
  except
    on E: Exception do
    begin
      FDiagnostic := E.Message;
      { A broken custom model never prevents chat or the bundled avatar. }
      try
        FModelFile := DefaultModel;
        FScene.Load(FilenameToURISafe(FModelFile));
        FDiagnostic := FDiagnostic + ' | Usando professor incluído.';
      except
        on E2: Exception do
        begin
          FModelFile := '';
          FDiagnostic := FDiagnostic + ' | ' + E2.Message;
        end;
      end;
    end;
  end;
  if FModelFile <> '' then
  begin
    Ini := TIniFile.Create(ChangeFileExt(FModelFile, '.ini'));
    try
      Missing := '';
      for S := Low(TProfessorState) to High(TProfessorState) do
      begin
        FAnimations[S] := Ini.ReadString('animations', AnimationName(S), AnimationName(S));
        if FScene.AnimationsList.IndexOf(FAnimations[S]) < 0 then
          Missing := Missing + ' ' + FAnimations[S];
      end;
      if Missing <> '' then FDiagnostic := FDiagnostic + ' | Clipes ausentes:' + Missing;
    finally Ini.Free; end;
    FViewport.AssignDefaultCamera;
    { glTF convention: Y up, character faces +Z. Frame using model bounds. }
    FModelHeight := Max(0.1, FScene.BoundingBox.Size.Y);
    FZoom := 1;
    FrameCamera;
  end;
  FNotice.Caption := FDiagnostic;
  FNotice.Visible := FDiagnostic <> '';
  FLastAnimation := '#reload';
  ApplyAnimation;
end;

procedure TProfessorView.ApplyAnimation;
var Clip: string;
begin
  if FModelFile = '' then Exit;
  Clip := FAnimations[FMachine.State];
  if (FMachine.State = psIdle) and not FAutoIdle then Clip := '';
  if (Clip <> '') and (FScene.AnimationsList.IndexOf(Clip) < 0) then
    Clip := FAnimations[psIdle];
  if Clip = FLastAnimation then Exit;
  FLastAnimation := Clip;
  if (Clip <> '') and (FScene.AnimationsList.IndexOf(Clip) >= 0) then
    FScene.PlayAnimation(Clip, True)
  else FScene.StopAnimation;
end;

procedure TProfessorView.SetActivity(AState: TProfessorState);
begin
  FMachine.SetActivity(AState);
  ApplyAnimation;
end;

procedure TProfessorView.Gesture(AState: TProfessorState);
begin
  FMachine.Gesture(AState, GetTickCount64);
  ApplyAnimation;
end;

procedure TProfessorView.TimerTick(Sender: TObject);
begin
  FMachine.Tick(GetTickCount64);
  ApplyAnimation;
end;

function TProfessorView.GetState: TProfessorState;
begin
  Result := FMachine.State;
end;

procedure TProfessorView.FrameCamera;
begin
  FViewport.Camera.SetWorldView(Vector3(0,FModelHeight*0.52,FModelHeight*1.9*FZoom),
    Vector3(0,0,-1),Vector3(0,1,0));
end;
procedure TProfessorView.ZoomBy(Steps: Single);
begin
  if FModelFile = '' then Exit;
  FZoom := EnsureRange(FZoom * Power(0.88,Steps), 0.4, 2.5);
  FrameCamera;
end;
function TProfessorControl.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  if Assigned(OnZoom) then begin OnZoom(WheelDelta/120); Result := True; end
  else Result := inherited DoMouseWheel(Shift,WheelDelta,MousePos);
end;
procedure TProfessorControl.CloseContext;
begin
  if HandleAllocated then DestroyHandle;
end;
procedure TProfessorView.ResetView(Sender: TObject);
begin FZoom := 1; FrameCamera; end;

end.
