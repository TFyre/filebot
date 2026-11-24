@echo off
setlocal EnableExtensions EnableDelayedExpansion

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

rem --- if this folder has its own downloads\data, use it instead of the baked URLs
rem --- (this is what makes a copied run\ folder self-contained)
set "DATA_OPTS="
set "LOCAL_DATA=%APP_ROOT%downloads\data"
if exist "%LOCAL_DATA%\moviedb.txt.xz" (
    set "LOCAL_DATA_URI=file:///!LOCAL_DATA:\=/!"
    set "DATA_OPTS=-Durl.release-groups=!LOCAL_DATA_URI!/release-groups.txt.xz -Durl.query-blacklist=!LOCAL_DATA_URI!/query-blacklist.txt.xz -Durl.series-mappings=!LOCAL_DATA_URI!/series-mappings.txt.xz -Durl.movie-list=!LOCAL_DATA_URI!/moviedb.txt.xz -Durl.thetvdb-index=!LOCAL_DATA_URI!/thetvdb.txt.xz -Durl.anidb-index=!LOCAL_DATA_URI!/anidb.txt.xz -Durl.osdb-index=!LOCAL_DATA_URI!/osdb.txt.xz"
)

rem --- pick a JavaFX-enabled JDK, so MediaInfo/JavaFX features keep working
set "JAVA_EXE=java"
if defined FILEBOT_JAVA if exist "%FILEBOT_JAVA%" set "JAVA_EXE=%FILEBOT_JAVA%"
if "%JAVA_EXE%"=="java" if defined JAVA_HOME if exist "%JAVA_HOME%\jmods\javafx.controls.jmod" set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"
if "%JAVA_EXE%"=="java" if exist "%APP_ROOT%jdk\bin\java.exe" if exist "%APP_ROOT%jdk\jmods\javafx.controls.jmod" set "JAVA_EXE=%APP_ROOT%jdk\bin\java.exe"
if "%JAVA_EXE%"=="java" if exist "C:\Program Files\Zulu\zulu11.92.113-ca-fx-jdk11.0.33-win_x64\bin\java.exe" set "JAVA_EXE=C:\Program Files\Zulu\zulu11.92.113-ca-fx-jdk11.0.33-win_x64\bin\java.exe"

rem --- prefer filebot.jar next to this script, else the newest dist\FileBot_*.jar
set "JAR=%APP_ROOT%filebot.jar"
if not exist "%JAR%" for %%J in ("%APP_ROOT%dist\FileBot_*.jar") do set "JAR=%%~fJ"
if not exist "%JAR%" (
    echo FileBot jar not found. Run build.cmd first, or put filebot.jar next to this script.
    exit /b 1
)

"%JAVA_EXE%" ^
 -Dapplication.deployment=msi ^
 -Dapplication.update=skip ^
 -Dapplication.help=skip ^
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
 %DATA_OPTS% ^
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
