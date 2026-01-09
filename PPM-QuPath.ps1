# QPSC Setup Script
# Supports both production (GitHub URL installation) and development (editable mode) setups

param(
    [string]$InstallDir = "$env:USERPROFILE\QPSC",
    [switch]$Development,
    [string]$QuPathDir = "$env:USERPROFILE\QuPath",
    [switch]$SkipQuPath,
    [switch]$Launch
)

$setupMode = if ($Development) { "Development" } else { "Production" }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QPSC $setupMode Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create installation directory
if (-not (Test-Path $InstallDir)) {
    Write-Host "[+] Creating installation directory: $InstallDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

Set-Location $InstallDir

# Check for Git if in development mode
if ($Development) {
    Write-Host "[+] Checking Git installation..." -ForegroundColor Cyan
    try {
        $gitVersion = git --version
        Write-Host "    Found: $gitVersion" -ForegroundColor Green
    } catch {
        Write-Host "[!] Git not found - please install Git from https://git-scm.com/download/win" -ForegroundColor Red
        exit 1
    }
}

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

# Install Python packages
Write-Host ""
Write-Host "[+] Installing Python microscope control packages..." -ForegroundColor Cyan

if ($Development) {
    Write-Host "    Mode: Development (editable install)" -ForegroundColor Yellow
    Write-Host ""

    # Repository URLs for cloning
    $repos = @{
        "ppm_library" = "https://github.com/uw-loci/ppm_library.git"
        "microscope_control" = "https://github.com/uw-loci/microscope_control.git"
        "microscope_command_server" = "https://github.com/uw-loci/microscope_command_server.git"
        "microscope_configurations" = "https://github.com/uw-loci/microscope_configurations.git"
    }

    # Clone Python repositories
    Write-Host "[+] Cloning Python repositories..." -ForegroundColor Cyan
    foreach ($repo in $repos.GetEnumerator()) {
        $repoName = $repo.Key
        $repoUrl = $repo.Value
        $repoPath = Join-Path $InstallDir $repoName

        if (Test-Path $repoPath) {
            Write-Host "    -> Already exists: $repoName (skipping)" -ForegroundColor Yellow
        } else {
            Write-Host "    -> Cloning: $repoName" -ForegroundColor White
            git clone $repoUrl $repoPath 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "       Success" -ForegroundColor Green
            } else {
                Write-Host "       FAILED" -ForegroundColor Red
            }
        }
    }

    # Create virtual environment
    Write-Host ""
    $venvPath = Join-Path $InstallDir "venv_qpsc"
    if (-not (Test-Path $venvPath)) {
        Write-Host "[+] Creating virtual environment: venv_qpsc" -ForegroundColor Green
        python -m venv $venvPath
    } else {
        Write-Host "[!] Virtual environment exists (skipping creation)" -ForegroundColor Yellow
    }

    # Install packages in editable mode (dependency order is critical)
    Write-Host "[+] Installing packages in editable mode..." -ForegroundColor Green
    $activateScript = Join-Path $venvPath "Scripts\Activate.ps1"

    $installOrder = @(
        "ppm_library",
        "microscope_control",
        "microscope_command_server"
    )

    foreach ($pkg in $installOrder) {
        $pkgPath = Join-Path $InstallDir $pkg
        if (Test-Path $pkgPath) {
            Write-Host "    -> Installing: $pkg" -ForegroundColor Cyan
            & $activateScript
            pip install -e $pkgPath
        }
    }

    # Also install pycromanager
    Write-Host "    -> Installing: pycromanager" -ForegroundColor Cyan
    & $activateScript
    pip install pycromanager

    Write-Host ""
    Write-Host "[+] Python packages installed in development mode" -ForegroundColor Green
    Write-Host "    Virtual environment: $venvPath" -ForegroundColor Cyan
    Write-Host "    To activate: $activateScript" -ForegroundColor Cyan

} else {
    Write-Host "    Mode: Production (GitHub URL installation)" -ForegroundColor Yellow
    Write-Host ""

    # Install from GitHub URLs in dependency order
    $githubPackages = @(
        @{name="ppm-library"; url="git+https://github.com/uw-loci/ppm_library.git"},
        @{name="microscope-control"; url="git+https://github.com/uw-loci/microscope_control.git"},
        @{name="microscope-server"; url="git+https://github.com/uw-loci/microscope_command_server.git"},
        @{name="pycromanager"; url="pycromanager"}
    )

    foreach ($pkg in $githubPackages) {
        $pkgName = $pkg.name
        $pkgUrl = $pkg.url

        Write-Host "    -> Installing: $pkgName" -ForegroundColor White
        pip install --upgrade $pkgUrl

        if ($LASTEXITCODE -ne 0) {
            Write-Host "       [!] Failed to install $pkgName" -ForegroundColor Red
        } else {
            Write-Host "       Success" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "[+] Python packages installed" -ForegroundColor Green
}

# Download configuration templates
Write-Host ""
Write-Host "[+] Downloading configuration templates..." -ForegroundColor Cyan

$configDir = Join-Path $InstallDir "configurations"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

if ($Development) {
    # In development mode, copy from cloned repo
    $templateSource = Join-Path $InstallDir "microscope_configurations"
    if (Test-Path $templateSource) {
        Write-Host "    -> Copying from cloned repository" -ForegroundColor Cyan

        # Copy templates
        $templatesFolder = Join-Path $templateSource "templates"
        if (Test-Path $templatesFolder) {
            Copy-Item -Path "$templatesFolder\*" -Destination $configDir -Force
        }

        # Copy example configs
        Copy-Item -Path "$templateSource\config_PPM.yml" -Destination $configDir -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "$templateSource\config_CAMM.yml" -Destination $configDir -Force -ErrorAction SilentlyContinue

        # Copy resources
        $resourcesSource = Join-Path $templateSource "resources"
        $resourcesDest = Join-Path $configDir "resources"
        if (Test-Path $resourcesSource) {
            if (-not (Test-Path $resourcesDest)) {
                New-Item -ItemType Directory -Path $resourcesDest -Force | Out-Null
            }
            Copy-Item -Path "$resourcesSource\*" -Destination $resourcesDest -Force
        }
    }
} else {
    # In production mode, download from GitHub
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
            Write-Host "       [!] Failed to download $file" -ForegroundColor Yellow
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
            Write-Host "       [!] Failed to download $file" -ForegroundColor Yellow
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
        Write-Host "       [!] Failed to download resources" -ForegroundColor Yellow
    }
}

Write-Host "[+] Configuration templates ready" -ForegroundColor Green

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
        Write-Host "    Please download and install QuPath 0.6.0+ from:" -ForegroundColor Yellow
        Write-Host "    https://qupath.github.io/" -ForegroundColor Cyan
        Write-Host ""
        $installQuPath = Read-Host "    Would you like to open the QuPath download page? (y/n)"
        if ($installQuPath -eq 'y') {
            Start-Process "https://qupath.github.io/"
        }
    }

    if ($Development) {
        # In development mode, clone QuPath extension repositories
        Write-Host ""
        Write-Host "[+] Cloning QuPath extension repositories..." -ForegroundColor Cyan

        $javaRepos = @{
            "qupath-extension-qpsc" = "https://github.com/uw-loci/qupath-extension-qpsc.git"
            "qupath-extension-tiles-to-pyramid" = "https://github.com/uw-loci/qupath-extension-tiles-to-pyramid.git"
        }

        foreach ($repo in $javaRepos.GetEnumerator()) {
            $repoName = $repo.Key
            $repoUrl = $repo.Value
            $repoPath = Join-Path $InstallDir $repoName

            if (Test-Path $repoPath) {
                Write-Host "    -> Already exists: $repoName (skipping)" -ForegroundColor Yellow
            } else {
                Write-Host "    -> Cloning: $repoName" -ForegroundColor White
                git clone $repoUrl $repoPath 2>&1 | Out-Null

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "       Success" -ForegroundColor Green
                } else {
                    Write-Host "       FAILED" -ForegroundColor Red
                }
            }
        }

        Write-Host ""
        Write-Host "[+] To build QuPath extensions:" -ForegroundColor Cyan
        Write-Host "    cd $InstallDir\qupath-extension-qpsc" -ForegroundColor Yellow
        Write-Host "    .\gradlew build" -ForegroundColor Yellow

    } else {
        # In production mode, download QuPath extensions
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

if ($Development) {
    $activateCmd = Join-Path (Join-Path $InstallDir "venv_qpsc") "Scripts\Activate.ps1"
    $pythonCmd = "& '$activateCmd'; python -m microscope_command_server.server.qp_server"
} else {
    $pythonCmd = "python -m microscope_command_server.server.qp_server"
}

$launcherScript = @"
# QPSC Launch Script
# Starts Micro-Manager server and optionally QuPath

Write-Host "Starting QPSC System..." -ForegroundColor Cyan

# Start microscope server in background
Write-Host "[+] Starting microscope server..." -ForegroundColor Green
$pythonCmd

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
Write-Host "Setup Mode:" -ForegroundColor Cyan
Write-Host "  $setupMode" -ForegroundColor White
Write-Host ""
Write-Host "Installed Components:" -ForegroundColor Cyan

if ($Development) {
    Write-Host "  [+] Python packages (editable mode in venv_qpsc)" -ForegroundColor White
    Write-Host "  [+] All repositories cloned for development" -ForegroundColor White
} else {
    Write-Host "  [+] Python packages (from GitHub)" -ForegroundColor White
}

Write-Host "  [+] Configuration templates" -ForegroundColor White

if (-not $SkipQuPath) {
    if ($Development) {
        Write-Host "  [+] QuPath extension source code (cloned)" -ForegroundColor White
    } else {
        Write-Host "  [+] QuPath extensions (JAR files)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan

if ($Development) {
    Write-Host "  1. Activate Python environment:" -ForegroundColor White
    $venvActivate = Join-Path (Join-Path $InstallDir "venv_qpsc") "Scripts\Activate.ps1"
    Write-Host "     $venvActivate" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  2. Build QuPath extensions:" -ForegroundColor White
    Write-Host "     cd $InstallDir\qupath-extension-qpsc" -ForegroundColor Yellow
    Write-Host "     .\gradlew build" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  3. Copy built JAR files to QuPath extensions folder" -ForegroundColor White
    Write-Host ""
    Write-Host "  4. Configure your microscope:" -ForegroundColor White
} else {
    Write-Host "  1. Configure your microscope:" -ForegroundColor White
}

Write-Host "     Edit: $configDir\config_template.yml" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. Set up Micro-Manager device adapters for your hardware" -ForegroundColor White
Write-Host ""
Write-Host "  3. Launch QPSC:" -ForegroundColor White
Write-Host "     $launcherPath --qupath" -ForegroundColor Yellow

if (-not $Development) {
    Write-Host ""
    Write-Host "  Or manually:" -ForegroundColor White
    Write-Host "     python -m microscope_command_server.server.qp_server  # Start server" -ForegroundColor Yellow
    Write-Host "     QuPath.exe                                            # Start QuPath" -ForegroundColor Yellow
}

Write-Host ""

# Launch if requested
if ($Launch) {
    Write-Host "[+] Launching QPSC..." -ForegroundColor Green
    & $launcherPath --qupath
}
