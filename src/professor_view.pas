unit professor_view;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Controls, ExtCtrls, StdCtrls, IniFiles,
  CastleControl, CastleViewport, CastleScene, CastleCameras, CastleVectors, CastleTransform,
  CastleURIUtils, LazFileUtils, professor_state, professor_catalog, Math, professor_commands;

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
    FSmile, FRightHandUp: Boolean;
    FRenderingActive: Boolean;
    FDirectiveGesture: string;
    FDirectiveUntil: QWord;
    FExtraPose: string;
    procedure TimerTick(Sender: TObject);
    procedure ApplyAnimation;
    function DefaultModel: string;
    function GetState: TProfessorState;
    function GetActivityLabel: string;
    procedure ResetView(Sender: TObject);
    procedure FrameCamera;
  public
    constructor Create(AOwner: TComponent; AParent: TWinControl); reintroduce;
    destructor Destroy; override;
    function LoadModel(const AFileName: string; AAutoIdle: Boolean): Boolean;
    procedure SetActivity(AState: TProfessorState);
    procedure Gesture(AState: TProfessorState);
    procedure ZoomBy(Steps: Single);
    function ExecuteCommand(Command: TAvatarCommand): Boolean;
    procedure ResetCommands;
    procedure SetRenderingActive(Active: Boolean);
    property Zoom: Single read FZoom;
    property Diagnostic: string read FDiagnostic;
    property Scene: TCastleScene read FScene;
    property ModelFile: string read FModelFile;
    property State: TProfessorState read GetState;
    property CurrentAnimation: string read FLastAnimation;
    property ActivityLabel: string read GetActivityLabel;
    property RenderingActive: Boolean read FRenderingActive;
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
  FScene.DefaultAnimationTransition := 0.32;
  FRenderingActive:=True;
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
  FSmile := False;
  FRightHandUp := False;
  FDirectiveGesture := '';
  FDirectiveUntil := 0;
  FExtraPose := '';
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
var Clip, Base, Requested: string;
begin
  if FModelFile = '' then Exit;
  Clip := FAnimations[FMachine.State];
  if FDirectiveGesture<>'' then Clip:=FDirectiveGesture
  else if FExtraPose<>'' then Clip:=FExtraPose;
  Base:=Clip;
  if FSmile then Clip:=Clip+'_smile';
  if FRightHandUp and (FDirectiveGesture='') and (FExtraPose='') then Clip:=Clip+'_right_hand_up';
  Requested:=Clip;
  if FScene.AnimationsList.IndexOf(Clip)<0 then
  begin
    Clip:=Base;
    if FRightHandUp and (FScene.AnimationsList.IndexOf(Base+'_right_hand_up')>=0) then Clip:=Base+'_right_hand_up'
    else if FSmile and (FScene.AnimationsList.IndexOf(Base+'_smile')>=0) then Clip:=Base+'_smile';
    if Requested<>Base then
    begin
      FNotice.Caption:='Modelo sem o gesto combinado: '+Requested;
      FNotice.Visible:=True;
    end;
  end;
  if (FMachine.State = psIdle) and not FAutoIdle and not FSmile and not FRightHandUp and (FDirectiveGesture='') then Clip := '';
  if (Clip <> '') and (FScene.AnimationsList.IndexOf(Clip) < 0) then
    Clip := FAnimations[psIdle];
  if Clip = FLastAnimation then Exit;
  FLastAnimation := Clip;
  if (Clip <> '') and (FScene.AnimationsList.IndexOf(Clip) >= 0) then
    FScene.PlayAnimation(Clip, True)
  else FScene.StopAnimation;
end;

