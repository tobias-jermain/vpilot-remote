; vPilot Remote Control — Inno Setup installer
; Build with: iscc VPilotRemoteControl.iss
; Requires Inno Setup 6: https://jrsoftware.org/isinfo.php

#define MyAppName "vPilot Remote Control"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "vPilot Remote Control Contributors"
#define MyAppURL "https://github.com/tobias-jermain/vpilot-remote"

[Setup]
AppId={{B4E2A1C0-9F3D-4E5A-8B7C-1234567890AB}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
DefaultDirName={localappdata}\vPilot\Plugins
DisableProgramGroupPage=yes
DisableDirPage=no
DisableReadyPage=no
OutputDir=dist
OutputBaseFilename=VPilotRemoteControl-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\plugin\bin\Release\net472\VPilotRemoteControl.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\plugin\bin\Release\net472\VPilotRemoteControl.pdb"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "..\README.md"; DestDir: "{app}"; DestName: "README.txt"; Flags: ignoreversion

[Code]
function VPilotFolderExists(): Boolean;
begin
  Result := DirExists(ExpandConstant('{localappdata}\vPilot'));
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  if not VPilotFolderExists() then
  begin
    if MsgBox('vPilot does not appear to be installed on this system (expected folder not found).' + #13#13 +
               'Continue installing the plugin anyway?', mbConfirmation, MB_YESNO) = IDNO then
      Result := False;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    MsgBox('vPilot Remote Control installed successfully.' + #13#13 +
           'The WebSocket server will listen on ws://localhost:9001 once vPilot loads the plugin.' + #13 +
           'Restart vPilot now to activate it.' + #13#13 +
           'See README.txt in this folder for companion app setup.',
           mbInformation, MB_OK);
  end;
end;

[UninstallDelete]
Type: files; Name: "{app}\VPilotRemoteControl.dll"
Type: files; Name: "{app}\VPilotRemoteControl.pdb"
Type: files; Name: "{app}\README.txt"
