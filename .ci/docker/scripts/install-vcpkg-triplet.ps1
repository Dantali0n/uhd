param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestDir,

    [Parameter(Mandatory = $true)]
    [string]$Triplet,

    [string]$VcpkgRoot = 'C:\vcpkg'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$vcpkgExe = Join-Path $VcpkgRoot 'vcpkg.exe'
if (-not (Test-Path -LiteralPath $vcpkgExe)) {
    Write-Error "vcpkg executable not found at: $vcpkgExe"
    exit 2
}

if (-not (Test-Path -LiteralPath $ManifestDir)) {
    Write-Error "Manifest directory not found: $ManifestDir"
    exit 2
}

Write-Host "Running vcpkg install in: $ManifestDir"
Write-Host "Triplet: $Triplet"

Push-Location $ManifestDir
try {
    & $vcpkgExe install --triplet $Triplet --clean-after-build
    $vcpkgExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($vcpkgExitCode -eq 0) {
    exit 0
}

Write-Host "##[error]vcpkg install failed with exit code: $vcpkgExitCode"

$buildtreesRoot = Join-Path $VcpkgRoot 'buildtrees'
if (-not (Test-Path -LiteralPath $buildtreesRoot)) {
    Write-Host "No buildtrees directory found at $buildtreesRoot"
    exit $vcpkgExitCode
}

function Write-LogIfExists {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $logInfo = Get-Item -LiteralPath $Path
        Write-Host "===== BEGIN LOG: $Path ($([int64]$logInfo.Length) bytes) ====="
        Get-Content -LiteralPath $Path -Raw
        Write-Host "===== END LOG: $Path ====="
        return $true
    }
    return $false
}

function Write-LogFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string]$Triplet
    )

    if (-not (Test-Path -LiteralPath $Directory)) {
        return
    }

    function Get-LogPriority {
        param([System.IO.FileInfo]$File)

        if ($File.Name -match '^config-') {
            return 0
        }
        if ($File.Name -match '^stdout-') {
            return 1
        }
        if ($File.Name -match '^stderr-') {
            return 2
        }
        return 3
    }

    $priorityLogs = Get-ChildItem -LiteralPath $Directory -File -Filter "*${Triplet}*.log" -ErrorAction SilentlyContinue |
        Sort-Object @{ Expression = { Get-LogPriority -File $_ } },
                     @{ Expression = { $_.LastWriteTimeUtc }; Descending = $true },
                     Name

    if (-not $priorityLogs) {
        $priorityLogs = Get-ChildItem -LiteralPath $Directory -File -Filter '*.log' -ErrorAction SilentlyContinue |
            Sort-Object @{ Expression = { Get-LogPriority -File $_ } },
                         @{ Expression = { $_.LastWriteTimeUtc }; Descending = $true },
                         Name
    }

    if (-not $priorityLogs) {
        Write-Host "No log files found in $Directory"
        return
    }

    Write-Host "Dumping log files from $Directory"
    foreach ($log in $priorityLogs) {
        if ($log.Length -eq 0) {
            Write-Host "===== SKIP EMPTY LOG: $($log.FullName) ====="
            continue
        }

        Write-Host "===== BEGIN LOG: $($log.FullName) ($([int64]$log.Length) bytes) ====="
        Get-Content -LiteralPath $log.FullName -Raw
        Write-Host "===== END LOG: $($log.FullName) ====="
    }
}

# Use the most recently modified log of any type to identify the failing port.
# This catches failures that occur before configure (fetch/extract/patch stage)
# where no config-*-out.log is ever created.
$candidate = Get-ChildItem -LiteralPath $buildtreesRoot -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

# If the most recent log is not a config-*-out.log, also try to find the newest
# config-*-out.log in the same port directory to seed the related-log dump,
# since config logs contain the most actionable CMake failure details.
if ($candidate) {
    $portDirFromRecent = $candidate.DirectoryName
    $configInSamePort = Get-ChildItem -LiteralPath $portDirFromRecent -File -Filter "config-$Triplet-*-out.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($configInSamePort) {
        $candidate = $configInSamePort
    }
}

if (-not $candidate) {
    Write-Host "No log files found under $buildtreesRoot"
    exit $vcpkgExitCode
}

$portDir = $candidate.DirectoryName
$portName = Split-Path -Leaf $portDir

Write-Host "Most recent failing dependency candidate: $portName"
Write-Host "Selected log seed: $($candidate.FullName)"

$seedName = [System.IO.Path]::GetFileNameWithoutExtension($candidate.Name)
if ($seedName.EndsWith('-out', [System.StringComparison]::OrdinalIgnoreCase)) {
    $seedPrefix = $seedName.Substring(0, $seedName.Length - 4)
    $relatedLogs = @(
        (Join-Path $portDir ($seedPrefix + '-CMakeCache.txt.log')),
        (Join-Path $portDir ($seedPrefix + '-CMakeConfigureLog.yaml.log')),
        (Join-Path $portDir ($seedPrefix + '-out.log'))
    )

    foreach ($log in $relatedLogs) {
        [void](Write-LogIfExists -Path $log)
    }
} else {
    [void](Write-LogIfExists -Path $candidate.FullName)
}

Write-LogFiles -Directory $portDir -Triplet $Triplet

Write-Host 'Recent buildtrees logs (top 20 by timestamp):'
Get-ChildItem -LiteralPath $buildtreesRoot -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 20 FullName, LastWriteTimeUtc |
    Format-Table -AutoSize |
    Out-String |
    Write-Host

exit $vcpkgExitCode
