program wave_finalize_tests;
{$mode objfpc}{$H+}
uses SysUtils, aiaudioplayback;
var Error:string;Success:Boolean;
begin
  if ParamCount<>2 then Halt(2);
  Success:=FinalizeStreamingWaveFile(ParamStr(1),Error);
  if Success<>(ParamStr(2)='ok') then begin WriteLn('FAIL: ',Error);Halt(1);end;
  WriteLn('PASS: completed WAV header validation');
end.
