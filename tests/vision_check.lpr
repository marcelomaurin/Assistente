program vision_check;
{$mode objfpc}{$H+}
uses Interfaces, Forms, SysUtils, Classes, vision_types, webcam_vision, frmconfig;
var F: TfrmConfig; L, LKinect, LCam: TStringList;
procedure Check(B: Boolean; const S: string);
begin
  if not B then
  begin
    WriteLn('ASSERTION FAILED: ', S);
    raise Exception.Create(S);
  end;
end;
begin
 Application.Initialize;
 try
   L := TStringList.Create;
   try
     L.AddObject(TWebcamVision.DeviceLabel(0, 'USB Camera'), TObject(PtrInt(0)));
     L.AddObject(TWebcamVision.DeviceLabel(3, 'USB Camera'), TObject(PtrInt(3)));
     Check(TWebcamVision.ResolveDevice(L, '') = -1, 'multiple cameras require selection');
     Check(TWebcamVision.ResolveDevice(L, 'USB Camera') = -1, 'ambiguous legacy name');
     Check(TWebcamVision.ResolveDevice(L, '3 - USB Camera') = 1, 'select second identical camera');
     Check(PtrInt(L.Objects[TWebcamVision.ResolveDevice(L, '3 - USB Camera')]) = 3,
       'use actual driver index, not list position');
     L.Delete(0);
     Check(TWebcamVision.ResolveDevice(L, 'USB Camera') = 0, 'restore unique legacy name');
     Check(TWebcamVision.ResolveDevice(L, '') = 0, 'single camera automatic selection');
     Check(TWebcamVision.ResolveDevice(L, 'missing camera') = -1, 'do not silently replace saved camera');
   finally L.Free end;
   Check(ParseVisionSource('webcam') = vsWebcam, 'webcam source');
   Check(ParseVisionSource('both') = vsBoth, 'both source');
   Check(ParseVisionSource(VisionSourceName(vsBoth)) = vsBoth, 'both persistence roundtrip');
   Check(ParseVisionSource('invalid') = vsNone, 'invalid source');
   Check(VisionCapabilities(vsWebcam) = [vcRGB], 'webcam only RGB');
   Check(VisionCapabilities(vsNone) = [], 'disabled capabilities');
   Check(vcSkeleton in VisionCapabilities(vsKinect), 'Kinect skeleton');

   // Testa os 4 casos de hardware detectado vs selecionado
   LKinect := TStringList.Create;
   LCam := TStringList.Create;
   F := TfrmConfig.Create(nil);
   try
     F.edKinectMinDist.Text := '1.2';
     F.edKinectMaxDist.Text := '3.5';
     F.edKinectTargetLeft.Text := 'ECG';

     // Caso 1: Sem dispositivos (LKinect = [], LCam = [])
     LKinect.Clear;
     LCam.Clear;
     F.ApplyDeviceList(LKinect, LCam, 0, '', True, True);
     Check(not F.chkEnableKinect.Enabled, 'caso 1: kinect desabilitado');
     Check(not F.chkEnableKinect.Checked, 'caso 1: kinect desmarcado');
     Check(not F.cbKinectDevice.Enabled, 'caso 1: combo kinect desabilitado');
     Check(F.cbKinectDevice.ItemIndex = -1, 'caso 1: combo kinect itemindex -1');
     Check((F.cbKinectDevice.Items.Count > 0) and (F.cbKinectDevice.Items[0] = 'Nenhum Kinect detectado'), 'caso 1: texto nenhum kinect');
     Check(not F.chkEnableCamera.Enabled, 'caso 1: camera desabilitada');
     Check(not F.chkEnableCamera.Checked, 'caso 1: camera desmarcada');
     Check(not F.cbCameraDevice.Enabled, 'caso 1: combo camera desabilitado');
     Check(F.cbCameraDevice.ItemIndex = -1, 'caso 1: combo camera itemindex -1');
     Check((F.cbCameraDevice.Items.Count > 0) and (F.cbCameraDevice.Items[0] = 'Nenhuma câmera detectada'), 'caso 1: texto nenhuma camera');
     Check(F.SelectedVisionSource = vsNone, 'caso 1: SelectedVisionSource vsNone');
     Check(F.edKinectMinDist.Text = '1.2', 'caso 1: preserva valor de distancia');
     Check(not F.edKinectMinDist.Enabled, 'caso 1: campo distancia desabilitado visualmente');
     Check(Pos('Kinect: não detectado', F.lblVisionStatus.Caption) > 0, 'caso 1: status kinect');
     Check(Pos('Câmera: não detectada', F.lblVisionStatus.Caption) > 0, 'caso 1: status camera');

     // Caso 2: Apenas webcam (LKinect = [], LCam = [0 - Microsoft WDM Image Capture])
     LKinect.Clear;
     LCam.Clear;
     LCam.Add('0 - Microsoft WDM Image Capture');
     F.ApplyDeviceList(LKinect, LCam, 0, '', True, True);
     Check(not F.chkEnableKinect.Enabled, 'caso 2: kinect desabilitado');
     Check(not F.chkEnableKinect.Checked, 'caso 2: kinect desmarcado');
     Check(F.chkEnableCamera.Enabled, 'caso 2: camera habilitada');
     Check(F.chkEnableCamera.Checked, 'caso 2: camera marcada conforme preferencia');
     Check(F.cbCameraDevice.ItemIndex = 0, 'caso 2: camera unica selecionada');
     Check(F.cbCameraDevice.Enabled, 'caso 2: combo camera habilitado');
     Check(F.SelectedVisionSource = vsWebcam, 'caso 2: SelectedVisionSource vsWebcam');
     Check(F.edKinectMinDist.Text = '1.2', 'caso 2: preserva parametros kinect');
     Check(not F.edKinectMinDist.Enabled, 'caso 2: kinect desabilitado visualmente');
     Check(Pos('Kinect: não detectado', F.lblVisionStatus.Caption) > 0, 'caso 2: status kinect nao detectado');
     Check(Pos('Câmera: 0 - Microsoft WDM Image Capture', F.lblVisionStatus.Caption) > 0, 'caso 2: status camera com nome');

     // Caso 3: Apenas Kinect (LKinect = [0 - Xbox NUI Sensor], LCam = [])
     LKinect.Clear;
     LCam.Clear;
     LKinect.Add('0 - Xbox NUI Sensor');
     F.ApplyDeviceList(LKinect, LCam, 0, '', True, True);
     Check(F.chkEnableKinect.Enabled, 'caso 3: kinect habilitado');
     Check(F.chkEnableKinect.Checked, 'caso 3: kinect marcado');
     Check(F.cbKinectDevice.ItemIndex = 0, 'caso 3: kinect unico selecionado');
     Check(F.cbKinectDevice.Enabled, 'caso 3: combo kinect habilitado');
     Check(not F.chkEnableCamera.Enabled, 'caso 3: camera desabilitada');
     Check(not F.chkEnableCamera.Checked, 'caso 3: camera desmarcada');
     Check(F.SelectedVisionSource = vsKinect, 'caso 3: SelectedVisionSource vsKinect');
     Check(F.edKinectMinDist.Enabled, 'caso 3: distancia kinect habilitada');
     Check(Pos('Kinect: 0 - Xbox NUI Sensor', F.lblVisionStatus.Caption) > 0, 'caso 3: status kinect');
     Check(Pos('Câmera: não detectada', F.lblVisionStatus.Caption) > 0, 'caso 3: status camera');

     // Caso 4: Kinect + Webcam (LKinect = [0 - Xbox NUI Sensor], LCam = [0 - Microsoft WDM Image Capture])
     LKinect.Clear;
     LCam.Clear;
     LKinect.Add('0 - Xbox NUI Sensor');
     LCam.Add('0 - Microsoft WDM Image Capture');
     F.ApplyDeviceList(LKinect, LCam, 0, '', True, True);
     Check(F.chkEnableKinect.Enabled, 'caso 4: kinect habilitado');
     Check(F.chkEnableKinect.Checked, 'caso 4: kinect marcado');
     Check(F.chkEnableCamera.Enabled, 'caso 4: camera habilitada');
     Check(F.chkEnableCamera.Checked, 'caso 4: camera marcada');
     Check(F.SelectedVisionSource = vsBoth, 'caso 4: SelectedVisionSource vsBoth');
     Check(F.cbKinectDevice.Enabled and F.cbCameraDevice.Enabled, 'caso 4: ambos combos habilitados');
     Check(F.edKinectMinDist.Enabled, 'caso 4: opcoes kinect ativas');
     Check(Pos('Kinect: 0 - Xbox NUI Sensor', F.lblVisionStatus.Caption) > 0, 'caso 4: status kinect');
     Check(Pos('Câmera: 0 - Microsoft WDM Image Capture', F.lblVisionStatus.Caption) > 0, 'caso 4: status camera');

     // Desmarca kinect no caso 4 -> deve virar vsWebcam
     F.chkEnableKinect.Checked := False;
     F.VisionSourceChange(nil);
     Check(F.SelectedVisionSource = vsWebcam, 'caso 4: desmarcar kinect mantem webcam');
     Check(not F.edKinectMinDist.Enabled, 'caso 4: desmarcar kinect desabilita distancia visualmente');

     // Desmarca camera no caso 4 -> deve virar vsNone
     F.chkEnableCamera.Checked := False;
     F.VisionSourceChange(nil);
     Check(F.SelectedVisionSource = vsNone, 'caso 4: desmarcar ambos resulta vsNone');

     Check(F.tsVisao.Caption = 'Vídeo', 'video tab title');
     Check(F.FindComponent('edVerIP') = nil, 'no vision server');
   finally
     F.Free;
     LKinect.Free;
     LCam.Free;
   end;
   L := TWebcamVision.Devices;
   try WriteLn('VFW devices: ', L.Count) finally L.Free end;
   WriteLn('Vision checks passed');
 except
   on E: Exception do
   begin
     WriteLn('FATAL: ', E.Message);
     Halt(1);
   end;
 end;
end.
