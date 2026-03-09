[Setup]
AppId={{D37793BB-4F15-4D56-8A3E-963BB2328DB4}
AppName=Duke Ignite Formaldehyde Monitor
AppVersion=1.0.31
AppPublisher=Duke Ignite
DefaultDirName={autopf}\DukeIgniteFormaldehydeMonitor
DisableProgramGroupPage=yes
; Remove the following line to run in administrative install mode (install for all users.)
PrivilegesRequired=lowest
OutputBaseFilename=DukeIgnite_Installer
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\DukeIgnite.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\Duke Ignite Formaldehyde Monitor"; Filename: "{app}\DukeIgnite.exe"
Name: "{autodesktop}\Duke Ignite Formaldehyde Monitor"; Filename: "{app}\DukeIgnite.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\DukeIgnite.exe"; Description: "{cm:LaunchProgram,Duke Ignite Formaldehyde Monitor}"; Flags: nowait postinstall skipifsilent
