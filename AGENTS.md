# AGENTS.md

## What this repository is

- **FileBot 4.8.0**, the last open-source snapshot of the FileBot source (fork point 2018-03-23). `master` is that snapshot plus README/build-config commits; `origin/fork-point` holds the upstream history.
- Java application: Swing desktop UI + command-line interface, with embedded Groovy 2.4.13 for scripting.
- Licence: [LICENSE.md](LICENSE.md) (modified "Don't Be A Dick" public licence). This checkout is used for **private builds**.
- **Do not change source files, `app.properties` or `build.xml` without the user's approval.** This file documents what is known to work.

## Repository layout

| Path | Purpose |
|---|---|
| `source/` | Java source (385 files), resources, property files. Starts at `net/filebot/Main.java`. |
| `test/` | JUnit sources; **not** compiled by the `fatjar` target. |
| `lib/jars/` | Hand-vendored jars (`jacksum`, `simmetrics`, `xmlrpc`). |
| `lib/native/win32-x64/` | Windows x64 native binaries used by `filebot.cmd` (MediaInfo, 7-Zip-JBinding, fpcalc, jnidispatch). `win32-x86` remains too; the Mac/Linux folders were removed. |
| `downloads/` | Offline snapshots of the data indexes and signed `fn:` script bundle. Embedded into the fat jar at build time; no runtime fetch. |
| `build.xml` | Ant build. Default target is `fatjar`. |
| `build.cmd`, `build.ps1` | One-command private build bootstrap (JDK detection, Ant/Ivy cache, resolve, slf4j fix, fatjar). |
| `filebot.cmd` | Windows launcher for the built jar: JDK/FX selection, native paths, console logging. |
| `package.cmd` | Assembles a self-contained `run\` folder (jar, launcher, native libs). |
| `run/` | Generated run folder (gitignored); run it with `run\filebot.cmd`. |
| `ivy.xml` | Dependency versions; resolved with Apache Ivy. |
| `app.properties` | Application version, main class, API keys, service URLs, target JVM. |
| `build-data/` | Maintenance Groovy scripts run *by FileBot itself* (`filebot -script ...`). Not part of the build. |

## Toolchain

| Tool | Requirement | Notes |
|---|---|---|
| **Java (build)** | **Java 21** (`jvm.version: 21`, `--release 21`). Use **Zulu 21 FX** so JavaFX is available to javac. | Four source files import `javafx.*`, so javac needs JavaFX. Verified with Zulu 21 FX **21.0.13.1** (clean rebuild of all 385 source files). |
| **Java (runtime)** | Java **21+**. Verified on Zulu 21 FX, plain Zulu 21 (CLI), and Corretto 25 with an external OpenJFX SDK 21.0.7. | JAXB is bundled in the fat jar. `initializeSecurityManager()` was removed because JDK 21 rejects it; format expressions run without a SecurityManager sandbox. JavaFX can come from an FX-enabled JDK (Zulu FX) or from an external OpenJFX SDK loaded by `filebot.cmd` via `--module-path`. If neither exists, `filebot.cmd` downloads the SDK once; plain JDK 21 works for CLI and filename-based renaming without either. |
| **Apache Ant** | **1.9.8+** minimum (the javac `release` attribute); verified **1.10.15**. | Ant is not installed on this machine; `build.cmd` downloads/caches 1.10.15. |
| **Apache Ivy** | Any 2.4+ / 2.5+. Verified **2.4.0** and **2.5.3**. | Must be on Ant's classpath (`ant -lib ivy.jar`). Ivy resolves all dependencies from Maven Central. |
| **Maven** | **Not used.** There is no `pom.xml`; do not add Maven/Gradle. | Maven 3.9.16 is installed but irrelevant. |
| **Groovy** | **Not a build tool.** `groovy-all 2.4.13` is bundled as a runtime library; there are no `.groovy` sources in the build. | The `build-data/*.groovy` maintenance scripts are run with the built FileBot jar, not with a Groovy install. |
| **Git** | Required. | `revision` target runs `git rev-list --count master`; branch `master` must exist. |
| Packaging tools | Not needed. | The packaging targets (`cask`, `deb`, `snap`, `appx`, `msi`, `portable`, `spk`, deploy/website targets) were removed; only `resolve`, `build`, `jar`, `fatjar`, `clean` and `eclipse-properties-builder` remain. |

Known good downloads for this machine:

- Zulu 21 FX JDK: `https://cdn.azul.com/zulu/bin/zulu21.54.201-ca-fx-jdk21.0.13.1-win_x64.zip`
- OpenJFX 21.0.7 SDK (runtime-only JavaFX): `https://download2.gluonhq.com/openjfx/21.0.7/openjfx-21.0.7_windows-x64_bin-sdk.zip`
- Apache Ant 1.10.15: `https://archive.apache.org/dist/ant/binaries/apache-ant-1.10.15-bin.zip`
- Apache Ivy 2.4.0: `https://repo1.maven.org/maven2/org/apache/ivy/ivy/2.4.0/ivy-2.4.0.jar`

Local verified JDK (downloaded/extracted by `build.ps1`, not installed):
`%LOCALAPPDATA%\filebot-build-tools\zulu21fx\zulu21.54.201-ca-fx-jdk21.0.13.1-win_x64` (Zulu 21.0.13.1, contains `jmods\javafx.*.jmod`). `build.ps1` downloads it if missing; `filebot.cmd` searches `JAVA_HOME`, `jdk\` next to the launcher, that cache, and `C:\Program Files\Zulu\zulu21*-ca-fx-jdk*`.

Local verified OpenJFX SDK (runtime-only):
`%LOCALAPPDATA%\filebot-build-tools\javafx21\javafx-sdk-21.0.7` (OpenJFX 21.0.7 `lib` + `bin`). `filebot.cmd` uses it when the selected Java has no built-in JavaFX, or when `FILEBOT_JAVAFX` points at it. If no SDK is present, `filebot.cmd` downloads this pinned SDK once from the official Gluon URL. The build itself still uses Zulu 21 FX for javac; the SDK is only for runtime.

JDK 21 note: the original project targeted Java 10, but JDK 10 with JavaFX is no longer readily redistributable. The build now targets **21** with Zulu 21 FX; `jre.version`/`jvm.version` are 21 and `--illegal-access=permit` was removed from the default options. `Main.initializeSecurityManager()` was removed because JDK 21 rejects `Policy`/`SecurityManager`; format expressions are no longer sandboxed (acceptable for private use).

## One-command build (verified 2026-11-24)

```bat
build.cmd
package.cmd
```

`package.cmd` assembles `run\` from `dist\`, `lib\native\win32-x64` and `filebot.cmd`; run it with `run\filebot.cmd`. `dist\` itself is not a good run folder because `build.cmd`/`ant clean` deletes it.

[build.ps1](build.ps1) is the actual bootstrap (the `.cmd` is a thin shim). It:

- finds a Java 21 FX JDK (`FILEBOT_JDK`, `JAVA_HOME`, the `zulu21fx` cache, or `C:\Program Files\Zulu\zulu21*-ca-fx-jdk*`), and downloads Zulu 21 FX only if none is usable;
- downloads and caches Ant 1.10.15 and Ivy 2.4.0 in `%LOCALAPPDATA%\filebot-build-tools` (override with `FILEBOT_TOOLS_DIR`);
- runs `resolve` on first use and fixes the missing `slf4j-api.jar`;
- runs `ant clean fatjar`; `build.xml` embeds `downloads/data` and `downloads/scripts` into the jar.

Optional Ant targets can be passed as space-separated arguments, e.g. `build.cmd fatjar` or `build.cmd -projecthelp` (the `.cmd` forwards them via `FILEBOT_ANT_ARGS`). Output: `dist/FileBot_4.8.0.jar` (~87 MB with the embedded data).

The manual steps below are the same sequence, for reference or CI.

## Build a fat jar (verified 2026-11-24)

Run from the repository root. Use a JDK 21 FX `JAVA_HOME` and an Ant distribution.

```bat
:: 1. Resolve dependencies into lib/ivy (downloads ~177 MB of runtime + transitive optional/test artifacts)
ant -lib C:\path\to\ivy-2.4.0.jar resolve

:: 2. Fresh resolves do NOT produce the slf4j-api main artifact (see quirks).
::    Drop it into the path build.xml expects:
curl -L -o lib\ivy\jar\slf4j-api.jar ^
  https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar

:: 3. Build the fat jar (downloads are embedded by build.xml), targeting Java 21
ant -lib C:\path\to\ivy-2.4.0.jar fatjar
```

PowerShell note: if you pass extra `-D` overrides, quote them (e.g. `'-Dkey=value'`); unquoted `-D` arguments containing dots can be split by PowerShell 5.1. `cmd.exe` and Git Bash's `bin/ant` do not have this problem.

Output: `dist/FileBot_4.8.0.jar` (~87 MB, entries stored uncompressed, `Main-Class: net.filebot.Main`). Copy/rename it to `filebot.jar` if desired.

The Java target comes from `app.properties` (`jvm.version: 21` → `--release 21`). Use a **JDK 21 FX** so javac can see JavaFX; Zulu 21 FX worked. Plain JDK 21 cannot compile the four JavaFX files.

The data indexes and the signed `fn:` script bundle are copied from `downloads/` into the jar by the `build` target. To refresh them, update `downloads/` and rebuild; there are no runtime URL overrides anymore.

## Run the fat jar (verified)

### Daily launcher: `filebot.cmd`

`filebot.cmd` is the intended Windows entry point. It keeps console logging visible and forwards all arguments, including files dragged onto the `.cmd`:

```bat
filebot.cmd                 :: start the GUI
filebot.cmd -version
filebot.cmd -rename ...     :: CLI
```

It:

- picks `FILEBOT_JAVA`, a Java 21 `JAVA_HOME`, a `jdk\` folder next to the script, the `zulu21fx` cache, `C:\Program Files\Zulu\zulu21*-ca-fx-jdk*`, or `java` on `PATH`;
- if the selected Java has no built-in JavaFX, finds an external OpenJFX SDK (`FILEBOT_JAVAFX`, the `javafx21` cache, `C:\Program Files\javafx-sdk-*`, or `%APP_ROOT%\javafx-sdk`) — or downloads the pinned OpenJFX 21.0.7 SDK once into the cache — and launches with `--module-path <sdk>\lib --add-modules javafx.controls,javafx.swing,javafx.fxml --enable-native-access=javafx.graphics`;
- uses actual Windows OS detection (`Settings.isWindowsOs()`): system L&F, `WinAppUtilities` tweaks, hides the unsupported `CLONE` action;
- sets the Windows options (`useNativeShell=true`, NTFS extended attributes, system proxies);
- points JNA / `java.library.path` at `lib\native\win32-x64` (plus the FX SDK `bin` when used) and sets `fpcalc`;
- passes `JAVA_OPTS` and `FILEBOT_OPTS` through.

The data indexes and signed `fn:` script bundle are embedded in the jar, so there are no `downloads\` files to carry around and no `app.filebot.net` calls. If you run `java -jar` directly instead, the Windows L&F still applies (it is detected from the OS), but you lose the native-dependent features (MediaInfo/`{vf}`, 7-Zip extraction, AcoustID, xattr metadata) and any external JavaFX module path. CLI identification/renaming/history still work; UI renaming on a non-JavaFX JDK can fail because the standard move/copy path uses `ProgressMonitor` (JavaFX), so use the `.cmd` or add the module path manually.

### Self-contained run folder

```bat
package.cmd
run\filebot.cmd
```

`package.cmd` creates (and recreates) `run\`:

```text
run\filebot.jar
run\filebot.cmd
run\lib\native\win32-x64\*        (MediaInfo, 7-Zip-JBinding, jnidispatch, fpcalc)
```

Do **not** use `dist\` as the run folder — `build.cmd`/`ant clean` deletes it. `run/` is gitignored.

JavaFX is supplied by the machine: an FX-enabled JDK, the cached OpenJFX SDK, `C:\Program Files\javafx-sdk-*`, or `run\javafx-sdk` (checked by `filebot.cmd`). If none is present, `filebot.cmd` downloads the pinned SDK on first launch; for an offline machine, copy `javafx-sdk-21.0.7` to `run\javafx-sdk`, or set `FILEBOT_JAVAFX`.

### Equivalent manual command (verified)

```bat
java ^
  -Djna.library.path=C:\myprogs\filebot\lib\native\win32-x64 ^
  -Djava.library.path=C:\myprogs\filebot\lib\native\win32-x64 ^
  -Dnet.filebot.AcoustID.fpcalc=C:\myprogs\filebot\lib\native\win32-x64\fpcalc.exe ^
  -jar FileBot_4.8.0.jar
```

The `.cmd` adds `-DuseNativeShell=true`, `-DuseExtendedFileAttributes=true`, `-DuseCreationDate=false`, `-Djava.net.useSystemProxies=true`, `-Djna.nosys=true`, `-Djna.nounpack=true` and `-Djna.boot.library.path`. When it uses an external OpenJFX SDK it also adds `--module-path <sdk>\lib --add-modules javafx.controls,javafx.swing,javafx.fxml --enable-native-access=javafx.graphics`.

- `jna.library.path` / `java.library.path` enable MediaInfo (`{vf}`, `-mediainfo`), 7-Zip-JBinding (`-extract`) and JNA itself. Without them, filename-based renaming still works but video metadata is empty and archive extraction fails.
- `net.filebot.AcoustID.fpcalc` is only needed for music/AcoustID lookups.
- **JAXB on Java 11+ (already handled):** the `fatjar` target in `build.xml` now bundles `jaxb-api`, `jaxb-impl` and `activation`, so rename history is written on Java 11+. Verified: a real `--action move` produced `history.xml` with no `NoClassDefFoundError`. If you build from an unmodified upstream `build.xml` (without those zipfilesets), a real rename still succeeds but the shutdown hook prints `NoClassDefFoundError: javax/xml/bind/JAXBContext` and does not write `history.xml`; either add the jars to the fat jar or run with `-cp "FileBot_4.8.0.jar;dist\lib\jaxb-api.jar;dist\lib\jaxb-impl.jar;dist\lib\activation.jar" net.filebot.Main ...`.

- Default user data lives in `%USERPROFILE%\.filebot` (settings/cache/history). Portable mode: add `-Djava.util.prefs.PreferencesFactory=net.filebot.util.prefs.FilePreferencesFactory -Dnet.filebot.util.prefs.file=<path>\prefs.properties -Dapplication.dir=<path>`.

Verified on JDK 21 (Zulu 21 FX, plain Zulu 21, and Corretto 25 + OpenJFX SDK 21.0.7) with the built jar and `filebot.cmd`: `-version`, `-help`, `-mediainfo`, `-rename --action test` and a real `--action move` (including `history.xml` via bundled JAXB and the Windows native-shell move), inline `g:` Groovy, `fn:sysinfo` from the embedded signed bundle (Groovy 2.4.13), TheMovieDB lookups, and the embedded data indexes. GUI startup was checked both with the Zulu FX JDK and with plain Corretto 25 + external OpenJFX SDK; the old ControlsFX `ProgressDialog` also works on JavaFX 21. The launcher's automatic SDK download/extract path was exercised with the SDK cache removed.

## Embedded data, scripts and external services

- `downloads/data/*.txt.xz` (7 indexes) and `downloads/scripts/m1.jar.xz` are copied into the jar by the `build` target. `ReleaseInfo.resource()` reads classpath `net/filebot/media/data/<name>.txt.xz` through `XZInputStream`; there is no Ehcache/URL fetch.
- `ScriptSource.GITHUB_STABLE` (legacy name used by the bundled `sysinfo` script) reads classpath `net/filebot/cli/m1.jar.xz` and verifies it with `repository.cer`. `g:` inline scripts and local `.groovy` files still work; the `dev:` (GitHub master) and remote `http(s)` script sources were removed.
- No `app.filebot.net` update/data/script calls remain. The update dialog, Getting Started page and donation/App Store prompt were removed. `url.*`, `github.*`, `update.url`, `donate.url`, `link.mas`, `link.mws` and `link.app.help` were removed from `app.properties`/`Settings.properties`/`ReleaseInfo.properties`.
- `Settings.getAppStoreLink()` still returns `null` because the bundled 2018 scripts check `Settings.appStoreLink`; the private build has no store link.
- Live metadata services are still used for lookups: TheMovieDB, OMDb, TheTVDB, TVMaze, AniDB, OpenSubtitles, Fanart.tv and AcoustID. Their API keys remain in `app.properties`. The 2018 embedded indexes only supply local name matching.
- User-initiated links remain in the Format dialog; they open only when clicked. The old Help menu was removed with `FileBotMenuBar`.
- One remaining automatic external call outside the metadata clients: `ImageMetadata.locate()` calls Google Maps geocoding when a format binding requests photo location (`{location}`). Remove it if you want zero incidental calls.
- The embedded 2018 scripts can still make their own network calls when explicitly run: `fn:sysinfo` checks `app.filebot.net/update.xml`, and `fn:amc` references `app.filebot.net/icon.png` for notifications. The bundle is signed, so changing those requires re-signing it (or replacing `repository.cer`); the GUI drag-and-rename workflow does not run these scripts.

## Known build/runtime quirks

1. **`slf4j-api.jar` missing after a fresh `resolve`.** `slf4j-jdk14`'s POM declares `slf4j-api` a second time as a test-jar, and Ivy's default retrieve pattern has no classifier; the main artifact is never fetched. The test-jar lands at `lib/ivy/test-jar/slf4j-api.jar`, and `fatjar` fails with `The archive slf4j-api.jar doesn't exist`. Fix by downloading the main 1.7.25 jar to `lib/ivy/jar/slf4j-api.jar`, or add `org.slf4j#slf4j-api;1.7.25` to `ivy.xml`.
2. **Packaging dependencies/assets removed:** `ivy.xml` no longer pulls `jdeb` or `ant-spk`, the packaging targets and `init` taskdefs are gone, and `installer/`, `website/` and the unused `appbundler.jar`/`ObjCBridge.jar`/`ant-compress.jar` were removed. The website review generation (`reviews.tsv`) was removed with them.
3. **`resolve` is a separate target.** The default `fatjar` target does not depend on it. Run `resolve` once (or after changing `ivy.xml`).
4. **`resolve` downloads ~177 MB** of runtime plus transitive optional/test artifacts. All direct dependencies are on Maven Central.
5. **`resolve` rewrites `lib/native/win32-x64/**`** (tracked files). It imports Windows x64 natives only; the Mac/Linux native folders were removed. `lib/ivy/`, `build/`, `dist/`, `cache/` are gitignored.
6. **`fatjar` uses `duplicate="fail"`.** Adding jars to it later can fail on duplicate entries (`module-info.class`, overlapping `META-INF/services`, etc.). Use explicit `include` patterns in any new `zipfileset`.
7. **The fat jar includes JAXB** (`jaxb-api`, `jaxb-impl`, `activation`) and **omits native libraries**. JavaFX is not bundled; it comes from an FX-enabled JDK or an external OpenJFX SDK (which `filebot.cmd` can download on demand).
8. **Prompts/update removed:** `SupportDialog` and `GettingStartedStage` were deleted, and `Main` no longer checks for updates or shows Getting Started. Legacy bundled scripts still reference `ScriptSource.GITHUB_STABLE` and `Settings.appStoreLink`; both names are preserved (the latter returns `null`).
9. **Build revision** comes from `git rev-list --count master` (5354 in this checkout). It is baked into `Settings.properties` and stored in the jar manifest.
10. **`test/` is not built** by the Ant file; there is no `test`/`junit` target.
11. **Embedded indexes are frozen** at the snapshots in `downloads/`; update those files and rebuild to refresh them. Live APIs still supply details for newer media.
12. **JDK 21 compile warnings are expected:** `AccessController`, `AccessControlContext`, `SecurityManager` and `Thread.stop()` are deprecated for removal. `SecureCompiledScript`/`PrivilegedInvocation` still use `AccessController`, but without a global SecurityManager it is effectively a no-op. The build succeeds with warnings.
13. **JavaFX can be external:** the build uses Zulu 21 FX (javac sees JavaFX), but the runtime does not require an FX JDK. `filebot.cmd` can use an OpenJFX SDK with a plain JDK 21+; verified with Corretto 25 + OpenJFX 21.0.7. If neither an FX JDK nor an SDK is found, it downloads the pinned OpenJFX 21.0.7 SDK once into `%LOCALAPPDATA%\filebot-build-tools\javafx21` (official Gluon URL; launcher bootstrap only). `--enable-native-access=javafx.graphics` is passed when using the external SDK (needed to silence JDK 25 native-access warnings).
14. **Windows-only cleanup:** Mac/Linux platform classes and branches were removed (`MacAppUtilities`, `DropToUnlock`, `MacXattrView`, GNOME GVFS, `FileBotMenuBar`). `Settings.isWindowsOs()` (`os.name` starts with `Windows`) now drives the system L&F, `WinAppUtilities` and hiding `CLONE`; the `application.deployment=msi` launch hack is gone. `Settings.useGVFS()` remains only because the bundled 2018 scripts reference it (it returns the system property; the app no longer uses it). `ObjCBridge.jar` was removed along with the Mac code.

## Key source files for runtime behaviour

| File | What it controls |
|---|---|
| `source/net/filebot/Main.java` | Startup; JavaFX init, window setup. No update/Getting Started checks, no SecurityManager. |
| `source/net/filebot/Settings.properties` | API keys and build-time placeholders — `@{...}` replaced at build time. |
| `source/net/filebot/media/ReleaseInfo.properties` | Release patterns only; the data indexes are embedded resources. |
| `source/net/filebot/media/ReleaseInfo.java` | Classpath XZ data loading (`net/filebot/media/data/`); pattern property overrides. |
| `source/net/filebot/cli/ScriptSource.java` | Embedded signed `fn:` bundle (`m1.jar.xz`), `g:` inline, local `.groovy`; signature via `repository.cer`. |
| `source/net/filebot/History.java` | JAXB history export (JAXB is bundled in the fat jar). |
| `build.xml` (`build` target) | Embeds `downloads/data` and `downloads/scripts/m1.jar.xz` into the jar. |

## Working agreements

- No Maven/Gradle; keep the Ant + Ivy build. `build.cmd` builds; `package.cmd` assembles `run\`; `run\filebot.cmd` runs the result.
- The application is Windows-only now; do not reintroduce Mac/Linux platform branches unless the user asks.
- Build outputs (`build/`, `dist/`, `run/`, `cache/`, `lib/ivy/`) are disposable and gitignored; do not commit them.
- Ant/Ivy downloads are cached outside the repo in `%LOCALAPPDATA%\filebot-build-tools` (`FILEBOT_TOOLS_DIR` overrides).
- `downloads/` contains the build-time source for the embedded indexes and signed script bundle; update those files and rebuild to refresh them.
- Any source-level change (removing features, adding bindings, changing prompts) needs explicit user approval.
