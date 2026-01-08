# PPM-QuPath Production Setup and Launch Script
# Downloads binaries and sets up QPSC for end users

param(
    [string]$InstallDir = "$env:USERPROFILE\QPSC",
    [string]$QuPathDir = "$env:USERPROFILE\QuPath",
    [switch]$SkipQuPath,
    [switch]$Launch
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QPSC Production Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create installation directory
if (-not (Test-Path $InstallDir)) {
    Write-Host "[+] Creating installation directory: $InstallDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

Set-Location $InstallDir

# Check for Python
Write-Host "[+] Checking Python installation..." -ForegroundColor Cyan
try {
    $pythonVersion = python --version
    Write-Host "    Found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "[!] Python not found - please install Python 3.9+ from https://www.python.org/" -ForegroundColor Red
    Write-Host "    Make sure to check 'Add Python to PATH' during installation" -ForegroundColor Yellow
    exit 1
}

# Install Python packages from PyPI
Write-Host ""
Write-Host "[+] Installing Python microscope control packages..." -ForegroundColor Cyan

$pipPackages = @(
    "microscope-server",  # This will install all dependencies
    "pycromanager"
)

foreach ($pkg in $pipPackages) {
    Write-Host "    -> Installing: $pkg" -ForegroundColor White
    pip install --upgrade $pkg
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    [!] Failed to install $pkg" -ForegroundColor Red
    }
}

Write-Host "[+] Python packages installed" -ForegroundColor Green

# Download configuration templates
Write-Host ""
Write-Host "[+] Downloading configuration templates..." -ForegroundColor Cyan

$configDir = Join-Path $InstallDir "configurations"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

$configRepo = "https://github.com/uw-loci/microscope_configurations"

# Download templates from templates/ folder
$templateFiles = @(
    "config_template.yml",
    "autofocus_template.yml",
    "imageprocessing_template.yml"
)

foreach ($file in $templateFiles) {
    $url = "$configRepo/raw/main/templates/$file"
    $destination = Join-Path $configDir $file

    Write-Host "    -> Downloading: $file" -ForegroundColor White
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
    } catch {
        Write-Host "    [!] Failed to download $file" -ForegroundColor Yellow
    }
}

# Download example configs from root
$exampleFiles = @(
    "config_PPM.yml",
    "config_CAMM.yml"
)

foreach ($file in $exampleFiles) {
    $url = "$configRepo/raw/main/$file"
    $destination = Join-Path $configDir $file

    Write-Host "    -> Downloading: $file" -ForegroundColor White
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
    } catch {
        Write-Host "    [!] Failed to download $file" -ForegroundColor Yellow
    }
}

# Download resources folder
Write-Host "    -> Downloading resources..." -ForegroundColor White
$resourcesDir = Join-Path $configDir "resources"
if (-not (Test-Path $resourcesDir)) {
    New-Item -ItemType Directory -Path $resourcesDir -Force | Out-Null
}

$resourcesUrl = "$configRepo/raw/main/resources/resources_LOCI.yml"
$resourcesDest = Join-Path $resourcesDir "resources_LOCI.yml"
try {
    Invoke-WebRequest -Uri $resourcesUrl -OutFile $resourcesDest -ErrorAction Stop
} catch {
    Write-Host "    [!] Failed to download resources" -ForegroundColor Yellow
}

Write-Host "[+] Configuration templates downloaded" -ForegroundColor Green

