unit presentation_media;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, ExtCtrls, Graphics, presentation_tags,
  presentation_paths, Windows, ActiveX, MMSystem, Variants, ComObj, FPReadPNG, FPReadJPEG;
type
  TPresentationMedia = class
  private
    FHost: TPanel; FImage: TImage;
    FSlideHandle: HWND; FOnVisualChange: TNotifyEvent; FVideo,FSound: Boolean;
    FPowerPoint,FDeck,FShow: OleVariant;
    FRoot,FActive,FActiveSound: string;
    FOwnPowerPoint,FComInitialized: Boolean;
    procedure Resize(Sender: TObject);
    procedure NotifyVisualChange;
    procedure EmbedSlides(Before: TList);
    procedure MCI(const Command: string);
    function QueryMCI(const Command: string): string;
    procedure GoToSlide(N: Integer);
    procedure CloseVisual;
    procedure StartTrack(const AliasName: string; const Tag: TPresentationTag);
    procedure PauseTrack(const AliasName: string; Value: Boolean);
  public
    constructor Create(const Root: string; Host: TPanel);
    destructor Destroy; override;
    procedure Execute(const Tag: TPresentationTag);
    procedure Close;
    procedure CloseSound;
    function CurrentSlide: Integer;
    function VideoPositionMS: Integer;
    function SoundPositionMS: Integer;
    function TimedPlaybackActive: Boolean;
    procedure SetPaused(Value: Boolean);
    property OnVisualChange: TNotifyEvent read FOnVisualChange write FOnVisualChange;
    property Active: string read FActive;
    property ActiveSound: string read FActiveSound;
  end;
implementation
constructor TPresentationMedia.Create(const Root: string; Host: TPanel);
begin
  inherited Create;
  if Host=nil then raise Exception.Create('Painel de midia obrigatorio');
  FComInitialized:=CoInitialize(nil)>=0;FRoot:=IncludeTrailingPathDelimiter(Root);FHost:=Host;
  FHost.OnResize:=@Resize;FHost.Color:=clBlack;
  FImage:=TImage.Create(nil);FImage.Parent:=FHost;FImage.Align:=alClient;
  FImage.Proportional:=True;FImage.Center:=True;FImage.Stretch:=True;
end;
destructor TPresentationMedia.Destroy;
begin
  Close;if FHost<>nil then FHost.OnResize:=nil;FImage.Free;
  if FComInitialized then CoUninitialize;inherited Destroy;
end;
procedure TPresentationMedia.NotifyVisualChange;
begin
  if FHost<>nil then FHost.Visible:=FActive<>'';
  if Assigned(FOnVisualChange) then FOnVisualChange(Self);
end;
function CollectSlideWindows(W: HWND; Data: LPARAM): BOOL; stdcall;
var Buffer: array[0..63] of Char;
begin
  Result:=True;
  if GetClassName(W,@Buffer,Length(Buffer))>0 then
    if StrPas(Buffer)='screenClass' then TList(Pointer(Data)).Add(Pointer(W));
end;
procedure TPresentationMedia.EmbedSlides(Before: TList);
var After: TList; I: Integer; W: HWND; Style,RemoveStyle: DWORD;
begin
  After:=TList.Create;
  try
    EnumWindows(@CollectSlideWindows,LPARAM(After));
    for I:=0 to After.Count-1 do begin
      W:=HWND(After[I]);
      if Before.IndexOf(Pointer(W))<0 then begin
        if FSlideHandle<>0 then raise Exception.Create('Janela de slides ambigua');
        FSlideHandle:=W;
      end;
    end;
    if FSlideHandle=0 then raise Exception.Create('Janela de slides nao localizada');
    ShowWindow(FSlideHandle,SW_HIDE);
    Style:=DWORD(GetWindowLong(FSlideHandle,GWL_STYLE));
    RemoveStyle:=DWORD(WS_POPUP) or DWORD(WS_CAPTION) or DWORD(WS_THICKFRAME) or DWORD(WS_SYSMENU);
    SetWindowLong(FSlideHandle,GWL_STYLE,
      LongInt((Style and (not RemoveStyle)) or DWORD(WS_CHILD)));
    Windows.SetParent(FSlideHandle,FHost.Handle);
    if Windows.GetParent(FSlideHandle)<>FHost.Handle then
      raise Exception.Create('Nao foi possivel incorporar os slides ao painel');
    EnableWindow(FSlideHandle,False);
    Resize(nil);
    SetWindowPos(FSlideHandle,0,0,0,FHost.ClientWidth,FHost.ClientHeight,
      SWP_NOZORDER or SWP_NOACTIVATE or SWP_FRAMECHANGED or SWP_SHOWWINDOW);
    if GetParentForm(FHost)<>nil then Windows.SetForegroundWindow(GetParentForm(FHost).Handle);
  finally After.Free;end;
end;
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
procedure TPresentationMedia.Resize(Sender: TObject);
begin
  if FVideo then MCI(Format('put pva_media window at 0 0 %d %d',[FHost.ClientWidth,FHost.ClientHeight]));
  if (FSlideHandle<>0) and IsWindow(FSlideHandle) then
    MoveWindow(FSlideHandle,0,0,FHost.ClientWidth,FHost.ClientHeight,True);
end;
procedure TPresentationMedia.CloseVisual;
begin
  if FVideo then begin mciSendStringW('close pva_media',nil,0,0);FVideo:=False;end;
  if not VarIsEmpty(FShow) then try FShow.View.Exit;except end;
  if not VarIsEmpty(FDeck) then try FDeck.Saved:=True;FDeck.Close;except end;
  FShow:=Unassigned;FDeck:=Unassigned;FSlideHandle:=0;
  if FOwnPowerPoint and not VarIsEmpty(FPowerPoint) then
    try if Integer(FPowerPoint.Presentations.Count)=0 then FPowerPoint.Quit;except end;
  FPowerPoint:=Unassigned;if FImage<>nil then FImage.Picture.Clear;FActive:='';NotifyVisualChange;
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
  FShow.View.GotoSlide(N);Resize(nil);
end;
procedure TPresentationMedia.Execute(const Tag: TPresentationTag);
var P,E,Stage,Device: string; Settings: OleVariant; N,PreviousSecurity: Integer; Before: TList;
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
          Settings:=FDeck.SlideShowSettings;Settings.ShowType:=1;Settings.AdvanceMode:=1;
          Before:=TList.Create;
          try
            EnumWindows(@CollectSlideWindows,LPARAM(Before));
            Stage:='Iniciar slides';FShow:=Settings.Run;
            Stage:='Incorporar slides';EmbedSlides(Before);GoToSlide(1);
          finally Before.Free;end;
        end else if TimedPresentationMedia(P) then begin
          FHost.Show;
          MCI('open "'+P+'" type mpegvideo alias pva_media parent '+IntToStr(FHost.Handle)+' style child');
          FVideo:=True;Resize(nil);StartTrack('pva_media',Tag);
        end else begin FImage.Picture.LoadFromFile(P);FHost.Show;end;
        FActive:=Tag.Argument;NotifyVisualChange;
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
