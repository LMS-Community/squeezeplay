#define SpAppSourcePath ".\"
#include "SqueezePlay-common.iss"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{09B790E3-21E3-4D1A-8130-AAA9227C9785}
AppName={#SpAppName}
AppVerName={#SpAppVerName}
AppPublisher={#SpAppPublisher}
AppPublisherURL={#SpAppURL}
AppSupportURL={#SpAppURL}
AppUpdatesURL={#SpAppURL}
DefaultDirName={pf}\Squeezebox\{#SpAppName}
DefaultGroupName={#SpAppName}
DisableReadyPage=yes
DisableProgramGroupPage=yes
OutputBaseFilename={#SpAppName}-setup
SolidCompression=yes
OutputDir=Output\Squeezeplay

[Languages]
Name: english; MessagesFile: compiler:Default.isl

[Tasks]
Name: desktopicon; Description: {cm:CreateDesktopIcon}; GroupDescription: {cm:AdditionalIcons}; Flags: unchecked
Name: quicklaunchicon; Description: {cm:CreateQuickLaunchIcon}; GroupDescription: {cm:AdditionalIcons}; Flags: unchecked

[Icons]
Name: {commondesktop}\{#SpAppName}; Filename: {app}\{#SpAppExeName}; Tasks: desktopicon
Name: {userappdata}\Microsoft\Internet Explorer\Quick Launch\{#SpAppName}; Filename: {app}\{#SpAppExeName}; Tasks: quicklaunchicon
Name: {group}\{cm:UninstallProgram, {#SpAppName}}; Filename: {uninstallexe}

[Run]
Filename: {app}\{#SpAppExeName}; Description: {cm:LaunchProgram,{#SpAppName}}; Flags: nowait postinstall skipifsilent

