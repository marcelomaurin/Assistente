unit ToolsOuvir;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  strutils, aiconn, aivoicerecognizer;

type

  { TfrmToolsOuvir }

  TfrmToolsOuvir = class(TForm)
    btConect: TButton;
    btDisconect: TButton;
    edIP: TEdit;
    edPort: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Shape1: TShape;
    procedure btConectClick(Sender: TObject);
    procedure btDisconectClick(Sender: TObject);
    procedure Shape1ChangeBounds(Sender: TObject);
  private
    lastfrase : string;
    FConn: TAIConnClient;
    FVoiceRecog: TAIVoiceRecognizer;
    procedure ConnDataReceived(Sender: TObject; const AData: string);
    procedure VoiceRecognized(Sender: TObject; const AText: string);
  public
    frase : string;
    constructor Create(AOwner: TComponent); override;
    procedure Conectar();
    procedure Disconectar();
    procedure ProcessaTextoReconhecido(const ATexto: string);
    property VoiceRecog: TAIVoiceRecognizer read FVoiceRecog;
  end;

var
  frmToolsOuvir: TfrmToolsOuvir;

implementation

{$R *.lfm}

uses main;

constructor TfrmToolsOuvir.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConn := TAIConnClient.Create(Self);
  FConn.OnDataReceived := @ConnDataReceived;

  FVoiceRecog := TAIVoiceRecognizer.Create(Self);
  FVoiceRecog.Engine := vreOpenAIWhisper;
  FVoiceRecog.OnRecognized := @VoiceRecognized;
end;

procedure TfrmToolsOuvir.Shape1ChangeBounds(Sender: TObject);
begin
end;

procedure TfrmToolsOuvir.btConectClick(Sender: TObject);
begin
  Conectar();
end;

procedure TfrmToolsOuvir.btDisconectClick(Sender: TObject);
begin
  Disconectar();
end;

procedure TfrmToolsOuvir.VoiceRecognized(Sender: TObject; const AText: string);
begin
  ProcessaTextoReconhecido(AText);
end;

procedure TfrmToolsOuvir.ProcessaTextoReconhecido(const ATexto: string);
var
  info: string;
  posicao: integer;
begin
  info := ATexto;
  posicao := Pos(frase, info);
  if (posicao <> 0) or (frase = '') then
  begin
    if (lastfrase <> info) then
    begin
      lastfrase := info;
      if frase <> '' then
        info := ReplaceStr(info, frase, '');

      frmmain.NewContext();
      frmmain.pergunta := Trim(info);
      frmmain.FazPergunta();
    end;
  end;
end;

procedure TfrmToolsOuvir.ConnDataReceived(Sender: TObject; const AData: string);
begin
  ProcessaTextoReconhecido(AData);
end;

procedure TfrmToolsOuvir.Conectar();
begin
  try
    FConn.Connect(edIP.text, StrToIntDef(edPort.text, 8097));
  except
  end;
end;

procedure TfrmToolsOuvir.Disconectar();
begin
  FConn.Disconnect;
end;

end.
