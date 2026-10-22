; Build through scripts/build_installer.ps1. PackageDir contains only release files.
#ifndef PackageDir
  #error Use scripts/build_installer.ps1 to prepare the verified payload.
#endif
#ifndef RepositoryDir
  #error RepositoryDir is required.
#endif
#define MyAppName "Assistente"
#define MyAppVersion "0.120"
#define MyAppPublisher "MAURINSOFT"
#define MyAppExeName "assistente.exe"

[Setup]
AppId={{25A25326-C619-4F25-B473-8916AF42FCD1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion=0.120.0.0
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://maurinsoft.com.br
AppSupportURL=https://github.com/marcelomaurin/Assistente
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
AllowNoIcons=yes
OutputDir={#RepositoryDir}\bin
OutputBaseFilename=setup_assistente_0120
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
CreateUninstallRegKey=not VerificationMode
CloseApplications=no
RestartApplications=no
SetupIconFile={#RepositoryDir}\src\assistente.ico

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#PackageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Check: not VerificationMode
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon; Check: not VerificationMode

[Run]
Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent; Check: not VerificationMode

[Code]
function VerificationMode: Boolean;
begin
  { Test the actual installer in an isolated directory, without registering
    the test installation or creating shortcuts in the user's environment. }
  Result := ExpandConstant('{param:VERIFYINSTALL|0}') = '1';
end;
