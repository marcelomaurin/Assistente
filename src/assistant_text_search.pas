unit assistant_text_search;
{$mode objfpc}{$H+}
interface
// Positions are zero-based UTF-8 character offsets, as used by LCL TMemo.
function FindAssistantText(const Text, Query: string; AfterChar: Integer;
  out FoundChar, FoundLength: Integer; out Wrapped: Boolean): Boolean;
implementation
uses LazUTF8;
function FindAssistantText(const Text, Query: string; AfterChar: Integer;
  out FoundChar, FoundLength: Integer; out Wrapped: Boolean): Boolean;
var Haystack, Needle: string; Position: Integer;
begin
  FoundChar:=-1;FoundLength:=0;Wrapped:=False;Result:=False;
  if Query='' then Exit;
  Haystack:=UTF8LowerCase(Text);Needle:=UTF8LowerCase(Query);
  if AfterChar<0 then AfterChar:=0;
  // UTF8Pos's optional start offset is a byte offset in some LCL versions.
  // Slice by characters first so accents never move the next-match cursor.
  Position:=UTF8Pos(Needle,UTF8Copy(Haystack,AfterChar+1,MaxInt));
  if Position>0 then Inc(Position,AfterChar);
  if (Position=0) and (AfterChar>0) then begin
    Position:=UTF8Pos(Needle,Haystack);Wrapped:=Position>0;
  end;
  if Position=0 then Exit;
  FoundChar:=Position-1;FoundLength:=UTF8Length(Query);Result:=True;
end;
end.
