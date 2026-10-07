#define Ver GetEnv("APP_VERSION")
[Setup]
AppName=Annotate Picture
AppVersion={#Ver}
DefaultDirName={autopf}\AnnotatePicture
DefaultGroupName=Annotate Picture
OutputDir=..\dist
OutputBaseFilename=annotate_picture-{#Ver}-setup
Compression=lzma2
[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs
[Icons]
Name: "{group}\Annotate Picture"; Filename: "{app}\annotate_picture.exe"
