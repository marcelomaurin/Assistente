unit presentation_media;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, ExtCtrls, Graphics, presentation_tags,
  Windows, ActiveX, MMSystem, Variants, ComObj, FPReadPNG, FPReadJPEG;
type
  TPresentationMedia = class
  private
    FWindow: TForm; FImage: TImage; FVideo: Boolean;
    FPowerPoint, FDeck, FShow: OleVariant;
    FRoot, FActive: string;
    FOwnPowerPoint: Boolean;
    procedure Resize(Sender: TObject);
    procedure WindowClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure MCI(const Command: string);
    procedure GoToSlide(N: Integer);
  public
    constructor Create(const Root: string);
    destructor Destroy; override;
    procedure Execute(const Tag: TPresentationTag);
    procedure Close;
    function CurrentSlide: Integer;
    procedure SetPaused(Value: Boolean);
    property Active: string read FActive;
  end;
implementation
constructor TPresentationMedia.Create(const Root: string);
begin
  inherited Create;CoInitialize(nil);FRoot:=IncludeTrailingPathDelimiter(Root);
  FWindow:=TForm.CreateNew(nil);FWindow.Caption:='Apresentacao';FWindow.SetBounds(80,80,960,600);
  FWindow.OnResize:=@Resize;FWindow.OnClose:=@WindowClose;FWindow.BorderStyle:=bsSizeable;
  FImage:=TImage.Create(FWindow);FImage.Parent:=FWindow;FImage.Align:=alClient;
  FImage.Proportional:=True;FImage.Center:=True;FWindow.Color:=clBlack;
end;
destructor TPresentationMedia.Destroy;
begin Close;FWindow.Free;CoUninitialize;inherited Destroy;end;
procedure TPresentationMedia.MCI(const Command: string);
var W: UnicodeString; R: MCIERROR; Buffer: array[0..255] of WideChar;
begin
  W:=UTF8Decode(Command);R:=mciSendStringW(PWideChar(W),nil,0,0);
  if R<>0 then begin
    mciGetErrorStringW(R,@Buffer,Length(Buffer));
    raise Exception.Create('Video: '+UTF8Encode(UnicodeString(PWideChar(@Buffer))));
  end;
end;
procedure TPresentationMedia.WindowClose(Sender: TObject; var CloseAction: TCloseAction);
begin Close;CloseAction:=caHide;end;
procedure TPresentationMedia.Resize(Sender: TObject);
begin
  if FVideo then MCI(Format('put pva_media window at 0 0 %d %d',[FWindow.ClientWidth,FWindow.ClientHeight]));

end;
procedure TPresentationMedia.Close;
begin
  if FVideo then begin mciSendStringW('close pva_media',nil,0,0);FVideo:=False;end;
  if not VarIsEmpty(FShow) then try FShow.View.Exit;except end;
  if not VarIsEmpty(FDeck) then try FDeck.Saved:=True;FDeck.Close;except end;
  FShow:=Unassigned;FDeck:=Unassigned;
  if FOwnPowerPoint and not VarIsEmpty(FPowerPoint) then
    try if Integer(FPowerPoint.Presentations.Count)=0 then FPowerPoint.Quit;except end;
  FPowerPoint:=Unassigned;FImage.Picture.Clear;FWindow.Hide;FActive:='';
end;
function TPresentationMedia.CurrentSlide: Integer;
begin
  if VarIsEmpty(FShow) then Result:=0 else Result:=FShow.View.CurrentShowPosition;
end;
procedure TPresentationMedia.GoToSlide(N: Integer);
begin
  if VarIsEmpty(FShow) then raise Exception.Create('Nenhuma apresentacao de slides aberta');
  if (N<1) or (N>Integer(FDeck.Slides.Count)) then raise Exception.Create('Slide fora dos limites');
  FShow.View.GotoSlide(N);
end;
procedure TPresentationMedia.Execute(const Tag: TPresentationTag);
var P,E,Stage: string; Settings: OleVariant; N,PreviousSecurity: Integer;
begin
  case Tag.Action of
    paCloseFile: Close;
    paOpenFile: begin
      P:=FRoot+StringReplace(Tag.Argument,'/',PathDelim,[rfReplaceAll]);
      if not FileExists(P) then raise Exception.Create('Midia ausente: '+Tag.Argument);
      Close;E:=LowerCase(ExtractFileExt(P));
      Stage:='Abrir midia';
      try
        if E='.pptx' then begin
          Stage:='Ativar PowerPoint';FOwnPowerPoint:=False;
          try FPowerPoint:=GetActiveOleObject('PowerPoint.Application');
          except FPowerPoint:=CreateOleObject('PowerPoint.Application');FOwnPowerPoint:=True;end;
          Stage:='Abrir PPTX';PreviousSecurity:=FPowerPoint.AutomationSecurity;
          FPowerPoint.AutomationSecurity:=3;
          try FDeck:=FPowerPoint.Presentations.Open(UTF8Decode(P),True,False,False);
          finally FPowerPoint.AutomationSecurity:=PreviousSecurity;end;
          Stage:='Configurar slides';
          Settings:=FDeck.SlideShowSettings;Settings.ShowType:=2;Settings.AdvanceMode:=1;
          Stage:='Iniciar slides';FShow:=Settings.Run;GoToSlide(1);
        end else if (E='.mp4') or (E='.avi') or (E='.wmv') then begin
          FWindow.Show;
          MCI('open "'+P+'" type mpegvideo alias pva_media parent '+IntToStr(FWindow.Handle)+' style child');
          FVideo:=True;Resize(nil);MCI('play pva_media');
        end else begin FImage.Picture.LoadFromFile(P);FWindow.Show;end;
        FActive:=Tag.Argument;
      except on Error: Exception do begin Close;raise Exception.Create(Stage+': '+Error.Message);end;end;
    end;
    paGoToSlide: GoToSlide(Tag.Slide);
    paNextSlide,paPreviousSlide: begin
      if VarIsEmpty(FShow) then raise Exception.Create('Nenhuma apresentacao de slides aberta');
      N:=FShow.View.CurrentShowPosition;
      if Tag.Action=paNextSlide then Inc(N) else Dec(N);
      GoToSlide(N);
    end;
  end;
end;
procedure TPresentationMedia.SetPaused(Value: Boolean);
begin
  if FVideo then if Value then MCI('pause pva_media') else MCI('resume pva_media');
  if not VarIsEmpty(FShow) then
    if Value then FShow.View.State:=3 else FShow.View.State:=1;
end;
end.
