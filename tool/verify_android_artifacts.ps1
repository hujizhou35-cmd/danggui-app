[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApkPath,

    [string]$AabPath,

    [string]$ExpectedVersionCode = "1",

    [string]$ExpectedCertificateSha256 = $env:DANGGUI_EXPECTED_CERT_SHA256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedApk = (Resolve-Path -LiteralPath $ApkPath).Path
$sdkRoot = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { $env:ANDROID_HOME }
if (-not $sdkRoot -or -not (Test-Path -LiteralPath $sdkRoot -PathType Container)) {
    throw "ANDROID_SDK_ROOT or ANDROID_HOME must point to an installed Android SDK."
}

function Find-AndroidTool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,
        [Parameter(Mandatory = $true)]
        [string]$SearchRoot
    )

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    $candidate =
        Get-ChildItem -LiteralPath $SearchRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @($CommandName, "$CommandName.bat", "$CommandName.exe") } |
        Sort-Object FullName |
        Select-Object -Last 1
    if (-not $candidate) {
        throw "Could not find $CommandName below $SearchRoot."
    }
    return $candidate.FullName
}

$apkAnalyzer = Find-AndroidTool -CommandName "apkanalyzer" -SearchRoot (Join-Path $sdkRoot "cmdline-tools")
$apkSigner = Find-AndroidTool -CommandName "apksigner" -SearchRoot (Join-Path $sdkRoot "build-tools")

$permissions = & $apkAnalyzer manifest permissions $resolvedApk 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "apkanalyzer failed: $($permissions -join [Environment]::NewLine)"
}
$permissions | Write-Host
$permissionNames =
    $permissions |
    ForEach-Object { $_.ToString().Trim() } |
    Where-Object { $_ } |
    Sort-Object -Unique

$expectedPermissions = @(
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE"
)
foreach ($requiredPermission in $expectedPermissions) {
    if ($permissionNames -notcontains $requiredPermission) {
        throw "The APK is missing required local-reminder permission $requiredPermission."
    }
}
foreach ($permission in $permissionNames) {
    $isExpected = $expectedPermissions -contains $permission
    $isAndroidXProtection =
        $permission -eq "com.danggui.memo.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
    if (-not $isExpected -and -not $isAndroidXProtection) {
        throw "The APK contains an unapproved permission: $permission"
    }
}

$identityChecks = @{
    "application-id" = "com.danggui.memo"
    "version-name" = "1.0.0"
    "version-code" = $ExpectedVersionCode
    "min-sdk" = "24"
    "target-sdk" = "36"
    "debuggable" = "false"
}
foreach ($check in $identityChecks.GetEnumerator()) {
    $actual = (& $apkAnalyzer manifest $check.Key $resolvedApk 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "apkanalyzer manifest $($check.Key) failed: $actual"
    }
    if ($actual -ne $check.Value) {
        throw "Unexpected APK $($check.Key): $actual (expected $($check.Value))."
    }
}

