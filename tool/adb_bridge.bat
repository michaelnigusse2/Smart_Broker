@echo off
rem ---------------------------------------------------------------------------
rem SmartBroker emulator bridge (for remote demos and testing).
rem
rem Watches build_logs\adb_request.txt for ONE command per request and sends
rem it to the running Android emulator with adb. Only these commands exist:
rem   screen               screenshot -> build_logs\screen.png
rem   dump                 UI tree    -> build_logs\ui.xml
rem   tap X Y              tap at pixel X,Y
rem   swipe X1 Y1 X2 Y2    swipe
rem   text WORD            type letters/digits (no spaces; use "key space")
rem   key back|home|enter|space|del
rem   launch               open SmartBroker
rem Anything else is ignored. Close this window to stop.
rem ---------------------------------------------------------------------------
setlocal EnableDelayedExpansion
cd /d "%~dp0.."
if not exist build_logs mkdir build_logs
set "SDK=%LOCALAPPDATA%\Android\Sdk"
if defined ANDROID_HOME set "SDK=%ANDROID_HOME%"
set "ADB=%SDK%\platform-tools\adb.exe"
set "REQ=build_logs\adb_request.txt"
set "LOG=build_logs\adb.log"
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
if /i "!CMD!"=="screen" goto do_screen
if /i "!CMD!"=="dump"   goto do_dump
if /i "!CMD!"=="tap"    goto do_tap
if /i "!CMD!"=="swipe"  goto do_swipe
if /i "!CMD!"=="text"   goto do_text
if /i "!CMD!"=="key"    goto do_key
if /i "!CMD!"=="launch" goto do_launch
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
echo(!P1!| findstr /r /x "[A-Za-z0-9+@.]*" >nul || (call :done "bad text" & exit /b 0)
if "!P1!"=="" (call :done "bad text" & exit /b 0)
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

:num
echo(%~1| findstr /r /x "[0-9][0-9]*" >nul && exit /b 0
call :done "bad number"
exit /b 1

:done
>> "%LOG%" echo [%time%] %~1
echo %~1 %time%> build_logs\adb_done.txt
exit /b 0
