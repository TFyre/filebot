@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------------------
rem FileBot private launcher (console logging stays visible)
rem
rem Uses the Windows deployment profile (system L&F, Windows UI tweaks,
rem native Explorer move/copy) and points JNA at lib\native\win32-x64.
rem Keep this file in the repository root, or copy it next to the jar together
rem with the lib\native\win32-x64 folder.
rem
rem Optional overrides:
rem   FILEBOT_JAVA   full path to a JavaFX-enabled java.exe
rem   JAVA_HOME      used if it contains jmods\javafx.controls.jmod
rem   JAVA_OPTS      extra JVM options
rem   FILEBOT_OPTS   extra FileBot/JVM options
rem ---------------------------------------------------------------------------

set "APP_ROOT=%~dp0"
set "NATIVE=%APP_ROOT%lib\native\win32-x64"

rem --- pick a Java 21 FX-enabled JDK, so MediaInfo/JavaFX features keep working
set "JAVA_EXE=java"
if defined FILEBOT_JAVA if exist "%FILEBOT_JAVA%" set "JAVA_EXE=%FILEBOT_JAVA%"

rem JAVA_HOME is used only if it is a Java 21 JavaFX JDK
if "%JAVA_EXE%"=="java" if defined JAVA_HOME if exist "%JAVA_HOME%\jmods\javafx.controls.jmod" if exist "%JAVA_HOME%\release" (
    findstr /b /c:"JAVA_VERSION=" "%JAVA_HOME%\release" | findstr /c:"21" >nul 2>&1
    if not errorlevel 1 set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"
)

rem jdk\ next to the launcher
if "%JAVA_EXE%"=="java" if exist "%APP_ROOT%jdk\jmods\javafx.controls.jmod" set "JAVA_EXE=%APP_ROOT%jdk\bin\java.exe"

rem Zulu 21 FX cached by build.ps1
if "%JAVA_EXE%"=="java" for /d %%D in ("%LOCALAPPDATA%\filebot-build-tools\zulu21fx\zulu21*") do if exist "%%~fD\jmods\javafx.controls.jmod" set "JAVA_EXE=%%~fD\bin\java.exe"

rem Zulu 21 FX installed under Program Files
if "%JAVA_EXE%"=="java" for /d %%D in ("C:\Program Files\Zulu\zulu21*-ca-fx-jdk*") do if exist "%%~fD\jmods\javafx.controls.jmod" set "JAVA_EXE=%%~fD\bin\java.exe"

rem --- prefer filebot.jar next to this script, else the newest dist\FileBot_*.jar
set "JAR=%APP_ROOT%filebot.jar"
if not exist "%JAR%" for %%J in ("%APP_ROOT%dist\FileBot_*.jar") do set "JAR=%%~fJ"
if not exist "%JAR%" (
    echo FileBot jar not found. Run build.cmd first, or put filebot.jar next to this script.
    exit /b 1
)

"%JAVA_EXE%" ^
 -Dapplication.deployment=msi ^
 -Djava.net.useSystemProxies=true ^
 -DuseNativeShell=true ^
 -DuseExtendedFileAttributes=true ^
 -DuseCreationDate=false ^
 -Djna.nosys=true ^
 -Djna.nounpack=true ^
 "-Djna.boot.library.path=%NATIVE%" ^
 "-Djna.library.path=%NATIVE%" ^
 "-Djava.library.path=%NATIVE%" ^
 "-Dnet.filebot.AcoustID.fpcalc=%NATIVE%\fpcalc.exe" ^
 %JAVA_OPTS% ^
 %FILEBOT_OPTS% ^
 -jar "%JAR%" %*

set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo.
    echo FileBot exited with code %RC%.
    pause
)
exit /b %RC%
