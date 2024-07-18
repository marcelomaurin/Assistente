unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls,  GifAnim, toolsfalar, toolsouvir, chatgpt , toolsver, setmain;

type

  { Tfrmmain }

  Tfrmmain = class(TForm)
    btIniciar: TButton;
    edFrase: TEdit;
    edTokenGPT: TEdit;
    GifAnim1: TGifAnim;
    Label1: TLabel;
    Label2: TLabel;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    procedure btIniciarClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private

  public
    pergunta : string;
    procedure NewContext();
    procedure FazPergunta();
  end;

var
  frmmain: Tfrmmain;

implementation

{$R *.lfm}

{ Tfrmmain }

procedure Tfrmmain.FormCreate(Sender: TObject);
begin
   FSetMain := TSetMain.create();
   FSetMain.CarregaContexto();
   edTokenGPT.text := FSetMain.CHATGPT;
   frmToolsfalar := TfrmToolsfalar.Create(self);
   frmToolsOuvir := TfrmToolsOuvir.create(self);
   frmToolsVer := TfrmToolsver.create(self);
   chatgpt1 := TCHATGPT.create(self);
   chatgpt1.TOKEN:=edTokenGPT.text;

end;

procedure Tfrmmain.btIniciarClick(Sender: TObject);
begin
  FSetMain.CHATGPT := edTokenGPT.text;
  FSetMain.SalvaContexto(false);

  GifAnim1.visible:= true;
  GifAnim1.Animate:=true;
  frmToolsOuvir.frase := edFrase.text;
  frmToolsOuvir.Show();
  frmToolsOuvir.Conectar();

  frmToolsfalar.Show();
  frmToolsfalar.Conectar();
  frmToolsfalar.btConectClick(self);

  frmToolsver.show();
  frmToolsver.Conectar();
  frmToolsver.btConectClick(self);

  chatgpt1.TOKEN:=edTokenGPT.text;

end;

procedure Tfrmmain.NewContext();
begin
    pergunta := '';
end;

procedure Tfrmmain.FazPergunta();
begin
     if(CHATGPT1 = nil) then
     begin
         CHATGPT1 := TCHATGPT.create(self);
     end;
     CHATGPT1.token := edTokenGPT.text;

     if(pergunta <> '') then
     begin
       frmToolsfalar.edFalar.Text := 'Claro, deixa eu pesquisar sua pergunta , aguarde um momento  ';
       frmToolsfalar.Falar();
       chatgpt1.token := edTokenGPT.text;
       chatgpt1.SendQuestion(pergunta);
       frmToolsfalar.edFalar.Text := chatgpt1.Response;
       frmToolsfalar.Falar();
     end;
end;

end.

