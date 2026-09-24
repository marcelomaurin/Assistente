unit webcam_vision;



{$mode objfpc}{$H+}



interface



uses

  Classes, SysUtils, Controls, ExtCtrls, Graphics, aicapturesource;



type

  TWebcamVision = class(TAICaptureSource)

  private

    FCaptureHost: TPanel;

  public

    destructor Destroy; override;

    procedure StopCapture;

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



destructor TWebcamVision.Destroy;

begin

  StopCapture;

  if FCaptureHost <> nil then

  begin

    FCaptureHost.Parent := nil;

    FreeAndNil(FCaptureHost);

  end;

  inherited Destroy;

end;



procedure TWebcamVision.StopCapture;

begin

  inherited StopCapture;

  if FCaptureHost <> nil then

    FCaptureHost.Visible := False;

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



  Result := List.IndexOf(Saved);

  if Result >= 0 then Exit;



  // Migra configuracoes que salvaram apenas o nome, se nao houver ambiguidade

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

    if Matches = 1 then Exit;

  end;



  // Se nao encontrou por nome exato, mas ha cameras disponiveis, seleciona a primeira (0)

  if (Result < 0) and (List.Count > 0) then

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



  // 2. Fallback legado VFW caso DirectShow nao retorne nada

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

      PreviewImage := nil; // O preview nativo do VFW desenha diretamente no painel sem captura GDI

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

