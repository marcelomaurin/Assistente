; Build through scripts/build_installer.ps1. PackageDir contains only release files.
#ifndef PackageDir
  #error Use scripts/build_installer.ps1 to prepare the verified payload.
#endif
#ifndef RepositoryDir
  #error RepositoryDir is required.
#endif
#define MyAppName "Assistente"
#ifndef MyAppVersion
  #define MyAppVersion "0.214"
#endif
#ifndef SetupCode
  #define SetupCode "0214"
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

Name: "motioneditordesktopicon"; Description: "Criar atalho do Editor de Movimentos (previa) na area de trabalho"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Required tag/presentation editor: always installed, independently of shortcut tasks.
Source: "{#PackageDir}\presentation_editor.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PackageDir}\*"; DestDir: "{app}"; Excludes: "presentation_editor.exe,AVATARES\movimentos.json,AVATARES\colisoes.json,AVATARES\movimentos\*"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PackageDir}\AVATARES\colisoes.json"; DestDir: "{app}\AVATARES"; Flags: ignoreversion uninsneveruninstall; Check: UpdateCollisionProfile
; The shared catalog is editable user configuration: preserve custom movements.
Source: "{#PackageDir}\AVATARES\movimentos.json"; DestDir: "{app}\AVATARES"; Flags: ignoreversion uninsneveruninstall; Check: UpdateMovementCatalog

; External motions are editable in the preview editor; keep existing and user-edited files.
Source: "{#PackageDir}\AVATARES\movimentos\*.json"; DestDir: "{app}\AVATARES\movimentos"; Flags: onlyifdoesntexist uninsneveruninstall

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Check: not VerificationMode
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon; Check: not VerificationMode

Name: "{autoprograms}\Editor de Tags do Assistente"; Filename: "{app}\presentation_editor.exe"; WorkingDir: "{app}"; Check: not VerificationMode
Name: "{autoprograms}\Editor de Apresentacoes do Assistente"; Filename: "{app}\presentation_editor.exe"; WorkingDir: "{app}"; Check: not VerificationMode
Name: "{autoprograms}\Assistente - Guia de comandos"; Filename: "{app}\docs\guia-comandos-assistente.md"; Check: not VerificationMode
Name: "{autodesktop}\Editor de Apresentacoes do Assistente"; Filename: "{app}\presentation_editor.exe"; WorkingDir: "{app}"; Tasks: editordesktopicon; Check: not VerificationMode

Name: "{autoprograms}\Editor de Movimentos do Assistente (previa)"; Filename: "{app}\motion_editor.exe"; WorkingDir: "{app}"; Check: not VerificationMode
Name: "{autodesktop}\Editor de Movimentos do Assistente (previa)"; Filename: "{app}\motion_editor.exe"; WorkingDir: "{app}"; Tasks: motioneditordesktopicon; Check: not VerificationMode
Name: "{autoprograms}\Assistente - Guia do Editor de Movimentos"; Filename: "{app}\docs\editor-movimentos.md"; Check: not VerificationMode

[Run]
Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent; Check: not VerificationMode

Filename: "{app}\motion_editor.exe"; WorkingDir: "{app}"; Description: "Abrir a previa do Editor de Movimentos"; Flags: nowait postinstall skipifsilent unchecked; Check: not VerificationMode

[Code]
function UpdateMovementCatalog: Boolean;
var CatalogPath: String;
begin
  CatalogPath := ExpandConstant('{app}\AVATARES\movimentos.json');
  Result := not FileExists(CatalogPath);
  { Upgrade known unchanged defaults, preserving edited catalogs. }
  if not Result then
    Result := (CompareText(GetSHA256OfFile(CatalogPath), '477ab2a3e080459f98ce1debd4a79f5538a2c1eb7a69d123179fb00869252460') = 0) or
      (CompareText(GetSHA256OfFile(CatalogPath), '2b20ed43d91fd9f81b9f6e75d32c3f39c5f18a694b4d23405e4fb75a37a9cc0e') = 0) or
      (CompareText(GetSHA256OfFile(CatalogPath), 'e09c3c4a86b90f8e6289a84f3699d62954e7a0bad021962c0ab2c3a166ae0c0d') = 0) or
      (CompareText(GetSHA256OfFile(CatalogPath), 'd6329e1d203312903ee06dee25f4880fdfe715f58a82a918ca32b55df4a06361') = 0);
end;

function UpdateCollisionProfile: Boolean;
var ProfilePath: String;
begin
  ProfilePath := ExpandConstant('{app}\AVATARES\colisoes.json');
  Result := not FileExists(ProfilePath);
  if not Result then
    Result := CompareText(GetSHA256OfFile(ProfilePath), '0964bef4455d8f15740acb6a1ec388a0655e45a2f4127aa42fb2d388c78d72f6') = 0;
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
