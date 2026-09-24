unit webcam_vision;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Controls, ExtCtrls, aicapturesource;
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
uses Windows;
function capGetDriverDescriptionW(Index: UINT; ADisplayName: PWideChar;
  NameSize: Integer; Version: PWideChar; VersionSize: Integer): BOOL;
  stdcall; external 'avicap32.dll';
class function TWebcamVision.DeviceLabel(Index: Integer; const ADisplayName: string): string;
begin
  Result := IntToStr(Index) + ' - ' + ADisplayName;
end;

class function TWebcamVision.ResolveDevice(List: TStrings; const Saved: string): Integer;
var I, Matches, P: Integer; ADisplayName: string;
begin
  Result := List.IndexOf(Saved);
  if Result >= 0 then Exit;
  // Migrate configurations that stored only the name, if unambiguous.
  Matches := 0;
  if Saved <> '' then
    for I := 0 to List.Count - 1 do
    begin
      P := Pos(' - ', List[I]);
      ADisplayName := Copy(List[I], P + 3, MaxInt);
      if (P > 0) and SameText(ADisplayName, Saved) then
      begin
        Inc(Matches);
        Result := I;
      end;
    end;
  if Matches <> 1 then Result := -1;
  if (Result < 0) and (Saved = '') and (List.Count = 1) then Result := 0;
end;

class function TWebcamVision.Devices: TStringList;
var I: Integer; N, V: array[0..255] of WideChar;
begin
  Result := TStringList.Create;
  // Enumerate the SAME VFW driver indices used by the capture backend.
  // DirectShow enumeration order is not a VFW device identifier.
  for I := 0 to 9 do
  begin
    FillChar(N, SizeOf(N), 0); FillChar(V, SizeOf(V), 0);
    if capGetDriverDescriptionW(I, N, Length(N), V, Length(V)) then
      Result.AddObject(DeviceLabel(I, UTF8Encode(UnicodeString(PWideChar(@N[0])))), TObject(PtrInt(I)));
  end;
end;
function TWebcamVision.OpenDevice(const Device: string; Parent: TWinControl;
  Preview: TImage): Boolean;
var L: TStringList; I: Integer;
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
  finally L.Free end;
end;
end.
