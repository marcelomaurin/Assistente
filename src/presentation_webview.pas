unit presentation_webview;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Windows, ActiveX, Classes, SysUtils, Forms, Controls, ExtCtrls, presentation_youtube;
type
  TPresentationWebView=class;
  TWebViewCallback=class(TInterfacedObject)
  protected Owner:TPresentationWebView;
  public constructor Create(AOwner:TPresentationWebView);
  end;
  TPresentationWebView=class
  private
    FHost:TWinControl;FEnvironment,FController,FWebView:IUnknown;
    FCallbacks:array of IUnknown;FCallbackObjects:TList;
    FFolder,FError,FPlayerError:string;FPlayerState:Integer;FReady,FFinished,FAppPaused:Boolean;
    function Handler(Kind:Integer):IUnknown;
    procedure Created(Kind:Integer;Code:HRESULT;Value:Pointer);
    procedure NativeEvent(Kind:Integer;Args:Pointer);
    procedure Fail(const Message:string;Code:HRESULT);
  public
    constructor Create(Host:TWinControl;const VideoID:string;StartSeconds:Integer;Muted:Boolean=False);
    destructor Destroy;override;
    procedure Resize;
    procedure SetPaused(Value:Boolean);
    procedure ExecuteScript(const Script:string);
    property PlayerState:Integer read FPlayerState;
    property PlayerError:string read FPlayerError;
    property Ready:Boolean read FReady;
    property Finished:Boolean read FFinished;
    property ErrorText:string read FError;
  end;
implementation
uses ComObj;
const
  PlayerHost='assistente.maurinsoft.com.br';
  PlayerURL=YouTubePlayerOrigin+'/player.html';
  IIDWebView3:TGUID='{A0D6DF20-3B92-416D-AA0C-437A9C727857}';
type
  IEnvironmentCreated=interface(IUnknown)
    ['{4E8A3389-C9D8-4BD2-B6B5-124FEE6CC14D}']
    function Invoke(Code:HRESULT;Value:Pointer):HRESULT;stdcall;
  end;
  IControllerCreated=interface(IUnknown)
    ['{6C4819F3-C9B7-4260-8127-C9F5BDE7F68C}']
    function Invoke(Code:HRESULT;Value:Pointer):HRESULT;stdcall;
  end;
  IWebMessage=interface(IUnknown)
    ['{57213F19-00E6-49FA-8E07-898EA01ECBD2}']
    function Invoke(Sender,Args:Pointer):HRESULT;stdcall;
  end;
  INavigation=interface(IUnknown)
    ['{9ADBE429-F36D-432B-9DDC-F8881FBD76E3}']
    function Invoke(Sender,Args:Pointer):HRESULT;stdcall;
  end;
  INewWindow=interface(IUnknown)
    ['{D4C185FE-C81C-4989-97AF-2D3FA7AB5651}']
    function Invoke(Sender,Args:Pointer):HRESULT;stdcall;
  end;
  IAccelerator=interface(IUnknown)
    ['{B29C7E28-FA79-41A8-8E44-65811C76DCB2}']
    function Invoke(Sender,Args:Pointer):HRESULT;stdcall;
  end;
  TCreatedHandler=class(TWebViewCallback,IEnvironmentCreated,IControllerCreated)
    Kind:Integer;
    function Invoke(Code:HRESULT;Value:Pointer):HRESULT;stdcall;
  end;
  TEventHandler=class(TWebViewCallback,IWebMessage,INavigation,INewWindow,IAccelerator)
    Kind:Integer;
    function Invoke(Sender,Args:Pointer):HRESULT;stdcall;
  end;
  TCreateEnvironment=function(BrowserFolder,UserData: PWideChar;Options,Completed:Pointer):HRESULT;stdcall;
  TCreateController=function(Self:Pointer;Parent:HWND;Completed:Pointer):HRESULT;stdcall;
  TGetObject=function(Self:Pointer;out Value:IUnknown):HRESULT;stdcall;
  TGetText=function(Self:Pointer;out Value:PWideChar):HRESULT;stdcall;
  TGetInteger=function(Self:Pointer;out Value:Integer):HRESULT;stdcall;
  TPutInteger=function(Self:Pointer;Value:Integer):HRESULT;stdcall;
  TPutBounds=function(Self:Pointer;Value:TRect):HRESULT;stdcall;
  TSimpleCall=function(Self:Pointer):HRESULT;stdcall;
  TNavigate=function(Self:Pointer;URL:PWideChar):HRESULT;stdcall;
  TExecuteScript=function(Self:Pointer;Script:PWideChar;Completed:Pointer):HRESULT;stdcall;
  TAddEvent=function(Self:Pointer;Handler:Pointer;out Token:Int64):HRESULT;stdcall;
  TMapFolder=function(Self:Pointer;Host,Folder:PWideChar;Access:Integer):HRESULT;stdcall;
