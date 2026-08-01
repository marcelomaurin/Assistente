unit frmsplash;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, GifAnim;

type

  { TfrmSplash }

  TfrmSplash = class(TForm)
    pnlMain: TPanel;
    GifAnimSplash: TGifAnim;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    lblVersion: TLabel;
    lblStatus: TLabel;
    pbProgress: TProgressBar;
    tmrSplash: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure tmrSplashTimer(Sender: TObject);
  private

  public

  end;

var
  frmSplashForm: TfrmSplash;

implementation

{$R *.lfm}

{ TfrmSplash }

procedure TfrmSplash.FormCreate(Sender: TObject);
begin
  lblTitle.Caption := 'Assistente Virtual AI';
  lblSubtitle.Caption := 'Agente Inteligente de Voz e Chat';
  lblVersion.Caption := 'Versão 1.0.0';
  lblStatus.Caption := 'Carregando componentes de IA...';

  pbProgress.Min := 0;
  pbProgress.Max := 100;
  pbProgress.Position := 0;

  tmrSplash.Interval := 50; // 50ms * 100 = 5000ms (5 segundos)
  tmrSplash.Enabled := False;
end;

procedure TfrmSplash.FormShow(Sender: TObject);
var
  GifFile: string;
begin
  GifFile := ExtractFilePath(ApplicationName) + 'img' + PathDelim + 'robo8.gif';
  if not FileExists(GifFile) then
    GifFile := ExtractFilePath(ExtractFileDir(ExtractFilePath(ApplicationName))) + 'img' + PathDelim + 'robo8.gif';
  if not FileExists(GifFile) then
    GifFile := ExtractFilePath(ApplicationName) + 'robo8.gif';

  if FileExists(GifFile) then
  begin
    try
      GifAnimSplash.FileName := GifFile;
      GifAnimSplash.Visible := True;
      GifAnimSplash.Animate := True;
    except
    end;
  end;

  tmrSplash.Enabled := True;
end;

procedure TfrmSplash.tmrSplashTimer(Sender: TObject);
begin
  pbProgress.Position := pbProgress.Position + 1;

  case pbProgress.Position of
    1..25:  lblStatus.Caption := 'Carregando modelos e motores de IA...';
    26..50: lblStatus.Caption := 'Inicializando síntese e reconhecimento de voz...';
    51..75: lblStatus.Caption := 'Carregando preferências e configurações...';
    76..99: lblStatus.Caption := 'Iniciando interface do Assistente...';
  end;

  if pbProgress.Position >= 100 then
  begin
    tmrSplash.Enabled := False;
    ModalResult := mrOk;
  end;
end;

end.
