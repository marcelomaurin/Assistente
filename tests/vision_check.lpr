program vision_check;
{$mode objfpc}{$H+}
uses Interfaces, Forms, SysUtils, Classes, vision_types, webcam_vision, frmconfig;
var F: TfrmConfig; L: TStringList;
procedure Check(B: Boolean; const S: string);
begin if not B then raise Exception.Create(S) end;
begin
 Application.Initialize;
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
 F := TfrmConfig.Create(nil);
 try
   F.edKinectMinDist.Text := '1.2';
   F.LoadVision(vsNone, 0, '');
   Check(not F.chkKinectSeated.Enabled, 'none disables seated');
   F.LoadVision(vsWebcam, 0, '');
   Check(not F.edKinectMinDist.Enabled, 'webcam disables distance');
   Check(not F.edKinectTargetLeft.Enabled, 'webcam disables pointing');
   Check(F.edKinectMinDist.Text = '1.2', 'preserves Kinect settings');
   F.LoadVision(vsKinect, 0, '');
   Check(F.edKinectMinDist.Enabled, 'Kinect enables distance');
   Check(F.SelectedVisionSource = vsKinect, 'Kinect only');
   F.LoadVision(vsBoth, 0, '');
   Check(F.SelectedVisionSource = vsBoth, 'both selected');
   Check(F.cbKinectDevice.Enabled and F.cbCameraDevice.Enabled, 'both selectors enabled');
   Check(F.edKinectMinDist.Enabled, 'Kinect options with both');
   F.chkEnableKinect.Checked := False;
   Check(F.SelectedVisionSource = vsWebcam, 'camera remains enabled');
   Check(not F.edKinectMinDist.Enabled, 'camera alone has no Kinect options');
   F.chkEnableCamera.Checked := False;
   Check(F.SelectedVisionSource = vsNone, 'disable both');
   Check(F.tsVisao.Caption = 'Vídeo', 'video tab title');
   Check(F.FindComponent('edVerIP') = nil, 'no vision server');
 finally F.Free end;
 L := TWebcamVision.Devices;
 try WriteLn('VFW devices: ', L.Count) finally L.Free end;
 WriteLn('Vision checks passed');
end.