var Loader:HMODULE=0;
// ABI slots and callback IIDs are from the pinned Microsoft WebView2 SDK.
// runtime/WebView2/1.0.4314.35/sdk-lock.json records its origin and hashes.
function Method(Obj:Pointer;Slot:Integer):Pointer;
begin Result:=PPointer(PtrUInt(PPointer(Obj)^)+PtrUInt(Slot)*SizeOf(Pointer))^;end;
procedure CloseController(Value:Pointer);
begin if Value<>nil then TSimpleCall(Method(Value,24))(Value);end;
constructor TWebViewCallback.Create(AOwner:TPresentationWebView);
begin inherited Create;Owner:=AOwner;end;
function TCreatedHandler.Invoke(Code:HRESULT;Value:Pointer):HRESULT;stdcall;
begin
  Result:=S_OK;
  if Owner=nil then begin if Kind=1 then CloseController(Value);Exit;end;
  try Owner.Created(Kind,Code,Value);except on E:Exception do Owner.Fail(E.Message,E_FAIL);end;
end;
function TEventHandler.Invoke(Sender,Args:Pointer):HRESULT;stdcall;
begin
  Result:=S_OK;if Owner=nil then Exit;
  try Owner.NativeEvent(Kind,Args);except on E:Exception do Owner.Fail(E.Message,E_FAIL);end;
end;
function TPresentationWebView.Handler(Kind:Integer):IUnknown;
var C:TCreatedHandler;E:TEventHandler;Base:TWebViewCallback;N:Integer;
begin
  if Kind<2 then begin
    C:=TCreatedHandler.Create(Self);C.Kind:=Kind;Base:=C;
    if Kind=0 then Result:=C as IEnvironmentCreated else Result:=C as IControllerCreated;
  end else begin
    E:=TEventHandler.Create(Self);E.Kind:=Kind;Base:=E;
    case Kind of 2:Result:=E as IWebMessage;3:Result:=E as INavigation;
      4:Result:=E as INewWindow;else Result:=E as IAccelerator;end;
  end;
  N:=Length(FCallbacks);SetLength(FCallbacks,N+1);FCallbacks[N]:=Result;FCallbackObjects.Add(Base);
end;
procedure TPresentationWebView.Fail(const Message:string;Code:HRESULT);
begin FError:=Message+' ('+IntToHex(LongWord(Code),8)+')';end;
constructor TPresentationWebView.Create(Host:TWinControl;const VideoID:string;StartSeconds:Integer;Muted:Boolean);
var CreateEnvironment:TCreateEnvironment;UserData,LibraryPath:UnicodeString;
  G:TGUID;Text:TStringList;H:IUnknown;R:HRESULT;Config:string;
begin
  inherited Create;FPlayerState:=-1;FHost:=Host;FCallbackObjects:=TList.Create;
  Config:=GetEnvironmentVariable('ASSISTENTE_CONFIG_DIR');
  if Config='' then Config:=IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA'))+'Assistente';
  CreateGUID(G);FFolder:=IncludeTrailingPathDelimiter(GetTempDir(False))+'assistente-youtube-'+GUIDToString(G);
  ForceDirectories(FFolder);Text:=TStringList.Create;
  try Text.Text:=YouTubePlayerHTML(VideoID,StartSeconds,Muted);Text.SaveToFile(FFolder+PathDelim+'player.html');finally Text.Free;end;
  LibraryPath:=UTF8Decode(ExtractFilePath(ParamStr(0))+'WebView2Loader.dll');
  if Loader=0 then Loader:=LoadLibraryW(PWideChar(LibraryPath));
  if Loader=0 then raise Exception.Create('WebView2Loader.dll ausente. Reinstale o Assistente atualizado.');
  Pointer(CreateEnvironment):=GetProcAddress(Loader,'CreateCoreWebView2EnvironmentWithOptions');
  if not Assigned(CreateEnvironment) then raise Exception.Create('Carregador WebView2 invalido');
  UserData:=UTF8Decode(IncludeTrailingPathDelimiter(Config)+'WebView2');ForceDirectories(UTF8Encode(UserData));
  H:=Handler(0);R:=CreateEnvironment(nil,PWideChar(UserData),nil,Pointer(H));
  if Failed(R) then raise Exception.Create('Nao foi possivel iniciar o player. Instale o Microsoft Edge WebView2 Runtime. Codigo '+IntToHex(LongWord(R),8));
