unit presentation_flow;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, LazUTF8, presentation_paths, professor_commands;
type
  TFlowAction = (faNone,faBlock,faGoto,faCall,faEvent,faEnd);
  TFlowToken = record
    Start,Size: Integer;
    Action: TFlowAction;
    Name,EventName: string;
  end;
  TFlowBlock = record
    Name,Key: string;
    Start,Finish: Integer;
  end;
  TFlowEvent = record
    EventName,BlockName: string;
  end;
  TFlowProgram = class
  private
    FSource: string;
    FTokens: array of TFlowToken;
    FBlocks: array of TFlowBlock;
    FEvents: array of TFlowEvent;
    procedure Scan;
    procedure Validate;
  public
    constructor Create(const Source: string);
    function BlockIndex(const Name: string): Integer;
    function TokenCount: Integer;
    function TokenAt(Index: Integer): TFlowToken;
    function BlockCount: Integer;
    function BlockName(Index: Integer): string;
    function EventCount: Integer;
    function EventBinding(Index: Integer): TFlowEvent;
    function HasFlow: Boolean;
    function Compile(const EntryBlock: string = ''; ImplicitEnd:Boolean = True): string;
    function WithoutFlowTags: string;
  end;
function FlowNameKey(const Name: string): string;
function MakeFlowTag(Action: TFlowAction; const Name: string = ''; const EventName: string = ''): string;
function NormalizeFlowEvent(const Name: string): string;
const FlowEventNames: array[0..3] of string = ('DETECCAO_VOZ','DETECCAO_ROSTO','MAO_LEVANTADA','RECONHECIMENTO_PESSOA');
const FlowEventTitles: array[0..3] of string = ('Detecção de voz','Detecção de rosto','Detecção de mão levantada','Reconhecimento de pessoa');
implementation
function FlowNameKey(const Name: string): string;
const Accents: array[0..25] of string = ('á','à','ã','â','ä','é','è','ê','ë','í','ì','î','ï','ó','ò','õ','ô','ö','ú','ù','û','ü','ç','ñ','ý','ÿ');
      Plain: array[0..25] of string = ('a','a','a','a','a','e','e','e','e','i','i','i','i','o','o','o','o','o','u','u','u','u','c','n','y','y');
var I: Integer;
begin
  Result:=UTF8LowerCase(Trim(Name));
  for I:=0 to High(Accents) do Result:=StringReplace(Result,Accents[I],Plain[I],[rfReplaceAll]);
  Result:=StringReplace(Result,'_',' ',[rfReplaceAll]);
  while Pos('  ',Result)>0 do Result:=StringReplace(Result,'  ',' ',[rfReplaceAll]);
end;
function Unwrap(const Value: string): string;
begin
  Result:=Trim(Value);
  if (Length(Result)>=2) and (Result[1]='{') and (Result[Length(Result)]='}') then
    Result:=Trim(Copy(Result,2,Length(Result)-2));
