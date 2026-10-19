@echo off
rem ---------------------------------------------------------------------------
rem SmartBroker: start the Android emulator and install the debug build.
rem
rem Double-click to: start the first Android Virtual Device from Android
rem Studio (unless an emulator is already running), wait for it to boot,
rem install build\app\outputs\flutter-apk\app-debug.apk and open the app.
rem Progress is also written to build_logs\emulator.log.
rem Build the APK first (dev runner "build" action, or flutter build apk --debug).
rem ---------------------------------------------------------------------------
setlocal
cd /d "%~dp0.."
if not exist build_logs mkdir build_logs
set "LOG=build_logs\emulator.log"
set "SDK=%LOCALAPPDATA%\Android\Sdk"
if defined ANDROID_HOME set "SDK=%ANDROID_HOME%"
set "ADB=%SDK%\platform-tools\adb.exe"
set "EMU=%SDK%\emulator\emulator.exe"
set "APK=build\app\outputs\flutter-apk\app-debug.apk"

echo started=%date% %time%> "%LOG%"
if not exist "%ADB%" (call :say "adb not found at %ADB%" & goto fail)
if not exist "%EMU%" (call :say "emulator not found at %EMU%" & goto fail)
if not exist "%APK%" (call :say "No debug APK yet - build it first" & goto fail)

"%ADB%" -e get-state >nul 2>&1
if not errorlevel 1 (
  call :say "Emulator already running"
  goto wait_boot
)

set "AVD="
for /f "usebackq delims=" %%a in (`"%EMU%" -list-avds`) do if not defined AVD set "AVD=%%a"
if not defined AVD (call :say "No Android Virtual Device found - create one in Android Studio > Device Manager" & goto fail)
call :say "Starting emulator %AVD%"
start "Android Emulator" "%EMU%" -avd "%AVD%"

:wait_boot
call :say "Waiting for the emulator to boot..."
"%ADB%" -e wait-for-device
:boot_loop
set "BOOTED="
for /f "usebackq delims=" %%b in (`"%ADB%" -e shell getprop sys.boot_completed 2^>nul`) do set "BOOTED=%%b"
if not "%BOOTED%"=="1" (
  timeout /t 3 /nobreak >nul
  goto boot_loop
)
call :say "Booted. Installing SmartBroker..."
"%ADB%" -e install -r "%APK%" >> "%LOG%" 2>&1
if errorlevel 1 (call :say "Install failed - see %LOG%" & goto fail)
"%ADB%" -e shell monkey -p com.smartbroker.smart_broker -c android.intent.category.LAUNCHER 1 >> "%LOG%" 2>&1
call :say "SmartBroker is open on the emulator."
>> "%LOG%" echo result=ok
echo finished=%date% %time%>> "%LOG%"
timeout /t 5 >nul
exit /b 0

:fail
>> "%LOG%" echo result=failed
echo finished=%date% %time%>> "%LOG%"
pause
exit /b 1

:say
echo %~1
>> "%LOG%" echo %~1
exit /b 0
