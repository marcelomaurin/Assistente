program assistente;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, main, funcoes, setmain, frmconfig;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  try
    Application.CreateForm(Tfrmmain, frmmain);
    Application.Run;
  except
    on E: Exception do
    begin
      with TStringList.Create do
      try
        Add('Exception class: ' + E.ClassName);
        Add('Exception message: ' + E.Message);
        SaveToFile('crash.log');
      finally
        Free;
      end;
      raise;
    end;
  end;
end.
