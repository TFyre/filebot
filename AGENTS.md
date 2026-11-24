# AGENTS.md

## What this repository is

- **FileBot 4.8.0**, the last open-source snapshot of the FileBot source (fork point 2018-03-23). `master` is that snapshot plus README/build-config commits; `origin/fork-point` holds the upstream history.
- Java application: Swing desktop UI + command-line interface, with embedded Groovy 2.4.13 for scripting.
- Licence: [LICENSE.md](LICENSE.md) (modified "Don't Be A Dick" public licence). This checkout is used for **private builds**.
- **Do not change source files, `app.properties` or `build.xml` without the user's approval.** This file documents what is known to work.

## Repository layout

| Path | Purpose |
|---|---|
| `source/` | Java source (395 files), resources, property files. Starts at `net/filebot/Main.java`. |
| `test/` | JUnit sources; **not** compiled by the `fatjar` target. |
| `lib/jars/` | Hand-vendored jars (`xmlrpc`, `ObjCBridge`, `simmetrics`, `jacksum`, `appbundler`). |
| `lib/native/<platform>/` | Native binaries already present for all supported platforms (MediaInfo, 7-Zip-JBinding, fpcalc, jnidispatch). |
| `downloads/` | Offline snapshots of resources the app normally fetches from `app.filebot.net` (see below). |
| `build.xml` | Ant build. Default target is `fatjar`. |
| `build.cmd`, `build.ps1` | One-command private build bootstrap (JDK detection, Ant/Ivy cache, resolve, slf4j fix, fatjar). |
| `filebot.cmd` | Windows launcher for the built jar: JDK selection, Windows deployment profile, native paths, console logging. |
| `package.cmd` | Assembles a self-contained `run\` folder (jar, launcher, native libs, downloads). |
| `run/` | Generated run folder (gitignored); run it with `run\filebot.cmd`. |
| `ivy.xml` | Dependency versions; resolved with Apache Ivy. |
| `app.properties` | Application version, main class, API keys, service URLs, target JVM. |
| `build-data/` | Maintenance Groovy scripts run *by FileBot itself* (`filebot -script ...`). Not part of the build. |
| `installer/`, `website/` | Packaging/website assets; not needed for a jar build. |

## Toolchain

| Tool | Requirement | Notes |
|---|---|---|
| **Java (build)** | JDK **10** with JavaFX is what the project targets (`jvm.version: 10`, `--release 10`). In practice use **Zulu 11 FX** and build with `-Djvm.version=11`. | Four source files import `javafx.*`, so javac needs JavaFX on the compile classpath/module path. A plain OpenJDK 10 or 11 (no FX) **cannot compile** the source. Verified with Zulu 11 FX **11.0.33** and **11.0.33.1** (clean rebuild of all 395 files). |
| **Java (runtime)** | Java **11+**. Verified on Zulu 11 FX (full features) and Zulu 17 (Swing/CLI; JavaFX features unavailable). | Java 11 removed the JAXB runtime (`javax.xml.bind`) from the JDK. The current `build.xml` bundles JAXB into the fat jar, so history export works; the stock/upstream fat jar omits it and fails on shutdown (see Runtime). Java 21+ additionally has no usable `SecurityManager` (exception is caught; log noise, sandbox disabled). |
| **Apache Ant** | **1.9.1+** minimum. Verified **1.10.15**. | The build uses namespaced `if:`/`unless:` attributes (Ant 1.9.1+) and `if:true`. Ant is **not installed** on this machine as of 2026-11-24. |
| **Apache Ivy** | Any 2.4+ / 2.5+. Verified **2.4.0** and **2.5.3**. | Must be on Ant's classpath (`ant -lib ivy.jar`). Ivy resolves all dependencies from Maven Central. |
| **Maven** | **Not used.** There is no `pom.xml`; do not add Maven/Gradle. | Maven 3.9.16 is installed but irrelevant. |
| **Groovy** | **Not a build tool.** `groovy-all 2.4.13` is bundled as a runtime library; there are no `.groovy` sources in the build. | The `build-data/*.groovy` maintenance scripts are run with the built FileBot jar, not with a Groovy install. |
| **Git** | Required. | `revision` target runs `git rev-list --count master`; branch `master` must exist. |
| Packaging tools | Not needed for `fatjar`. | `gpg`, `scp`, `codesign`, `productbuild`, `snapcraft`, `makepri`/`makeappx`, WiX `candle`/`light` are only used by `deb`/`msi`/`appx`/`cask`/`deploy-*` targets. |

Known good downloads for this machine:

- Zulu 11 FX JDK: `https://cdn.azul.com/zulu/bin/zulu11.92.201-ca-fx-jdk11.0.33.1-win_x64.zip`
- Apache Ant 1.10.15: `https://archive.apache.org/dist/ant/binaries/apache-ant-1.10.15-bin.zip`
- Apache Ivy 2.4.0: `https://repo1.maven.org/maven2/org/apache/ivy/ivy/2.4.0/ivy-2.4.0.jar`

Local verified JDK (ZIP extracted, **not** installed; set `JAVA_HOME` per build shell):
`C:\Program Files\Zulu\zulu11.92.113-ca-fx-jdk11.0.33-win_x64` (Zulu 11.0.33, contains `jmods\javafx.*.jmod`). The existing `C:\Program Files\Zulu\zulu-11` is the plain JDK and has **no** JavaFX.

Java 10 note: Oracle JDK 10.0.2 (with JavaFX + JAXB) is only behind an Oracle login; Zulu 10 does **not** include JavaFX, BellSoft's Liberica 10 "Full" (which did) is no longer offered through their API, and the OpenJFX 10 SDK is no longer publicly downloadable. Hence the Zulu 11 FX + `-Djvm.version=11` recipe.

## One-command build (verified 2026-11-24)

```bat
build.cmd
package.cmd
```

`package.cmd` assembles `run\` from `dist\`, `lib\native\win32-x64`, `downloads\` and `filebot.cmd`; run it with `run\filebot.cmd`. `dist\` itself is not a good run folder because `build.cmd`/`ant clean` deletes it.

[build.ps1](build.ps1) is the actual bootstrap (the `.cmd` is a thin shim). It:

- finds `FILEBOT_JDK` / `JAVA_HOME` / the local Zulu 11 FX path, and downloads Zulu 11 FX only if none is usable;
- downloads and caches Ant 1.10.15 and Ivy 2.4.0 in `%LOCALAPPDATA%\filebot-build-tools` (override with `FILEBOT_TOOLS_DIR`);
- runs `resolve` on first use and fixes the missing `slf4j-api.jar`;
- runs `ant clean fatjar` with `-Djvm.version=11` and the local `downloads/` URLs.

Optional Ant targets can be passed as space-separated arguments, e.g. `build.cmd fatjar` or `build.cmd -projecthelp` (the `.cmd` forwards them via `FILEBOT_ANT_ARGS`). Output: `dist/FileBot_4.8.0.jar`.

The manual steps below are the same sequence, for reference or CI.

## Build a fat jar (verified 2026-11-24)

Run from the repository root. Use a JDK 11 FX `JAVA_HOME` and an Ant distribution.

```bat
:: 1. Resolve dependencies into lib/ivy (downloads ~190 MB)
ant -lib C:\path\to\ivy-2.4.0.jar resolve

:: 2. Fresh resolves do NOT produce the slf4j-api main artifact (see quirks).
::    Drop it into the path build.xml expects:
curl -L -o lib\ivy\jar\slf4j-api.jar ^
  https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar

:: 3. Build the fat jar, baking the offline downloads and targeting Java 11
ant -lib C:\path\to\ivy-2.4.0.jar -Djvm.version=11 ^
  -Durl.data=file:///C:/myprogs/filebot/downloads/data ^
  -Dgithub.stable=file:///C:/myprogs/filebot/downloads/scripts/m1.jar.xz ^
  fatjar
```

PowerShell note: quote every `-D` argument (`'-Djvm.version=11'`, `'-Durl.data=...'`). Unquoted, PowerShell 5.1 splits `-Djvm.version=11` into `-Djvm` and `.version=11`, and Ant fails with `Target "11" does not exist`. `cmd.exe` and Git Bash's `bin/ant` do not have this problem.

Output: `dist/FileBot_4.8.0.jar` (~84 MB, entries stored uncompressed, `Main-Class: net.filebot.Main`). Copy/rename it to `filebot.jar` if desired.

Why `-Djvm.version=11`: `build.xml` compiles with `release="${jvm.version}"` (10 by default). Zulu 11 FX's javac does **not** expose `javafx.*` under `--release 10`; `--release 11` does. With a genuine JDK 10 that contains JavaFX, omit this override.

Why the `-Durl.*` overrides: they are substituted into `ReleaseInfo.properties`/`Settings.properties` at build time (the `copy-replace` macro includes command-line `-D` user properties). Without them the jar points at dead `app.filebot.net` URLs and movie detection fails. The baked `file:///` paths are absolute; if the repository moves, rebuild or use the runtime overrides below.

## Run the fat jar (verified)

### Daily launcher: `filebot.cmd`

`filebot.cmd` is the intended Windows entry point. It keeps console logging visible and forwards all arguments, including files dragged onto the `.cmd`:

```bat
filebot.cmd                 :: start the GUI
filebot.cmd -version
filebot.cmd -rename ...     :: CLI
```

It:

- picks `FILEBOT_JAVA`, a JavaFX-enabled `JAVA_HOME`, a `jdk\` folder next to the script, or the local Zulu 11 FX path (falling back to `java` on `PATH`);
- uses the Windows deployment profile (`-Dapplication.deployment=msi`: system L&F, `WinAppUtilities` tweaks, hides the unsupported `CLONE` action);
- sets the MSI-style options (`useNativeShell=true`, NTFS extended attributes, system proxies);
- points JNA / `java.library.path` at `lib\native\win32-x64` and sets `fpcalc`;
- skips the update and Getting Started checks;
- passes `JAVA_OPTS` and `FILEBOT_OPTS` through.

The launcher also uses `downloads\data` next to itself (via runtime `-Durl.*` overrides) when present, so the generated `run\` is self-contained for data. `fn:` scripts still use the build-time script-bundle path baked into the jar; the planned embedding change removes that limitation. If you run `java -jar` directly instead, you lose the Windows L&F and the native-dependent features (MediaInfo/`{vf}`, 7-Zip extraction, AcoustID, xattr metadata). CLI identification/renaming/history still work; UI renaming on a non-JavaFX JDK can fail because the standard move/copy path uses `ProgressMonitor` (JavaFX), so use the `.cmd`/FX JDK for the GUI.

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
run\downloads\data\*              (used by filebot.cmd at runtime)
run\downloads\scripts\*           (for the upcoming embedding change)
```

Do **not** use `dist\` as the run folder — `build.cmd`/`ant clean` deletes it. `run/` is gitignored.

### Equivalent manual command (verified)

```bat
java ^
  -Dapplication.update=skip ^
  -Dapplication.help=skip ^
  -Djna.library.path=C:\myprogs\filebot\lib\native\win32-x64 ^
  -Djava.library.path=C:\myprogs\filebot\lib\native\win32-x64 ^
  -Dnet.filebot.AcoustID.fpcalc=C:\myprogs\filebot\lib\native\win32-x64\fpcalc.exe ^
  -jar FileBot_4.8.0.jar
```

The `.cmd` adds `-Dapplication.deployment=msi`, `-DuseNativeShell=true`, `-DuseExtendedFileAttributes=true`, `-DuseCreationDate=false`, `-Djava.net.useSystemProxies=true`, `-Djna.nosys=true`, `-Djna.nounpack=true` and `-Djna.boot.library.path`.

- `application.update=skip` prevents the GUI's "New updates available" modal (`app.filebot.net/update.xml` advertises FileBot 5.3.0; this build's revision is 5354).
- `application.help=skip` skips the one-time JavaFX Getting Started page.
- `jna.library.path` / `java.library.path` enable MediaInfo (`{vf}`, `-mediainfo`), 7-Zip-JBinding (`-extract`) and JNA itself. Without them, filename-based renaming still works but video metadata is empty and archive extraction fails.
- `net.filebot.AcoustID.fpcalc` is only needed for music/AcoustID lookups.
- **JAXB on Java 11+ (already handled):** the `fatjar` target in `build.xml` now bundles `jaxb-api`, `jaxb-impl` and `activation`, so rename history is written on Java 11+. Verified: a real `--action move` produced `history.xml` with no `NoClassDefFoundError`. If you build from an unmodified upstream `build.xml` (without those zipfilesets), a real rename still succeeds but the shutdown hook prints `NoClassDefFoundError: javax/xml/bind/JAXBContext` and does not write `history.xml`; either add the jars to the fat jar or run with `-cp "FileBot_4.8.0.jar;dist\lib\jaxb-api.jar;dist\lib\jaxb-impl.jar;dist\lib\activation.jar" net.filebot.Main ...`.

- Default user data lives in `%USERPROFILE%\.filebot` (settings/cache/history). Portable mode: add `-Djava.util.prefs.PreferencesFactory=net.filebot.util.prefs.FilePreferencesFactory -Dnet.filebot.util.prefs.file=<path>\prefs.properties -Dapplication.dir=<path>`.

Verified working with the built jar and with `filebot.cmd`: `-version`, `-help`, `-mediainfo`, `-rename --action test` and a real `--action move` (including `history.xml` via bundled JAXB and the Windows native-shell move), inline `g:` Groovy, `fn:sysinfo` from the local signed script bundle, TheMovieDB lookups, and local data indexes.

## Runtime URLs and the `downloads/` folder

| Property / feature | Default URL | Status 2026-11-24 | Local copy | Override |
|---|---|---|---|---|
| `url.movie-list`, `url.thetvdb-index`, `url.anidb-index`, `url.osdb-index`, `url.release-groups`, `url.query-blacklist`, `url.series-mappings` (all built from `url.data`) | `https://app.filebot.net/data/*.txt.xz` | **404 (dead)** | `downloads/data/*.txt.xz` (7 files) | Build-time `-Durl.data=file:///.../downloads/data`, or per-key runtime `-Durl.movie-list=file:///...` etc. |
| `github.stable` (`fn:` scripts) | `https://app.filebot.net/scripts/m1.jar.xz` | **404 (dead)** | `downloads/scripts/m1.jar.xz` (signed bundle, 2018-03-16 r516) | **Build-time only**: `-Dgithub.stable=file:///.../m1.jar.xz` |
| `update.url` | `https://app.filebot.net/update.xml` | **alive**; advertises 5.3.0/r11096 | — | Build-time only; or runtime `-Dapplication.update=skip` |
| `github.master` (`dev:` scripts) | `https://raw.githubusercontent.com/filebot/scripts/master/` | alive | — | Build-time only |
| `link.app.help` (first-run Getting Started) | `https://www.filebot.net/getting-started/embed.html` | alive | — | Runtime `-Dapplication.help=skip` |

Important distinctions:

- `url.data` itself is only used at **build time** to expand `@{url.data}` in `source/net/filebot/media/ReleaseInfo.properties`. It is **not** read at runtime.
- At runtime, `ReleaseInfo.getProperty(name)` first checks `System.getProperty(name)`, so the seven individual `url.*` keys **can** be overridden per run with `-Durl.movie-list=...`; `file:` URLs work. This is useful if the jar was built without the local URL overrides.
- `github.stable` and `update.url` are read with `Settings.getApplicationProperty` (ResourceBundle only), so there is **no** runtime `-D` override; set them at build time or edit the bundled properties inside the jar.
- The data files are 2018 snapshots and are used for local name matching; detail/metadata requests still go to live services. TheMovieDB and OMDb responded successfully with the keys in `app.properties`; TheTVDB v1/v2 endpoints responded as well.
- Cache/expiry: `url.refresh` is a system property; the cache lives under the application dir (`~/.filebot/cache` by default).
- Confirmed failure mode with dead URLs: `-rename` prints `Resource not found: .../moviedb.txt.xz` and ends with "Failed to identify or process any files". The local overrides fix this entirely.

## Known build/runtime quirks

1. **`slf4j-api.jar` missing after a fresh `resolve`.** `slf4j-jdk14`'s POM declares `slf4j-api` a second time as a test-jar, and Ivy's default retrieve pattern has no classifier; the main artifact is never fetched. The test-jar lands at `lib/ivy/test-jar/slf4j-api.jar`, and `fatjar` fails with `The archive slf4j-api.jar doesn't exist`. Fix by downloading the main 1.7.25 jar to `lib/ivy/jar/slf4j-api.jar`, or add `org.slf4j#slf4j-api;1.7.25` to `ivy.xml`.
2. **`jdeb` is retrieved as type `maven-plugin`** (`lib/ivy/maven-plugin/jdeb.jar`), not `lib/ivy/jar/jdeb.jar`. This is fine: `init`'s classpath is every `**/*.jar` under `lib`, so the `jdeb`/`ant-spk` taskdefs load.
3. **`resolve` is a separate target.** The default `fatjar` target does not depend on it. Run `resolve` once (or after changing `ivy.xml`).
4. **`resolve` downloads ~192 MB** because jdeb's transitive tree is large. All direct dependencies (including `net.filebot:ant-spk:0.6`) are on Maven Central.
5. **`resolve` rewrites `lib/native/**`** (tracked files). With the pinned versions the content is identical and `git status` stays clean; `lib/ivy/`, `build/`, `dist/`, `cache/` are gitignored.
6. **`fatjar` uses `duplicate="fail"`.** Adding jars to it later can fail on duplicate entries (`module-info.class`, overlapping `META-INF/services`, etc.). Use explicit `include` patterns in any new `zipfileset`.
7. **The fat jar includes JAXB** (`jaxb-api`, `jaxb-impl`, `activation`) and **omits native libraries**. JavaFX is not bundled; it must come from the JDK (Zulu FX) or be added separately.
8. **Donation/App Store prompt is already in this 4.8.0 source** (`source/net/filebot/ui/SupportDialog.java`). It appears on GUI close after rename thresholds. The aggressive branch compares `os.name` exactly to `"Windows 10"`/`"Mac OS X"`, so on Windows 11 it falls back to the base thresholds (2000 × 2ⁿ renames in a session, or 2000 × 5ⁿ total, where n = number of times the prompt has already been answered). The update dialog is separate (see `application.update`).
9. **Build revision** comes from `git rev-list --count master` (5354 in this checkout). It is baked into `Settings.properties` and stored in the jar manifest.
10. **`test/` is not built** by the Ant file; there is no `test`/`junit` target.

## Key source files for runtime behaviour

| File | What it controls |
|---|---|
| `source/net/filebot/Main.java` | Startup; update check, Getting Started, JavaFX init, SecurityManager. |
| `source/net/filebot/Settings.properties` | `github.stable`, `update.url`, API keys, links — `@{...}` replaced at build time. |
| `source/net/filebot/media/ReleaseInfo.properties` | Data index URLs (`@{url.data}/...`), release patterns. |
| `source/net/filebot/media/ReleaseInfo.java` | `getProperty()` runtime `-D` overrides; XZ data loading. |
| `source/net/filebot/cli/ScriptSource.java` | `fn:`/`dev:`/`g:` script sources; signature via `repository.cer`. |
| `source/net/filebot/ui/SupportDialog.java` | Donation / App Store review prompt. |
| `source/net/filebot/History.java` | JAXB history export (JAXB is bundled in the fat jar). |

## Working agreements

- No Maven/Gradle; keep the Ant + Ivy build. `build.cmd` builds; `package.cmd` assembles `run\`; `run\filebot.cmd` runs the result.
- Build outputs (`build/`, `dist/`, `run/`, `cache/`, `lib/ivy/`) are disposable and gitignored; do not commit them.
- Ant/Ivy downloads are cached outside the repo in `%LOCALAPPDATA%\filebot-build-tools` (`FILEBOT_TOOLS_DIR` overrides).
- `downloads/` contains the offline snapshots used by private builds; keep them in sync if URLs change.
- Prefer build-time `-D` overrides over editing `app.properties` when experimenting with URLs.
- Any source-level change (disabling prompts, adding bindings, patching URLs) needs explicit user approval.
