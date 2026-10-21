unit professor_settings;
{$mode objfpc}{$H+}
interface
uses SysUtils, frmconfig, setmain;
procedure LoadProfessorSettings(F: TfrmConfig; C: TSetMain);
procedure SaveProfessorSettings(F: TfrmConfig; C: TSetMain);
implementation
procedure LoadProfessorSettings(F: TfrmConfig; C: TSetMain);
begin
  F.edAvatarModel.Text := C.Avatar3DModel;
  F.chkAvatarAutoIdle.Checked := C.Avatar3DAutoIdle;
  { These legacy options need phonemes / blend-shapes on the selected model.
    Do not present them as implemented by the generic animation adapter. }
  F.chkAvatarAutoBlink.Checked := C.Avatar3DAutoBlink;
  F.chkAvatarAutoBlink.Enabled := False;
  F.chkAvatarAutoBlink.Caption := 'Piscar: definido nos clipes do modelo';
  F.chkAvatarLipSync.Checked := C.Avatar3DLipSync;
  F.chkAvatarLipSync.Enabled := False;
  F.chkAvatarLipSync.Caption := 'Fala animada (sem sincronização por fonemas)';
  F.cbAvatarQuality.Enabled := False;
  F.cbProvider.ItemIndex := C.ChatGPTProvider;
  F.CarregaModelosDoProvedor;
  F.cbModel.Text := C.ChatGPTModel;
  F.edTokenGPT.Text := C.CHATGPT;
  F.edURL.Text := C.ChatGPTURL;
  F.edJarvisURL.Text := C.JarvisURL;
  F.edJarvisKey.Text := C.JarvisAPIKey;
  F.cbJarvisMode.Text := C.JarvisIAMode;
  F.chkMinimizeTray.Checked := C.MinimizeToTray;
  F.chkAutoSpeak.Checked := C.AutoSpeak;
  F.cbSynthEngine.ItemIndex := C.SynthEngine;
  F.cbSynthModel.Text := C.VoiceModel;
  F.CarregaVozesDoSintetizador;
  F.cbSynthVoice.Text := C.SynthVoice;
  F.tbSynthVolume.Position := C.SynthVolume;
  F.tbSynthRate.Position := C.SynthRate;
  F.chkSynthAsync.Checked := C.SynthAsync;
  F.cbRecogEngine.ItemIndex := C.RecogEngine;
  F.edRecogLanguage.Text := C.RecogLanguage;
  F.chkContinuousListening.Checked := C.ContinuousListening;
  F.EnumerateAudioDevices(C.AudioDeviceIndex);
  F.cbAudioSampleRate.Text := IntToStr(C.AudioSampleRate);
  F.cbAudioChannels.ItemIndex := C.AudioChannels - 1;
  F.LoadVision(C.VisionSource, C.KinectDeviceIndex, C.CameraDevice);
  F.chkKinectSeated.Checked := C.KinectSeatedMode;
  F.edKinectMinDist.Text := FloatToStr(C.KinectMinDistance);
  F.edKinectMaxDist.Text := FloatToStr(C.KinectMaxDistance);
  F.edMyHost.Text := C.HostnameMy;
  F.edMyDb.Text := C.BancoMy;
  F.edMyUser.Text := C.UsernameMy;
  F.edMyPass.Text := C.PasswordMy;
  F.edPostHost.Text := C.HostnamePost;
  F.edPostDb.Text := C.BancoPost;
  F.edPostUser.Text := C.UsernamePost;
  F.edPostPass.Text := C.PasswordPost;
  F.edPostSchema.Text := C.SchemaPost;
end;

procedure SaveProfessorSettings(F: TfrmConfig; C: TSetMain);
begin
  if (Trim(F.edAvatarModel.Text) <> '') and
    (Trim(F.edAvatarModel.Text) <> C.Avatar3DModel) then C.Avatar3DProfile := 'custom';
  C.Avatar3DModel := Trim(F.edAvatarModel.Text);
  C.Avatar3DAutoIdle := F.chkAvatarAutoIdle.Checked;
  if F.cbProvider.ItemIndex >= 0 then C.ChatGPTProvider := F.cbProvider.ItemIndex;
  C.ChatGPTModel := F.cbModel.Text;
  C.CHATGPT := F.edTokenGPT.Text;
  C.ChatGPTURL := F.edURL.Text;
  C.JarvisURL := F.edJarvisURL.Text;
  C.JarvisAPIKey := F.edJarvisKey.Text;
  C.JarvisIAMode := F.cbJarvisMode.Text;
  C.MinimizeToTray := F.chkMinimizeTray.Checked;
  C.AutoSpeak := F.chkAutoSpeak.Checked;
  if F.cbSynthEngine.ItemIndex >= 0 then C.SynthEngine := F.cbSynthEngine.ItemIndex;
  C.VoiceModel := F.cbSynthModel.Text;
  C.SynthVoice := F.cbSynthVoice.Text;
  C.SynthVolume := F.tbSynthVolume.Position;
  C.SynthRate := F.tbSynthRate.Position;
  C.SynthAsync := F.chkSynthAsync.Checked;
  if F.cbRecogEngine.ItemIndex >= 0 then C.RecogEngine := F.cbRecogEngine.ItemIndex;
  C.RecogLanguage := F.edRecogLanguage.Text;
  C.ContinuousListening := F.chkContinuousListening.Checked;
  C.AudioDeviceIndex := F.GetSelectedAudioDeviceIndex;
  C.AudioDeviceName := F.GetSelectedAudioDeviceName;
  C.AudioSampleRate := StrToIntDef(F.cbAudioSampleRate.Text, C.AudioSampleRate);
  if F.cbAudioChannels.ItemIndex >= 0 then C.AudioChannels := F.cbAudioChannels.ItemIndex + 1;
  C.VisionSource := F.SelectedVisionSource;
  if F.chkEnableKinect.Checked then C.KinectDeviceIndex := F.cbKinectDevice.ItemIndex;
  if F.chkEnableCamera.Checked then C.CameraDevice := F.cbCameraDevice.Text;
  C.KinectSeatedMode := F.chkKinectSeated.Checked;
  C.KinectMinDistance := StrToFloatDef(F.edKinectMinDist.Text, C.KinectMinDistance);
  C.KinectMaxDistance := StrToFloatDef(F.edKinectMaxDist.Text, C.KinectMaxDistance);
  C.HostnameMy := F.edMyHost.Text;
  C.BancoMy := F.edMyDb.Text;
  C.UsernameMy := F.edMyUser.Text;
  C.PasswordMy := F.edMyPass.Text;
  C.HostnamePost := F.edPostHost.Text;
  C.BancoPost := F.edPostDb.Text;
  C.UsernamePost := F.edPostUser.Text;
  C.PasswordPost := F.edPostPass.Text;
  C.SchemaPost := F.edPostSchema.Text;
end;
end.
