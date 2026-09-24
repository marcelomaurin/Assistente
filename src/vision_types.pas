unit vision_types;
{$mode objfpc}{$H+}
interface
uses SysUtils;
type
  TVisionSource = (vsNone, vsKinect, vsWebcam);
  TVisionState = (vstSelected, vstDetected, vstInitialized, vstError);
  TVisionCapability = (vcRGB, vcDepth, vcSkeleton, vcGesture,
    vcPersonTracking, vcDistance, vcPointing);
  TVisionCapabilities = set of TVisionCapability;
function VisionSourceName(Source: TVisionSource): string;
function ParseVisionSource(const Value: string): TVisionSource;
function VisionCapabilities(Source: TVisionSource): TVisionCapabilities;
implementation
function VisionSourceName(Source: TVisionSource): string;
begin
  case Source of
    vsKinect: Result := 'kinect';
    vsWebcam: Result := 'webcam';
    else Result := 'none';
  end;
end;
function ParseVisionSource(const Value: string): TVisionSource;
begin
  if SameText(Value, 'kinect') then Result := vsKinect
  else if SameText(Value, 'webcam') then Result := vsWebcam
  else Result := vsNone;
end;
function VisionCapabilities(Source: TVisionSource): TVisionCapabilities;
begin
  case Source of
    vsKinect: Result := [vcRGB, vcDepth, vcSkeleton, vcGesture,
      vcPersonTracking, vcDistance, vcPointing];
    vsWebcam: Result := [vcRGB];
    else Result := [];
  end;
end;
end.
