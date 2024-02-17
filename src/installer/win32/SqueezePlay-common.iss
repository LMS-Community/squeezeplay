#define SpAppName "SqueezePlay"
#define SpAppVerName "SqueezePlay 8.0.1r1467"
#define SpAppPublisher "Ralph Irving"
#define SpAppURL "http://www.slimdevices.com"
#define SpAppExeName "squeezeplay.exe"

[Files]
Source: {#SpAppSourcePath}..\..\Release\squeezeplay.exe; DestDir: {app}; Flags: ignoreversion; Tasks: ; Languages:
Source: {#SpAppSourcePath}..\..\Release\*; DestDir: {app}; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: *.pdb,*.ilk,*.exp,*.lib,stdout.txt,stderror.txt,.svn,*.map
Source: {#SpAppSourcePath}Microsoft.VC90.CRT\*; DestDir: {app}\Microsoft.VC90.CRT; Flags: ignoreversion
Source: {#SpAppSourcePath}Microsoft.VC90.CRT\*; DestDir: {app}\socket\Microsoft.VC90.CRT; Flags: ignoreversion
Source: {#SpAppSourcePath}Microsoft.VC90.CRT\*; DestDir: {app}\mime\Microsoft.VC90.CRT; Flags: ignoreversion

[Icons]
Name: {group}\{#SpAppName}; Filename: {app}\{#SpAppExeName}

[InstallDelete]
Name: {app}\lua\*; Type: filesandordirs; Languages:
