unit webcam_vision;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, aicapturesource;

type
  TWebcamVision = class(TAICaptureSource)
  private
    FCaptureHost: TPanel;
  public
    class function DeviceLabel(Index: Integer; const ADisplayName: string): string;
    class function ResolveDevice(List: TStrings; const Saved: string): Integer;
    class function Devices: TStringList;
    function OpenDevice(const Device: string; Parent: TWinControl;
      Preview: TImage): Boolean;
  end;

implementation

uses
  Windows, aicamera_vfw;

function capGetDriverDescriptionW(Index: UINT; ADisplayName: PWideChar;
  NameSize: Integer; Version: PWideChar; VersionSize: Integer): BOOL;
  stdcall; external 'avicap32.dll';

class function TWebcamVision.DeviceLabel(Index: Integer; const ADisplayName: string): string;
begin
  Result := IntToStr(Index) + ' - ' + ADisplayName;
end;

class function TWebcamVision.ResolveDevice(List: TStrings; const Saved: string): Integer;
var
  I, Matches, P: Integer;
  ADisplayName: string;
begin
  Result := List.IndexOf(Saved);
  if Result >= 0 then Exit;

  // Migra configurações que salvaram apenas o nome, se não houver ambiguidade
  Matches := 0;
  if Saved <> '' then
  begin
    for I := 0 to List.Count - 1 do
    begin
      P := Pos(' - ', List[I]);
      ADisplayName := Copy(List[I], P + 3, MaxInt);
      if (P > 0) and (SameText(ADisplayName, Saved) or SameText(List[I], Saved)) then
      begin
        Inc(Matches);
        Result := I;
      end;
    end;
    if Matches <> 1 then
      Result := -1;
  end;

  // Caso especial: se configurado apenas 1 dispositivo e Saved vazio
  if (Result < 0) and (Saved = '') and (List.Count = 1) then
    Result := 0
  // Migração transparente do rótulo genérico anterior (Microsoft WDM Image Capture)
  else if (Result < 0) and (Pos('Microsoft WDM', Saved) > 0) and (List.Count > 0) then
    Result := 0;
end;

class function TWebcamVision.Devices: TStringList;
var
  CamBackend: TAICameraVFWBackend;
  DSList: TStringList;
  I: Integer;
  N, V: array[0..255] of WideChar;
begin
  Result := TStringList.Create;

  // 1. Enumera os nomes reais das webcams conectadas via DirectShow
  try
    CamBackend := TAICameraVFWBackend.Create;
    try
      DSList := CamBackend.ListCameras(10);
      try
        for I := 0 to DSList.Count - 1 do
          Result.AddObject(DSList[I], TObject(PtrInt(I)));
      finally
        DSList.Free;
      end;
    finally
      CamBackend.Free;
    end;
  except
  end;

  // Se encontrou webcams reais (USB, integradas, virtuais), retorna
  if Result.Count > 0 then Exit;

  // 2. Fallback legado VFW caso DirectShow não retorne nada
  for I := 0 to 9 do
  begin
    FillChar(N, SizeOf(N), 0);
    FillChar(V, SizeOf(V), 0);
    if capGetDriverDescriptionW(I, N, Length(N), V, Length(V)) then
      Result.AddObject(DeviceLabel(I, UTF8Encode(UnicodeString(PWideChar(@N[0])))), TObject(PtrInt(I)));
  end;
end;

function TWebcamVision.OpenDevice(const Device: string; Parent: TWinControl;
  Preview: TImage): Boolean;
var
  L: TStringList;
  I: Integer;
begin
  StopCapture;
  Result := False;
  L := Devices;
  try
    I := ResolveDevice(L, Device);
    if I < 0 then
    begin
      SetError('Webcam selecionada nao encontrada. Atualize os dispositivos.');
      Exit;
    end;
    SourceKind := cskCameraLocal;
    CameraIndex := PtrInt(L.Objects[I]);
    DeviceName := L[I];
    if FCaptureHost = nil then
    begin
      FCaptureHost := TPanel.Create(Self);
      FCaptureHost.Visible := False;
    end;
    FCaptureHost.Parent := Parent;
    PreviewHandle := FCaptureHost.Handle;
    PreviewEnabled := False;
    PreviewImage := Preview;
    FPS := 10;
    Result := StartCapture;
    if Result and not QueryFrame then
    begin
      StopCapture;
      Result := False;
    end;
  finally
    L.Free;
  end;
end;

end.
