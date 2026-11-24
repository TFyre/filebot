#requires -version 5.1
# FileBot private build bootstrap:
#   - finds (or downloads) a JavaFX-enabled JDK
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
$ZuluVersion   = '11.0.33.1'
$ZuluUrl       = 'https://cdn.azul.com/zulu/bin/zulu11.92.201-ca-fx-jdk11.0.33.1-win_x64.zip'
$ZuluDir       = Join-Path $ToolsDir 'zulu11fx'
$AntDir        = Join-Path $ToolsDir "apache-ant-$AntVersion"
$AntBat        = Join-Path $AntDir 'bin\ant.bat'
$IvyJar        = Join-Path $ToolsDir "ivy-$IvyVersion.jar"

New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-JdkFx([string]$Path) {
    if (-not $Path) { return $false }
    $javac = Join-Path $Path 'bin\javac.exe'
    $fxJmod = Join-Path $Path 'jmods\javafx.controls.jmod'
    $fxProps = Join-Path $Path 'lib\javafx.properties'
    return (Test-Path $javac) -and ((Test-Path $fxJmod) -or (Test-Path $fxProps))
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
$candidates = @(
    $env:FILEBOT_JDK,
    $env:JAVA_HOME,
    'C:\Program Files\Zulu\zulu11.92.113-ca-fx-jdk11.0.33-win_x64',
    (Join-Path $ZuluDir 'zulu11.92.201-ca-fx-jdk11.0.33.1-win_x64')
)
foreach ($candidate in $candidates) {
    if (Test-JdkFx $candidate) { $Jdk = $candidate; break }
}

if (-not $Jdk) {
    $zip = Join-Path $ToolsDir "zulu-$ZuluVersion-win_x64.zip"
    Get-File $ZuluUrl $zip
    Write-Step "Extracting Zulu $ZuluVersion"
    Expand-Archive -Path $zip -DestinationPath $ZuluDir -Force
    $Jdk = Get-ChildItem -Path $ZuluDir -Directory | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not (Test-JdkFx $Jdk)) { throw "Downloaded JDK does not contain JavaFX: $Jdk" }
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
    & $AntBat -lib $IvyJar '-Djvm.version=11' @AntArgs
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
