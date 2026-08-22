[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$Alias = "danggui",

    [string]$DistinguishedName = "CN=Danggui Release, OU=Mobile, O=Danggui, C=CN"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

foreach ($name in "DANGGUI_KEYSTORE_PASSWORD", "DANGGUI_KEY_PASSWORD") {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        throw "$name must be set in the current process before generating a keystore."
    }
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$target = [IO.Path]::GetFullPath($OutputPath)
$repoPrefix = $repoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if ($target.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create the official keystore inside the repository. Choose an external secure path."
}
if (Test-Path -LiteralPath $target) {
    throw "Refusing to overwrite an existing keystore: $target"
}

$parent = Split-Path -Parent $target
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$keytool = (Get-Command keytool -ErrorAction Stop).Source

$arguments = @(
    "-genkeypair",
    "-keystore", $target,
    "-storetype", "JKS",
    "-storepass:env", "DANGGUI_KEYSTORE_PASSWORD",
    "-alias", $Alias,
    "-keypass:env", "DANGGUI_KEY_PASSWORD",
    "-keyalg", "RSA",
    "-keysize", "4096",
    "-sigalg", "SHA256withRSA",
    "-validity", "10000",
    "-dname", $DistinguishedName
)
& $keytool @arguments
if ($LASTEXITCODE -ne 0) {
    throw "keytool failed with code $LASTEXITCODE."
}

$certificatePath = "$target.cer"
& $keytool -exportcert -rfc -keystore $target -storepass:env DANGGUI_KEYSTORE_PASSWORD -alias $Alias -file $certificatePath
if ($LASTEXITCODE -ne 0) {
    throw "Certificate export failed with code $LASTEXITCODE."
}

Write-Host "Keystore created outside the repository: $target"
Write-Host "Public certificate exported: $certificatePath"
Write-Host "Record the following certificate digest in ANDROID_EXPECTED_CERT_SHA256:"
& $keytool -list -v -keystore $target -storepass:env DANGGUI_KEYSTORE_PASSWORD -alias $Alias |
    Select-String -Pattern "SHA256:"
