[CmdletBinding()]
param(
    [switch]$SkipTests,
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
Set-Location -LiteralPath $repoRoot

function Resolve-FlutterCommand {
    $command = Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    $localPropertiesPath = Join-Path $repoRoot "android/local.properties"
    if (Test-Path -LiteralPath $localPropertiesPath) {
        $sdkLine = Get-Content -LiteralPath $localPropertiesPath | Where-Object { $_ -match "^flutter\.sdk=" } | Select-Object -First 1
        if ($sdkLine) {
            $sdkPath = ($sdkLine -replace "^flutter\.sdk=", "") -replace "\\\\", "\"
            $candidate = Join-Path $sdkPath "bin/flutter.bat"
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }
    throw "Flutter was not found on PATH or in android/local.properties."
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command exited with code $LASTEXITCODE."
    }
}

function Resolve-DartCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FlutterCommand
    )

    $flutterBin = Split-Path -Parent $FlutterCommand
    $bundledDart = Join-Path $flutterBin "cache/dart-sdk/bin/dart.exe"
    if (Test-Path -LiteralPath $bundledDart) {
        return $bundledDart
    }
    $command = Get-Command dart -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }
    throw "Dart was not found beside Flutter or on PATH."
}

$requiredSigningVariables = @(
    "DANGGUI_KEYSTORE_PATH",
    "DANGGUI_KEYSTORE_PASSWORD",
    "DANGGUI_KEY_ALIAS",
    "DANGGUI_KEY_PASSWORD"
)
$providedVariables = @($requiredSigningVariables | Where-Object { [Environment]::GetEnvironmentVariable($_) })
$propertiesPath = Join-Path $repoRoot "android/keystore.properties"

if ($providedVariables.Count -gt 0 -and $providedVariables.Count -lt $requiredSigningVariables.Count) {
    throw "Release signing environment variables are only partially configured."
}

$signingMode =
    if ($providedVariables.Count -eq $requiredSigningVariables.Count -or (Test-Path -LiteralPath $propertiesPath)) {
        "release"
    } else {
        "debug-fallback"
    }

if ($signingMode -eq "debug-fallback") {
    Write-Warning "No release keystore was supplied. Outputs are debug-signed and must not be published."
}

$flutter = Resolve-FlutterCommand
$dart = Resolve-DartCommand -FlutterCommand $flutter
Invoke-Checked $flutter config --no-analytics
Invoke-Checked $flutter pub get --enforce-lockfile
Invoke-Checked $dart run tool/audit_offline_boundary.dart
if (-not $SkipTests) {
    Invoke-Checked $flutter analyze --fatal-infos
    Invoke-Checked $flutter test --reporter expanded
}
Invoke-Checked $flutter build apk --release
Invoke-Checked $flutter build apk --release --split-per-abi
Invoke-Checked $flutter build appbundle --release

$versionLine = Get-Content -LiteralPath (Join-Path $repoRoot "pubspec.yaml") | Where-Object { $_ -match "^version:\s*" } | Select-Object -First 1
$version = if ($versionLine) { ($versionLine -replace "^version:\s*", "").Trim() } else { "unknown" }
$safeVersion = $version -replace "\+", "-"
if (-not $OutputRoot) {
    $OutputRoot = Join-Path $repoRoot "dist/android/$safeVersion-$signingMode"
}
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

$universalApk = Join-Path $repoRoot "build/app/outputs/flutter-apk/app-release.apk"
$stagedUniversal = Join-Path $OutputRoot "danggui-android-universal-$signingMode.apk"
Copy-Item -LiteralPath $universalApk -Destination $stagedUniversal -Force

$splitVersionCodes = [ordered]@{
    "armeabi-v7a" = "1001"
    "arm64-v8a" = "2001"
    "x86_64" = "4001"
}
$stagedSplitApks = [ordered]@{}
foreach ($abi in $splitVersionCodes.Keys) {
    $source = Join-Path $repoRoot "build/app/outputs/flutter-apk/app-$abi-release.apk"
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Expected split APK was not generated: $source"
    }
    $destination = Join-Path $OutputRoot "danggui-android-$abi-$signingMode.apk"
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $stagedSplitApks[$abi] = $destination
}

$bundleSource = Join-Path $repoRoot "build/app/outputs/bundle/release/app-release.aab"
$stagedBundle = Join-Path $OutputRoot "danggui-android-$signingMode.aab"
Copy-Item -LiteralPath $bundleSource -Destination $stagedBundle -Force

$verifier = Join-Path $PSScriptRoot "verify_android_artifacts.ps1"
& $verifier -ApkPath $stagedUniversal -AabPath $stagedBundle -ExpectedVersionCode "1"
foreach ($abi in $splitVersionCodes.Keys) {
    & $verifier -ApkPath $stagedSplitApks[$abi] -ExpectedVersionCode $splitVersionCodes[$abi]
}

Get-ChildItem -LiteralPath $OutputRoot -File |
    Where-Object { $_.Extension -in @(".apk", ".aab") } |
    ForEach-Object { "$(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 | Select-Object -ExpandProperty Hash)  $($_.Name)" } |
    Set-Content -LiteralPath (Join-Path $OutputRoot "SHA256SUMS") -Encoding utf8
Set-Content -LiteralPath (Join-Path $OutputRoot "SIGNING_MODE.txt") -Value $signingMode -Encoding utf8
& $flutter --version | Set-Content -LiteralPath (Join-Path $OutputRoot "TOOLCHAIN.txt") -Encoding utf8

Write-Host "Android artifacts staged at $OutputRoot"
