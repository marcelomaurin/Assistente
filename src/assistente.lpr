program assistente;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, main, aibase, chatgpt, funcoes, setmain, frmconfig, aivoicesynthesizer, aivoicerecognizer, frmsplash;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(Tfrmmain, frmmain);

  // Exibe a tela de Splash estilizada por 5 segundos antes de exibir o assistente
  frmSplashForm := TfrmSplash.Create(nil);
  try
    frmSplashForm.ShowModal;
  finally
    frmSplashForm.Free;
  end;

  Application.Run;
end.
