unit frmconfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls, ExtCtrls;

type

  { TfrmConfig }

  TfrmConfig = class(TForm)
    pcConfig: TPageControl;
    tsIA: TTabSheet;
    tsVoz: TTabSheet;
    tsVisao: TTabSheet;
    tsBanco: TTabSheet;
    
    // Aba IA
    lblToken: TLabel;
    edTokenGPT: TEdit;
    lblProvider: TLabel;
    cbProvider: TComboBox;
    lblModel: TLabel;
    edModel: TEdit;
    lblURL: TLabel;
    edURL: TEdit;
    
    // Aba Voz
    lblFrase: TLabel;
    edFrase: TEdit;
    lblSynth: TLabel;
    edSynthIP: TEdit;
    edSynthPort: TEdit;
    lblRecog: TLabel;
    edRecogIP: TEdit;
    edRecogPort: TEdit;

    // Aba Visão
    lblVer: TLabel;
    edVerIP: TEdit;
    edVerPort: TEdit;

    // Aba Banco de Dados
    lblMyTitle: TLabel;
    lblMyHost: TLabel;
    edMyHost: TEdit;
    lblMyDb: TLabel;
    edMyDb: TEdit;
    lblMyUser: TLabel;
    edMyUser: TEdit;
    lblMyPass: TLabel;
    edMyPass: TEdit;

    lblPostTitle: TLabel;
    lblPostHost: TLabel;
    edPostHost: TEdit;
    lblPostDb: TLabel;
    edPostDb: TEdit;
    lblPostUser: TLabel;
    edPostUser: TEdit;
    lblPostPass: TLabel;
    edPostPass: TEdit;
    lblPostSchema: TLabel;
    edPostSchema: TEdit;

    pnlButtons: TPanel;
    btSalvar: TButton;
    btCancelar: TButton;

    procedure btSalvarClick(Sender: TObject);
    procedure btCancelarClick(Sender: TObject);
  private

  public

  end;

var
  frmConfigForm: TfrmConfig;

implementation

{$R *.lfm}

{ TfrmConfig }

procedure TfrmConfig.btSalvarClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TfrmConfig.btCancelarClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
