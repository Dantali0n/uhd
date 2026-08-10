param(
    [string]$PackageName,

    [string]$Version = "",

    [string]$InstallArgs = "",

    [ValidateRange(0, 20)]
    [int]$RetryCount = 2,

    [ValidateRange(1, 3600)]
    [int]$RetryDelaySeconds = 30,

    [ValidateRange(0, 100000)]
    [int]$LogTailLines = 300,

    [Alias('h')]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

function Show-Usage {
    Write-Host "Usage:"
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File install-choco-package.ps1 -PackageName <name> [-Version <version>] [-InstallArgs <args>] [-RetryCount <n>] [-RetryDelaySeconds <sec>]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -PackageName   Chocolatey package ID (required)."
    Write-Host "  -Version       Optional package version passed as --version."
    Write-Host "  -InstallArgs   Optional installer args passed as --installargs."
    Write-Host "  -RetryCount    Number of retries after the first failed attempt (default: 2)."
    Write-Host "  -RetryDelaySeconds   Wait time between retries in seconds (default: 30)."
    Write-Host "  -LogTailLines  Number of log lines to show on final failure (default: 300, use 0 to disable)."
    Write-Host "  -Help, --help  Show this help text."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 -PackageName doxygen.install -Version 1.9.8"
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 -PackageName cmake.install -Version 3.22.3 -InstallArgs \"ADD_CMAKE_TO_PATH=System\""
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 -PackageName git"
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 -PackageName doxygen.install -Version 1.9.8 -RetryCount 3 -RetryDelaySeconds 30"
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 -PackageName doxygen.install -Version 1.9.8 -LogTailLines 1000"
}

if ($Help -or ($ExtraArgs -contains '--help')) {
    Show-Usage
    exit 0
}

if (-not $PackageName) {
    Write-Host "Error: -PackageName is required."
    Write-Host "Run with --help to see usage."
    exit 2
}

$ErrorActionPreference = 'Stop'

$chocoRoot = if ($env:ChocolateyInstall) { $env:ChocolateyInstall } else { 'C:\ProgramData\chocolatey' }
$logPath = Join-Path $chocoRoot 'logs\chocolatey.log'
$packageLibPath = Join-Path (Join-Path $chocoRoot 'lib') $PackageName
$maxAttempts = $RetryCount + 1

$chocoArgs = @('install', '-y', $PackageName)
if ($Version) {
    $chocoArgs += @('--version', $Version)
}
if ($InstallArgs) {
    $chocoArgs += @('--installargs', $InstallArgs)
}

for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    Write-Host "Installing Chocolatey package: $PackageName (attempt $attempt of $maxAttempts)"
    & choco @chocoArgs
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "Successfully installed Chocolatey package: $PackageName"
        exit 0
    }

    Write-Host "Chocolatey install failed for package '$PackageName' (exit code $exitCode)."

    if ($attempt -lt $maxAttempts) {
        Write-Host "Retrying in $RetryDelaySeconds seconds..."
        Start-Sleep -Seconds $RetryDelaySeconds
    }
}

if ($LogTailLines -gt 0) {
    if (Test-Path $logPath) {
        Write-Host "Showing last $LogTailLines lines from $logPath"
        Get-Content $logPath -Tail $LogTailLines
    }
    else {
        Write-Host "Chocolatey log not found at $logPath"
    }
}
else {
    Write-Host "Skipping Chocolatey log output because -LogTailLines is set to 0"
}

if (Test-Path $packageLibPath) {
    Write-Host "Contents of $packageLibPath"
    Get-ChildItem -Path $packageLibPath -Force
}

exit $exitCode