end;
procedure ValidateName(const Name: string);
var I: Integer; Key: string; Parsed: TAvatarScript;
begin
  if (Name='') or (UTF8Length(Name)>80) or not ValidPresentationUTF8(Name) then
    raise Exception.Create('Nome de bloco invalido (1 a 80 caracteres)');
  for I:=1 to Length(Name) do
    if (Ord(Name[I])<32) or (Name[I] in ['[',']','{','}',':','=','|','/','\','`']) then
      raise Exception.Create('Caractere invalido no nome do bloco');
  Key:=FlowNameKey(Name);Parsed:=ParseAvatarScript('['+Name+']');
  if (Key='fim') or (Key='bloco') or (Key='goto') or (Key='event') or
    (Parsed.CommandCount+Parsed.PresentationCount+Parsed.JointCount>0) then
    raise Exception.Create('Nome de bloco reservado: '+Name);
end;
function NormalizeFlowEvent(const Name: string): string;
var Key: string;
begin
  Key:=FlowNameKey(Unwrap(Name));
  if (Key='deteccao de voz') or (Key='deteccao voz') then Result:=FlowEventNames[0]
  else if (Key='deteccao de rosto') or (Key='deteccao rosto') then Result:=FlowEventNames[1]
  else if (Key='deteccao de mao levantada') or (Key='deteccao mao levantada') or (Key='mao levantada') then Result:=FlowEventNames[2]
  else if (Key='reconhecimento de pessoa') or (Key='reconhecimento pessoa') then Result:=FlowEventNames[3]
  else raise Exception.Create('Evento nao disponivel: '+Name);
end;
function MakeFlowTag(Action: TFlowAction; const Name: string; const EventName: string): string;
var N: string;
begin
  N:=Unwrap(Name);
  if Action<>faEnd then ValidateName(N);
  case Action of
    faBlock: Result:='[BLOCO:{'+N+'}]';
    faGoto: Result:='[GOTO:{'+N+'}]';
    faCall: Result:='[{'+N+'}]';
    faEvent: Result:='[EVENT={'+NormalizeFlowEvent(EventName)+'}:{'+N+'}]';
    faEnd: Result:='[FIM]';
    else raise Exception.Create('Comando de fluxo invalido');
  end;
end;
constructor TFlowProgram.Create(const Source: string);
begin
  inherited Create;
  if (Length(Source)>1024*1024) or not ValidPresentationUTF8(Source) then
    raise Exception.Create('Roteiro deve ser UTF-8 e ter ate 1 MiB');
  FSource:=Source;Scan;Validate;
end;
function TFlowProgram.BlockIndex(const Name: string): Integer;
var I: Integer; Key: string;
begin
  Result:=-1;Key:=FlowNameKey(Unwrap(Name));
  for I:=0 to High(FBlocks) do if FBlocks[I].Key=Key then Exit(I);
end;
function TFlowProgram.TokenCount: Integer;
begin Result:=Length(FTokens);end;
function TFlowProgram.TokenAt(Index: Integer): TFlowToken;
begin Result:=FTokens[Index];end;
function TFlowProgram.BlockCount: Integer;
begin Result:=Length(FBlocks);end;
function TFlowProgram.BlockName(Index: Integer): string;
begin Result:=FBlocks[Index].Name;end;
function TFlowProgram.EventCount: Integer;
begin Result:=Length(FEvents);end;
function TFlowProgram.EventBinding(Index: Integer): TFlowEvent;
begin Result:=FEvents[Index];end;
function TFlowProgram.HasFlow: Boolean;
var I: Integer;
begin Result:=False;for I:=0 to High(FTokens) do if FTokens[I].Action<>faNone then Exit(True);end;
procedure TFlowProgram.Scan;
var I,J,N,Ticks,Run,K,B,Sep: Integer; Token: TFlowToken; Text,Key,Value: string;
  Parsed: TAvatarScript;
begin
  I:=1;N:=Length(FSource);Ticks:=0;
  while I<=N do begin
    if FSource[I]='`' then begin
      Run:=1;while (I+Run<=N) and (FSource[I+Run]='`') do Inc(Run);
      if Ticks=0 then Ticks:=Run else if Ticks=Run then Ticks:=0;
      Inc(I,Run);Continue;
    end;
    if (FSource[I]='[') and (Ticks=0) and ((I=1) or (FSource[I-1]<>'\')) then begin
      J:=I+1;while (J<=N) and not (FSource[J] in [']',#10,#13,'[']) do Inc(J);
      Text:=Trim(Copy(FSource,I+1,J-I-1));Key:=UTF8LowerCase(Text);
      Token:=Default(TFlowToken);Token.Start:=I;Token.Size:=J-I+1;
      if ((J<N) and (FSource[J+1]='(')) or ((I>1) and (FSource[I-1]='!')) then begin I:=J+1;Continue;end;
      if Copy(Key,1,6)='bloco:' then begin Token.Action:=faBlock;Token.Name:=Unwrap(Copy(Text,7,MaxInt));end
      else if Copy(Key,1,5)='goto:' then begin Token.Action:=faGoto;Token.Name:=Unwrap(Copy(Text,6,MaxInt));end
      else if Copy(Key,1,6)='event=' then begin
        Token.Action:=faEvent;Value:=Copy(Text,7,MaxInt);Sep:=Pos(':',Value);
        if Sep=0 then raise Exception.Create('EVENT exige evento:bloco');
        Token.EventName:=NormalizeFlowEvent(Copy(Value,1,Sep-1));Token.Name:=Unwrap(Copy(Value,Sep+1,MaxInt));
      end else if Key='fim' then Token.Action:=faEnd
      else if ((Key='bloco') or (Copy(Key,1,6)='bloco=') or (Key='goto') or (Copy(Key,1,5)='goto=') or (Key='event') or (Copy(Key,1,6)='event:') or (Copy(Key,1,4)='fim=') or (Copy(Key,1,4)='fim:')) then
        raise Exception.Create('Tag de fluxo invalida: '+Text)
      else if (Length(Text)>0) and (Text[1]='{') then begin Token.Action:=faCall;Token.Name:=Unwrap(Text);end;
      if Token.Action<>faNone then begin
        if (J>N) or (FSource[J]<>']') then raise Exception.Create('Tag de fluxo sem fechamento');
        if Token.Action<>faEnd then ValidateName(Token.Name);
      end;
      // Keep all bracket tokens for a second pass resolving shorthand calls.
      if Token.Action=faNone then Token.Name:=Text;
      K:=Length(FTokens);SetLength(FTokens,K+1);FTokens[K]:=Token;
      if K>=8192 then raise Exception.Create('Excesso de tags no roteiro');
      if Token.Action=faBlock then begin
        if BlockIndex(Token.Name)>=0 then raise Exception.Create('Bloco duplicado: '+Token.Name);
        B:=Length(FBlocks);if B>=256 then raise Exception.Create('Limite de 256 blocos');
        if B>0 then FBlocks[B-1].Finish:=I;
        SetLength(FBlocks,B+1);FBlocks[B].Name:=Token.Name;FBlocks[B].Key:=FlowNameKey(Token.Name);
        FBlocks[B].Start:=J+1;FBlocks[B].Finish:=N+1;
      end;
      I:=J+1;Continue;
    end;
    Inc(I);
  end;
  for I:=0 to High(FTokens) do begin
    if (FTokens[I].Action=faNone) and (BlockIndex(FTokens[I].Name)>=0) then begin
      Parsed:=ParseAvatarScript(Copy(FSource,FTokens[I].Start,FTokens[I].Size));
      if Parsed.CommandCount+Parsed.PresentationCount+Parsed.JointCount=0 then FTokens[I].Action:=faCall;
    end;
  end;
end;
procedure TFlowProgram.Validate;
var I,J,K: Integer; Marks: array of Byte;
  procedure Visit(B,Depth: Integer);
  var T,Target: Integer;
  begin
    if Depth>32 then raise Exception.Create('Limite de 32 chamadas encadeadas');
    if Marks[B]=1 then raise Exception.Create('Ciclo de blocos: '+FBlocks[B].Name);
    if Marks[B]=2 then Exit;
    Marks[B]:=1;
    for T:=0 to High(FTokens) do
      if (FTokens[T].Start>=FBlocks[B].Start) and (FTokens[T].Start<FBlocks[B].Finish) and
        (FTokens[T].Action in [faCall,faGoto]) then begin
        Target:=BlockIndex(FTokens[T].Name);Visit(Target,Depth+1);
      end;
    Marks[B]:=2;
  end;
begin
  for I:=0 to High(FTokens) do begin
    if (FTokens[I].Action in [faCall,faGoto,faEvent]) and (BlockIndex(FTokens[I].Name)<0) then
      raise Exception.Create('Bloco inexistente: '+FTokens[I].Name);
    if FTokens[I].Action=faEvent then begin
      for J:=0 to High(FEvents) do
        if (FEvents[J].EventName=FTokens[I].EventName) and
          (FlowNameKey(FEvents[J].BlockName)=FlowNameKey(FTokens[I].Name)) then raise Exception.Create('Evento duplicado: '+FTokens[I].EventName);
      K:=Length(FEvents);SetLength(FEvents,K+1);
      FEvents[K].EventName:=FTokens[I].EventName;FEvents[K].BlockName:=FBlocks[BlockIndex(FTokens[I].Name)].Name;
    end;
  end;
  SetLength(Marks,BlockCount);
  for I:=0 to High(FBlocks) do Visit(I,1);
end;
function TFlowProgram.Compile(const EntryBlock: string; ImplicitEnd:Boolean): string;
var Stopped: Boolean; Calls,Entry,Finish,I: Integer;
  procedure Append(const Text: string);
  begin
    if Length(Result)+Length(Text)>1024*1024 then raise Exception.Create('Execucao expandida excede 1 MiB');
    Result:=Result+Text;
  end;
  procedure Expand(Start,Ending,Depth: Integer);
  var K,Pos,Target: Integer;
  begin
    Inc(Calls);if (Depth>32) or (Calls>4096) then raise Exception.Create('Limite de chamadas por execucao');
    Pos:=Start;
    for K:=0 to High(FTokens) do begin
      if Stopped then Exit;
      if (FTokens[K].Start<Start) or (FTokens[K].Start>=Ending) or (FTokens[K].Action=faNone) then Continue;
      Append(Copy(FSource,Pos,FTokens[K].Start-Pos));Pos:=FTokens[K].Start+FTokens[K].Size;
      case FTokens[K].Action of
        faCall,faGoto: begin
          Target:=BlockIndex(FTokens[K].Name);Expand(FBlocks[Target].Start,FBlocks[Target].Finish,Depth+1);
          if FTokens[K].Action=faGoto then begin
            if not Stopped then Append('[FIM]');Stopped:=True;
          end;
        end;
        faEnd: begin Append('[FIM]');Stopped:=True;end;
      end;
    end;
    if not Stopped then Append(Copy(FSource,Pos,Ending-Pos));
  end;
begin
  Result:='';Stopped:=False;Calls:=0;
  if EntryBlock<>'' then begin
    Entry:=BlockIndex(EntryBlock);if Entry<0 then raise Exception.Create('Bloco inexistente: '+EntryBlock);
    Expand(FBlocks[Entry].Start,FBlocks[Entry].Finish,1);
  end else begin
    Finish:=Length(FSource)+1;
    for I:=0 to High(FTokens) do if FTokens[I].Action=faBlock then begin Finish:=FTokens[I].Start;Break;end;
    Expand(1,Finish,1);
  end;
  if ImplicitEnd and (BlockCount>0) and not Stopped then Append('[FIM]');
end;
function TFlowProgram.WithoutFlowTags: string;
var I: Integer;
begin
  Result:=FSource;
  for I:=High(FTokens) downto 0 do if FTokens[I].Action<>faNone then
    Delete(Result,FTokens[I].Start,FTokens[I].Size);
end;
end.
