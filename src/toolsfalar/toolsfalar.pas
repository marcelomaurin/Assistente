unit toolsfalar;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics,
  Dialogs, StdCtrls, ExtCtrls, aiconn, aivoicesynthesizer;

type

  { TfrmToolsfalar }

  TfrmToolsfalar = class(TForm)
    btFalar: TButton;
    btConect: TButton;
    btDisconect: TButton;
    edIP: TEdit;
    edFalar: TEdit;
    edPort: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Shape1: TShape;
    procedure btConectClick(Sender: TObject);
    procedure btDisconectClick(Sender: TObject);
    procedure btFalarClick(Sender: TObject);
    procedure edPortChange(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FConn: TAIConnClient;
    FVoiceSynth: TAIVoiceSynthesizer;
    procedure ConnDataReceived(Sender: TObject; const AData: string);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Falar();
    procedure Conectar();
    procedure Disconectar();
    property VoiceSynth: TAIVoiceSynthesizer read FVoiceSynth;
  end;

var
  frmToolsfalar: TfrmToolsfalar;

implementation

{$R *.lfm}

constructor TfrmToolsfalar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConn := TAIConnClient.Create(Self);
  FConn.OnDataReceived := @ConnDataReceived;
  FVoiceSynth := TAIVoiceSynthesizer.Create(Self);
  FVoiceSynth.Engine := seSystemDefault;
end;

procedure TfrmToolsfalar.FormDestroy(Sender: TObject);
begin
end;

procedure TfrmToolsfalar.btConectClick(Sender: TObject);
begin
  Conectar();
end;

procedure TfrmToolsfalar.btDisconectClick(Sender: TObject);
begin
  Disconectar();
end;

procedure TfrmToolsfalar.btFalarClick(Sender: TObject);
begin
  Falar();
end;

procedure TfrmToolsfalar.edPortChange(Sender: TObject);
begin
end;

procedure TfrmToolsfalar.ConnDataReceived(Sender: TObject; const AData: string);
begin
end;

procedure TfrmToolsfalar.Falar();
var
  pergunta: string;
begin
  pergunta := edFalar.text;
  if (pergunta <> '') then
  begin
    FVoiceSynth.Say(pergunta);

    if FConn.Connected then
      FConn.SendText(pergunta);
  end;
end;

procedure TfrmToolsfalar.Conectar();
begin
  try
    FConn.Connect(edIP.text, StrToIntDef(edPort.text, 8096));
  except
  end;
end;

procedure TfrmToolsfalar.Disconectar();
begin
  FConn.Disconnect;
end;

end.
