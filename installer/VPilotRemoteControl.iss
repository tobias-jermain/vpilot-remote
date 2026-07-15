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
const
  WebSocketPort = '9001';
  FirewallRuleName = 'vPilot Remote Control';

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

// Opens LAN access to the plugin's WebSocket port: a URL ACL reservation (so
// HttpListener can bind to all interfaces, not just loopback — see
// ARCHITECTURE.md) and a firewall rule to allow the inbound connections that
// enables. Both need admin rights, which the installer itself deliberately
// doesn't require (it installs to %LOCALAPPDATA%) — so this runs as a single
// separate elevated step instead, prompting once via UAC.
function ConfigureLanAccess(): Boolean;
var
  ResultCode: Integer;
  Params: String;
begin
  Params := '/c netsh http add urlacl url=http://+:' + WebSocketPort + '/ user=Everyone' +
    ' & netsh advfirewall firewall add rule name="' + FirewallRuleName + '"' +
    ' dir=in action=allow protocol=TCP localport=' + WebSocketPort;
  Result := ShellExec('runas', ExpandConstant('{cmd}'), Params, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if MsgBox('vPilot Remote Control needs one-time Windows permission to accept connections ' +
              'from other devices on your LAN (port ' + WebSocketPort + '). ' +
              'Click Yes, then approve the Windows admin prompt that follows.' + #13#13 +
              'Click No to skip — the plugin will still work for a client running on this same PC.',
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      if not ConfigureLanAccess() then
        MsgBox('Could not launch the elevated setup step. You can run it manually later — see CONTRIBUTING.md.',
               mbError, MB_OK);
    end;

    MsgBox('vPilot Remote Control installed successfully.' + #13#13 +
           'The WebSocket server will listen on ws://<this-pc-ip>:9001 once vPilot loads the plugin.' + #13 +
           'Restart vPilot now to activate it.' + #13#13 +
           'See README.txt in this folder for companion app setup.',
           mbInformation, MB_OK);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
  Params: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    Params := '/c netsh http delete urlacl url=http://+:' + WebSocketPort + '/' +
      ' & netsh advfirewall firewall delete rule name="' + FirewallRuleName + '"';
    ShellExec('runas', ExpandConstant('{cmd}'), Params, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

[UninstallDelete]
Type: files; Name: "{app}\VPilotRemoteControl.dll"
Type: files; Name: "{app}\VPilotRemoteControl.pdb"
Type: files; Name: "{app}\README.txt"
