@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------------------
rem FileBot private launcher (console logging stays visible)
rem
rem Uses the Windows system L&F, native Explorer move/copy and JNA native
rem libraries. JavaFX can come either from an FX-enabled JDK (Zulu FX) or from
rem an external OpenJFX SDK loaded via --module-path at runtime.
rem Keep this file in the repository root, or copy it next to the jar together
rem with the lib\native\win32-x64 folder.
rem
rem Optional overrides:
rem   FILEBOT_JAVA    full path to java.exe (Java 21+; FX or plain)
rem   FILEBOT_JAVAFX  full path to an OpenJFX SDK (javafx-sdk-21...)
rem   JAVA_HOME       fallback Java home (plain or FX)
rem   JAVA_OPTS       extra JVM options
rem   FILEBOT_OPTS    extra FileBot/JVM options
rem ---------------------------------------------------------------------------

set "APP_ROOT=%~dp0"
set "NATIVE=%APP_ROOT%lib\native\win32-x64"

rem --- choose the Java executable
set "JAVA_EXE="
if defined FILEBOT_JAVA if exist "%FILEBOT_JAVA%" set "JAVA_EXE=%FILEBOT_JAVA%"

rem An explicitly requested FX SDK is used with JAVA_HOME/plain java, not with an FX JDK
if not defined JAVA_EXE if defined FILEBOT_JAVAFX if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"

rem Prefer a JavaFX-enabled JDK (no module path needed) unless an SDK was requested
if not defined JAVA_EXE if not defined FILEBOT_JAVAFX if defined JAVA_HOME if exist "%JAVA_HOME%\jmods\javafx.controls.jmod" if exist "%JAVA_HOME%\release" (
    findstr /b /c:"JAVA_VERSION=" "%JAVA_HOME%\release" | findstr /c:"21" >nul 2>&1
    if not errorlevel 1 set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"
)
if not defined JAVA_EXE if not defined FILEBOT_JAVAFX if exist "%APP_ROOT%jdk\jmods\javafx.controls.jmod" set "JAVA_EXE=%APP_ROOT%jdk\bin\java.exe"
if not defined JAVA_EXE if not defined FILEBOT_JAVAFX for /d %%D in ("%LOCALAPPDATA%\filebot-build-tools\zulu21fx\zulu21*") do if exist "%%~fD\jmods\javafx.controls.jmod" set "JAVA_EXE=%%~fD\bin\java.exe"
if not defined JAVA_EXE if not defined FILEBOT_JAVAFX for /d %%D in ("C:\Program Files\Zulu\zulu21*-ca-fx-jdk*") do if exist "%%~fD\jmods\javafx.controls.jmod" set "JAVA_EXE=%%~fD\bin\java.exe"

rem Fall back to JAVA_HOME or PATH java (plain JDK + external FX SDK)
if not defined JAVA_EXE if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"
if not defined JAVA_EXE set "JAVA_EXE=java"

rem --- does the selected Java already contain JavaFX?
set "JAVA_IS_FX="
if defined JAVA_HOME if exist "%JAVA_HOME%\jmods\javafx.controls.jmod" set "JAVA_IS_FX=1"
if not defined JAVA_IS_FX if not "%JAVA_EXE%"=="java" (
    for %%I in ("%JAVA_EXE%") do set "JAVA_BIN=%%~dpI"
    if exist "%JAVA_BIN%..\jmods\javafx.controls.jmod" set "JAVA_IS_FX=1"
)

rem --- find an external OpenJFX SDK when Java does not include JavaFX
set "FX_SDK="
if defined JAVA_IS_FX goto :fx_done
if defined FILEBOT_JAVAFX if exist "%FILEBOT_JAVAFX%\lib\javafx.controls.jar" set "FX_SDK=%FILEBOT_JAVAFX%"
if not defined FX_SDK for /d %%D in ("%LOCALAPPDATA%\filebot-build-tools\javafx21\javafx-sdk-*") do if exist "%%~fD\lib\javafx.controls.jar" set "FX_SDK=%%~fD"
if not defined FX_SDK for /d %%D in ("C:\Program Files\javafx-sdk-*") do if exist "%%~fD\lib\javafx.controls.jar" set "FX_SDK=%%~fD"
if not defined FX_SDK if exist "%APP_ROOT%javafx-sdk\lib\javafx.controls.jar" set "FX_SDK=%APP_ROOT%javafx-sdk"
:fx_done

rem --- JavaFX modules and native library path
set "FX_OPTS="
set "JAVA_LIBRARY_PATH=%NATIVE%"
if defined FX_SDK (
    set "FX_OPTS=--module-path "%FX_SDK%\lib" --add-modules javafx.controls,javafx.swing,javafx.fxml --enable-native-access=javafx.graphics"
    set "JAVA_LIBRARY_PATH=%FX_SDK%\bin;%NATIVE%"
    set "PATH=%FX_SDK%\bin;%PATH%"
)
if not defined JAVA_IS_FX if not defined FX_SDK echo WARNING: JavaFX SDK not found. JavaFX-backed GUI features may fail.

rem --- prefer filebot.jar next to this script, else the newest dist\FileBot_*.jar
set "JAR=%APP_ROOT%filebot.jar"
if not exist "%JAR%" for %%J in ("%APP_ROOT%dist\FileBot_*.jar") do set "JAR=%%~fJ"
if not exist "%JAR%" (
    echo FileBot jar not found. Run build.cmd first, or put filebot.jar next to this script.
    exit /b 1
)

"%JAVA_EXE%" %FX_OPTS% ^
 -Djava.net.useSystemProxies=true ^
 -DuseNativeShell=true ^
 -DuseExtendedFileAttributes=true ^
 -DuseCreationDate=false ^
 -Djna.nosys=true ^
 -Djna.nounpack=true ^
 "-Djna.boot.library.path=%NATIVE%" ^
 "-Djna.library.path=%NATIVE%" ^
 "-Djava.library.path=%JAVA_LIBRARY_PATH%" ^
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
