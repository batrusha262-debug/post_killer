#define MyAppName "Post Killer"
#define MyAppPublisher "Post Killer contributors"
#define MyAppURL "https://github.com/batrusha262-debug/post_killer"
#define MyAppExeName "post_killer.exe"
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif

[Setup]
AppId={{1D40B6E7-9E25-4DB8-AF2D-3A5B39A83B7D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\Post Killer
DefaultGroupName=Post Killer
OutputDir=..\..\dist
OutputBaseFilename=Post-Killer-{#MyAppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "..\..\apps\client_flutter\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Post Killer"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Post Killer"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Post Killer"; Flags: nowait postinstall skipifsilent
