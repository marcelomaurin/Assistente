program movement_rig_probe;
{$mode objfpc}{$H+}
uses SysUtils,movement_timeline;
var R:TMovementRuntime;
begin
  DefaultFormatSettings.DecimalSeparator:=#46;
  R:=TMovementRuntime.Create;
  try R.LoadRig(ParamStr(1),ParamStr(2),StrToFloat(ParamStr(3)));WriteLn('PASS: ',R.NodeCount,' nodes');
  finally R.Free;end;
end.
