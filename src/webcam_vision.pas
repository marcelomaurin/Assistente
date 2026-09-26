unit webcam_vision;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Graphics, aicapturesource
  {$IFDEF MSWINDOWS}
  , aiwindowsvideopreview
  {$ENDIF}
  ;

type
  { TWebcamVision }

  TWebcamVision = class(TAICaptureSource)
  private
    FCaptureHost: TPanel;
    {$IFDEF MSWINDOWS}
    FDirectShowPreview: TAIWindowsVideoPreview;
    FDirectShowActive: Boolean;
    {$ENDIF}
    function GetIsActive: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure StopCapture;
    function CaptureToBitmap(out ABmp: Graphics.TBitmap): Boolean;

    class function DeviceLabel(Index: Integer; const ADisplayName: string): string;
    class function ResolveDevice(List: TStrings; const Saved: string): Integer;
    class function Devices: TStringList;

    function OpenDevice(const Device: string; Parent: TWinControl;
      Preview: TImage): Boolean;

    property Active: Boolean read GetIsActive;
  end;

implementation

uses
  {$IFDEF MSWINDOWS}
  Windows, aicamera_vfw
  {$ENDIF}
  ;

{$IFDEF MSWINDOWS}
function capGetDriverDescriptionW(Index: UINT; ADisplayName: PWideChar;
  NameSize: Integer; Version: PWideChar; VersionSize: Integer): BOOL;
  stdcall; external 'avicap32.dll';
{$ENDIF}

constructor TWebcamVision.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCaptureHost := nil;
  {$IFDEF MSWINDOWS}
  FDirectShowPreview := nil;
  FDirectShowActive := False;
  {$ENDIF}
end;

destructor TWebcamVision.Destroy;
begin
  StopCapture;
  {$IFDEF MSWINDOWS}
  if FDirectShowPreview <> nil then
  begin
    FDirectShowPreview.Stop;
    FreeAndNil(FDirectShowPreview);
  end;
  {$ENDIF}
  if FCaptureHost <> nil then
  begin
    FCaptureHost.Parent := nil;
    FreeAndNil(FCaptureHost);
  end;
  inherited Destroy;
end;

function TWebcamVision.GetIsActive: Boolean;
begin
  {$IFDEF MSWINDOWS}
  if FDirectShowActive then
  begin
    Result := True;
    Exit;
  end;
  {$ENDIF}
  Result := inherited Active;
end;

procedure TWebcamVision.StopCapture;
begin
  {$IFDEF MSWINDOWS}
  if FDirectShowPreview <> nil then
  begin
    FDirectShowPreview.Stop;
  end;
  FDirectShowActive := False;
  {$ENDIF}

  if FCaptureHost <> nil then
    FCaptureHost.Visible := False;

  if inherited Active then
    inherited StopCapture;
end;

function TWebcamVision.CaptureToBitmap(out ABmp: Graphics.TBitmap): Boolean;
{$IFDEF MSWINDOWS}
var
  DC: HDC;
  W, H: Integer;
{$ENDIF}
begin
  Result := False;
  ABmp := nil;

  {$IFDEF MSWINDOWS}
  if FDirectShowActive and (FCaptureHost <> nil) and (FCaptureHost.Handle <> 0) then
  begin
    try
      W := FCaptureHost.Width;
      H := FCaptureHost.Height;
      if W <= 1 then W := 640;
      if H <= 1 then H := 480;

      ABmp := Graphics.TBitmap.Create;
      ABmp.Width := W;
      ABmp.Height := H;
      DC := GetDC(FCaptureHost.Handle);
      if DC <> 0 then
      begin
        try
          BitBlt(ABmp.Canvas.Handle, 0, 0, W, H, DC, 0, 0, SRCCOPY);
          Result := True;
          Exit;
        finally
          ReleaseDC(FCaptureHost.Handle, DC);
        end;
      end;
    except
      on E: Exception do
      begin
        FreeAndNil(ABmp);
        SetError('Falha ao capturar frame DirectShow: ' + E.Message);
      end;
    end;
  end;
  {$ENDIF}

  Result := inherited CaptureToBitmap(ABmp);
end;

class function TWebcamVision.DeviceLabel(Index: Integer; const ADisplayName: string): string;
begin
  Result := IntToStr(Index) + ' - ' + ADisplayName;
end;

class function TWebcamVision.ResolveDevice(List: TStrings; const Saved: string): Integer;
var
  I, Matches, P: Integer;
  ADisplayName: string;
begin
  Result := -1;
  if (List = nil) or (List.Count = 0) then Exit;

  // 1. Procura match exato com o item completo (ex: "3 - USB Camera")
  Result := List.IndexOf(Saved);
  if Result >= 0 then Exit;

  // 2. Se Saved for vazio:
  if Trim(Saved) = '' then
  begin
    if List.Count = 1 then
      Result := 0
    else
      Result := -1; // multiple cameras require explicit selection
    Exit;
  end;

  // 3. Match por nome limpo (migração de nome legado sem índice, ex: "USB Camera")
  Matches := 0;
  for I := 0 to List.Count - 1 do
  begin
    P := Pos(' - ', List[I]);
    if P > 0 then
      ADisplayName := Copy(List[I], P + 3, MaxInt)
    else
      ADisplayName := List[I];

    if SameText(ADisplayName, Saved) or SameText(List[I], Saved) then
    begin
      Inc(Matches);
      Result := I;
    end;
  end;

  if Matches = 1 then Exit; // achou único match válido
  Result := -1; // ambíguo (>1) ou não encontrado
