unit toolsver;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, lNetComponents, Forms, Controls, Graphics,
  Dialogs, StdCtrls, ExtCtrls, lNet;

type

  { TfrmToolsver }

  TfrmToolsver = class(TForm)
    btFalar: TButton;
    btConect: TButton;
    btDisconect: TButton;
    edIP: TEdit;
    edFalar: TEdit;
    edPort: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    LTCPComponent1: TLTCPComponent;
    Shape1: TShape;
    procedure btConectClick(Sender: TObject);
    procedure btDisconectClick(Sender: TObject);
    procedure btFalarClick(Sender: TObject);
    procedure edPortChange(Sender: TObject);
    procedure LTCPComponent1Connect(aSocket: TLSocket);
    procedure LTCPComponent1Disconnect(aSocket: TLSocket);
    procedure LTCPComponent1Error(const msg: string; aSocket: TLSocket);
    procedure LTCPComponent1Receive(aSocket: TLSocket);
  private
    { private declarations }
  public
    { public declarations }
    procedure Falar();
    procedure Conectar();
    procedure Disconectar();
  end;

var
  frmToolsver: TfrmToolsver;

implementation

{$R *.lfm}

{ TfrmMain }

procedure TfrmToolsver.btConectClick(Sender: TObject);
begin
  Conectar();
end;

procedure TfrmToolsver.btDisconectClick(Sender: TObject);
begin
  Disconectar();
end;

procedure TfrmToolsver.btFalarClick(Sender: TObject);
begin
  Falar();
end;

procedure TfrmToolsver.edPortChange(Sender: TObject);
begin

end;

procedure TfrmToolsver.LTCPComponent1Connect(aSocket: TLSocket);
begin
  //ShowMessage('Conectou!');
end;

procedure TfrmToolsver.LTCPComponent1Disconnect(aSocket: TLSocket);
begin
  //ShowMessage('Disconectou');
end;

procedure TfrmToolsver.LTCPComponent1Error(const msg: string; aSocket: TLSocket);
begin
  //ShowMessage('Erro ao conectar!');
end;

procedure TfrmToolsver.LTCPComponent1Receive(aSocket: TLSocket);
var
   info : String;
begin
  //ShowMessage('Recebeu a mensagem:');

  aSocket.GetMessage(info);
  //ShowMessage(info);
end;

procedure TfrmToolsver.Falar();
var
   pergunta: string;
begin
  pergunta := edFalar.text;
  if(pergunta<>'') then
  begin
     LTCPComponent1.SendMessage(edFalar.text,nil);
     //Disconectar();
  end;
end;

procedure TfrmToolsver.Conectar();
begin
  LTCPComponent1.Connect(edIP.text,strtoint(edPort.text));
end;

procedure TfrmToolsver.Disconectar();
begin
  LTCPComponent1.Disconnect(true);
end;

end.

