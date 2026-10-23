unit presentation_cli;
{$mode objfpc}{$H+}
interface
uses SysUtils, Windows;
function PresentationParam(Index: Integer): string;
implementation
type TArguments = array[0..65535] of PWideChar; PArguments = ^TArguments;
var Args: array of string;
function CommandLineToArgvW(Command: PWideChar; var Count: Integer): PArguments; stdcall; external 'shell32.dll';
function PresentationParam(Index: Integer): string;
begin if (Index<0) or (Index>=Length(Args)) then Result:='' else Result:=Args[Index];end;
procedure InitializeArguments;
var A: PArguments; I,N: Integer;
begin
  SetMultiByteConversionCodePage(CP_UTF8);DefaultSystemCodePage:=CP_UTF8;
  A:=CommandLineToArgvW(GetCommandLineW,N);
  if A=nil then raise Exception.Create('Nao foi possivel ler argumentos Unicode');
  try SetLength(Args,N);for I:=0 to N-1 do Args[I]:=UTF8Encode(UnicodeString(A^[I]));
  finally LocalFree(HLOCAL(A));end;
end;
initialization
  InitializeArguments;
end.
