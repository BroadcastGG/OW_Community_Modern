<# : batch portion (begins PowerShell multi-line comment block) - this file is looking for install.json
@echo off
TITLE BGG
: runs the batch file as an administrator
if not "%1"=="am_admin" (powershell start -WindowStyle Minimized -verb runas '%0' am_admin & exit /b)
: sets the working directory to the batch file location
cd /d %~dp0%
:runtime

setlocal enableDelayedExpansion

: replace this to change the file path to be changed in the json
echo Setting Path and Variables
set rep=C:/Broadcast/

: setting variables
set "installpath=%~dp0%"**
set "var=%installpath:\=/%"
set "var2=%var::=%"
set "var2=%var2:/=-%"
set "var2=%var2: =_%"

: change the following to rename the scene and output filename
set out=BroadcastGGCommunity_%var2%
set /a num=%RANDOM%

: runs the powershell script chain at the bottom of the batch file
echo Running PowerShell JSON preparations
powershell -noprofile "iex (${%~f0} | out-string)"

: runs individual powershell scripts that do not require to be chained together
: replace paths in text files
echo Running PowerShell TXT replacement for files dropped in the last 15 minutes
powershell -command "Get-ChildItem -recurse -include "*path.txt" | Where-Object {$_.CreationTime -gt (Get-Date).AddMinutes(-15)} | ForEach {(Get-Content $_ | ForEach {$_ -replace [regex]::Escape('C:\Broadcast'), '%cd%'}) | Set-Content -encoding UTF8 $_ }"
powershell -command "Get-ChildItem -recurse -include "*logo.txt" | Where-Object {$_.CreationTime -gt (Get-Date).AddMinutes(-15)} | ForEach {(Get-Content $_ | ForEach {$_ -replace [regex]::Escape('C:\Broadcast'), '%cd%'}) | Set-Content -encoding UTF8 $_ }"

: replace paths in xml & xml based files
echo Running PowerShell XML replacement for files dropped in the last 15 minutes
powershell -command "Get-ChildItem -recurse -include "*.xml" | Where-Object {$_.CreationTime -gt (Get-Date).AddMinutes(-15)} | ForEach {(Get-Content $_ | ForEach {$_ -replace [regex]::Escape('C:\Broadcast'), '%cd%'}) | Set-Content -encoding UTF8 $_ }"

: replace paths in json file and rename the scene to the install path
echo Running PowerShell JSON replacement
powershell -Command "(gc install.json) -replace '%rep%', '%var%' | Out-File -encoding UTF8 install.json"
powershell -Command "(gc install.json) -replace 'scriptbyjayp33', '%out%' | Out-File -encoding UTF8 install.json"

: duplicates the install.json file to the scene name and drops to the working directory
echo Dropping JSON file to OBS AppData Directory
copy install.json %out%.json

: duplicates the install.json file to the scene name and drops to obs scene directory
copy install.json %appdata%\obs-studio\basic\scenes\%out%.json

:regfind
: searches the registry for the install location of obs
echo Finding OBS Installation Location
for /f "tokens=3,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\OBS Studio"  /ve  ^|findstr /ri "REG_SZ"') do set "obsinstall=%%a %%b"

: removes the ending space if there is one, due to the way that command prompt handles spaces
set "obsinstall=%obsinstall:studio =studio%"

: checks for previous luma wipe, copies the luma wipes data to the obs install path, and backs up the previous wipes.json if needed
set "lumawipes=%obsinstall%\data\obs-plugins\obs-transitions\luma_wipes\"
findstr /m "linear-h-ease.png" "%lumawipes%wipes.json"
if %errorlevel%==0 (
  if exist "%lumawipes%linear-h-ease.png" (
    echo Wipe Found - Update Not Required
  ) else (
    echo Wipe Reference Found, but file missing, replacing.
    copy "%installpath%luma_wipes\linear-h-ease.png" "%lumawipes%linear-h-ease.png"
  )
) else (
  echo Dropping Luma Wipes Data to OBS Installation Location
  copy "%lumawipes%wipes.json" "%lumawipes%wipesold%num%.json"
  copy "%installpath%luma_wipes" "%lumawipes%"
)

rd "%installpath%luma_wipes" /s /q

echo Dropping Launcher
>launcher.bat (
  echo @echo off
  echo if not DEFINED IS_MINIMIZED set IS_MINIMIZED=1 ^&^& start "" /min "launcher.bat" ^&^& exit
  echo title BGG Local Server
  echo echo PLEASE KEEP THIS WINDOW OPEN
  echo echo This will shut down the required local server once you exit OBS.
  echo cd %~dp0%scoreboard
  echo start OW_Scoreboard_Tool.exe
  echo cd %~dp0%nginx
  echo start nginx
  echo cd /d "%obsinstall% \bin\64bit"
  echo obs64.exe --collection "%out%"
  echo echo.
  echo echo Now Closing...
  echo taskkill /IM "OW_Scoreboard_Tool.exe" /f
  echo cd %~dp0%nginx
  echo nginx -s quit
  echo exit
)

: launches Scoreboard tool from install path, and obs
echo Launching Scoreboard Tool and OBS
del install.json & del "%~f0" & start launcher.bat & exit
goto :EOF

: end batch / begin PowerShell chimera #>
$JsonData = Get-Content install.json -raw | ConvertFrom-Json
$JsonData.name = "scriptbyjayp33"
ConvertTo-Json $JsonData -Depth 100 -Compress | Out-File -encoding UTF8 install.json -force
