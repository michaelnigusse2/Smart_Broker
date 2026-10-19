@echo off
rem ---------------------------------------------------------------------------
rem SmartBroker emulator bridge (remote demos and UI checks).
rem
rem Watches build_logs\emu_request.txt for ONE command per request and sends it
rem to the running Android emulator with adb. Only these commands exist:
rem   screen               screenshot -> build_logs\screen.png
rem   dump                 UI tree    -> build_logs\ui.xml
rem   tap X Y              tap at pixel X,Y
rem   swipe X1 Y1 X2 Y2    swipe
rem   text WORD            type letters/digits (no spaces; use "key space")
rem   key back|home|enter|space|del
rem   launch               open SmartBroker
rem   install              install the debug APK again and open the app
rem   logcat               Flutter log since the last "logcat" -> build_logs\logcat.txt
rem   font 0.85|1.0|1.15|1.3|1.5   system font size
rem   density reset|NUMBER system display size (dpi)
rem Anything else is ignored. Close this window to stop.
rem ---------------------------------------------------------------------------
setlocal EnableDelayedExpansion
cd /d "%~dp0.."
if not exist build_logs mkdir build_logs
set "SDK=%LOCALAPPDATA%\Android\Sdk"
if defined ANDROID_HOME set "SDK=%ANDROID_HOME%"
set "ADB=%SDK%\platform-tools\adb.exe"
set "APK=build\app\outputs\flutter-apk\app-debug.apk"
set "REQ=build_logs\emu_request.txt"
set "LOG=build_logs\emu.log"
echo SmartBroker emulator bridge is watching %REQ%
echo Close this window to stop.
echo started=%date% %time%> "%LOG%"

:loop
if exist "%REQ%" (
  set "LINE="
  set /p LINE=<"%REQ%"
  del "%REQ%"
  call :handle
)
timeout /t 1 /nobreak >nul
goto loop

:handle
set "CMD=" & set "P1=" & set "P2=" & set "P3=" & set "P4="
for /f "tokens=1-5" %%a in ("!LINE!") do (
  set "CMD=%%a"
  set "P1=%%b"
  set "P2=%%c"
  set "P3=%%d"
  set "P4=%%e"
)
echo [%time%] !CMD! !P1! !P2! !P3! !P4!
if /i "!CMD!"=="screen"  goto do_screen
if /i "!CMD!"=="dump"    goto do_dump
if /i "!CMD!"=="tap"     goto do_tap
if /i "!CMD!"=="swipe"   goto do_swipe
if /i "!CMD!"=="text"    goto do_text
if /i "!CMD!"=="key"     goto do_key
if /i "!CMD!"=="launch"  goto do_launch
if /i "!CMD!"=="install" goto do_install
if /i "!CMD!"=="logcat"  goto do_logcat
if /i "!CMD!"=="font"    goto do_font
if /i "!CMD!"=="density" goto do_density
if /i "!CMD!"=="storage" goto do_storage
if /i "!CMD!"=="reinstall" goto do_reinstall
if /i "!CMD!"=="devices" goto do_devices
if /i "!CMD!"=="scribe"  goto do_scribe
call :done "ignored"
exit /b 0

:do_screen
"%ADB%" -e exec-out screencap -p > build_logs\screen.png 2>> "%LOG%"
call :done "screen"
exit /b 0

:do_dump
"%ADB%" -e shell uiautomator dump /sdcard/sb_ui.xml >> "%LOG%" 2>&1
"%ADB%" -e pull /sdcard/sb_ui.xml build_logs\ui.xml >> "%LOG%" 2>&1
call :done "dump"
exit /b 0

:do_tap
call :num "!P1!" || exit /b 0
call :num "!P2!" || exit /b 0
"%ADB%" -e shell input tap !P1! !P2! >> "%LOG%" 2>&1
call :done "tap"
exit /b 0

:do_swipe
call :num "!P1!" || exit /b 0
call :num "!P2!" || exit /b 0
call :num "!P3!" || exit /b 0
call :num "!P4!" || exit /b 0
"%ADB%" -e shell input swipe !P1! !P2! !P3! !P4! 300 >> "%LOG%" 2>&1
call :done "swipe"
exit /b 0

