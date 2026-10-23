unit professor_commands;
{$mode objfpc}{$H+}
interface
uses SysUtils, presentation_tags, presentation_joint_tags, movement_catalog;
type
  TAvatarCommand = (acNone, acSmile, acNeutral, acApplause, acRaiseRightHand,
    acLowerRightHand, acWave, acWalk,
    acBlink, acNod, acShakeHead, acThink, acExplain, acPointRight, acPointLeft, acRaiseLeftHand, acLowerLeftHand, acRaiseBothHands, acLowerBothHands, acLookLeft, acLookRight, acLookFront, acSurprise, acSad, acSerious, acLaugh, acCelebrate, acBow, acThumbsUp, acThumbsDown, acOpenArms, acCloseArms, acCrossArms, acUncrossArms, acSit, acStand, acStepBack, acStepForward, acDance, acStopGesture, acRelax, acOK, acHeart, acLookBackRight, acLookBackLeft, acFingerNo, acRaiseRightFoot, acCloseLeftHand, acOpenLeftHand, acCloseRightHand, acOpenRightHand, acYawn, acOpenEyes, acCloseEyes, acCustom);
  TAvatarScriptStep = record
    Text, MovementID: string;
    Command: TAvatarCommand;
    Presentation: TPresentationTag;
    Joint: TJointTag;
    SourceStart, SourceLength: Integer;
  end;
  TAvatarScript = record
    PlainText: string;
    Steps: array of TAvatarScriptStep;
    CommandCount, PresentationCount, JointCount: Integer;
  end;
function ParseAvatarScript(const Source: string; CommandLimit: Integer = 64): TAvatarScript;
function AvatarCommandName(Command: TAvatarCommand): string;
function AvatarInstructionText: string;
function SilentSegmentDuration(const Text: string): QWord;
implementation

function CommandForTag(const Tag: string; out MovementID: string): TAvatarCommand;
var M: TMovementDefinition; C: TAvatarCommand;
begin
  Result:=acNone;MovementID:='';
  if not FindMovement(Tag,M) then Exit;
  MovementID:=M.ID;Result:=acCustom;
  for C:=acSmile to acCloseEyes do
    if NormalizeMovementTag(AvatarCommandName(C))=NormalizeMovementTag(M.ID) then Exit(C);
end;

function ParseAvatarScript(const Source: string; CommandLimit: Integer): TAvatarScript;
var I,J,N,Backticks,CodeTicks: Integer; Buffer,Tag,MotionID: string; Command: TAvatarCommand; Media: TPresentationTag; Joint: TJointTag;
  procedure AddStep(const Text: string; Cmd: TAvatarCommand);
  var Count: Integer;
  begin
    Count:=Length(Result.Steps);SetLength(Result.Steps,Count+1);
    Result.Steps[Count]:=Default(TAvatarScriptStep);
    Result.Steps[Count].SourceStart:=I;Result.Steps[Count].SourceLength:=J-I+1;
    Result.Steps[Count].Text:=Text;Result.Steps[Count].Command:=Cmd;
  end;
  procedure Flush;
  begin
    if Buffer<>'' then begin AddStep(Buffer,acNone);Result.PlainText:=Result.PlainText+Buffer;Buffer:='';end;
  end;
