program installer_ssl_check;
{$mode objfpc}{$H+}
uses SysUtils, openssl;
var Root, Version: string;
begin
  if ParamCount<>1 then Halt(2);
  Root:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  DLLSSLName:=Root+'libssl-1_1.dll';
  DLLUtilName:=Root+'libcrypto-1_1.dll';
  if not InitSSLInterface then
  begin WriteLn('FAIL: packaged SSL runtime did not initialize');Halt(1);end;
  Version:=OpenSSLGetVersion(0);
  if Pos('OpenSSL 1.1.1',Version)<>1 then
  begin WriteLn('FAIL: unexpected SSL runtime: '+Version);Halt(1);end;
  WriteLn('PASS: packaged Win32 SSL runtime: '+Version);
end.
