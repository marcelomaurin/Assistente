program voice_native_tests;
{$mode objfpc}{$H+}
uses SysUtils,Classes,Math,aispeechfilter,aicontinuouslistener;
type TReceiver=class
 Count:Integer;FileName:string;
 procedure Speech(Sender:TObject;const FilePath:string;Duration:Integer);
end;
procedure TReceiver.Speech(Sender:TObject;const FilePath:string;Duration:Integer);
begin Inc(Count);FileName:=FilePath;end;
procedure Check(B:Boolean;const Text:string);
begin if not B then raise Exception.Create(Text);end;
var Filter:TAISpeechFilter;Listener:TAIContinuousListener;Receiver:TReceiver;
 Input:array of SmallInt;Output:TBytes;I,N,C:Integer;Sum:Double;
function Gain(Frequency:Double):Double;
begin
 Filter.Configure(16000,1);SetLength(Input,16000);
 for I:=0 to High(Input) do Input[I]:=Round(10000*Sin(2*Pi*Frequency*I/16000));
 Filter.Filter(@Input[0],Length(Input),Output);Sum:=0;
 for I:=8000 to 15999 do Sum:=Sum+Sqr(PSmallInt(@Output[0])[I]);
 Result:=Sqrt(Sum/8000)/(10000/Sqrt(2));
end;
procedure Feed(Frequency,Amplitude:Double;Frames:Integer);
var F,J:Integer;
begin
 SetLength(Input,800*Listener.Channels);
 for F:=0 to Frames-1 do
 begin
  for J:=0 to High(Input) do Input[J]:=Round(Amplitude*Sin(2*Pi*Frequency*(J div Listener.Channels)/16000));
  Listener.FeedPCM(@Input[0],Length(Input));
 end;
end;
begin
 Filter:=TAISpeechFilter.Create;Listener:=TAIContinuousListener.Create(nil);Receiver:=TReceiver.Create;
 try
  Check(Gain(1000)>0.98,'Speech band attenuated');
  Check(Gain(20)<0.05,'Low-frequency rumble not rejected');
  Check(Gain(7900)<0.02,'High-frequency noise not rejected');
  Filter.Configure(16000,2);SetLength(Input,3200);
  for I:=0 to 1599 do begin Input[I*2]:=10000;Input[I*2+1]:=0;end;
  Filter.Filter(@Input[0],Length(Input),Output);
  for I:=0 to 1599 do Check(PSmallInt(@Output[0])[I*2+1]=0,'Stereo filter leaks channels');
  Listener.OnSpeechUtterance:=@Receiver.Speech;
  for C:=1 to 2 do
  begin
   Listener.Channels:=C;Listener.StartPCMInput;N:=Receiver.Count;
   Feed(1000,0,40);Check(Receiver.Count=N,'Silence submitted');
   Feed(20,8000,20);Feed(1000,0,20);Check(Receiver.Count=N,'Rumble submitted');
   Feed(1000,8000,1);Feed(1000,0,20);Check(Receiver.Count=N,'Short impulse submitted');
   Feed(1000,8000,4);Feed(1000,0,20);Check(Receiver.Count=N,'Short noise became speech through silence duration');
   Feed(1000,8000,10);Feed(1000,0,10);Check(Receiver.Count=N,'Utterance finalized before silence timeout');
   Feed(1000,0,12);Check(Receiver.Count=N+1,'Speech plus silence not finalized exactly once');
   Check(FileExists(Receiver.FileName),'No WAV created');DeleteFile(Receiver.FileName);
   Feed(1000,0,40);Check(Receiver.Count=N+1,'Silence resubmitted old utterance');Listener.StopListening;
  end;
  WriteLn('PASS: speech band, rumble/high-frequency attenuation, channel isolation, mono/stereo VAD, silence rejection, impulse rejection, min voiced duration, silence timeout, single WAV');
 finally Receiver.Free;Listener.Free;Filter.Free;end;
end.
