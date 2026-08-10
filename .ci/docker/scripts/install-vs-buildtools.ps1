param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    # Optional base temp directory for download and installer extraction.
    # A random subfolder is always created under this base path and cleaned up unless -PreserveTemp is set.
    [string]$TempDir = '',

    # Preserve the generated temp working directory for debugging.
    [switch]$PreserveTemp,

    # All remaining arguments are passed directly to vs_buildtools.exe.
    # Example: -InstallerArgs '--quiet','--wait','--norestart','--installPath','C:\VS','--add','Microsoft.VisualStudio.Workload.VCTools','--includeRecommended'
    [string[]]$InstallerArgs = @('--quiet', '--wait', '--norestart', '--add', 'Microsoft.VisualStudio.Workload.VCTools', '--includeRecommended')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- URL validation (mirrors check-url.ps1 logic) ---
if ([string]::IsNullOrWhiteSpace($Url)) {
    throw "VS_BUILD_TOOLS_URL is empty. Provide a valid download URL."
}

Write-Host "Validating VS Build Tools URL: $Url"
$resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -Method Head
if ($resp.StatusCode -ne 200) {
    throw "URL check failed: StatusCode=$($resp.StatusCode)"
}
$ct = $resp.Headers['Content-Type']
if ($ct -and $ct -match 'text/html') {
    throw "URL check failed: Content-Type=$ct (expected binary)"
}
$cl = [int64]($resp.Headers['Content-Length'] | Select-Object -First 1)
if ($cl -and $cl -lt 1048576) {
    throw "URL check failed: Content-Length=$cl (suspiciously small)"
}
Write-Host "URL validation passed (Content-Type: $ct, Content-Length: $cl bytes)."

# --- Setup temp directory ---
if (-not [string]::IsNullOrWhiteSpace($TempDir)) {
    $temp = Join-Path $TempDir ([System.IO.Path]::GetRandomFileName())
} else {
    $temp = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName())
}
Write-Host "Using temp directory: $temp"
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$env:TEMP = $temp
$env:TMP  = $temp

# --- Download ---
$exe = Join-Path $temp 'vs_buildtools.exe'
Write-Host "Downloading VS Build Tools to $exe ..."
Invoke-WebRequest $Url -OutFile $exe -UseBasicParsing
Write-Host "Download complete: $exe"

# --- Install ---
Push-Location $temp
try {
    $fullCmd = ".\vs_buildtools.exe " + ($InstallerArgs -join ' ')
    Write-Host "Install command: $fullCmd"
    $p = Start-Process -FilePath '.\vs_buildtools.exe' -ArgumentList $InstallerArgs -Wait -PassThru
    $code = $p.ExitCode
    Write-Host "VS installer exit code: $code"

    if ($code -ne 0 -and $code -ne 3010) {
        # Dump installer logs to stdout before cleanup
        Get-ChildItem -Path $env:TEMP -Recurse -File -Include 'dd_*', '*.log' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 20 -ExpandProperty FullName |
            ForEach-Object { Write-Host ('==== ' + $_ + ' ===='); Get-Content $_ -Tail 250 }

        $b1 = Join-Path $env:ProgramData 'Microsoft\VisualStudio\Packages\_bootstrapper'
        if (Test-Path $b1) {
            Get-ChildItem -Path $b1 -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 20 -ExpandProperty FullName |
                ForEach-Object { Write-Host ('==== ' + $_ + ' ===='); Get-Content $_ -Tail 250 }
        }

        throw "Installer failed with exit code: $code"
    }
}
finally {
    Pop-Location
    if ($PreserveTemp) {
        Write-Host "Preserving temp directory: $temp"
    } else {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
    # Give Windows time to flush pending filesystem writes (e.g. msiexec deferred
    # operations) before Docker captures the layer. Without this, hcsshim::ImportLayer
    # can fail with ERROR_PATH_NOT_FOUND (0x3) due to a race condition between
    # NTFS lazy-write completion and the layer snapshot.
    # Runs unconditionally: even a failed install may have partial writes pending.
    Write-Host "Waiting 10 seconds for filesystem writes to flush..."
    Start-Sleep -Seconds 10
    Write-Host "Filesystem flush wait complete."
}

Write-Host "VS Build Tools installed successfully."
