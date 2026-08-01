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
    lblToken: TLabel;
    edTokenGPT: TEdit;
    lblProvider: TLabel;
    cbProvider: TComboBox;
    lblModel: TLabel;
    edModel: TEdit;
    lblURL: TLabel;
    edURL: TEdit;
    lblFrase: TLabel;
    edFrase: TEdit;
    lblSynth: TLabel;
    edSynthIP: TEdit;
    edSynthPort: TEdit;
    lblRecog: TLabel;
    edRecogIP: TEdit;
    edRecogPort: TEdit;
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
