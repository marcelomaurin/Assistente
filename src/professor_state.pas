unit professor_state;

{$mode objfpc}{$H+}

interface

type
  TProfessorState = (psIdle, psListening, psThinking, psSpeaking, psWave, psWalk);
  { Rendering never owns the conversational state. Gestures expire back to the
    latest activity; an incoming question or speech preempts a gesture. }
  TProfessorStateMachine = class
  private
    FActivity, FState: TProfessorState;
    FGestureUntil: QWord;
  public
    constructor Create;
    procedure SetActivity(AState: TProfessorState);
    procedure Gesture(AState: TProfessorState; ANow: QWord);
    procedure Tick(ANow: QWord);
    property State: TProfessorState read FState;
  end;

function AnimationName(AState: TProfessorState): string;

implementation

const Names: array[TProfessorState] of string =
  ('idle', 'listening', 'thinking', 'talking', 'wave', 'walk');

function AnimationName(AState: TProfessorState): string;
begin
  Result := Names[AState];
end;

constructor TProfessorStateMachine.Create;
begin
  inherited Create;
  FActivity := psIdle;
  FState := psIdle;
end;

procedure TProfessorStateMachine.SetActivity(AState: TProfessorState);
begin
  if AState in [psWave, psWalk] then Exit;
  FActivity := AState;
  FState := AState;
  FGestureUntil := 0;
end;

procedure TProfessorStateMachine.Gesture(AState: TProfessorState; ANow: QWord);
begin
  if not (AState in [psWave, psWalk]) or
    (FActivity in [psThinking, psSpeaking]) then Exit;
  FState := AState;
  FGestureUntil := ANow + 2400;
end;

procedure TProfessorStateMachine.Tick(ANow: QWord);
begin
  if (FGestureUntil <> 0) and (ANow >= FGestureUntil) then
  begin
    FState := FActivity;
    FGestureUntil := 0;
  end;
end;

end.