# QuPath setup
if (-not $SkipQuPath) {
    Write-Host ""
    Write-Host "[+] Setting up QuPath..." -ForegroundColor Cyan

    # Check if QuPath is already installed
    $quPathExe = Join-Path $QuPathDir "QuPath.exe"
    if (Test-Path $quPathExe) {
        Write-Host "    Found QuPath at: $QuPathDir" -ForegroundColor Green
    } else {
        Write-Host "    QuPath not found at: $QuPathDir" -ForegroundColor Yellow
        Write-Host "    Please download and install QuPath 0.5.0+ from:" -ForegroundColor Yellow
        Write-Host "    https://qupath.github.io/" -ForegroundColor Cyan
        Write-Host ""
        $installQuPath = Read-Host "    Would you like to open the QuPath download page? (y/n)"
        if ($installQuPath -eq 'y') {
            Start-Process "https://qupath.github.io/"
        }
    }

    # Download QuPath extensions
    Write-Host ""
    Write-Host "[+] Downloading QuPath extensions..." -ForegroundColor Cyan

    $extensionsDir = Join-Path $QuPathDir "extensions"
    if (-not (Test-Path $extensionsDir)) {
        Write-Host "    Creating extensions directory: $extensionsDir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $extensionsDir -Force | Out-Null
    }

    # Extension repositories and their latest release URLs
    $extensions = @{
        "qupath-extension-qpsc" = "uw-loci/qupath-extension-qpsc"
        "qupath-extension-tiles-to-pyramid" = "uw-loci/qupath-extension-tiles-to-pyramid"
    }

    foreach ($ext in $extensions.GetEnumerator()) {
        $extName = $ext.Key
        $extRepo = $ext.Value

        Write-Host "    -> Checking: $extName" -ForegroundColor White

        # Get latest release
        $apiUrl = "https://api.github.com/repos/$extRepo/releases/latest"
        try {
            $release = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop

            # Find JAR file in assets
            $jarAsset = $release.assets | Where-Object { $_.name -like "*.jar" } | Select-Object -First 1

            if ($jarAsset) {
                $jarName = $jarAsset.name
                $jarUrl = $jarAsset.browser_download_url
                $jarDest = Join-Path $extensionsDir $jarName

                if (Test-Path $jarDest) {
                    Write-Host "       Already installed: $jarName" -ForegroundColor Green
                } else {
                    Write-Host "       Downloading: $jarName" -ForegroundColor Cyan
                    Invoke-WebRequest -Uri $jarUrl -OutFile $jarDest
                    Write-Host "       Installed: $jarName" -ForegroundColor Green
                }
            } else {
                Write-Host "       [!] No JAR file found in latest release" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "       [!] Failed to get latest release for $extName" -ForegroundColor Red
            Write-Host "       Please download manually from: https://github.com/$extRepo/releases" -ForegroundColor Yellow
        }
    }
}

# Check for Micro-Manager
Write-Host ""
Write-Host "[+] Checking Micro-Manager installation..." -ForegroundColor Cyan
$mmDirs = @(
    "C:\Program Files\Micro-Manager-2.0",
    "C:\Program Files\Micro-Manager",
    "C:\Micro-Manager-2.0",
    "C:\Micro-Manager"
)

$mmFound = $false
foreach ($mmDir in $mmDirs) {
    if (Test-Path $mmDir) {
        Write-Host "    Found Micro-Manager at: $mmDir" -ForegroundColor Green
        $mmFound = $true
        break
    }
}

if (-not $mmFound) {
    Write-Host "    [!] Micro-Manager not found" -ForegroundColor Yellow
    Write-Host "    Please download and install Micro-Manager 2.0+ from:" -ForegroundColor Yellow
    Write-Host "    https://micro-manager.org/Download_Micro-Manager_Latest_Release" -ForegroundColor Cyan
}

# Create launcher script
Write-Host ""
Write-Host "[+] Creating launcher script..." -ForegroundColor Cyan

$launcherScript = @"
# QPSC Launch Script
# Starts Micro-Manager server and optionally QuPath

Write-Host "Starting QPSC System..." -ForegroundColor Cyan

# Start microscope server in background
Write-Host "[+] Starting microscope server..." -ForegroundColor Green
Start-Process -NoNewWindow -FilePath "python" -ArgumentList "-m microscope_server.server.qp_server"

# Wait for server to initialize
Start-Sleep -Seconds 3

# Launch QuPath if requested
if (`$args -contains "--qupath") {
    Write-Host "[+] Launching QuPath..." -ForegroundColor Green
    `$quPathExe = "$quPathExe"
    if (Test-Path `$quPathExe) {
        Start-Process `$quPathExe
    } else {
        Write-Host "[!] QuPath not found at: `$quPathExe" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "QPSC System Started" -ForegroundColor Green
Write-Host "  - Microscope server is running" -ForegroundColor White
Write-Host "  - Press Ctrl+C to stop the server" -ForegroundColor White
Write-Host ""

# Keep script running
Read-Host "Press Enter to stop the microscope server"
"@

$launcherPath = Join-Path $InstallDir "Launch-QPSC.ps1"
$launcherScript | Out-File -FilePath $launcherPath -Encoding UTF8
Write-Host "    Created: $launcherPath" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installation Directory:" -ForegroundColor Cyan
Write-Host "  $InstallDir" -ForegroundColor White
Write-Host ""
Write-Host "Installed Components:" -ForegroundColor Cyan
Write-Host "  [+] Python packages (microscope-server, microscope-control, ppm-library)" -ForegroundColor White
Write-Host "  [+] Configuration templates" -ForegroundColor White
if (-not $SkipQuPath) {
    Write-Host "  [+] QuPath extensions (if available)" -ForegroundColor White
}
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Configure your microscope:" -ForegroundColor White
Write-Host "     Edit: $configDir\config_template.yml" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. Set up Micro-Manager device adapters for your hardware" -ForegroundColor White
Write-Host ""
Write-Host "  3. Launch QPSC:" -ForegroundColor White
Write-Host "     $launcherPath --qupath" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Or manually:" -ForegroundColor White
Write-Host "     microscope-server          # Start server" -ForegroundColor Yellow
Write-Host "     QuPath.exe                 # Start QuPath" -ForegroundColor Yellow
Write-Host ""

# Launch if requested
if ($Launch) {
    Write-Host "[+] Launching QPSC..." -ForegroundColor Green
    & $launcherPath --qupath
}
