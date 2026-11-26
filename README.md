# FileBot 4.8.0 — private Windows build

Private fork of the last open-source FileBot source snapshot (version 4.8.0, fork point 23 March 2018), adapted for local use on Windows. The original upstream history is preserved on the [`fork-point`](../../tree/fork-point/) branch.

## Requirements

- Windows 10/11 x64
- Java 21. The build needs a JavaFX-enabled JDK; `build.cmd` can download Zulu 21 FX if no suitable JDK is found.
- Internet access for the first build (Ant, Ivy, Maven Central dependencies, and possibly the JDK/JavaFX SDK)

Maven and Gradle are not used. The build is Apache Ant + Ivy, bootstrapped by `build.cmd`.

## Build

From the repository root:

```bat
build.cmd
package.cmd
```

- `build.cmd` resolves dependencies and produces `dist\FileBot_4.8.0.jar`.
- `package.cmd` assembles the self-contained `run\` folder: jar, launcher and Windows x64 native libraries.

Ant, Ivy and any downloaded JDK/JavaFX SDK are cached in `%LOCALAPPDATA%\filebot-build-tools` (override with `FILEBOT_TOOLS_DIR`).

## Run

```bat
run\filebot.cmd                 :: start the GUI
run\filebot.cmd -version
run\filebot.cmd -rename ...     :: command-line use
```

`filebot.cmd` keeps console logging visible, forwards all arguments (including files dragged onto it), configures the Windows native libraries, and selects JavaFX. JavaFX can come from an FX-enabled JDK or an external OpenJFX SDK. If neither is available, the launcher downloads the pinned OpenJFX 21.0.7 SDK once. For offline use, place `javafx-sdk-21.0.7` in `run\javafx-sdk` or set `FILEBOT_JAVAFX`.

`java -jar dist\FileBot_4.8.0.jar` still works for CLI use, but without the launcher you must set the native library paths yourself (MediaInfo, 7-Zip extraction, AcoustID) and supply JavaFX on the module path for GUI operations.

## Changes from upstream

- **Java 21:** the build and runtime target JDK 21; JAXB is bundled so rename history works on modern JDKs. The obsolete SecurityManager sandbox was removed.
- **Offline data and scripts:** the 2018 data indexes and signed `fn:` script bundle are embedded from `downloads/` into the jar. No `app.filebot.net` update/data/script calls remain.
- **UI cleanup:** removed the update check, Getting Started page, donation/App Store prompt and the old Help menu.
- **Windows-only:** removed Mac/Linux platform code and native binaries; only the `win32-x64` natives are included.
- **Simplified packaging:** removed the installer/UWP/deploy/website targets and their dependencies. The only outputs are the fat jar and the `run\` folder.
- **Runtime JavaFX:** loaded from an FX-enabled JDK or an OpenJFX SDK; `filebot.cmd` downloads the SDK on demand.
- **Build helpers:** `build.cmd`/`build.ps1`, `package.cmd` and `filebot.cmd`.

Live metadata lookups still use TheMovieDB, TheTVDB, TVMaze, AniDB, OMDb, OpenSubtitles, Fanart.tv and AcoustID. The embedded indexes supply local name matching.

## User data

Settings, cache and rename history live in `%USERPROFILE%\.filebot` by default. For a portable layout:

```bat
-Djava.util.prefs.PreferencesFactory=net.filebot.util.prefs.FilePreferencesFactory
-Dnet.filebot.util.prefs.file=<path>\prefs.properties
-Dapplication.dir=<path>
```

## Licence

[Modified "Don't Be A Dick" public licence](LICENSE.md).
