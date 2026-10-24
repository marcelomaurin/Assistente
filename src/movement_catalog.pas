unit movement_catalog;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, presentation_joint_tags, movement_timeline;
type
  TMovementJoints = array of TJointTag;
  TMovementVariant=record Avatar:string;Timeline:TMovementTimeline;end;
  TMovementDefinition = record
    ID, Tag, Title, Category, Description, Clip, TalkingClip, Mode: string;
    Aliases: array of string;
    Duration, Transition: Integer;
    SpeechMouth: Boolean;
    Joints: TMovementJoints;
    Timeline:TMovementTimeline;
    Variants:array of TMovementVariant;
  end;
function NormalizeMovementTag(const Value: string): string;
function MovementCatalogFile: string;
procedure ReloadMovementCatalog(const FileName: string = '');
function MovementTimelineFor(const M:TMovementDefinition;const Avatar:string):TMovementTimeline;
function MovementCollisionFile:string;
function MovementCount: Integer;
function MovementAt(Index: Integer): TMovementDefinition;
function FindMovement(const Value: string; out Movement: TMovementDefinition): Boolean;
function MovementInstructions: string;
implementation
uses fpjson, jsonparser, Math, presentation_tags;
type TMovementDefinitions = array of TMovementDefinition;
var Items: TMovementDefinitions; LoadedFile: string; LoadedAge: Int64 = -1;
  CatalogLock: TRTLCriticalSection;

function NormalizeMovementTag(const Value: string): string;
const Accented: array[0..23] of string = ('á','Á','à','À','ã','Ã','â','Â',
 'é','É','ê','Ê','í','Í','ó','Ó','ô','Ô','ç','Ç','ú','Ú','ü','Ü');
 Plain: array[0..23] of string = ('a','a','a','a','a','a','a','a',
 'e','e','e','e','i','i','o','o','o','o','c','c','u','u','u','u');