$mergedManifest = & $apkAnalyzer manifest print $resolvedApk 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "apkanalyzer manifest print failed: $($mergedManifest -join [Environment]::NewLine)"
}
$mergedManifestText = $mergedManifest -join "`n"
try {
    [xml]$mergedManifestXml = $mergedManifestText
}
catch {
    throw "apkanalyzer returned malformed merged XML: $($_.Exception.Message)"
}
$androidNamespace = "http://schemas.android.com/apk/res/android"
$applicationElement = $mergedManifestXml.manifest.application
if (-not $applicationElement) {
    throw "Merged APK manifest has no application element."
}
foreach ($attribute in @("allowBackup", "usesCleartextTraffic")) {
    if ($applicationElement.GetAttribute($attribute, $androidNamespace) -ne "false") {
        throw "Merged APK application must set android:$attribute=`"false`"."
    }
}
$mainActivity =
    @($applicationElement.activity) |
    Where-Object {
        $_.GetAttribute("name", $androidNamespace).EndsWith(".MainActivity")
    } |
    Select-Object -First 1
if (-not $mainActivity) {
    throw "Merged APK manifest has no MainActivity."
}
$orientation = $mainActivity.GetAttribute("screenOrientation", $androidNamespace)
if ($orientation -notin @("portrait", "1")) {
    throw "Merged APK MainActivity must remain portrait-only; apkanalyzer reported '$orientation'."
}
foreach ($receiver in @(
    "ScheduledNotificationReceiver",
    "ScheduledNotificationBootReceiver",
    "ActionBroadcastReceiver"
)) {
    $receiverElement =
        @($applicationElement.receiver) |
        Where-Object {
            $_.GetAttribute("name", $androidNamespace).EndsWith(".$receiver")
        } |
        Select-Object -First 1
    if (
        -not $receiverElement -or
        $receiverElement.GetAttribute("exported", $androidNamespace) -ne "false"
    ) {
        throw "Merged APK receiver $receiver must exist and remain non-exported."
    }
}

$signatureReport = & $apkSigner verify --verbose --print-certs $resolvedApk 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "apksigner verification failed: $($signatureReport -join [Environment]::NewLine)"
}
$signatureReport | Write-Host

if ($ExpectedCertificateSha256) {
    $digestLine = $signatureReport | Where-Object { $_ -match "certificate SHA-256 digest:" } | Select-Object -First 1
    if (-not $digestLine) {
        throw "apksigner did not report a certificate SHA-256 digest."
    }
    $actual = ($digestLine -replace "^.*certificate SHA-256 digest:\s*", "") -replace "[:\s]", ""
    $expected = $ExpectedCertificateSha256 -replace "[:\s]", ""
    if ($actual.ToUpperInvariant() -ne $expected.ToUpperInvariant()) {
        throw "APK certificate SHA-256 does not match the expected official certificate."
    }
}

if ($AabPath) {
    $resolvedAab = (Resolve-Path -LiteralPath $AabPath).Path
    $jar = (Get-Command jar -ErrorAction Stop).Source
    $signatureEntries = & $jar tf $resolvedAab 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "jar could not list $resolvedAab."
    }
    $hasSignatureFile = $signatureEntries | Where-Object { $_ -match "^META-INF/[^/]+\.SF$" } | Select-Object -First 1
    $hasSignatureBlock = $signatureEntries | Where-Object { $_ -match "^META-INF/[^/]+\.(RSA|DSA|EC)$" } | Select-Object -First 1
    if (-not $hasSignatureFile -or -not $hasSignatureBlock) {
        throw "AAB does not contain a complete JAR signature block."
    }
    $jarSigner = (Get-Command jarsigner -ErrorAction Stop).Source
    & $jarSigner -verify $resolvedAab
    if ($LASTEXITCODE -ne 0) {
        throw "jarsigner verification failed for $resolvedAab."
    }
    if ($ExpectedCertificateSha256) {
        $keyTool = (Get-Command keytool -ErrorAction Stop).Source
        $certificateReport = & $keyTool -printcert -jarfile $resolvedAab 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "keytool certificate inspection failed for $resolvedAab."
        }
        $aabDigestLine =
            $certificateReport |
            Where-Object { $_ -match "^\s*SHA256:\s*" } |
            Select-Object -First 1
        if (-not $aabDigestLine) {
            throw "keytool did not report an AAB certificate SHA-256 fingerprint."
        }
        $actualAab = ($aabDigestLine -replace "^\s*SHA256:\s*", "") -replace "[:\s]", ""
        $expectedAab = $ExpectedCertificateSha256 -replace "[:\s]", ""
        if ($actualAab.ToUpperInvariant() -ne $expectedAab.ToUpperInvariant()) {
            throw "AAB certificate SHA-256 does not match the expected official certificate."
        }
    }
}
