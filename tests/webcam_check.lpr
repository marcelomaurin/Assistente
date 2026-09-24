program webcam_check;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Graphics, webcam_vision;
var F: TForm; C: TWebcamVision; L: TStringList; B: TBitmap;
begin
 Application.Initialize;
 F := TForm.Create(nil); C := TWebcamVision.Create(nil); L := TWebcamVision.Devices;
 try
   if L.Count = 1 then begin
     if not C.OpenDevice(L[0], F, nil) then raise Exception.Create(C.LastError);
     if not C.CaptureToBitmap(B) then raise Exception.Create(C.LastError);
     try WriteLn('RGB frame: ', B.Width, 'x', B.Height) finally B.Free end;
     C.StopCapture;
     if C.Active then raise Exception.Create('Capture failed to stop');
     WriteLn('Webcam capture and shutdown passed');
   end else WriteLn('Hardware test skipped: requires exactly one camera');
 finally L.Free; C.Free; F.Free end;
end.
