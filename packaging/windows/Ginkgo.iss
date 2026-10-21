#define AppName "Ginkgo"
#define AppPublisher "Ginkgo contributors"
#define AppURL "https://juanwang-buaa.github.io/ginkgo/"
#define AppExeName "ginkgo_mirror.exe"

#ifndef AppVersion
  #define AppVersion "0.1.0-alpha.4"
#endif

#ifndef BundleDir
  #define BundleDir "flutter\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{D3A06D5D-4416-46D2-80AC-D6524D9E2114}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL=https://github.com/JUANWANG-BUAA/ginkgo/issues
AppUpdatesURL=https://github.com/JUANWANG-BUAA/ginkgo/releases
AppComments=Ginkgo Windows Alpha
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=..\..\dist
OutputBaseFilename=Ginkgo-{#AppVersion}-windows-x64-setup
SetupIconFile=..\..\flutter\windows\runner\resources\app_icon.ico
LicenseFile=..\..\LICENSE
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupLogging=yes
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\{#AppExeName}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription=Ginkgo Windows installer
VersionInfoProductName={#AppName}
VersionInfoProductVersion=0.1.0.4
VersionInfoVersion=0.1.0.4

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
