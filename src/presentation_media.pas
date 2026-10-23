unit presentation_media;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, ExtCtrls, Graphics, presentation_tags,
  presentation_paths, Windows, ActiveX, MMSystem, Variants, ComObj, FPReadPNG, FPReadJPEG;
type
  TPresentationMedia = class
  private
    FWindow: TForm; FImage: TImage; FVideo,FSound: Boolean;
    FPowerPoint,FDeck,FShow: OleVariant;
    FRoot,FActive,FActiveSound: string;
    FOwnPowerPoint: Boolean;
    procedure Resize(Sender: TObject);
    procedure WindowClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure MCI(const Command: string);
    function QueryMCI(const Command: string): string;
    procedure GoToSlide(N: Integer);
    procedure CloseVisual;
    procedure StartTrack(const AliasName: string; const Tag: TPresentationTag);
    procedure PauseTrack(const AliasName: string; Value: Boolean);
  public
    constructor Create(const Root: string);
    destructor Destroy; override;
    procedure Execute(const Tag: TPresentationTag);
    procedure Close;
    procedure CloseSound;
    function CurrentSlide: Integer;
    function VideoPositionMS: Integer;
    function SoundPositionMS: Integer;
    function TimedPlaybackActive: Boolean;
    procedure SetPaused(Value: Boolean);
    property Active: string read FActive;
    property ActiveSound: string read FActiveSound;
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
function TPresentationMedia.QueryMCI(const Command: string): string;
var W: UnicodeString; R: MCIERROR; Buffer: array[0..255] of WideChar;
begin
  FillChar(Buffer,SizeOf(Buffer),0);W:=UTF8Decode(Command);
  R:=mciSendStringW(PWideChar(W),@Buffer,Length(Buffer),0);
  if R<>0 then begin
    mciGetErrorStringW(R,@Buffer,Length(Buffer));
    raise Exception.Create('Midia: '+UTF8Encode(UnicodeString(PWideChar(@Buffer))));
  end;
  Result:=UTF8Encode(UnicodeString(PWideChar(@Buffer)));
end;
procedure TPresentationMedia.MCI(const Command: string);
begin QueryMCI(Command);end;
procedure TPresentationMedia.WindowClose(Sender: TObject; var CloseAction: TCloseAction);
begin CloseVisual;CloseAction:=caHide;end;
procedure TPresentationMedia.Resize(Sender: TObject);
begin
  if FVideo then MCI(Format('put pva_media window at 0 0 %d %d',[FWindow.ClientWidth,FWindow.ClientHeight]));
end;
procedure TPresentationMedia.CloseVisual;
begin
  if FVideo then begin mciSendStringW('close pva_media',nil,0,0);FVideo:=False;end;
  if not VarIsEmpty(FShow) then try FShow.View.Exit;except end;
  if not VarIsEmpty(FDeck) then try FDeck.Saved:=True;FDeck.Close;except end;
  FShow:=Unassigned;FDeck:=Unassigned;
  if FOwnPowerPoint and not VarIsEmpty(FPowerPoint) then
    try if Integer(FPowerPoint.Presentations.Count)=0 then FPowerPoint.Quit;except end;
  FPowerPoint:=Unassigned;FImage.Picture.Clear;FWindow.Hide;FActive:='';
end;
procedure TPresentationMedia.CloseSound;
begin
  if FSound then mciSendStringW('close pva_sound',nil,0,0);
  FSound:=False;FActiveSound:='';
end;
procedure TPresentationMedia.Close;
begin CloseSound;CloseVisual;end;
function TPresentationMedia.CurrentSlide: Integer;
begin if VarIsEmpty(FShow) then Result:=0 else Result:=FShow.View.CurrentShowPosition;end;
function TPresentationMedia.VideoPositionMS: Integer;
begin if FVideo then Result:=StrToInt(QueryMCI('status pva_media position')) else Result:=0;end;
function TPresentationMedia.SoundPositionMS: Integer;
begin if FSound then Result:=StrToInt(QueryMCI('status pva_sound position')) else Result:=0;end;
function TPresentationMedia.TimedPlaybackActive: Boolean;
var Mode: string;
begin
  Result:=False;
  if FVideo then begin Mode:=QueryMCI('status pva_media mode');Result:=(Mode='playing') or (Mode='paused');end;
  if FSound then begin Mode:=QueryMCI('status pva_sound mode');Result:=Result or (Mode='playing') or (Mode='paused');end;
