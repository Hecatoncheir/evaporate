; Установщик Evaporate для Windows.
;
; Обычный мастер «Далее — Далее — Готово»: архив с папкой файлов человеку
; ставить некуда, а тут появляются и ярлыки, и запись в «Установку и
; удаление программ», и удаление одной кнопкой.
;
; Версия приходит снаружи: её знает CI по имени тега, а держать её в двух
; местах значит однажды разойтись.
;   iscc /DAppVersion=1.2.3 /DSourceDir=... windows/installer.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif

#define AppName "Evaporate"
#define AppExe "evaporate.exe"
#define AppPublisher "Hecatoncheir"
#define AppUrl "https://github.com/Hecatoncheir/evaporate"

[Setup]
; Идентификатор не меняется от версии к версии: по нему установщик узнаёт
; прежнюю установку и обновляет её, а не плодит вторую копию рядом.
AppId={{9F2B5A46-5B7E-4E5B-9A1E-1D9C6D2A7C31}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
; Ставим для одного пользователя и не спрашиваем об этом: прав
; администратора не просим, игры и сохранения всё равно лежат в его папках,
; а в свою папку приложение потом сможет поставить обновление само —
; в Program Files оно бы упёрлось в права.
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=evaporate-{#AppVersion}-windows-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Приложение шестидесятичетырёхбитное, и на 32-битной системе не пойдёт —
; сказать об этом лучше сразу, а не после установки.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
; Язык берём по системе и лишним окном не спрашиваем: мастер и так должен
; сводиться к «Далее — Далее — Готово».
ShowLanguageDialog=auto
LicenseFile=..\LICENSE

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
  GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; \
  Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Папка обновления, которую приложение готовит себе само. Настройки,
; библиотеку и снимки сохранений не трогаем: человек мог удалять
; приложение, чтобы поставить заново, и терять из-за этого сейвы нельзя.
Type: filesandordirs; Name: "{localappdata}\evaporate\updates"
