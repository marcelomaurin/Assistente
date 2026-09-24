unit webcam_vision;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Controls, ExtCtrls, aicapturesource;
type
  TWebcamVision = class(TAICaptureSource)
  private
    FCaptureHost: TPanel;
  public
    class function Devices: TStringList;
    function OpenDevice(const Device: string; Parent: TWinControl;
      Preview: TImage): Boolean;
  end;
implementation
uses Windows;
function capGetDriverDescriptionW(Index: UINT; Name: PWideChar;
  NameSize: Integer; Version: PWideChar; VersionSize: Integer): BOOL;
  stdcall; external 'avicap32.dll';
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
      Result.AddObject(UTF8Encode(UnicodeString(PWideChar(@N[0]))), TObject(PtrInt(I)));
  end;
end;
function TWebcamVision.OpenDevice(const Device: string; Parent: TWinControl;
  Preview: TImage): Boolean;
var L: TStringList; I, J: Integer;
begin
  StopCapture;
  Result := False;
  L := Devices;
  try
    I := L.IndexOf(Device);
    if (I < 0) and (Device = '') and (L.Count = 1) then I := 0;
    if I < 0 then
    begin
      SetError('Webcam selecionada nao encontrada. Atualize os dispositivos.');
      Exit;
    end;
    for J := I + 1 to L.Count - 1 do
      if SameText(L[J], L[I]) then
      begin
        SetError('Drivers de camera com nomes identicos; selecao ambigua.');
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
