@echo off
rem ---------------------------------------------------------------------------
rem SmartBroker dev runner
rem
rem Leave this window open while working with the AI assistant. It watches for
rem build_logs\request.txt and runs ONE of a fixed set of Flutter commands:
rem   pubget | analyze | test | format | build | all
rem Anything else in the request file is ignored. Output goes to
rem build_logs\result.log and build_logs\done.txt marks completion.
rem Close this window (or press Ctrl+C) to stop.
rem ---------------------------------------------------------------------------
setlocal
cd /d "%~dp0.."
if not exist build_logs mkdir build_logs

set "FLUTTER=flutter"
if exist "C:\flutter\bin\flutter.bat" set "FLUTTER=C:\flutter\bin\flutter.bat"
set "DART=dart"
if exist "C:\flutter\bin\dart.bat" set "DART=C:\flutter\bin\dart.bat"

echo SmartBroker dev runner is watching build_logs\request.txt
echo Project: %CD%
echo Flutter: %FLUTTER%
echo Leave this window open. Close it to stop.
echo.

:loop
if exist "build_logs\request.txt" (
  set /p ACTION=<"build_logs\request.txt"
  del "build_logs\request.txt"
  call :run
)
timeout /t 3 /nobreak >nul
goto loop

:run
if exist "build_logs\done.txt" del "build_logs\done.txt"
set "LOG=build_logs\result.log"
echo action=%ACTION%> "%LOG%"
echo started=%date% %time%>> "%LOG%"
echo [%time%] Running: %ACTION%
if /i "%ACTION%"=="pubget"  goto do_pubget
if /i "%ACTION%"=="analyze" goto do_analyze
if /i "%ACTION%"=="test"    goto do_test
if /i "%ACTION%"=="format"  goto do_format
if /i "%ACTION%"=="build"   goto do_build
if /i "%ACTION%"=="all"     goto do_all
echo unknown action ignored>> "%LOG%"
goto finish

:do_pubget
echo ===== flutter pub get>> "%LOG%"
call "%FLUTTER%" pub get >> "%LOG%" 2>&1
echo exit_pubget=%errorlevel%>> "%LOG%"
goto finish

:do_analyze
echo ===== flutter analyze>> "%LOG%"
call "%FLUTTER%" analyze >> "%LOG%" 2>&1
echo exit_analyze=%errorlevel%>> "%LOG%"
goto finish

:do_test
echo ===== flutter test>> "%LOG%"
call "%FLUTTER%" test >> "%LOG%" 2>&1
echo exit_test=%errorlevel%>> "%LOG%"
goto finish

:do_format
echo ===== dart format>> "%LOG%"
call "%DART%" format --output=none --set-exit-if-changed lib test >> "%LOG%" 2>&1
echo exit_format=%errorlevel%>> "%LOG%"
goto finish

:do_build
echo ===== flutter build apk --debug>> "%LOG%"
call "%FLUTTER%" build apk --debug >> "%LOG%" 2>&1
echo exit_build=%errorlevel%>> "%LOG%"
goto finish

:do_all
echo ===== flutter pub get>> "%LOG%"
call "%FLUTTER%" pub get >> "%LOG%" 2>&1
echo exit_pubget=%errorlevel%>> "%LOG%"
echo ===== flutter analyze>> "%LOG%"
call "%FLUTTER%" analyze >> "%LOG%" 2>&1
echo exit_analyze=%errorlevel%>> "%LOG%"
echo ===== flutter test>> "%LOG%"
call "%FLUTTER%" test >> "%LOG%" 2>&1
echo exit_test=%errorlevel%>> "%LOG%"
echo ===== flutter build apk --debug>> "%LOG%"
call "%FLUTTER%" build apk --debug >> "%LOG%" 2>&1
echo exit_build=%errorlevel%>> "%LOG%"
goto finish

:finish
echo finished=%date% %time%>> "%LOG%"
echo %date% %time%> "build_logs\done.txt"
echo [%time%] Done: %ACTION%
exit /b 0