end;

class function TWebcamVision.Devices: TStringList;
{$IFDEF MSWINDOWS}
var
  DSPreview: TAIWindowsVideoPreview;
  DSDevs: TAIVideoDevices;
  I: Integer;
  N, V: array[0..255] of WideChar;
begin
  Result := TStringList.Create;

  // 1. Enumera os nomes reais das webcams conectadas via DirectShow (Windows 10/11)
  try
    DSPreview := TAIWindowsVideoPreview.Create;
    try
      DSDevs := DSPreview.ListDevices;
      for I := 0 to High(DSDevs) do
      begin
        Result.AddObject(DeviceLabel(I, DSDevs[I].Name), TObject(PtrInt(I)));
      end;
    finally
      DSPreview.Free;
    end;
  except
  end;

  // Se encontrou webcams reais (USB, integradas, virtuais), retorna
  if Result.Count > 0 then Exit;

  // 2. Fallback legado VFW caso DirectShow nao retorne nada
  for I := 0 to 9 do
  begin
    FillChar(N, SizeOf(N), 0);
    FillChar(V, SizeOf(V), 0);
    if capGetDriverDescriptionW(I, N, Length(N), V, Length(V)) then
      Result.AddObject(DeviceLabel(I, UTF8Encode(UnicodeString(PWideChar(@N[0])))), TObject(PtrInt(I)));
  end;
end;
{$ELSE}
begin
  Result := TStringList.Create;
end;
{$ENDIF}

function TWebcamVision.OpenDevice(const Device: string; Parent: TWinControl;
  Preview: TImage): Boolean;
var
  L: TStringList;
  I: Integer;
  {$IFDEF MSWINDOWS}
  DSDevs: TAIVideoDevices;
  DSMonikerID: string;
  W, H: Integer;
  {$ENDIF}
begin
  StopCapture;
  Result := False;
  L := Devices;
  try
    I := ResolveDevice(L, Device);
    if I < 0 then
    begin
      if (Trim(Device) = '') and (L.Count > 0) then
        I := 0
      else if (L.Count > 0) and (Pos('Microsoft WDM Image Capture', Device) > 0) then
        I := 0
      else
      begin
        SetError('Webcam selecionada nao encontrada. Atualize os dispositivos.');
        Exit;
      end;
    end;

    SourceKind := cskCameraLocal;
    CameraIndex := PtrInt(L.Objects[I]);
    DeviceName := L[I];

    {$IFDEF MSWINDOWS}
    // 1. Inicializa via DirectShow (compatível com todas as webcams USB modernas no Windows 10/11)
    try
      if FDirectShowPreview = nil then
        FDirectShowPreview := TAIWindowsVideoPreview.Create;

      DSDevs := FDirectShowPreview.ListDevices;
      if (CameraIndex >= 0) and (CameraIndex <= High(DSDevs)) then
        DSMonikerID := DSDevs[CameraIndex].ID
      else
        DSMonikerID := '';

      if DSMonikerID <> '' then
      begin
        if FCaptureHost = nil then
        begin
          FCaptureHost := TPanel.Create(Self);
          FCaptureHost.BevelOuter := bvNone;
          FCaptureHost.Color := clBlack;
          FCaptureHost.Caption := '';
        end;

        if Preview <> nil then
        begin
          FCaptureHost.Parent := Parent;
          FCaptureHost.SetBounds(Preview.Left, Preview.Top, Preview.Width, Preview.Height);
          FCaptureHost.Visible := True;
          FCaptureHost.BringToFront;
          W := Preview.Width;
          H := Preview.Height;
        end
        else
        begin
          FCaptureHost.Parent := Parent;
          FCaptureHost.SetBounds(0, 0, 1, 1);
          FCaptureHost.Visible := False;
          W := 640;
          H := 480;
        end;

        if (FCaptureHost.Parent <> nil) and (FCaptureHost.Handle <> 0) and
           FDirectShowPreview.Start(DSMonikerID, FCaptureHost.Handle, W, H) then
        begin
          FDirectShowActive := True;
          ClearError;
          Result := True;
          Exit;
        end;
      end;
    except
      on E: Exception do
        SetError('DirectShow: ' + E.Message);
    end;
    {$ENDIF}

    // 2. Fallback para TAICaptureSource (VFW legado)
    if Preview <> nil then
    begin
      if FCaptureHost = nil then
      begin
        FCaptureHost := TPanel.Create(Self);
        FCaptureHost.BevelOuter := bvNone;
        FCaptureHost.Color := clBlack;
        FCaptureHost.Caption := '';
      end;
      FCaptureHost.Parent := Parent;
      FCaptureHost.SetBounds(Preview.Left, Preview.Top, Preview.Width, Preview.Height);
      FCaptureHost.Visible := True;
      FCaptureHost.BringToFront;
      PreviewHandle := FCaptureHost.Handle;
      PreviewEnabled := True;
      Width := Preview.Width;
      Height := Preview.Height;
      PreviewImage := nil;
    end
    else
    begin
      if FCaptureHost <> nil then
        FCaptureHost.Visible := False;
      PreviewHandle := 0;
      PreviewEnabled := False;
      PreviewImage := nil;
    end;

    FPS := 15;
    Result := StartCapture;
  finally
    L.Free;
  end;
end;

end.
