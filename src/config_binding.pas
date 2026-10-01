unit config_binding;
{$mode objfpc}{$H+}
interface
uses SysUtils, frmconfig, setmain;
procedure LoadSettings(F:TfrmConfig; C:TSetMain);
procedure SaveSettings(F:TfrmConfig; C:TSetMain);
implementation
procedure LoadSettings(F:TfrmConfig; C:TSetMain);
begin
  F.edTokenGPT.Text := C.CHATGPT;
  F.edURL.Text := C.ChatGPTURL;
  F.edJarvisURL.Text := C.JarvisURL;
  F.edJarvisKey.Text := C.JarvisAPIKey;
  F.edRecogLanguage.Text := C.RecogLanguage;
  F.edMyHost.Text := C.HostnameMy;
  F.edMyDb.Text := C.BancoMy;
  F.edMyUser.Text := C.UsernameMy;
  F.edMyPass.Text := C.PasswordMy;
  F.edPostHost.Text := C.HostnamePost;
  F.edPostDb.Text := C.BancoPOST;
  F.edPostUser.Text := C.UsernamePost;
  F.edPostPass.Text := C.PasswordPost;
  F.edPostSchema.Text := C.SchemaPost;
  F.chkAutoSpeak.Checked := C.AutoSpeak;
  F.chkMinimizeTray.Checked := C.MinimizeToTray;
  F.chkSynthAsync.Checked := C.SynthAsync;
  F.chkContinuousListening.Checked := C.ContinuousListening;
  F.chkKinectSeated.Checked := C.KinectSeatedMode;
  F.cbProvider.ItemIndex := C.ChatGPTProvider;
  F.cbSynthEngine.ItemIndex := C.SynthEngine;
  F.cbRecogEngine.ItemIndex := C.RecogEngine;
  F.tbSynthVolume.Position := C.SynthVolume;
  F.tbSynthRate.Position := C.SynthRate;
  F.CarregaModelosDoProvedor;
  F.cbModel.Text:=C.ChatGPTModel;
  F.CarregaVozesDoSintetizador;
  F.cbSynthModel.Text:=C.VoiceModel;
  if C.SynthEngine=3 then F.cbSynthVoice.Text:=C.VoiceRemoteVoice
  else F.cbSynthVoice.Text:=C.SynthVoice;
  F.cbAudioSampleRate.ItemIndex:=Ord(C.AudioSampleRate=44100);
  F.cbAudioChannels.ItemIndex:=Ord(C.AudioChannels=2);
  F.EnumerateAudioDevices(C.AudioDeviceIndex);
  if C.JarvisIAMode='local_only' then F.cbJarvisMode.ItemIndex:=1
  else if C.JarvisIAMode='cloud_only' then F.cbJarvisMode.ItemIndex:=2
  else F.cbJarvisMode.ItemIndex:=0;
  F.edKinectMinDist.Text:=FloatToStr(C.KinectMinDistance);
  F.edKinectMaxDist.Text:=FloatToStr(C.KinectMaxDistance);
  F.LoadVision(C.VisionSource,C.KinectDeviceIndex,C.CameraDevice);
end;
procedure SaveSettings(F:TfrmConfig; C:TSetMain);
begin
  C.CHATGPT := F.edTokenGPT.Text;
  C.ChatGPTURL := F.edURL.Text;
  C.JarvisURL := F.edJarvisURL.Text;
  C.JarvisAPIKey := F.edJarvisKey.Text;
  C.RecogLanguage := F.edRecogLanguage.Text;
  C.HostnameMy := F.edMyHost.Text;
  C.BancoMy := F.edMyDb.Text;
  C.UsernameMy := F.edMyUser.Text;
  C.PasswordMy := F.edMyPass.Text;
  C.HostnamePost := F.edPostHost.Text;
  C.BancoPOST := F.edPostDb.Text;
  C.UsernamePost := F.edPostUser.Text;
  C.PasswordPost := F.edPostPass.Text;
  C.SchemaPost := F.edPostSchema.Text;
  C.AutoSpeak := F.chkAutoSpeak.Checked;
  C.MinimizeToTray := F.chkMinimizeTray.Checked;
  C.SynthAsync := F.chkSynthAsync.Checked;
  C.ContinuousListening := F.chkContinuousListening.Checked;
  C.KinectSeatedMode := F.chkKinectSeated.Checked;
  C.ChatGPTProvider := F.cbProvider.ItemIndex;
  C.SynthEngine := F.cbSynthEngine.ItemIndex;
  C.RecogEngine := F.cbRecogEngine.ItemIndex;
  C.SynthVolume := F.tbSynthVolume.Position;
  C.SynthRate := F.tbSynthRate.Position;
  C.ChatGPTModel:=Trim(F.cbModel.Text);
  C.VoiceModel:=Trim(F.cbSynthModel.Text);
  if C.SynthEngine=3 then begin
    C.VoiceRemoteVoice:=F.cbSynthVoice.Text;
    if C.VoiceProvider=0 then C.VoiceProvider:=1;
  end else begin C.SynthVoice:=F.cbSynthVoice.Text;C.VoiceProvider:=0;end;
  if F.cbAudioSampleRate.ItemIndex=1 then C.AudioSampleRate:=44100 else C.AudioSampleRate:=16000;
  C.AudioChannels:=F.cbAudioChannels.ItemIndex+1;
  C.AudioDeviceIndex:=F.GetSelectedAudioDeviceIndex;
  C.AudioDeviceName:=F.GetSelectedAudioDeviceName;
  case F.cbJarvisMode.ItemIndex of
    1:C.JarvisIAMode:='local_only';2:C.JarvisIAMode:='cloud_only';
    else C.JarvisIAMode:='auto';end;
  C.VisionSource:=F.SelectedVisionSource;
  if F.cbKinectDevice.ItemIndex>=0 then C.KinectDeviceIndex:=F.cbKinectDevice.ItemIndex;
  if F.cbCameraDevice.ItemIndex>=0 then C.CameraDevice:=F.cbCameraDevice.Text;
  C.KinectMinDistance:=SafeParseFloat(F.edKinectMinDist.Text,C.KinectMinDistance);
  C.KinectMaxDistance:=SafeParseFloat(F.edKinectMaxDist.Text,C.KinectMaxDistance);
  C.SalvaContexto(False);
end;
end.
