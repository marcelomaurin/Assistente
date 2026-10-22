unit assistant_integration_protocol;
{$mode objfpc}{$H+}
interface
uses SysUtils, Classes, fpjson;
const
  IntegrationRequestLimit = 16384;
  IntegrationResponseLimit = 1048576;
  IntegrationBufferBytes = IntegrationResponseLimit+1;
type
  TIntegrationConfig = record
    Enabled: Boolean;
    BindIP, Token, AllowedIPs: string;
    Port: Integer;
  end;
function DefaultIntegrationConfig: TIntegrationConfig;
function ParseIPv4(const Text: string; out IP: LongWord): Boolean;
function IsValidUTF8(const Text:UTF8String):Boolean;
function DecodeIntegrationBytes(const Data:RawByteString):UTF8String;
function StrictIntegrationJSON(const Text:UTF8String):TJSONData;
function ValidIntegrationToken(const Token: string): Boolean;
function GenerateIntegrationToken: string;
function ValidateIntegrationConfig(const Config: TIntegrationConfig; out Error: string): Boolean;
function IntegrationIPAllowed(const IP, Allowed: string): Boolean;
function SecureTokenEqual(const A,B: string): Boolean;
function ParseIntegrationRequest(const Text: UTF8String; out Request: TJSONObject): Boolean;
function IntegrationString(O:TJSONObject; const Name:string):UTF8String;
function IntegrationError(const Code:string):TJSONObject;
function IntegrationOK(Data:TJSONData):TJSONObject;
implementation
uses jsonparser,jsonscanner;
function DecodeIntegrationBytes(const Data:RawByteString):UTF8String;
begin SetString(Result,PAnsiChar(Data),Length(Data));end;
function StrictIntegrationJSON(const Text:UTF8String):TJSONData;
var Parser:TJSONParser;C:Char;Depth:Integer;Started,Done,Quoted,Escaped:Boolean;
begin
  Depth:=0;Started:=False;Done:=False;Quoted:=False;Escaped:=False;
  if not IsValidUTF8(Text) then raise EConvertError.Create('Invalid UTF-8');
  // Bound nesting BEFORE allocating a recursive JSON tree. Also reject a
  // second value/trailing garbage on FPC versions whose parser accepts it.
  for C in Text do begin
    if Done then begin if not (C in [#9,#10,#13,' ']) then raise EConvertError.Create('Trailing data');Continue;end;
    if Quoted then begin
      if Escaped then Escaped:=False else if C='\' then Escaped:=True else if C='"' then Quoted:=False;
      Continue;
    end;
    if not Started then begin
      if C in [#9,#10,#13,' '] then Continue;
      if C<>'{' then raise EConvertError.Create('Object required');Started:=True;
    end;
    case C of
      '"':Quoted:=True;
      '{','[':begin Inc(Depth);if Depth>32 then raise EConvertError.Create('Excessive nesting');end;
      '}',']':begin Dec(Depth);if Depth<0 then raise EConvertError.Create('Invalid nesting');if Depth=0 then Done:=True;end;
    end;
  end;
  if not Done or Quoted then raise EConvertError.Create('Incomplete object');
  Parser:=TJSONParser.Create(Text,[joUTF8,joStrict]);
  try Result:=Parser.Parse;finally Parser.Free;end;
end;
function IsValidUTF8(const Text:UTF8String):Boolean;
var I,J,N,B,Next:Integer;
begin
  I:=1;Result:=False;
  while I<=Length(Text) do begin
    B:=Ord(Text[I]);N:=0;
    if B<128 then N:=0 else if B in [194..223] then N:=1
    else if B in [224..239] then N:=2 else if B in [240..244] then N:=3 else Exit;
    if I+N>Length(Text) then Exit;
    if N>0 then begin
      Next:=Ord(Text[I+1]);
      if ((B=224) and (Next<160)) or ((B=237) and (Next>=160)) or
        ((B=240) and (Next<144)) or ((B=244) and (Next>143)) then Exit;
      for J:=1 to N do if not (Ord(Text[I+J]) in [128..191]) then Exit;
    end;
    Inc(I,N+1);
  end;
  Result:=True;
end;
function BCryptGenRandom(Provider:Pointer; Buffer:Pointer; Count,Flags:LongWord):LongInt;
  stdcall; external 'bcrypt.dll';
function DefaultIntegrationConfig:TIntegrationConfig;
begin
  Result:=Default(TIntegrationConfig);Result.BindIP:='127.0.0.1';
  Result.AllowedIPs:='127.0.0.1';Result.Port:=18766;
end;
function ParseIPv4(const Text:string;out IP:LongWord):Boolean;
var I,Part,Count,Digits:Integer;
begin
  Result:=False;IP:=0;Part:=0;Count:=0;Digits:=0;
  for I:=1 to Length(Text)+1 do
    if (I>Length(Text)) or (Text[I]='.') then
    begin
      if (Digits=0) or (Count>=4) then Exit;
      IP:=(IP shl 8) or LongWord(Part);Inc(Count);Part:=0;Digits:=0;
    end else begin
      if not (Text[I] in ['0'..'9']) then Exit;
      if (Digits=1) and (Part=0) then Exit;
      Inc(Digits);Part:=Part*10+Ord(Text[I])-48;
      if (Digits>3) or (Part>255) then Exit;
    end;
  Result:=Count=4;
end;
function ValidIntegrationToken(const Token:string):Boolean;
var C:Char;
begin
  Result:=False;if Length(Token)<>64 then Exit;
  for C in Token do if not (C in ['0'..'9','a'..'f','A'..'F']) then Exit;
  Result:=True;
end;
function GenerateIntegrationToken:string;
const Hex:array[0..15] of Char='0123456789abcdef';
var Bytes:array[0..31] of Byte;I:Integer;
begin
  if BCryptGenRandom(nil,@Bytes,SizeOf(Bytes),2)<>0 then
    raise Exception.Create('Falha ao gerar token pelo Windows');
  SetLength(Result,64);
  for I:=0 to 31 do begin Result[I*2+1]:=Hex[Bytes[I] shr 4];Result[I*2+2]:=Hex[Bytes[I] and 15];end;
  FillChar(Bytes,SizeOf(Bytes),0);
end;
function IPList(const Text:string):TStringList;
begin
  Result:=TStringList.Create;Result.StrictDelimiter:=True;Result.Delimiter:=';';
  Result.DelimitedText:=StringReplace(StringReplace(StringReplace(Text,#13,'',[rfReplaceAll]),#10,';',[rfReplaceAll]),',',';',[rfReplaceAll]);
end;
function ValidateIntegrationConfig(const Config:TIntegrationConfig;out Error:string):Boolean;
var IP:LongWord;List:TStringList;S:string;Count:Integer;
begin
  Result:=False;Error:='';
  if not ParseIPv4(Config.BindIP,IP) then Error:='Endereço de escuta deve ser IPv4 literal.'
  else if (Config.Port<1) or (Config.Port>65535) then Error:='Porta deve estar entre 1 e 65535.'
  else if not ValidIntegrationToken(Config.Token) then Error:='Gere um token de 64 caracteres hexadecimais.';
  if Error<>'' then Exit;
  List:=IPList(Config.AllowedIPs);Count:=0;
  try
    for S in List do if Trim(S)<>'' then begin
      if not ParseIPv4(Trim(S),IP) then begin Error:='Lista permitida aceita somente IPs IPv4 individuais.';Exit;end;
      Inc(Count);
    end;
    if (Count=0) or (Count>128) then begin Error:='Informe de 1 a 128 IPs permitidos.';Exit;end;
  finally List.Free;end;
  Result:=True;
end;
function IntegrationIPAllowed(const IP,Allowed:string):Boolean;
var Actual,Candidate:LongWord;S:string;List:TStringList;
begin
  Result:=False;if not ParseIPv4(IP,Actual) then Exit;
  List:=IPList(Allowed);
  try for S in List do if ParseIPv4(Trim(S),Candidate) and (Actual=Candidate) then Exit(True);
  finally List.Free;end;
end;
function SecureTokenEqual(const A,B:string):Boolean;
var I:Integer;Diff:LongWord;
begin
  // Fixed-size comparison; no prefix-dependent early exit.
  if (Length(A)<>64) or (Length(B)<>64) then Exit(False);
  Diff:=0;for I:=1 to 64 do Diff:=Diff or (Ord(A[I]) xor Ord(B[I]));Result:=Diff=0;
end;
function IntegrationString(O:TJSONObject;const Name:string):UTF8String;
var D:TJSONData;
begin Result:='';D:=O.Find(Name);if (D<>nil) and (D.JSONType=jtString) then Result:=D.AsString;end;
function ParseIntegrationRequest(const Text:UTF8String;out Request:TJSONObject):Boolean;
var D:TJSONData;I,J:Integer;
begin
  Result:=False;Request:=nil;
  if (Length(Text)=0) or (Length(Text)>IntegrationRequestLimit) or (Pos(#0,Text)>0) or not IsValidUTF8(Text) then Exit;
  D:=nil;
  try
    try D:=StrictIntegrationJSON(Text);except Exit;end;
    if not (D is TJSONObject) then Exit;
    Request:=TJSONObject(D);
    for I:=0 to Request.Count-1 do
      for J:=0 to I-1 do if Request.Names[I]=Request.Names[J] then Exit;
    if (Request.Find('v')=nil) or (Request.Find('v').AsJSON<>'1') or
      (IntegrationString(Request,'action')='') then Exit;
    Result:=True;D:=nil;
  finally D.Free;if not Result then Request:=nil;end;
end;
function IntegrationError(const Code:string):TJSONObject;
begin Result:=TJSONObject.Create(['v',1,'ok',False,'error',Code]);end;
function IntegrationOK(Data:TJSONData):TJSONObject;
begin Result:=TJSONObject.Create(['v',1,'ok',True]);Result.Add('result',Data);end;
initialization
  // FPC 3.2.2's JSON internals also use ordinary AnsiString temporaries.
  // This RTL instance must use UTF-8 even in DLL/console hosts without LCL.
  SetMultiByteConversionCodePage(65001);
end.
