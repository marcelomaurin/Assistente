unit professor_listener;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, SyncObjs, ExtCtrls, aicontinuouslistener;
type
  TProfessorListenState = (plsIdle, plsListening, plsSpeech, plsSilence, plsPaused, plsError);
  TProfessorSpeechEvent = procedure(Sender: TObject; const AFileName: string) of object;
  TProfessorListenEvent = procedure(Sender: TObject; AState: TProfessorListenState) of object;
  { Adapt the PINNED voice library. Capture callbacks only fill a mailbox;
    LCL callbacks and capture stop/start always run on the main thread. }
  TProfessorListener = class(TComponent)
  private
    FNative: TAIContinuousListener;
    FLock: TCriticalSection;
    FPending: TStringList;
    FTimer: TTimer;
    FNativeState: TAIListeningState;
    FEnabled, FPaused: Boolean;
    FState: TProfessorListenState;
    FOnSpeechReady: TProfessorSpeechEvent;
    FOnStateChange: TProfessorListenEvent;
    procedure NativeSpeech(Sender: TObject; const AFile: string; ADuration: Integer);
    procedure NativeState(Sender: TObject; AOld, ANew: TAIListeningState);
    procedure Tick(Sender: TObject);
    procedure SetState(AState: TProfessorListenState);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    procedure Pause;
    procedure Resume;
    property Native: TAIContinuousListener read FNative;
    property Enabled: Boolean read FEnabled;
    property State: TProfessorListenState read FState;
    property OnSpeechReady: TProfessorSpeechEvent read FOnSpeechReady write FOnSpeechReady;
    property OnStateChange: TProfessorListenEvent read FOnStateChange write FOnStateChange;
  end;
implementation
constructor TProfessorListener.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLock := TCriticalSection.Create;
  FPending := TStringList.Create;
  FNative := TAIContinuousListener.Create(Self);
  FNative.OnSpeechUtterance := @NativeSpeech;
  FNative.OnStateChanged := @NativeState;
  FNativeState := lsStopped;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 50;
  FTimer.OnTimer := @Tick;
end;
destructor TProfessorListener.Destroy;
begin
  FTimer.Enabled := False;
  Stop;
  FNative.Free;
  FPending.Free;
  FLock.Free;
  inherited Destroy;
end;
procedure TProfessorListener.NativeSpeech(Sender: TObject; const AFile: string; ADuration: Integer);
begin
  FLock.Acquire;
  try FPending.Add(AFile); finally FLock.Release; end;
end;
procedure TProfessorListener.NativeState(Sender: TObject; AOld, ANew: TAIListeningState);
begin
  FLock.Acquire;
  try FNativeState := ANew; finally FLock.Release; end;
end;
procedure TProfessorListener.SetState(AState: TProfessorListenState);
begin
  if FState = AState then Exit;
  FState := AState;
  if Assigned(FOnStateChange) then FOnStateChange(Self, AState);
end;
procedure TProfessorListener.Tick(Sender: TObject);
var FileName: string; S: TAIListeningState;
begin
  FileName := '';
  FLock.Acquire;
  try
    S := FNativeState;
    if FPending.Count > 0 then begin FileName := FPending[0]; FPending.Delete(0); end;
  finally FLock.Release; end;
  if FEnabled and not FPaused then
    case S of
      lsListening: SetState(plsListening);
      lsSpeechDetected, lsCapturingSpeech: SetState(plsSpeech);
      lsWaitingSilence: SetState(plsSilence);
      lsError: SetState(plsError);
    end;
  if FileName <> '' then
  begin
    if FEnabled and not FPaused and Assigned(FOnSpeechReady) then
    begin Pause; FOnSpeechReady(Self, FileName); end
    else SysUtils.DeleteFile(FileName);
  end;
end;
procedure TProfessorListener.Start;
begin
  if FEnabled then Exit;
  FEnabled := FNative.StartListening;
  FPaused := False;
  if FEnabled then SetState(plsListening) else SetState(plsError);
end;
procedure TProfessorListener.Stop;
var I: Integer;
begin
  FEnabled := False;
  FPaused := False;
  FNative.StopListening;
  FLock.Acquire;
  try
    for I := 0 to FPending.Count - 1 do SysUtils.DeleteFile(FPending[I]);
    FPending.Clear;
  finally FLock.Release; end;
  SetState(plsIdle);
end;
procedure TProfessorListener.Pause;
begin
  if not FEnabled or FPaused then Exit;
  FPaused := True;
  FNative.StopListening;
  SetState(plsPaused);
end;
procedure TProfessorListener.Resume;
begin
  if not FEnabled or not FPaused then Exit;
  FPaused := False;
  FEnabled := FNative.StartListening;
  if FEnabled then SetState(plsListening) else SetState(plsError);
end;
end.
