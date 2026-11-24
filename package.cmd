@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------------------
rem Assemble a self-contained run folder from the built jar:
rem   run\filebot.jar
rem   run\filebot.cmd
rem   run\lib\native\win32-x64\*
rem
rem Run it with: run\filebot.cmd
rem The data indexes and signed script bundle are embedded in the jar.
rem ---------------------------------------------------------------------------

set "ROOT=%~dp0"
set "RUN=%ROOT%run"

set "JAR="
for %%J in ("%ROOT%dist\FileBot_*.jar") do set "JAR=%%~fJ"
if not defined JAR (
    echo No dist\FileBot_*.jar found. Run build.cmd first.
    exit /b 1
)
if not exist "%ROOT%lib\native\win32-x64" (
    echo lib\native\win32-x64 not found. Is this the repository root?
    exit /b 1
)

if exist "%RUN%" rmdir /s /q "%RUN%"
mkdir "%RUN%\lib\native\win32-x64" >nul 2>&1

copy /y "%JAR%" "%RUN%\filebot.jar" >nul
copy /y "%ROOT%filebot.cmd" "%RUN%\filebot.cmd" >nul
xcopy /e /i /y "%ROOT%lib\native\win32-x64" "%RUN%\lib\native\win32-x64" >nul

echo Packaged: %RUN%
echo Run:      %RUN%\filebot.cmd