end;
procedure TPresentationMedia.StartTrack(const AliasName: string; const Tag: TPresentationTag);
var Duration: Integer;
begin
  MCI('set '+AliasName+' time format milliseconds');
  if Tag.HasStart then begin
    Duration:=StrToInt(QueryMCI('status '+AliasName+' length'));
    if Tag.StartMS>=Duration then raise Exception.Create('Inicio fora da duracao: '+Tag.Argument);
    MCI('seek '+AliasName+' to '+IntToStr(Tag.StartMS));
  end;
  MCI('play '+AliasName);
end;
procedure TPresentationMedia.GoToSlide(N: Integer);
begin
  if VarIsEmpty(FShow) then raise Exception.Create('Nenhuma apresentacao de slides aberta');
  if (N<1) or (N>Integer(FDeck.Slides.Count)) then raise Exception.Create('Slide fora dos limites');
  FShow.View.GotoSlide(N);
end;
procedure TPresentationMedia.Execute(const Tag: TPresentationTag);
var P,E,Stage,Device: string; Settings: OleVariant; N,PreviousSecurity: Integer;
begin
  case Tag.Action of
    paCloseFile: Close;
    paCloseSound: CloseSound;
    paOpenFile: begin
      P:=FRoot+StringReplace(Tag.Argument,'/',PathDelim,[rfReplaceAll]);
      if not FileExists(P) then raise Exception.Create('Midia ausente: '+Tag.Argument);
      E:=LowerCase(ExtractFileExt(P));
      if AudioPresentationMedia(P) then begin
        CloseSound;
        try
          if E='.wav' then Device:='waveaudio' else Device:='mpegvideo';
          MCI('open "'+P+'" type '+Device+' alias pva_sound');
          FSound:=True;StartTrack('pva_sound',Tag);FActiveSound:=Tag.Argument;
        except CloseSound;raise;end;
        Exit;
      end;
      CloseVisual;Stage:='Abrir midia';
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
        end else if TimedPresentationMedia(P) then begin
          FWindow.Show;
          MCI('open "'+P+'" type mpegvideo alias pva_media parent '+IntToStr(FWindow.Handle)+' style child');
          FVideo:=True;Resize(nil);StartTrack('pva_media',Tag);
        end else begin FImage.Picture.LoadFromFile(P);FWindow.Show;end;
        FActive:=Tag.Argument;
      except on Error: Exception do begin CloseVisual;raise Exception.Create(Stage+': '+Error.Message);end;end;
    end;
    paGoToSlide: GoToSlide(Tag.Slide);
    paNextSlide,paPreviousSlide: begin
      N:=CurrentSlide;if N=0 then raise Exception.Create('Nenhuma apresentacao de slides aberta');
      if Tag.Action=paNextSlide then Inc(N) else Dec(N);GoToSlide(N);
    end;
  end;
end;
procedure TPresentationMedia.PauseTrack(const AliasName: string; Value: Boolean);
var Mode: string;
begin
  Mode:=QueryMCI('status '+AliasName+' mode');
  if Value and (Mode='playing') then MCI('pause '+AliasName)
  else if not Value and (Mode='paused') then MCI('resume '+AliasName);
end;
procedure TPresentationMedia.SetPaused(Value: Boolean);
begin
  if FVideo then PauseTrack('pva_media',Value);
  if FSound then PauseTrack('pva_sound',Value);
  if not VarIsEmpty(FShow) then if Value then FShow.View.State:=3 else FShow.View.State:=1;
end;
end.