:do_text
if "!P1!"=="" (call :done "bad text" & exit /b 0)
echo(!P1!| findstr /r /x "[A-Za-z0-9+@.]*" >nul || (call :done "bad text" & exit /b 0)
"%ADB%" -e shell input text !P1! >> "%LOG%" 2>&1
call :done "text"
exit /b 0

:do_key
set "CODE="
if /i "!P1!"=="back"  set "CODE=4"
if /i "!P1!"=="home"  set "CODE=3"
if /i "!P1!"=="enter" set "CODE=66"
if /i "!P1!"=="space" set "CODE=62"
if /i "!P1!"=="del"   set "CODE=67"
if not defined CODE (call :done "bad key" & exit /b 0)
"%ADB%" -e shell input keyevent !CODE! >> "%LOG%" 2>&1
call :done "key"
exit /b 0

:do_launch
"%ADB%" -e shell monkey -p com.smartbroker.smart_broker -c android.intent.category.LAUNCHER 1 >nul 2>> "%LOG%"
call :done "launch"
exit /b 0

:do_install
"%ADB%" -e install -r "%APK%" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo install failed, clearing emulator caches and retrying>> "%LOG%"
  "%ADB%" -e shell pm trim-caches 64G >> "%LOG%" 2>&1
  "%ADB%" -e install -r "%APK%" >> "%LOG%" 2>&1
)
"%ADB%" -e shell monkey -p com.smartbroker.smart_broker -c android.intent.category.LAUNCHER 1 >nul 2>> "%LOG%"
call :done "install"
exit /b 0

:do_reinstall
rem Removes SmartBroker and its data from the emulator first (frees space).
"%ADB%" -e uninstall com.smartbroker.smart_broker >> "%LOG%" 2>&1
"%ADB%" -e install "%APK%" >> "%LOG%" 2>&1
"%ADB%" -e shell monkey -p com.smartbroker.smart_broker -c android.intent.category.LAUNCHER 1 >nul 2>> "%LOG%"
call :done "reinstall"
exit /b 0

:do_devices
"%ADB%" devices -l > build_logs\devices.txt 2>&1
call :done "devices"
exit /b 0

:do_scribe
rem Addis Scribe trial: push the speech runtime (+ model, audio) and run
rem tool\scribe\run_on_device.sh on the device. "scribe emu" checks the runtime only
rem (the emulator has no room for the 499 MB model); "scribe phone" runs it all.
set "SEL=" & set "ABI="
if /i "!P1!"=="emu" (set "SEL=-e" & set "ABI=x64")
if /i "!P1!"=="phone" (set "SEL=-d" & set "ABI=arm64")
if not defined SEL (call :done "bad target" & exit /b 0)
set "SD=build_logs\scribe"
set "OUT=!SD!\result_!P1!.txt"
echo scribe !P1! %date% %time%> "!OUT!"
"%ADB%" !SEL! shell mkdir -p /data/local/tmp/scribe/wav >> "!OUT!" 2>&1
"%ADB%" !SEL! push "!SD!\android-!ABI!\." /data/local/tmp/scribe/ >> "!OUT!" 2>&1
"%ADB%" !SEL! push "!SD!\jfk.wav" /data/local/tmp/scribe/ >> "!OUT!" 2>&1
"%ADB%" !SEL! push "tool\scribe\run_on_device.sh" /data/local/tmp/scribe/run.sh >> "!OUT!" 2>&1
if /i "!P1!"=="phone" "%ADB%" !SEL! push "!SD!\addis-scribe-rnnt-q5_k.gguf" /data/local/tmp/scribe/ >> "!OUT!" 2>&1
if exist "!SD!\wav" "%ADB%" !SEL! push "!SD!\wav\." /data/local/tmp/scribe/wav/ >> "!OUT!" 2>&1
"%ADB%" !SEL! shell chmod 755 /data/local/tmp/scribe/nemo-speech >> "!OUT!" 2>&1
"%ADB%" !SEL! shell sh /data/local/tmp/scribe/run.sh >> "!OUT!" 2>&1
"%ADB%" !SEL! pull /data/local/tmp/scribe/out "!SD!\out_!P1!" >> "!OUT!" 2>&1
echo finished %date% %time%>> "!OUT!"
call :done "scribe"
exit /b 0

:do_logcat
"%ADB%" -e logcat -d -v time -s flutter:V AndroidRuntime:E > build_logs\logcat.txt 2>> "%LOG%"
"%ADB%" -e logcat -c >> "%LOG%" 2>&1
call :done "logcat"
exit /b 0

:do_font
set "OK="
for %%v in (0.85 1.0 1.15 1.3 1.5) do if "!P1!"=="%%v" set "OK=1"
if not defined OK (call :done "bad font" & exit /b 0)
"%ADB%" -e shell settings put system font_scale !P1! >> "%LOG%" 2>&1
call :done "font"
exit /b 0

:do_density
if /i "!P1!"=="reset" (
  "%ADB%" -e shell wm density reset >> "%LOG%" 2>&1
  call :done "density"
  exit /b 0
)
call :num "!P1!" || exit /b 0
"%ADB%" -e shell wm density !P1! >> "%LOG%" 2>&1
call :done "density"
exit /b 0

:do_storage
"%ADB%" -e shell df -h /data > build_logs\storage.txt 2>> "%LOG%"
call :done "storage"
exit /b 0

:num
echo(%~1| findstr /r /x "[0-9][0-9]*" >nul && exit /b 0
call :done "bad number"
exit /b 1

:done
>> "%LOG%" echo [%time%] %~1
echo %~1 %time%> build_logs\emu_done.txt
exit /b 0
