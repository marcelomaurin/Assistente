program vision_check;
{$mode objfpc}{$H+}
uses Interfaces, Forms, SysUtils, Classes, vision_types, webcam_vision, frmconfig;
var F: TfrmConfig; L: TStringList;
procedure Check(B: Boolean; const S: string);
begin if not B then raise Exception.Create(S) end;
begin
 Application.Initialize;
 Check(ParseVisionSource('webcam') = vsWebcam, 'webcam source');
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
 finally F.Free end;
 L := TWebcamVision.Devices;
 try WriteLn('VFW devices: ', L.Count) finally L.Free end;
 WriteLn('Vision checks passed');
end.