var I: Integer;
begin
  Result:=Trim(Value);
  for I:=0 to High(Accented) do Result:=StringReplace(Result,Accented[I],Plain[I],[rfReplaceAll]);
  Result:=LowerCase(Result);Result:=StringReplace(Result,'_',' ',[rfReplaceAll]);
  Result:=StringReplace(Result,#9,' ',[rfReplaceAll]);
  while Pos('  ',Result)>0 do Result:=StringReplace(Result,'  ',' ',[rfReplaceAll]);
end;

function DefaultFile: string;
var Base,Candidate: string; I: Integer;
begin
  Result:=GetEnvironmentVariable('ASSISTENTE_MOVEMENTS_FILE');
  if Result<>'' then Exit(ExpandFileName(Result));
  Base:=ExtractFilePath(ParamStr(0));
  for I:=0 to 3 do begin
    Candidate:=IncludeTrailingPathDelimiter(Base)+'AVATARES'+PathDelim+'movimentos.json';
    if FileExists(Candidate) then Exit(ExpandFileName(Candidate));
    Base:=ExtractFileDir(ExcludeTrailingPathDelimiter(Base));
  end;
  Result:=ExpandFileName('AVATARES'+PathDelim+'movimentos.json');
end;

function TextField(O: TJSONObject; const Key, DefaultValue: string): string;
var D: TJSONData;
begin
  D:=O.Find(Key);if D=nil then Exit(DefaultValue);
  if D.JSONType<>jtString then raise EConvertError.Create('Campo de texto invalido: '+Key);
  Result:=D.AsString;
end;

function NumberField(O: TJSONObject; const Key: string; DefaultValue: Integer): Integer;
var D: TJSONData; V: Double;
begin
  D:=O.Find(Key);if D=nil then Exit(DefaultValue);
  if D.JSONType<>jtNumber then raise EConvertError.Create('Campo numerico invalido: '+Key);
  V:=D.AsFloat;
  if IsNan(V) or IsInfinite(V) or (V<0) or (V>60000) or (V<>Trunc(V)) then
    raise EConvertError.Create('Valor numerico fora do limite: '+Key);
  Result:=Round(V);
end;

procedure LoadLocked(const FileName: string);
var Text: TStringList; Root,D,A,J: TJSONData; O,JO: TJSONObject;
  Profiles:TJSONData;V:Integer;
  Next: TMovementDefinitions; Seen: TStringList; I,K,N: Integer;
  Axis: string; M: TMovementDefinition; T: TJointTag;
  procedure RegisterToken(const Value: string);
  var P: Integer; Normal: string;Presentation:TPresentationTag;
  begin
    Normal:=NormalizeMovementTag(Value);
    if (Normal='') or (Length(Normal)>120) or (Pos('[',Normal)>0) or (Pos(']',Normal)>0) or
       (Pos('=',Normal)>0) or (Pos(#10,Normal)>0) or (Pos(#13,Normal)>0) then
      raise EConvertError.Create('Tag ou identificador invalido: '+Value);
    if (Normal='fim') or (Pos('bloco:',Normal)=1) or (Pos('goto:',Normal)=1) or (Pos('event:',Normal)=1) or TryParsePresentationTag(Value,Presentation) then
      raise EConvertError.Create('Tag reservada a apresentacoes: '+Value);
    P:=Seen.IndexOf(Normal);
    if (P>=0) and (PtrInt(Seen.Objects[P])<>I) then
      raise EConvertError.Create('Tag duplicada: '+Value);
    if P<0 then Seen.AddObject(Normal,TObject(PtrInt(I)));
  end;
begin
  if not FileExists(FileName) then raise EConvertError.Create('Catalogo de movimentos ausente: '+FileName);
  Text:=TStringList.Create;Seen:=TStringList.Create;Root:=nil;
  try
    Text.LoadFromFile(FileName);
    if Length(Text.Text)>32*1024*1024 then raise EConvertError.Create('Catalogo de movimentos excede 32 MiB');
    Root:=GetJSON(Text.Text);
    if not (Root is TJSONObject) then raise EConvertError.Create('Catalogo deve ser um objeto JSON');
    O:=TJSONObject(Root);
    if not (NumberField(O,'version',0) in [1,2]) then raise EConvertError.Create('Versao do catalogo nao suportada');
    A:=O.Find('movements');
    if not (A is TJSONArray) or (A.Count=0) or (A.Count>512) then raise EConvertError.Create('Use de 1 a 512 movimentos');
    SetLength(Next,A.Count);
    for I:=0 to A.Count-1 do begin
      if not (A.Items[I] is TJSONObject) then raise EConvertError.Create('Movimento deve ser um objeto');
      O:=TJSONObject(A.Items[I]);M:=Default(TMovementDefinition);
      M.ID:=TextField(O,'id','');M.Tag:=TextField(O,'tag',M.ID);
      M.Title:=TextField(O,'title',M.Tag);M.Description:=TextField(O,'description','');
      M.Category:=TextField(O,'category','Geral');M.Clip:=TextField(O,'clip','');
      M.TalkingClip:=TextField(O,'talking_clip','');M.Mode:=TextField(O,'mode','gesture');
      M.Timeline:=ParseMovementTimeline(O);
      Profiles:=O.Find('profiles');if Profiles<>nil then begin
        if not (Profiles is TJSONObject) or (Profiles.Count>32) then raise EConvertError.Create('profiles deve conter ate 32 variantes');
        SetLength(M.Variants,Profiles.Count);
        for V:=0 to Profiles.Count-1 do begin
          if not (Profiles.Items[V] is TJSONObject) then raise EConvertError.Create('Variante invalida');
          M.Variants[V].Avatar:=TJSONObject(Profiles).Names[V];M.Variants[V].Timeline:=ParseMovementTimeline(TJSONObject(Profiles.Items[V]));
          if (M.Variants[V].Timeline.DurationMS<>M.Timeline.DurationMS) or (M.Variants[V].Timeline.TransitionMS<>M.Timeline.TransitionMS) or (M.Variants[V].Timeline.ReturnMS<>M.Timeline.ReturnMS) or (M.Variants[V].Timeline.ReturnToStart<>M.Timeline.ReturnToStart) then raise EConvertError.Create('Variante deve conservar os tempos do movimento');
        end;
      end;
      M.Duration:=NumberField(O,'duration_ms',2400);M.Transition:=NumberField(O,'transition_ms',320);
      if (M.Duration<50) or (M.Transition>5000) then raise EConvertError.Create('Duracao ou transicao invalida: '+M.ID);
      if (M.Mode<>'gesture') and (M.Mode<>'pose') and (M.Mode<>'reset') and (M.Mode<>'smile') and
        (M.Mode<>'raise_right') and (M.Mode<>'lower_right') and (M.Mode<>'clear_pose') and
        (M.Mode<>'lower_both') and (M.Mode<>'stop') then raise EConvertError.Create('Modo invalido: '+M.Mode);
      D:=O.Find('speech_mouth');
      if D<>nil then begin
        if D.JSONType<>jtBoolean then raise EConvertError.Create('speech_mouth deve ser booleano');
        M.SpeechMouth:=D.AsBoolean;
      end;
      RegisterToken(M.ID);RegisterToken(M.Tag);
      D:=O.Find('aliases');
      if D<>nil then begin
        if not (D is TJSONArray) then raise EConvertError.Create('aliases deve ser uma lista');
        SetLength(M.Aliases,D.Count);
        for K:=0 to D.Count-1 do begin
          if D.Items[K].JSONType<>jtString then raise EConvertError.Create('Alias deve ser texto');
          M.Aliases[K]:=D.Items[K].AsString;RegisterToken(M.Aliases[K]);
        end;
      end;
      J:=O.Find('joints');
      if J<>nil then begin
        if not (J is TJSONArray) or (J.Count>64) then raise EConvertError.Create('joints deve ter ate 64 articulacoes');
        SetLength(M.Joints,J.Count);
        for K:=0 to J.Count-1 do begin
          if not (J.Items[K] is TJSONObject) then raise EConvertError.Create('Articulacao deve ser objeto');
          JO:=TJSONObject(J.Items[K]);T:=Default(TJointTag);
          T.Bone:=TextField(JO,'bone','');Axis:=TextField(JO,'axis','');
          if (Length(Axis)<>1) or not (Axis[1] in ['x','y','z']) then raise EConvertError.Create('Eixo invalido');
          T.Axis:=Axis[1];D:=JO.Find('angle');
          if (D=nil) or (D.JSONType<>jtNumber) then raise EConvertError.Create('Angulo invalido');
          T.Angle:=D.AsFloat;T.Duration:=NumberField(JO,'duration_ms',600);T.Smooth:=True;
          if IsNan(T.Angle) or IsInfinite(T.Angle) or (JointAngleLimit(T.Bone)=0) or
            (Abs(T.Angle)>JointAngleLimit(T.Bone)) or (T.Duration<50) or (T.Duration>10000) then
            raise EConvertError.Create('Articulacao fora dos limites: '+T.Bone);
          for N:=0 to K-1 do if M.Joints[N].Bone=T.Bone then raise EConvertError.Create('Osso repetido: '+T.Bone);
          M.Joints[K]:=T;
        end;
      end;
      if (M.Mode='gesture') or (M.Mode='pose') then
        if (M.Clip='') and (Length(M.Joints)=0) and (Length(M.Timeline.Tracks)=0) then raise EConvertError.Create('Movimento sem clip ou joints: '+M.ID);
      Next[I]:=M;
    end;
    Items:=Next;LoadedFile:=ExpandFileName(FileName);LoadedAge:=FileAge(LoadedFile);
  finally Root.Free;Seen.Free;Text.Free;end;
end;

procedure EnsureLocked;
begin
  if LoadedFile='' then LoadLocked(DefaultFile)
  else if FileAge(LoadedFile)<>LoadedAge then LoadLocked(LoadedFile);
end;

function MovementCatalogFile: string;
begin
  EnterCriticalSection(CatalogLock);
  try if LoadedFile='' then Result:=DefaultFile else Result:=LoadedFile;
  finally LeaveCriticalSection(CatalogLock);end;
end;
procedure ReloadMovementCatalog(const FileName: string);
var Target: string;
begin
  EnterCriticalSection(CatalogLock);
  try
    Target:=FileName;if Target='' then Target:=LoadedFile;if Target='' then Target:=DefaultFile;
    LoadLocked(Target);
  finally LeaveCriticalSection(CatalogLock);end;
end;
function MovementTimelineFor(const M:TMovementDefinition;const Avatar:string):TMovementTimeline;
var I:Integer;
begin for I:=0 to High(M.Variants) do if M.Variants[I].Avatar=Avatar then Exit(M.Variants[I].Timeline);Result:=M.Timeline;end;
function MovementCollisionFile:string;
begin Result:=ExtractFilePath(MovementCatalogFile)+'colisoes.json';end;
function MovementCount: Integer;
begin
  EnterCriticalSection(CatalogLock);
  try EnsureLocked;Result:=Length(Items);finally LeaveCriticalSection(CatalogLock);end;
end;
function MovementAt(Index: Integer): TMovementDefinition;
begin
  EnterCriticalSection(CatalogLock);
  try EnsureLocked;if (Index<0) or (Index>=Length(Items)) then raise ERangeError.Create('Movimento inexistente');Result:=Items[Index];
  finally LeaveCriticalSection(CatalogLock);end;
end;
function FindMovement(const Value: string; out Movement: TMovementDefinition): Boolean;
var S: string; I,K: Integer;
begin
  Movement:=Default(TMovementDefinition);S:=NormalizeMovementTag(Value);Result:=False;
  EnterCriticalSection(CatalogLock);
  try
    EnsureLocked;
    for I:=0 to High(Items) do begin
      if (NormalizeMovementTag(Items[I].Tag)=S) or (NormalizeMovementTag(Items[I].ID)=S) then begin Movement:=Items[I];Exit(True);end;
      for K:=0 to High(Items[I].Aliases) do if NormalizeMovementTag(Items[I].Aliases[K])=S then begin Movement:=Items[I];Exit(True);end;
    end;
  finally LeaveCriticalSection(CatalogLock);end;
end;
function MovementInstructions: string;
var I: Integer;
begin
  EnterCriticalSection(CatalogLock);
  try
    EnsureLocked;Result:='';
    for I:=0 to High(Items) do Result:=Result+'['+Items[I].Tag+'] '+Items[I].Description+'; ';
  finally LeaveCriticalSection(CatalogLock);end;
end;
initialization InitCriticalSection(CatalogLock);
finalization DoneCriticalSection(CatalogLock);
end.
