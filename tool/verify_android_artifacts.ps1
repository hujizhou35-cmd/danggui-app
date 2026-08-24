[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApkPath,

    [string]$AabPath,

    [string]$ExpectedVersionCode,

    [string]$ExpectedCertificateSha256 = $env:DANGGUI_EXPECTED_CERT_SHA256,

    [string]$BundletoolJar = $env:BUNDLETOOL_JAR
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedApk = (Resolve-Path -LiteralPath $ApkPath).Path
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$versionLine = Get-Content -LiteralPath (Join-Path $repoRoot "pubspec.yaml") | Where-Object { $_ -match "^version:\s*" } | Select-Object -First 1
if (-not $versionLine) {
    throw "pubspec.yaml does not declare a release version."
}
$technicalVersion = ($versionLine -replace "^version:\s*", "").Trim()
if ($technicalVersion -notmatch "^(?<name>\d+\.\d+\.\d+)\+(?<code>[1-9]\d*)$") {
    throw "pubspec.yaml version must use semantic-name+positive-build-number: $technicalVersion"
}
$expectedVersionName = $Matches["name"]
if (-not $ExpectedVersionCode) {
    $ExpectedVersionCode = $Matches["code"]
}
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
    "version-name" = $expectedVersionName
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
    if (-not $BundletoolJar -or -not (Test-Path -LiteralPath $BundletoolJar -PathType Leaf)) {
        throw "BUNDLETOOL_JAR must point to the pinned bundletool-all JAR for AAB metadata verification."
    }
    $resolvedBundletool = (Resolve-Path -LiteralPath $BundletoolJar).Path
    $java = (Get-Command java -ErrorAction Stop).Source
    $bundleValidation = & $java -jar $resolvedBundletool validate "--bundle=$resolvedAab" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "bundletool validate failed: $($bundleValidation -join [Environment]::NewLine)"
    }
    $bundletoolErrorFile = New-TemporaryFile
    try {
        $aabManifestDump = & $java -jar $resolvedBundletool dump manifest "--bundle=$resolvedAab" --module=base 2> $bundletoolErrorFile
        if ($LASTEXITCODE -ne 0) {
            $bundletoolError = Get-Content -LiteralPath $bundletoolErrorFile -Raw
            throw "bundletool dump manifest failed: $bundletoolError"
        }
        try {
            [xml]$aabManifestXml = $aabManifestDump -join "`n"
        }
        catch {
            throw "bundletool returned malformed AAB manifest XML: $($_.Exception.Message)"
        }
    }
    finally {
        Remove-Item -LiteralPath $bundletoolErrorFile -Force -ErrorAction SilentlyContinue
    }

    $aabRoot = $aabManifestXml.DocumentElement
    if (-not $aabRoot -or $aabRoot.LocalName -ne "manifest") {
        throw "AAB base module has no manifest root element."
    }
    $aabUsesSdk = $aabRoot.SelectSingleNode("uses-sdk")
    if (-not $aabUsesSdk) {
        throw "AAB manifest has no uses-sdk element."
    }

    function Convert-AabIntegerAttribute {
        param(
            [Parameter(Mandatory = $true)]
            [System.Xml.XmlElement]$Element,
            [Parameter(Mandatory = $true)]
            [string]$Name
        )

        $value = $Element.GetAttribute($Name, $androidNamespace)
        if (-not $value) {
            throw "AAB manifest is missing android:$Name."
        }
        if ($value.StartsWith("0x", [StringComparison]::OrdinalIgnoreCase)) {
            return [Convert]::ToInt32($value.Substring(2), 16)
        }
        $parsed = 0
        if (-not [int]::TryParse($value, [ref]$parsed)) {
            throw "AAB manifest android:$Name is not an integer: $value"
        }
        return $parsed
    }

    $aabIdentityChecks = @{
        "package" = "com.danggui.memo"
        "version-name" = $expectedVersionName
        "version-code" = [int]$ExpectedVersionCode
        "min-sdk" = 24
        "target-sdk" = 36
    }
    $aabIdentityActual = @{
        "package" = $aabRoot.GetAttribute("package")
        "version-name" = $aabRoot.GetAttribute("versionName", $androidNamespace)
        "version-code" = Convert-AabIntegerAttribute -Element $aabRoot -Name "versionCode"
        "min-sdk" = Convert-AabIntegerAttribute -Element $aabUsesSdk -Name "minSdkVersion"
        "target-sdk" = Convert-AabIntegerAttribute -Element $aabUsesSdk -Name "targetSdkVersion"
    }
    foreach ($field in $aabIdentityChecks.Keys) {
        $actual = $aabIdentityActual[$field]
        $expected = $aabIdentityChecks[$field]
        if ($actual -ne $expected) {
            throw "Unexpected AAB ${field}: $actual (expected $expected)."
        }
    }

    $aabPermissionNames =
        @($aabRoot.SelectNodes("uses-permission | uses-permission-sdk-23")) |
        ForEach-Object { $_.GetAttribute("name", $androidNamespace) } |
        Where-Object { $_ } |
        Sort-Object -Unique
    foreach ($requiredPermission in $expectedPermissions) {
        if ($aabPermissionNames -notcontains $requiredPermission) {
            throw "The AAB is missing required local-reminder permission $requiredPermission."
        }
    }
    foreach ($permission in $aabPermissionNames) {
        $isExpected = $expectedPermissions -contains $permission
        $isAndroidXProtection =
            $permission -eq "com.danggui.memo.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
        if (-not $isExpected -and -not $isAndroidXProtection) {
            throw "The AAB contains an unapproved permission: $permission"
        }
    }

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
