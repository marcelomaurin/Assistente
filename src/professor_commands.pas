unit professor_commands;
{$mode objfpc}{$H+}
interface
uses SysUtils;
type
  TAvatarCommand = (acNone, acSmile, acNeutral, acApplause, acRaiseRightHand,
    acLowerRightHand, acWave, acWalk);
  TAvatarScriptStep = record
    Text: string;
    Command: TAvatarCommand;
  end;
  TAvatarScript = record
    PlainText: string;
    Steps: array of TAvatarScriptStep;
    CommandCount: Integer;
  end;
function ParseAvatarScript(const Source: string): TAvatarScript;
function AvatarCommandName(Command: TAvatarCommand): string;
function AvatarInstructionText: string;
function SilentSegmentDuration(const Text: string): QWord;
implementation

function NormalizeTag(const Tag: string): string;
const Accented: array[0..19] of string = ('á','Á','à','À','ã','Ã','â','Â',
  'é','É','ê','Ê','í','Í','ó','Ó','ô','Ô','ç','Ç');
      Plain: array[0..19] of string = ('a','a','a','a','a','a','a','a',
  'e','e','e','e','i','i','o','o','o','o','c','c');
var I: Integer;
begin
  Result:=Trim(Tag);
  for I:=0 to High(Accented) do Result:=StringReplace(Result,Accented[I],Plain[I],[rfReplaceAll]);
  Result:=LowerCase(Result);
  Result:=StringReplace(Result,'_',' ',[rfReplaceAll]);
  while Pos('  ',Result)>0 do Result:=StringReplace(Result,'  ',' ',[rfReplaceAll]);
end;

function CommandForTag(const Tag: string): TAvatarCommand;
var S: string;
begin
  S:=NormalizeTag(Tag);
  Result:=acNone;
  if (S='sorriso') or (S='sorrir') then Result:=acSmile
  else if (S='neutro') or (S='parar movimentos') then Result:=acNeutral
  else if (S='aplausos') or (S='aplaudir') then Result:=acApplause
  else if (S='levantar mao direita') or (S='levante a mao direita') then Result:=acRaiseRightHand
  else if (S='abaixar mao direita') or (S='abaixe mao direita') or (S='abaixe a mao direita') then Result:=acLowerRightHand
  else if (S='aceno') or (S='acenar') then Result:=acWave
  else if (S='caminhar') or (S='caminhada') then Result:=acWalk;
end;

function ParseAvatarScript(const Source: string): TAvatarScript;
var I,J,N,Backticks,CodeTicks: Integer; Buffer,Tag: string; Command: TAvatarCommand;
  procedure AddStep(const Text: string; Cmd: TAvatarCommand);
  var Count: Integer;
  begin
    Count:=Length(Result.Steps);SetLength(Result.Steps,Count+1);
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
      while (J<=N) and (J-I<=80) and not (Source[J] in [']',#10,#13,'[']) do Inc(J);
      if (J<=N) and (Source[J]=']') then
      begin
        Tag:=Copy(Source,I+1,J-I-1);Command:=CommandForTag(Tag);
        { Links and images with bracketed labels are ordinary text. }
        if (J<N) and (Source[J+1]='(') then Command:=acNone;
        if (I>1) and (Source[I-1]='!') then Command:=acNone;
        if Command<>acNone then
        begin
          Flush;
          { Limit animation events, but never pronounce extra recognized tags. }
          if Result.CommandCount<64 then begin AddStep('',Command);Inc(Result.CommandCount);end;
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
  'levantar mao direita','abaixar mao direita','aceno','caminhar');
begin Result:=Names[Command];end;

function AvatarInstructionText: string;
begin
  Result:='Você controla o avatar 3D com tags no texto final, imediatamente antes do trecho ao qual o gesto se aplica. '+
    'Use apenas estas tags, com moderação: '+
    '[sorriso] mantém um sorriso discreto; [neutro] remove sorriso, mão levantada e gestos; '+
    '[aplausos] bate palmas por 2,4 segundos; [aceno] acena por 2,4 segundos; '+
    '[caminhar] demonstra caminhada no lugar por 2,4 segundos; '+
    '[levantar mao direita] ergue e mantém a mão DIREITA do próprio personagem, à esquerda de quem o vê; '+
    '[abaixar mao direita] baixa essa mão. Sempre encerre a mão levantada com a tag de abaixar. '+
    'As tags são executadas e removidas da voz e do chat. Não escreva tags dentro de código e não invente comandos. '+
    'Exemplo: [sorriso] Olá! [aplausos] Obrigado por estar aqui. '+
    '[levantar mao direita] Se tiver uma dúvida, este é o gesto de levantar a mão direita. '+
    '[abaixar mao direita] Pode me fazer sua pergunta. '+
    'Esses comandos só movimentam o avatar: não detectam mãos ou rostos de visitantes e não acionam sensores. '+
    'Não afirme que detectou uma mão humana ou que iniciou escuta apenas por inserir uma tag.';
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