end;
procedure TPresentationWebView.Created(Kind:Integer;Code:HRESULT;Value:Pointer);
var H,Web3:IUnknown;R:HRESULT;Token:Int64;Folder,HostName,URL:UnicodeString;
begin
  if Failed(Code) or (Value=nil) then begin Fail('Nao foi possivel iniciar o player WebView2',Code);Exit;end;
  if Kind=0 then begin
    FEnvironment:=IUnknown(Value);H:=Handler(1);
    R:=TCreateController(Method(Pointer(FEnvironment),3))(Pointer(FEnvironment),FHost.Handle,Pointer(H));
    if Failed(R) then Fail('Nao foi possivel criar a janela do player',R);
    Exit;
  end;
  FController:=IUnknown(Value);
  OleCheck(TGetObject(Method(Value,25))(Value,FWebView));
  OleCheck(FWebView.QueryInterface(IIDWebView3,Web3));
  Folder:=UTF8Decode(FFolder);HostName:=UTF8Decode(PlayerHost);URL:=UTF8Decode(PlayerURL);
  OleCheck(TMapFolder(Method(Pointer(Web3),71))(Pointer(Web3),PWideChar(HostName),PWideChar(Folder),0));
  H:=Handler(2);OleCheck(TAddEvent(Method(Pointer(FWebView),34))(Pointer(FWebView),Pointer(H),Token));
  H:=Handler(3);OleCheck(TAddEvent(Method(Pointer(FWebView),7))(Pointer(FWebView),Pointer(H),Token));
  H:=Handler(4);OleCheck(TAddEvent(Method(Pointer(FWebView),44))(Pointer(FWebView),Pointer(H),Token));
  H:=Handler(5);OleCheck(TAddEvent(Method(Pointer(FController),19))(Pointer(FController),Pointer(H),Token));
  Resize;OleCheck(TPutInteger(Method(Pointer(FController),4))(Pointer(FController),1));
  OleCheck(TNavigate(Method(Pointer(FWebView),5))(Pointer(FWebView),PWideChar(URL)));
end;
procedure TPresentationWebView.NativeEvent(Kind:Integer;Args:Pointer);
var A,B:PWideChar;S,Origin:string;Key,EventKind:Integer;Form:TCustomForm;
begin
  if Kind=4 then begin TPutInteger(Method(Args,6))(Args,1);Exit;end;
  if Kind=5 then begin
    OleCheck(TGetInteger(Method(Args,3))(Args,EventKind));
    OleCheck(TGetInteger(Method(Args,4))(Args,Key));
    if (EventKind in [0,2]) and ((Key=VK_ESCAPE) or ((Key=Ord('P')) and
      (GetKeyState(VK_CONTROL)>=0) and (GetKeyState(VK_MENU)>=0) and (GetKeyState(VK_SHIFT)>=0))) then begin
      TPutInteger(Method(Args,8))(Args,1);Form:=GetParentForm(FHost);
      if Form<>nil then PostMessage(Form.Handle,WM_KEYDOWN,Key,0);
    end;Exit;
  end;
  A:=nil;B:=nil;
  try
    OleCheck(TGetText(Method(Args,3))(Args,A));Origin:=UTF8Encode(UnicodeString(A));
    if Kind=3 then begin
      if (Origin<>PlayerURL) and (Origin<>'about:blank') then TPutInteger(Method(Args,8))(Args,1);
      Exit;
    end;
    if Origin<>PlayerURL then Exit;
    OleCheck(TGetText(Method(Args,5))(Args,B));S:=UTF8Encode(UnicodeString(B));
    if S='loaded' then begin FReady:=True;SetPaused(FAppPaused);end
    else if Copy(S,1,6)='state:' then TryStrToInt(Copy(S,7,MaxInt),FPlayerState)
    else if Copy(S,1,6)='error:' then FPlayerError:=Copy(S,7,MaxInt)
    else if S='done' then FFinished:=True
    else if Copy(S,1,13)='script-error:' then FError:=S;
  finally if A<>nil then CoTaskMemFree(A);if B<>nil then CoTaskMemFree(B);end;
end;
procedure TPresentationWebView.Resize;
var Bounds:TRect;
begin
  if (FController=nil) or (FHost=nil) then Exit;
  Bounds:=Rect(0,0,FHost.ClientWidth,FHost.ClientHeight);
  OleCheck(TPutBounds(Method(Pointer(FController),6))(Pointer(FController),Bounds));
end;
procedure TPresentationWebView.ExecuteScript(const Script:string);
var W:UnicodeString;
begin
  if FWebView=nil then Exit;W:=UTF8Decode('(()=>{try{'+Script+'}catch(e){window.chrome.webview.postMessage("script-error:"+e.message)}})()');
  OleCheck(TExecuteScript(Method(Pointer(FWebView),29))(Pointer(FWebView),PWideChar(W),nil));
end;
procedure TPresentationWebView.SetPaused(Value:Boolean);
begin
  FAppPaused:=Value;
  if FReady then if Value then ExecuteScript('setAppPaused(true)') else ExecuteScript('setAppPaused(false)');
end;
destructor TPresentationWebView.Destroy;
var I:Integer;
begin
  if FCallbackObjects<>nil then for I:=0 to FCallbackObjects.Count-1 do TWebViewCallback(FCallbackObjects[I]).Owner:=nil;
  CloseController(Pointer(FController));FWebView:=nil;FController:=nil;FEnvironment:=nil;
  SetLength(FCallbacks,0);FCallbackObjects.Free;
  if FFolder<>'' then begin SysUtils.DeleteFile(FFolder+PathDelim+'player.html');RemoveDir(FFolder);end;
  inherited Destroy;
end;
end.
