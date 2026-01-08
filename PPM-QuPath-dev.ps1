# PPM-QuPath Development Setup Script
# Clones all QPSC repositories for development workflow

param(
    [string]$TargetDir = "C:\QPSC_Dev",
    [switch]$SkipPython,
    [switch]$SkipJava
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QPSC Development Environment Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create target directory
if (-not (Test-Path $TargetDir)) {
    Write-Host "[+] Creating directory: $TargetDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
} else {
    Write-Host "[!] Directory exists: $TargetDir" -ForegroundColor Yellow
}

Set-Location $TargetDir

# Repository URLs
$repos = @{
    # QuPath Extensions (Java)
    "qupath-extension-qpsc" = "https://github.com/uw-loci/qupath-extension-qpsc.git"
    "qupath-extension-tiles-to-pyramid" = "https://github.com/uw-loci/qupath-extension-tiles-to-pyramid.git"

    # Python Microscope Control
    "microscope_command_server" = "https://github.com/uw-loci/microscope_command_server.git"
    "microscope_control" = "https://github.com/uw-loci/microscope_control.git"
    "ppm_library" = "https://github.com/uw-loci/ppm_library.git"
    "microscope_configurations" = "https://github.com/uw-loci/microscope_configurations.git"
}

# Clone repositories
Write-Host ""
Write-Host "Cloning Repositories..." -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

foreach ($repo in $repos.GetEnumerator()) {
    $repoName = $repo.Key
    $repoUrl = $repo.Value
    $repoPath = Join-Path $TargetDir $repoName

    if (Test-Path $repoPath) {
        Write-Host "[!] Already exists: $repoName (skipping)" -ForegroundColor Yellow
    } else {
        Write-Host "[+] Cloning: $repoName" -ForegroundColor Green
        git clone $repoUrl $repoPath

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    -> Success" -ForegroundColor Green
        } else {
            Write-Host "    -> FAILED" -ForegroundColor Red
        }
    }
}

# Setup Python development environment
if (-not $SkipPython) {
    Write-Host ""
    Write-Host "Setting up Python Development Environment..." -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan

    # Check for Python
    try {
        $pythonVersion = python --version
        Write-Host "[+] Found: $pythonVersion" -ForegroundColor Green
    } catch {
        Write-Host "[!] Python not found - please install Python 3.9+ first" -ForegroundColor Red
        exit 1
    }

    # Create virtual environment
    $venvPath = Join-Path $TargetDir "venv_qpsc"
    if (-not (Test-Path $venvPath)) {
        Write-Host "[+] Creating virtual environment: venv_qpsc" -ForegroundColor Green
        python -m venv $venvPath
    } else {
        Write-Host "[!] Virtual environment exists (skipping)" -ForegroundColor Yellow
    }

    # Activate virtual environment and install packages in editable mode
    Write-Host "[+] Installing Python packages in development mode..." -ForegroundColor Green

    $activateScript = Join-Path $venvPath "Scripts\Activate.ps1"

    # Install in dependency order
    $installOrder = @(
        "ppm_library",
        "microscope_control",
        "microscope_command_server"
    )

    foreach ($pkg in $installOrder) {
        $pkgPath = Join-Path $TargetDir $pkg
        if (Test-Path $pkgPath) {
            Write-Host "    -> Installing: $pkg" -ForegroundColor Cyan
            & $activateScript
            pip install -e $pkgPath
        }
    }

    Write-Host ""
    Write-Host "[+] Python packages installed in editable mode" -ForegroundColor Green
    Write-Host "    To activate: $activateScript" -ForegroundColor Cyan
}

# Setup Java development environment
if (-not $SkipJava) {
    Write-Host ""
    Write-Host "Java Development Setup..." -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan

    # Check for Java
    try {
        $javaVersion = java -version 2>&1 | Select-Object -First 1
        Write-Host "[+] Found: $javaVersion" -ForegroundColor Green
    } catch {
        Write-Host "[!] Java not found - please install Java 21+ first" -ForegroundColor Red
    }

    # Check for Gradle
    try {
        $gradleVersion = gradle --version | Select-Object -First 1
        Write-Host "[+] Found: $gradleVersion" -ForegroundColor Green
    } catch {
        Write-Host "[!] Gradle not found (QuPath extensions use gradlew wrapper)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "[+] To build QuPath extensions:" -ForegroundColor Cyan
    Write-Host "    cd $TargetDir\qupath-extension-qpsc" -ForegroundColor White
    Write-Host "    .\gradlew build" -ForegroundColor White
}

# Create configuration directory
$configDir = Join-Path $TargetDir "configs"
if (-not (Test-Path $configDir)) {
    Write-Host ""
    Write-Host "[+] Creating configs directory: $configDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null

    # Copy configuration templates
    $templateSource = Join-Path $TargetDir "microscope_configurations"
    if (Test-Path $templateSource) {
        Write-Host "[+] Copying configuration templates..." -ForegroundColor Green

        # Copy template files from templates/ folder
        $templatesFolder = Join-Path $templateSource "templates"
        if (Test-Path $templatesFolder) {
            Copy-Item -Path "$templatesFolder\*" -Destination $configDir -Force
        }

        # Copy example configs from root
        Copy-Item -Path "$templateSource\config_PPM.yml" -Destination $configDir -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "$templateSource\config_CAMM.yml" -Destination $configDir -Force -ErrorAction SilentlyContinue

        # Copy resources folder
        Copy-Item -Path "$templateSource\resources" -Destination $configDir -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "    -> Templates copied to: $configDir" -ForegroundColor Cyan
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Development Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Repository Structure:" -ForegroundColor Cyan
Write-Host "  $TargetDir\" -ForegroundColor White
Write-Host "  ├── qupath-extension-qpsc/           (Java)" -ForegroundColor White
Write-Host "  ├── qupath-extension-tiles-to-pyramid/ (Java)" -ForegroundColor White
Write-Host "  ├── microscope_command_server/       (Python)" -ForegroundColor White
Write-Host "  ├── microscope_control/              (Python)" -ForegroundColor White
Write-Host "  ├── ppm_library/                     (Python)" -ForegroundColor White
Write-Host "  ├── microscope_configurations/       (YAML)" -ForegroundColor White
Write-Host "  ├── configs/                         (Your configs)" -ForegroundColor White
Write-Host "  └── venv_qpsc/                       (Python venv)" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Activate Python environment:" -ForegroundColor White
Write-Host "     $activateScript" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. Build QuPath extensions:" -ForegroundColor White
Write-Host "     cd $TargetDir\qupath-extension-qpsc" -ForegroundColor Yellow
Write-Host "     .\gradlew build" -ForegroundColor Yellow
Write-Host ""
Write-Host "  3. Configure your microscope:" -ForegroundColor White
Write-Host "     Edit files in: $configDir" -ForegroundColor Yellow
Write-Host ""
Write-Host "  4. Start microscope server:" -ForegroundColor White
Write-Host "     microscope-server" -ForegroundColor Yellow
Write-Host ""
