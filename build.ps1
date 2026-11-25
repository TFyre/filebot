#requires -version 5.1
# FileBot private build bootstrap:
#   - finds (or downloads) a Java 21 FX-enabled JDK
#   - downloads Ant + Ivy into a local cache
#   - runs Ivy resolve, fixes the slf4j-api artifact, and builds the fat jar
# Optional: set FILEBOT_ANT_ARGS to override the Ant targets (default: "clean fatjar").

$ErrorActionPreference = 'Stop'

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
    # older .NET; defaults are usually fine
}

$RepoRoot      = $PSScriptRoot
$ToolsDir      = if ($env:FILEBOT_TOOLS_DIR) { $env:FILEBOT_TOOLS_DIR } else { Join-Path $env:LOCALAPPDATA 'filebot-build-tools' }
$AntVersion    = '1.10.15'
$IvyVersion    = '2.4.0'
$Slf4jVersion  = '1.7.25'
$ZuluVersion   = '21.0.13.1'
$ZuluUrl       = 'https://cdn.azul.com/zulu/bin/zulu21.54.201-ca-fx-jdk21.0.13.1-win_x64.zip'
$ZuluDir       = Join-Path $ToolsDir 'zulu21fx'
$AntDir        = Join-Path $ToolsDir "apache-ant-$AntVersion"
$AntBat        = Join-Path $AntDir 'bin\ant.bat'
$IvyJar        = Join-Path $ToolsDir "ivy-$IvyVersion.jar"

New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Jdk21Fx([string]$Path) {
    if (-not $Path) { return $false }
    $javac = Join-Path $Path 'bin\javac.exe'
    $fxJmod = Join-Path $Path 'jmods\javafx.controls.jmod'
    $release = Join-Path $Path 'release'
    if (-not (Test-Path $javac) -or -not (Test-Path $fxJmod) -or -not (Test-Path $release)) { return $false }

    $line = Get-Content -Path $release | Where-Object { $_ -like 'JAVA_VERSION=*' } | Select-Object -First 1
    return $line -match 'JAVA_VERSION="21'
}

function Get-File([string]$Url, [string]$Destination) {
    if (Test-Path $Destination) { return }
    Write-Step "Downloading $Url"
    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination
}

function Get-RemoteHash([string]$Url) {
    return (Invoke-WebRequest -UseBasicParsing -Uri $Url).Content.ToString().Trim().Split(' ')[0].ToLowerInvariant()
}

function Assert-Hash([string]$File, [string]$Url, [string]$Algorithm) {
    $expected = Get-RemoteHash $Url
    $actual = (Get-FileHash -Algorithm $Algorithm -Path $File).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        throw "$Algorithm mismatch for $File`n  expected: $expected`n  actual:   $actual"
    }
}

# ---------------------------------------------------------------- JDK ----
$Jdk = $null
$candidates = @($env:FILEBOT_JDK, $env:JAVA_HOME)
if (Test-Path $ZuluDir) {
    $candidates += Get-ChildItem -Path $ZuluDir -Directory | Select-Object -ExpandProperty FullName
}
$candidates += Get-ChildItem -Path 'C:\Program Files\Zulu' -Directory -Filter 'zulu21*-ca-fx-jdk*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

foreach ($candidate in $candidates) {
    if (Test-Jdk21Fx $candidate) { $Jdk = $candidate; break }
}

if (-not $Jdk) {
    $zip = Join-Path $ZuluDir 'zulu21fx.zip'
    Get-File $ZuluUrl $zip
    Write-Step "Extracting Zulu $ZuluVersion"
    Expand-Archive -Path $zip -DestinationPath $ZuluDir -Force
    $Jdk = Get-ChildItem -Path $ZuluDir -Directory | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not (Test-Jdk21Fx $Jdk)) { throw "Downloaded JDK is not a Java 21 FX JDK: $Jdk" }
}

$env:JAVA_HOME = $Jdk
Write-Step "JAVA_HOME=$Jdk"

# ---------------------------------------------------------------- Ant ----
if (-not (Test-Path $AntBat)) {
    $antZip = Join-Path $ToolsDir "apache-ant-$AntVersion-bin.zip"
    $antUrl = "https://archive.apache.org/dist/ant/binaries/apache-ant-$AntVersion-bin.zip"
    Get-File $antUrl $antZip
    Assert-Hash $antZip "$antUrl.sha512" 'SHA512'
    Write-Step "Extracting Ant $AntVersion"
    Expand-Archive -Path $antZip -DestinationPath $ToolsDir -Force
}
if (-not (Test-Path $AntBat)) { throw "ant.bat not found: $AntBat" }

# ---------------------------------------------------------------- Ivy ----
if (-not (Test-Path $IvyJar)) {
    $ivyUrl = "https://repo1.maven.org/maven2/org/apache/ivy/ivy/$IvyVersion/ivy-$IvyVersion.jar"
    Get-File $ivyUrl $IvyJar
    Assert-Hash $IvyJar "$ivyUrl.sha1" 'SHA1'
}

# ------------------------------------------------------------ resolve ----
$IvyMarker = Join-Path $RepoRoot 'lib\ivy\jar\groovy-all.jar'
if (-not (Test-Path $IvyMarker)) {
    Write-Step "Resolving dependencies with Ivy"
    Push-Location $RepoRoot
    try {
        & $AntBat -lib $IvyJar resolve
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($code -ne 0) { exit $code }
}

# Ivy retrieves slf4j-api as a test-jar, but build.xml wants the main jar.
$Slf4jJar = Join-Path $RepoRoot 'lib\ivy\jar\slf4j-api.jar'
if (-not (Test-Path $Slf4jJar)) {
    $slf4jUrl = "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/$Slf4jVersion/slf4j-api-$Slf4jVersion.jar"
    Get-File $slf4jUrl $Slf4jJar
    Assert-Hash $Slf4jJar "$slf4jUrl.sha1" 'SHA1'
}

# -------------------------------------------------------------- build ----
$AntArgs = @()
if ($env:FILEBOT_ANT_ARGS) {
    $AntArgs = @($env:FILEBOT_ANT_ARGS -split '\s+' | Where-Object { $_ })
}
if ($AntArgs.Count -eq 0) { $AntArgs = @('clean', 'fatjar') }

Write-Step "Running ant $($AntArgs -join ' ')"
Push-Location $RepoRoot
try {
    & $AntBat -lib $IvyJar @AntArgs
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($code -ne 0) { exit $code }

$jar = Get-ChildItem -Path (Join-Path $RepoRoot 'dist') -Filter 'FileBot_*.jar' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($jar) {
    Write-Host ''
    Write-Step ("Built {0} ({1:N1} MB)" -f $jar.FullName, ($jar.Length / 1MB))
}
