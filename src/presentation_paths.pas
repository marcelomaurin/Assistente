unit presentation_paths;
{$mode objfpc}{$H+}
interface
uses SysUtils, Classes;
function ValidPresentationUTF8(const S: string): Boolean;
function SafePresentationPath(const S: string): Boolean;
function SupportedPresentationMedia(const S: string): Boolean;
implementation
function ValidPresentationUTF8(const S: string): Boolean;
var I,J,N: Integer; B,C: LongWord;
begin
  Result:=False;I:=1;
  while I<=Length(S) do begin
    B:=Byte(S[I]);N:=0;C:=B;
    if B>=128 then begin
      if (B>=$C2) and (B<=$DF) then begin N:=1;C:=B and $1F;end
      else if (B>=$E0) and (B<=$EF) then begin N:=2;C:=B and $0F;end
      else if (B>=$F0) and (B<=$F4) then begin N:=3;C:=B and $07;end
      else Exit;
      if I+N>Length(S) then Exit;
      for J:=1 to N do begin B:=Byte(S[I+J]);if (B and $C0)<>$80 then Exit;C:=(C shl 6) or (B and $3F);end;
      if ((N=1) and (C<$80)) or ((N=2) and (C<$800)) or ((N=3) and (C<$10000)) or
        ((C>=$D800) and (C<=$DFFF)) or (C>$10FFFF) then Exit;
    end;
    if C=0 then Exit;
    Inc(I,N+1);
  end;
  Result:=True;
end;

function SafePresentationPath(const S: string): Boolean;
var Parts: TStringList; I,J: Integer; P,B: string;
begin
  Result:=False;
  if not ValidPresentationUTF8(S) or (S='') or (Length(S)>240) or (S[1]='/') or (Pos('\',S)>0) then Exit;
  for I:=1 to Length(S) do
    if (Ord(S[I])<32) or (S[I] in [':','*','?','"','<','>','|','[',']']) then Exit;
  Parts:=TStringList.Create;
  try
    Parts.StrictDelimiter:=True;Parts.Delimiter:='/';Parts.DelimitedText:=S;
    for I:=0 to Parts.Count-1 do begin
      P:=Parts[I];
      if (P='') or (P='.') or (P='..') or (P[Length(P)] in [' ','.']) then Exit;
      J:=Pos('.',P);if J>0 then B:=Copy(P,1,J-1) else B:=P;
      B:=UpperCase(B);
      if (B='CON') or (B='PRN') or (B='AUX') or (B='NUL') or
        ((Length(B)=4) and ((Copy(B,1,3)='COM') or (Copy(B,1,3)='LPT')) and (B[4] in ['0'..'9'])) then Exit;
    end;
    Result:=Parts.Count>0;
  finally Parts.Free;end;
end;
function SupportedPresentationMedia(const S: string): Boolean;
var E: string;
begin
  E:=LowerCase(ExtractFileExt(S));
  Result:=(E='.png') or (E='.jpg') or (E='.jpeg') or (E='.bmp') or
    (E='.mp4') or (E='.avi') or (E='.wmv') or (E='.pptx');
end;
end.
