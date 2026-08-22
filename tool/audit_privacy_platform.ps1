[CmdletBinding()]
param(
    [switch]$SkipPubGet,
    [switch]$SkipTests,
    [switch]$SkipResolvedPlugins
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
        $sdkLine =
            Get-Content -LiteralPath $localPropertiesPath |
            Where-Object { $_ -match "^flutter\.sdk=" } |
            Select-Object -First 1
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

$flutter = Resolve-FlutterCommand
$dart = Resolve-DartCommand -FlutterCommand $flutter

if (-not $SkipPubGet) {
    Invoke-Checked $flutter pub get --enforce-lockfile
}

$auditArguments = @("run", "tool/audit_offline_boundary.dart")
if ($SkipResolvedPlugins) {
    $auditArguments += "--no-resolved-plugins"
}
Invoke-Checked $dart @auditArguments

if (-not $SkipTests) {
    Invoke-Checked $flutter test test/platform/privacy_platform_config_test.dart --reporter expanded
}

Write-Host "Privacy/platform source release gate passed."