begin
  Result:=Default(TAvatarScript);I:=1;N:=Length(Source);Buffer:='';CodeTicks:=0;
  while I<=N do
  begin
    if Source[I]='`' then
    begin
      Backticks:=1;
      while (I+Backticks<=N) and (Source[I+Backticks]='`') do Inc(Backticks);
      if CodeTicks=0 then CodeTicks:=Backticks else if Backticks=CodeTicks then CodeTicks:=0;
      Buffer:=Buffer+Copy(Source,I,Backticks);Inc(I,Backticks);Continue;
    end;
    if (Source[I]='[') and (CodeTicks=0) and ((I=1) or (Source[I-1]<>'\')) then
    begin
      J:=I+1;
      while (J<=N) and (J-I<=512) and not (Source[J] in [']',#10,#13,'[']) do Inc(J);
      if (J<=N) and (Source[J]=']') then
      begin
        Tag:=Copy(Source,I+1,J-I-1);Command:=CommandForTag(Tag,MotionID);
        if not TryParsePresentationTag(Tag,Media) then Media:=Default(TPresentationTag);
        if not TryParseJointTag(Tag,Joint) then Joint:=Default(TJointTag);
        { Links and images with bracketed labels are ordinary text. }
        if (J<N) and (Source[J+1]='(') then begin Command:=acNone;Media.Action:=paNone;Joint.Bone:='';end;
        if (I>1) and (Source[I-1]='!') then begin Command:=acNone;Media.Action:=paNone;Joint.Bone:='';end;
        if (Media.Action<>paNone) or (Joint.Bone<>'') then
        begin
          Flush;AddStep('',acNone);
          if Media.Action<>paNone then begin Result.Steps[High(Result.Steps)].Presentation:=Media;Inc(Result.PresentationCount);end
          else begin Result.Steps[High(Result.Steps)].Joint:=Joint;Inc(Result.JointCount);end;
          I:=J+1;Continue;
        end;
        if Command<>acNone then
        begin
          Flush;
          { Limit animation events, but never pronounce extra recognized tags. }
          if Result.CommandCount<CommandLimit then begin AddStep('',Command);Result.Steps[High(Result.Steps)].MovementID:=MotionID;Inc(Result.CommandCount);end;
          I:=J+1;Continue;
        end;
      end;
    end;
    Buffer:=Buffer+Source[I];Inc(I);
  end;
  Flush;
end;

function AvatarCommandName(Command: TAvatarCommand): string;
const Names: array[TAvatarCommand] of string = ('','sorriso','neutro','aplausos',
  'levantar mao direita','abaixar mao direita','aceno','caminhar',
  'piscar', 'concordar', 'negar', 'pensar', 'explicar', 'apontar direita', 'apontar esquerda', 'levantar mao esquerda', 'abaixar mao esquerda', 'levantar ambas maos', 'abaixar ambas maos', 'olhar esquerda', 'olhar direita', 'olhar frente', 'surpresa', 'triste', 'serio', 'rir', 'comemorar', 'cumprimentar', 'positivo', 'negativo', 'abrir bracos', 'fechar bracos', 'cruzar bracos', 'descruzar bracos', 'sentar', 'levantar', 'passo atras', 'passo frente', 'dancar', 'parar gesto', 'relaxar', 'gesticular ok', 'coracao com as maos', 'olhar para tras direita', 'olhar para tras esquerda', 'nao com o dedo', 'levantar pe direito', 'fechar mao esquerda', 'abrir mao esquerda', 'fechar mao direita', 'abrir mao direita', 'bocejar', 'abrir olhos', 'fechar olhos', '');
begin Result:=Names[Command];end;

function AvatarInstructionText: string;
begin
  Result:='Você controla o avatar 3D com tags no texto final, imediatamente antes do trecho ao qual o gesto se aplica. '+
    'Use com moderação apenas as tags do catálogo compartilhado: '+MovementInstructions+
    'As tags são executadas e removidas da voz e do chat. Não escreva tags dentro de código e não invente comandos. '+
    'Direita e esquerda são as do personagem. Uma nova pose persistente substitui a anterior. '+
    'Use [neutro] para limpar todas as poses. A boca acompanha a fala, exceto durante o bocejo. '+
    'Exemplo: [sorriso] Olá! [aplausos] Obrigado. [levantar mao direita] Pode perguntar. [abaixar mao direita] '+
    'Esses comandos só movimentam o avatar; não detectam visitantes e não acionam sensores.';
end;

function SilentSegmentDuration(const Text: string): QWord;
var I,Words: Integer; Inside: Boolean;
begin
  Words:=0;Inside:=False;
  for I:=1 to Length(Text) do
    if Text[I] in [' ',#9,#10,#13] then Inside:=False
    else if not Inside then begin Inc(Words);Inside:=True;end;
  Result:=QWord(Words)*340;
  if Result<250 then Result:=250;
  if Result>15000 then Result:=15000;
end;
end.
