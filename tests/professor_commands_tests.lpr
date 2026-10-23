program professor_commands_tests;
{$mode objfpc}{$H+}
uses SysUtils, professor_commands;
var S: TAvatarScript; I: Integer; Input: string;
procedure Check(Condition: Boolean; const Message: string);
begin if not Condition then raise Exception.Create(Message);end;
begin
  Input:='[sorriso] Oi [Aplausos] muito obrigado por estar aqui, '+
    '[levantar mao direita] se tiver uma duvida, levante a mão direita que eu irei escutar vc.[abaixe mao direita]';
  S:=ParseAvatarScript(Input);
  Check(S.CommandCount=4,'Four directives expected');
  Check((S.Steps[0].Command=acSmile) and (S.Steps[2].Command=acApplause) and
    (S.Steps[4].Command=acRaiseRightHand) and (S.Steps[6].Command=acLowerRightHand),'Order');
  Check(Pos('[',S.PlainText)=0,'Tags leaked to spoken text');
  Check(Pos('levante a mão direita',S.PlainText)>0,'Ordinary speech altered');
  S:=ParseAvatarScript('[LEVANTAR MÃO DIREITA] A [abaixe a mão direita] B');
  Check((S.CommandCount=2) and (S.Steps[0].Command=acRaiseRightHand),'Case and accents');
  Input:='`[sorriso]` [sorriso](https://example.test) [não é comando] [sorriso';
  S:=ParseAvatarScript(Input);Check((S.CommandCount=0) and (S.PlainText=Input),'Literal brackets/code/links');
  Input:='```texto'+LineEnding+'[aplausos]'+LineEnding+'``` [sorriso] Oi';
  S:=ParseAvatarScript(Input);Check(S.CommandCount=1,'Fenced code executed');
  Input:='';for I:=1 to 100 do Input:=Input+'[sorriso]';
  S:=ParseAvatarScript(Input);Check((S.CommandCount=64) and (S.PlainText=''),'Bounded directives');
  Check(Pos('[aplausos]',AvatarInstructionText)>0,'AI missing directive vocabulary');
  Check(SilentSegmentDuration('Oi')>=250,'Silent clock');
  for I:=Ord(Low(TAvatarCommand))+1 to Ord(acCloseEyes) do begin
    S:=ParseAvatarScript('['+AvatarCommandName(TAvatarCommand(I))+']');
    Check((S.CommandCount=1) and (S.Steps[0].Command=TAvatarCommand(I)), 'Canonical command round trip');
  end;
  S:=ParseAvatarScript('[Gesticular OK][jóia][Balançar a cabeça dizendo SIM][cabeça não][Fazendo coração com as mãos][Dar tchau][dizer não com os dedos][bocechar][abrir os olhos][fechar os olhos]');
  Check((S.CommandCount=10) and (S.PlainText=''), 'Requested natural aliases');
  S:=ParseAvatarScript('[cruzar os braços][descruzar os braços][abrir os braços][fechar os braços]');
  Check((S.CommandCount=4) and (S.Steps[0].Command=acCrossArms), 'Arm tags with articles');
  WriteLn('PASS: user example, command order, clean speech, accents, code/link literals, limits and AI instructions');
end.
