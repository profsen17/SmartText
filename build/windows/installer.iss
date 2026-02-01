#define MyAppName "SmartText"
#define MyAppVersion "0.1.0"
#define MyAppExeName "SmartText.exe"

[Setup]
AppId={{D6F4A0B2-8F44-4EAF-BB8C-2F42F71D7B01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
OutputDir={#SourcePath}\..\..\dist_installer
OutputBaseFilename=SmartText-Setup

[Files]
Source: "{#SourcePath}\..\..\dist\SmartText\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch SmartText"; Flags: nowait postinstall skipifsilent