function TProfessorView.ExecuteCommand(Command: TAvatarCommand): Boolean;
var Expected: string;
begin
  Expected:='';
  case Command of
    acNone: Exit(True);
    acSmile: begin FSmile:=True;Expected:=FAnimations[psIdle]+'_smile';end;
    acNeutral: begin ResetCommands;Exit(True);end;
    acRaiseRightHand: begin FRightHandUp:=True;FDirectiveGesture:='';Expected:=FAnimations[psIdle]+'_right_hand_up';end;
    acLowerRightHand: begin FRightHandUp:=False;FDirectiveGesture:='';end;
    acStopGesture: begin FDirectiveGesture:='';FDirectiveUntil:=0;end;
    acRelax: begin FExtraPose:='';end;
    acRaiseLeftHand,acRaiseBothHands,acLookLeft,acLookRight,acSurprise,
    acSad,acSerious,acCrossArms,acSit:
      begin FExtraPose:=StringReplace(AvatarCommandName(Command),' ','_',[rfReplaceAll]);Expected:=FExtraPose;end;
    acLowerLeftHand,acLowerBothHands,acLookFront,acCloseArms,acUncrossArms,acStand:
      begin FExtraPose:='';end;
    acApplause,acWave,acWalk:
      begin
        case Command of
          acApplause: begin FDirectiveGesture:='applause';if FMachine.State=psSpeaking then FDirectiveGesture:='applause_talking';end;
          acWave: FDirectiveGesture:=FAnimations[psWave];
          acWalk: FDirectiveGesture:=FAnimations[psWalk];
        end;
        Expected:=FDirectiveGesture;
        FDirectiveUntil:=GetTickCount64+2400;
      end;
    else begin
      FDirectiveGesture:=StringReplace(AvatarCommandName(Command),' ','_',[rfReplaceAll]);
      Expected:=FDirectiveGesture;
      FDirectiveUntil:=GetTickCount64+2400;
    end;
  end;
  if Command in [acRaiseRightHand,acLowerRightHand] then FScene.DefaultAnimationTransition:=0.6;
  ApplyAnimation;
  FScene.DefaultAnimationTransition:=0.32;
  Result:=(Expected='') or (FScene.AnimationsList.IndexOf(Expected)>=0);
  if not Result then
  begin FNotice.Caption:='Modelo sem comando: '+AvatarCommandName(Command);FNotice.Visible:=True;end;
end;

procedure TProfessorView.ResetCommands;
begin
  FSmile:=False;FRightHandUp:=False;FDirectiveGesture:='';FDirectiveUntil:=0;FExtraPose:='';
  ApplyAnimation;
end;

procedure TProfessorView.SetRenderingActive(Active: Boolean);
begin
  FRenderingActive:=Active;
  FTimer.Enabled:=Active;
  FControl.AutoRedisplay:=Active;
  FScene.TimePlaying:=Active;
  if Active then
  begin
    FControl.Container.Fps.ZeroNextSecondsPassed;
    FControl.Invalidate;
  end;
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
  if (FDirectiveUntil<>0) and (GetTickCount64>=FDirectiveUntil) then
  begin FDirectiveUntil:=0;FDirectiveGesture:='';end;
  FMachine.Tick(GetTickCount64);
  ApplyAnimation;
end;

function TProfessorView.GetState: TProfessorState;
begin
  Result := FMachine.State;
end;

function TProfessorView.GetActivityLabel: string;
begin
  if Pos('applause',FDirectiveGesture)=1 then Exit('Aplaudindo');
  if (FDirectiveGesture<>'') and (FDirectiveGesture=FAnimations[psWave]) then Exit('Acenando');
  if (FDirectiveGesture<>'') and (FDirectiveGesture=FAnimations[psWalk]) then Exit('Caminhando');
  if FRightHandUp then Exit('Mão direita levantada');
  case FMachine.State of
    psIdle: if FSmile then Result:='Sorrindo' else Result:='Pronto';
    psListening: Result:='Escutando';
    psThinking: Result:='Pensando';
    psSpeaking: Result:='Falando';
    psWave: Result:='Acenando';
    psWalk: Result:='Caminhando';
  end;
end;

procedure TProfessorView.FrameCamera;
var Focus: Single;
begin
  Focus:=0.52+0.24*(1-Min(1,FZoom))/0.6;
  FViewport.Camera.SetWorldView(Vector3(0,FModelHeight*Focus,FModelHeight*2.1*FZoom),
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
