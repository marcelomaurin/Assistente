; Build through scripts/build_installer.ps1. PackageDir contains only release files.
#ifndef PackageDir
  #error Use scripts/build_installer.ps1 to prepare the verified payload.
#endif
#ifndef RepositoryDir
  #error RepositoryDir is required.
#endif
#define MyAppName "Assistente"
#ifndef MyAppVersion
  #define MyAppVersion "0.210"
#endif
#ifndef SetupCode
  #define SetupCode "0210"
#endif
#define MyAppPublisher "MAURINSOFT"
#define MyAppExeName "assistente.exe"

[Setup]
AppId={code:SetupApplicationId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}.0.0
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://maurinsoft.com.br
AppSupportURL=https://github.com/marcelomaurin/Assistente
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
UsePreviousLanguage=no
AllowNoIcons=yes
OutputDir={#RepositoryDir}\bin
OutputBaseFilename=setup_assistente_{#SetupCode}
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

Name: "editordesktopicon"; Description: "Criar atalho do Editor de Apresentacoes na area de trabalho"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#PackageDir}\*"; DestDir: "{app}"; Excludes: "AVATARES\movimentos.json"; Flags: ignoreversion recursesubdirs createallsubdirs
; The shared catalog is editable user configuration: preserve custom movements.
Source: "{#PackageDir}\AVATARES\movimentos.json"; DestDir: "{app}\AVATARES"; Flags: ignoreversion uninsneveruninstall; Check: UpdateMovementCatalog

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Check: not VerificationMode
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon; Check: not VerificationMode

Name: "{autoprograms}\Editor de Apresentacoes do Assistente"; Filename: "{app}\presentation_editor.exe"; WorkingDir: "{app}"; Check: not VerificationMode
Name: "{autoprograms}\Assistente - Guia de comandos"; Filename: "{app}\docs\guia-comandos-assistente.md"; Check: not VerificationMode
Name: "{autodesktop}\Editor de Apresentacoes do Assistente"; Filename: "{app}\presentation_editor.exe"; WorkingDir: "{app}"; Tasks: editordesktopicon; Check: not VerificationMode

[Run]
Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent; Check: not VerificationMode

[Code]
function UpdateMovementCatalog: Boolean;
var CatalogPath: String;
begin
  CatalogPath := ExpandConstant('{app}\AVATARES\movimentos.json');
  Result := not FileExists(CatalogPath);
  { Upgrade the unchanged original 0.210 catalog, preserving edited catalogs. }
  if not Result then
    Result := CompareText(GetSHA256OfFile(CatalogPath), '477ab2a3e080459f98ce1debd4a79f5538a2c1eb7a69d123179fb00869252460') = 0;
end;

function VerificationMode: Boolean;
begin
  { Test the actual installer in an isolated directory, without registering
    the test installation or creating shortcuts in the user's environment. }
  Result := ExpandConstant('{param:VERIFYINSTALL|0}') = '1';
end;

function SetupApplicationId(Param: String): String;
begin
  if VerificationMode then
    Result := '{B59B306D-29F8-413D-9507-B94C03F8B130}'
  else
    Result := '{25A25326-C619-4F25-B473-8916AF42FCD1}';
end;
