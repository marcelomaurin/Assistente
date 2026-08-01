unit frmconfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls, ExtCtrls, chatgpt;

type

  { TfrmConfig }

  TfrmConfig = class(TForm)
    pcConfig: TPageControl;
    tsIA: TTabSheet;
    tsVoz: TTabSheet;
    tsVisao: TTabSheet;
    tsBanco: TTabSheet;
    
    // Aba IA (Ordem: Provedor -> Modelo -> Token -> URL)
    lblProvider: TLabel;
    cbProvider: TComboBox;
    lblModel: TLabel;
    cbModel: TComboBox;
    lblToken: TLabel;
    edTokenGPT: TEdit;
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

    procedure cbProviderChange(Sender: TObject);
    procedure btSalvarClick(Sender: TObject);
    procedure btCancelarClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    procedure CarregaModelosDoProvedor;
  public

  end;

var
  frmConfigForm: TfrmConfig;

implementation

{$R *.lfm}

{ TfrmConfig }

procedure TfrmConfig.CarregaModelosDoProvedor;
var
  Prov: TAIProvider;
  ModeloAtual: string;
begin
  ModeloAtual := cbModel.Text;
  Prov := GetAIProviderFromIndex(cbProvider.ItemIndex);
  GetAIModelListForProvider(Prov, cbModel.Items);

  if cbModel.Items.IndexOf(ModeloAtual) >= 0 then
    cbModel.Text := ModeloAtual
  else if cbModel.Items.Count > 0 then
    cbModel.ItemIndex := 0;
end;

procedure TfrmConfig.cbProviderChange(Sender: TObject);
var
  Prov: TAIProvider;
begin
  Prov := GetAIProviderFromIndex(cbProvider.ItemIndex);
  CarregaModelosDoProvedor;
  edURL.Text := GetDefaultEndpointForProvider(Prov);
end;

procedure TfrmConfig.FormShow(Sender: TObject);
begin
  GetAIProviderList(cbProvider.Items);
  if (cbProvider.ItemIndex < 0) or (cbProvider.ItemIndex >= cbProvider.Items.Count) then
    cbProvider.ItemIndex := 0;
  CarregaModelosDoProvedor;
end;

procedure TfrmConfig.btSalvarClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TfrmConfig.btCancelarClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
