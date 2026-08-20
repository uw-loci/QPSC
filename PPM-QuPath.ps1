# QPSC Setup Script
# Supports both production (GitHub URL installation) and development (editable mode) setups

param(
    [string]$InstallDir = "$env:USERPROFILE\QPSC",
    [switch]$Development,
    [string]$QuPathDir = "$env:USERPROFILE\QuPath",
    [switch]$SkipQuPath,
    [switch]$Launch,
    [string]$PythonExe
)

$setupMode = if ($Development) { "Development" } else { "Production" }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QPSC $setupMode Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# If user did not explicitly pass -InstallDir, prompt to confirm or change
if (-not $PSBoundParameters.ContainsKey('InstallDir')) {
    Write-Host "Installation directory: $InstallDir" -ForegroundColor White
    Write-Host ""
    $userInput = Read-Host "Press Enter to accept, or type a new path"
    if ($userInput -ne "") {
        $InstallDir = $userInput.Trim('"').Trim("'")
    }
    Write-Host ""
}

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

# Check for Python.
#
# Do NOT wrap a native command in try/catch to test for it: try/catch only traps
# PowerShell *terminating* errors, and an .exe that exits nonzero is not one. The
# old code did exactly that, so when 'python' resolved to the Microsoft Store stub
# the catch never fired, the version string came back empty, and setup carried on
# to die later at venv creation with "ensure Python venv module is available" --
# a wrong diagnosis that sent people looking at venv instead of at PATH.
Write-Host "[+] Checking Python installation..." -ForegroundColor Cyan

$storeStubSeen = $false

function Find-Python {
    param([string]$Explicit)

    $candidates = if ($Explicit) { @($Explicit) } else { @("python", "python3", "py") }

    foreach ($candidate in $candidates) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }

        # Windows puts stub launchers in WindowsApps whose only job is to
        # advertise the Microsoft Store. They resolve exactly like a real
        # python.exe, so reject them by path instead of by running them.
        if ($cmd.Source -like "*\WindowsApps\*") {
            $script:storeStubSeen = $true
            continue
        }

        $reported = (& $candidate --version 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) { continue }
        if ($reported -notmatch "Python\s+(\d+)\.(\d+)") { continue }

        return [pscustomobject]@{
            Path  = $cmd.Source
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Text  = $reported.Trim()
        }
    }
    return $null
}

$python = Find-Python -Explicit $PythonExe

if (-not $python) {
    if ($PythonExe) {
        Write-Host "[!] -PythonExe '$PythonExe' is not a usable Python interpreter." -ForegroundColor Red
    } else {
        Write-Host "[!] No usable Python found on PATH." -ForegroundColor Red
    }
    if ($storeStubSeen) {
        Write-Host "    'python' here resolves to the Microsoft Store stub in WindowsApps," -ForegroundColor Yellow
        Write-Host "    which is not a real Python - it only prints an advert and exits." -ForegroundColor Yellow
    }
    Write-Host "" -ForegroundColor Yellow
    Write-Host "    Common causes:" -ForegroundColor Yellow
    Write-Host "      - Anaconda is installed but not on PATH. Its installer leaves it off" -ForegroundColor Yellow
    Write-Host "        by default. Use the 'Anaconda PowerShell Prompt' from the Start menu," -ForegroundColor Yellow
    Write-Host "        or run 'conda init powershell' once and restart PowerShell." -ForegroundColor Yellow
    Write-Host "      - No Python installed. Get 3.10+ from https://www.python.org/ and tick" -ForegroundColor Yellow
    Write-Host "        'Add Python to PATH' during installation." -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "    Or point this script straight at an interpreter:" -ForegroundColor Yellow
    Write-Host "      .\PPM-QuPath.ps1 -PythonExe 'C:\Users\you\anaconda3\python.exe'" -ForegroundColor Yellow
    if ($storeStubSeen) {
        Write-Host "" -ForegroundColor Yellow
        Write-Host "    To stop the stub shadowing a real Python: Settings > Apps > Advanced" -ForegroundColor Yellow
        Write-Host "    app settings > App execution aliases > turn off python.exe/python3.exe." -ForegroundColor Yellow
    }
    exit 1
}

# All four microscope packages declare requires-python >= 3.10. Fail here with a
# clear message rather than deep inside a pip resolution error.
if ($python.Major -lt 3 -or ($python.Major -eq 3 -and $python.Minor -lt 10)) {
    Write-Host "[!] Found $($python.Text) at $($python.Path)" -ForegroundColor Red
    Write-Host "    QPSC needs Python 3.10 or newer." -ForegroundColor Yellow
    Write-Host "    With Anaconda: conda create -n qpsc python=3.12, then activate it." -ForegroundColor Yellow
    exit 1
}

Write-Host "    Found: $($python.Text)" -ForegroundColor Green
Write-Host "    Using: $($python.Path)" -ForegroundColor DarkGray
$pythonExePath = $python.Path

# Install Python packages
Write-Host ""
Write-Host "[+] Installing Python microscope control packages..." -ForegroundColor Cyan

if ($Development) {
    Write-Host "    Mode: Development (editable install)" -ForegroundColor Yellow
    Write-Host ""

    # Repository URLs for cloning
    $repos = @{
        "microscope_imageprocessing" = "https://github.com/uw-loci/microscope_imageprocessing.git"
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
        & $pythonExePath -m venv $venvPath
    } else {
        Write-Host "[!] Virtual environment exists (skipping creation)" -ForegroundColor Yellow
    }

    # Upgrade pip first (pip 21.2.3 bundled with Python 3.10 does not support
    # PEP 660 editable installs with pyproject.toml-only packages)
    Write-Host "[+] Upgrading pip in virtual environment..." -ForegroundColor Cyan
    $venvPython = Join-Path $venvPath "Scripts\python.exe"
    & $venvPython -m pip install --upgrade pip --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    [!] pip upgrade failed - editable installs may not work" -ForegroundColor Yellow
        Write-Host "    Continuing anyway..." -ForegroundColor Yellow
    } else {
        Write-Host "    pip upgraded successfully" -ForegroundColor Green
    }

    # Install packages in editable mode (dependency order is critical)
    Write-Host "[+] Installing packages in editable mode..." -ForegroundColor Green
    $venvPip = Join-Path $venvPath "Scripts\pip.exe"

    $installOrder = @(
        "microscope_imageprocessing",
        "ppm_library",
        "microscope_control",
        "microscope_command_server"
    )

    foreach ($pkg in $installOrder) {
        $pkgPath = Join-Path $InstallDir $pkg
        if (Test-Path $pkgPath) {
            Write-Host "    -> Installing: $pkg" -ForegroundColor Cyan
            & $venvPip install -e $pkgPath
        }
    }

    # Also install standalone packages not included in the editable packages
    Write-Host "    -> Installing: opencv-python-headless" -ForegroundColor Cyan
    & $venvPip install opencv-python-headless

    Write-Host "    -> Installing: pycromanager" -ForegroundColor Cyan
    & $venvPip install pycromanager

    Write-Host ""
    Write-Host "[+] Python packages installed in development mode" -ForegroundColor Green
    Write-Host "    Virtual environment: $venvPath" -ForegroundColor Cyan
    Write-Host "    To activate: $activateScript" -ForegroundColor Cyan

} else {
    Write-Host "    Mode: Production (GitHub URL installation with virtual environment)" -ForegroundColor Yellow
    Write-Host ""

    # Create virtual environment
    $venvPath = Join-Path $InstallDir "venv_qpsc"
    if (-not (Test-Path $venvPath)) {
        Write-Host "[+] Creating virtual environment: venv_qpsc" -ForegroundColor Green
        & $pythonExePath -m venv $venvPath

        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Failed to create virtual environment" -ForegroundColor Red
            Write-Host "    Please ensure Python venv module is available" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "[!] Virtual environment exists (skipping creation)" -ForegroundColor Yellow
    }

    # Get activation script path
    $activateScript = Join-Path $venvPath "Scripts\Activate.ps1"

    # Upgrade pip first (avoids noisy "pip version" warnings on every install)
    Write-Host ""
    Write-Host "[+] Upgrading pip in virtual environment..." -ForegroundColor Cyan
    $venvPython = Join-Path $venvPath "Scripts\python.exe"
    & $venvPython -m pip install --upgrade pip --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    pip upgraded successfully" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "[+] Installing packages into virtual environment..." -ForegroundColor Green
    Write-Host "    Virtual environment: $venvPath" -ForegroundColor Cyan

    # Install from GitHub URLs in dependency order
    $githubPackages = @(
        @{name="opencv-python-headless"; url="opencv-python-headless"},
        @{name="microscope-imageprocessing"; url="git+https://github.com/uw-loci/microscope_imageprocessing.git"},
        @{name="ppm-library"; url="git+https://github.com/uw-loci/ppm_library.git"},
        @{name="microscope-control"; url="git+https://github.com/uw-loci/microscope_control.git"},
        @{name="microscope-command-server"; url="git+https://github.com/uw-loci/microscope_command_server.git"},
        @{name="pycromanager"; url="pycromanager"}
    )

    foreach ($pkg in $githubPackages) {
        $pkgName = $pkg.name
        $pkgUrl = $pkg.url

        Write-Host "    -> Installing: $pkgName" -ForegroundColor White

        # Use venv pip directly (activation doesn't persist across commands)
        $venvPip = Join-Path $venvPath "Scripts\pip.exe"
        & $venvPip install --upgrade $pkgUrl

        if ($LASTEXITCODE -ne 0) {
            Write-Host "       [!] Failed to install $pkgName" -ForegroundColor Red
        } else {
            Write-Host "       Success" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "[+] Python packages installed in virtual environment" -ForegroundColor Green
    Write-Host "    Virtual environment: $venvPath" -ForegroundColor Cyan
    Write-Host "    To activate: $activateScript" -ForegroundColor Cyan
}

# Verify package installation
Write-Host ""
Write-Host "[+] Verifying package installation..." -ForegroundColor Cyan

$packagesToVerify = @("opencv-python-headless", "microscope-imageprocessing", "microscope-command-server", "microscope-control", "ppm-library", "pycromanager")
$allPackagesInstalled = $true

# Both Development and Production modes now use venv
$venvPath = Join-Path $InstallDir "venv_qpsc"
$venvPip = Join-Path $venvPath "Scripts\pip.exe"

# Check packages using venv pip directly
foreach ($pkg in $packagesToVerify) {
    $verifyResult = & $venvPip show $pkg 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [OK] $pkg" -ForegroundColor Green
    } else {
        Write-Host "    [FAIL] $pkg - NOT INSTALLED" -ForegroundColor Red
        $allPackagesInstalled = $false
    }
}

if (-not $allPackagesInstalled) {
    Write-Host ""
    Write-Host "[!] ERROR: Some packages failed to install!" -ForegroundColor Red
    Write-Host "    Please check the error messages above and try again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Common fixes:" -ForegroundColor Yellow
    Write-Host "      - Ensure you have internet connection" -ForegroundColor White
    Write-Host "      - Try running: pip install --upgrade pip" -ForegroundColor White
    Write-Host "      - Check if Git is installed (required for git+ URLs)" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "[+] All packages verified successfully" -ForegroundColor Green

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
        Copy-Item -Path "$templateSource\config_OWS3.yml" -Destination $configDir -Force -ErrorAction SilentlyContinue

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
        "config_CAMM.yml",
        "config_OWS3.yml"
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

    # Search for QuPath installation
    Write-Host "    Searching for QuPath installation..." -ForegroundColor White

    $quPathExe = $null
    $searchPaths = @(
        # User-specified path (if provided as parameter)
        $QuPathDir,
        # MSI installation default (AppData\Local with version)
        (Get-ChildItem -Path "$env:LOCALAPPDATA\QuPath-*" -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            Select-Object -First 1 -ExpandProperty FullName),
        # Alternative MSI location
        "$env:LOCALAPPDATA\QuPath",
        # Portable installation in user profile
        "$env:USERPROFILE\QuPath",
        # Program Files locations
        "${env:ProgramFiles}\QuPath",
        "${env:ProgramFiles(x86)}\QuPath"
    )

    foreach ($path in $searchPaths) {
        if (-not $path) { continue }

        # Try multiple QuPath executable locations
        $possibleExes = @(
            "$path\QuPath.exe",           # Standard location
            "$path\QuPath-*.exe",         # Versioned executable (e.g., QuPath-0.6.0.exe)
            "$path\bin\QuPath.exe"        # Alternative location
        )

        foreach ($exePattern in $possibleExes) {
            $foundExe = Get-ChildItem -Path $exePattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($foundExe) {
                $quPathExe = $foundExe.FullName
                $QuPathDir = $path
                Write-Host "    Found QuPath at: $quPathExe" -ForegroundColor Green
                break
            }
        }

        if ($quPathExe) { break }
    }

    if (-not $quPathExe) {
        Write-Host "    [!] QuPath not found in common locations" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor Yellow
        Write-Host "    Searched:" -ForegroundColor Yellow
        Write-Host "      - $env:LOCALAPPDATA\QuPath-*" -ForegroundColor Gray
        Write-Host "      - $env:USERPROFILE\QuPath" -ForegroundColor Gray
        Write-Host "      - ${env:ProgramFiles}\QuPath" -ForegroundColor Gray
        Write-Host ""
        Write-Host "    You can continue setup without QuPath auto-detection." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "    To use QuPath with QPSC later:" -ForegroundColor Yellow
        Write-Host "      1. Install QuPath 0.6.0+ from: https://qupath.github.io/" -ForegroundColor Cyan
        Write-Host "      2. Or re-run this script with -QuPathDir parameter pointing to your QuPath installation" -ForegroundColor Cyan
        Write-Host "         Example: .\PPM-QuPath.ps1 -QuPathDir 'C:\path\to\QuPath-0.6.0'" -ForegroundColor Gray
        Write-Host ""
        $openDownloadPage = Read-Host "    Would you like to open the QuPath download page now? (y/n)"
        if ($openDownloadPage -eq 'y') {
            Start-Process "https://qupath.github.io/"
        }
        Write-Host ""
        Write-Host "    Continuing setup..." -ForegroundColor Cyan
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
        # In production mode, download QuPath extensions (only if QuPath was found)
        if ($quPathExe) {
            Write-Host ""
            Write-Host "[+] Downloading QuPath extensions..." -ForegroundColor Cyan

            # Download JARs to local QPSC extensions folder (always accessible to user)
            $localExtensionsDir = Join-Path $InstallDir "extensions"
            if (-not (Test-Path $localExtensionsDir)) {
                Write-Host "    Creating local extensions directory: $localExtensionsDir" -ForegroundColor Cyan
                New-Item -ItemType Directory -Path $localExtensionsDir -Force | Out-Null
            }
            Write-Host "    Downloading to: $localExtensionsDir" -ForegroundColor Cyan

            # Also determine QuPath user data directory for automatic installation
            $quPathUserDataDir = Get-ChildItem -Path "$env:USERPROFILE\QuPath\v*" -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                Select-Object -First 1

            $quPathExtensionsDir = $null
            if ($quPathUserDataDir) {
                $quPathExtensionsDir = Join-Path $quPathUserDataDir.FullName "extensions"
                Write-Host "    Will also copy to QuPath: $quPathExtensionsDir" -ForegroundColor Cyan
                if (-not (Test-Path $quPathExtensionsDir)) {
                    New-Item -ItemType Directory -Path $quPathExtensionsDir -Force | Out-Null
                }
            } else {
                Write-Host "    QuPath user data directory not found - JARs will remain in local folder" -ForegroundColor Yellow
                Write-Host "    You can manually copy them to QuPath after first launch" -ForegroundColor Yellow
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

            # Get latest release (including prereleases)
            $apiUrl = "https://api.github.com/repos/$extRepo/releases"
            try {
                $releases = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop

                if ($releases.Count -eq 0) {
                    Write-Host "       [!] No releases found" -ForegroundColor Yellow
                    continue
                }

                # Get most recent release (first in list, regardless of prerelease status)
                $release = $releases[0]
                $releaseTag = $release.tag_name
                $isPrerelease = $release.prerelease

                if ($isPrerelease) {
                    Write-Host "       Found: $releaseTag (prerelease)" -ForegroundColor Yellow
                } else {
                    Write-Host "       Found: $releaseTag" -ForegroundColor Green
                }

                # Find JAR file in assets - prefer -all.jar (shadow JAR with bundled dependencies)
                $jarAsset = $release.assets | Where-Object { $_.name -like "*-all.jar" } | Select-Object -First 1

                # Fallback to regular .jar if -all.jar not found
                if (-not $jarAsset) {
                    $jarAsset = $release.assets | Where-Object { $_.name -like "*.jar" } | Select-Object -First 1
                }

                if ($jarAsset) {
                    $jarName = $jarAsset.name
                    $jarUrl = $jarAsset.browser_download_url
                    $localJarPath = Join-Path $localExtensionsDir $jarName

                    # Download to local QPSC extensions folder
                    if (Test-Path $localJarPath) {
                        Write-Host "       Already downloaded: $jarName" -ForegroundColor Green
                    } else {
                        Write-Host "       Downloading: $jarName" -ForegroundColor Cyan
                        Invoke-WebRequest -Uri $jarUrl -OutFile $localJarPath
                        Write-Host "       Downloaded: $jarName" -ForegroundColor Green
                    }
                    Write-Host "       Local location: $localJarPath" -ForegroundColor Gray

                    # Also copy to QuPath extensions directory if found
                    if ($quPathExtensionsDir) {
                        $quPathJarPath = Join-Path $quPathExtensionsDir $jarName
                        if (Test-Path $quPathJarPath) {
                            Write-Host "       Already in QuPath: $jarName" -ForegroundColor Green
                        } else {
                            Copy-Item -Path $localJarPath -Destination $quPathJarPath -Force
                            Write-Host "       Copied to QuPath: $jarName" -ForegroundColor Green
                        }
                        Write-Host "       QuPath location: $quPathJarPath" -ForegroundColor Gray
                    }
                } else {
                    Write-Host "       [!] No JAR file found in release $releaseTag" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "       [!] Failed to get releases for $extName" -ForegroundColor Red
                Write-Host "       Error: $($_.Exception.Message)" -ForegroundColor Gray
                Write-Host "       Please download manually from: https://github.com/$extRepo/releases" -ForegroundColor Yellow
            }
        }

        Write-Host ""
        Write-Host "[+] QuPath extensions download complete" -ForegroundColor Green
        Write-Host "    Downloaded to: $localExtensionsDir" -ForegroundColor Cyan
        if ($quPathExtensionsDir) {
            Write-Host "    Copied to QuPath: $quPathExtensionsDir" -ForegroundColor Cyan
        }
        Write-Host ""
        Write-Host "    IMPORTANT:" -ForegroundColor Yellow
        if (-not $quPathExtensionsDir) {
            Write-Host "    1. QuPath user data directory not found." -ForegroundColor Yellow
            Write-Host "       Launch QuPath once, then manually copy JAR files from:" -ForegroundColor Yellow
            Write-Host "       $localExtensionsDir" -ForegroundColor Gray
            Write-Host "       to your QuPath extensions directory." -ForegroundColor Yellow
            Write-Host ""
        }
        Write-Host "    1. JAR files are stored in your QPSC installation for easy access:" -ForegroundColor Yellow
        Write-Host "       $localExtensionsDir" -ForegroundColor Gray
        Write-Host ""
        Write-Host "    2. If you have configured a custom extensions directory in QuPath," -ForegroundColor Yellow
        Write-Host "       manually copy the JAR files from the location above." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "    3. If QuPath is already running, restart it to load the extensions!" -ForegroundColor Yellow
        Write-Host "       Otherwise, the QPSC menu will not appear." -ForegroundColor Yellow

        } else {
            Write-Host ""
            Write-Host "    [!] Skipping QuPath extensions download - QuPath not found" -ForegroundColor Yellow
            Write-Host "    Extensions will need to be installed manually after QuPath is installed" -ForegroundColor Yellow
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
# Starts the microscope command server and QuPath
#
# Usage:
#   .\Launch-QPSC.ps1              # Start server + QuPath
#   .\Launch-QPSC.ps1 --no-qupath  # Start server only

param([switch]`$NoQuPath)
if (`$args -contains "--no-qupath") { `$NoQuPath = `$true }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QPSC Launcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

`$venvPip = "$InstallDir\venv_qpsc\Scripts\pip.exe"
`$venvPython = "$InstallDir\venv_qpsc\Scripts\python.exe"

# --- Step 1: Verify Python packages ---
Write-Host "[1/3] Verifying Python packages..." -ForegroundColor Cyan

`$packagesOK = `$true
`$requiredPackages = @("opencv-python-headless", "microscope-imageprocessing", "microscope-command-server", "microscope-control", "ppm-library", "pycromanager")

foreach (`$pkg in `$requiredPackages) {
    `$result = & `$venvPip show `$pkg 2>`$null
    if (`$LASTEXITCODE -ne 0) {
        Write-Host "      [FAIL] `$pkg - NOT INSTALLED" -ForegroundColor Red
        `$packagesOK = `$false
    } else {
        Write-Host "      [OK] `$pkg" -ForegroundColor Green
    }
}

if (-not `$packagesOK) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ERROR: Required packages are missing" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  One or more Python packages failed verification." -ForegroundColor White
    Write-Host "  This usually means the initial setup did not complete." -ForegroundColor White
    Write-Host ""
    Write-Host "  To fix, re-run the setup script:" -ForegroundColor Yellow
    Write-Host "    .\PPM-QuPath.ps1" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "      All packages verified" -ForegroundColor Green
Write-Host ""

# --- Step 2: Test that the package can be imported ---
Write-Host "[2/3] Testing Python module import..." -ForegroundColor Cyan
`$importTest = & `$venvPython -c "import microscope_command_server; print('OK')" 2>&1
if (`$LASTEXITCODE -ne 0) {
    Write-Host "      [FAIL] Cannot import microscope_command_server" -ForegroundColor Red
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ERROR: Python import failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  The package is installed but Python cannot load it." -ForegroundColor White
    Write-Host "  This may indicate a dependency conflict or corrupt install." -ForegroundColor White
    Write-Host ""
    Write-Host "  Error details:" -ForegroundColor Yellow
    Write-Host "  `$importTest" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  To fix, try re-running setup:" -ForegroundColor Yellow
    Write-Host "    .\PPM-QuPath.ps1" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
} else {
    Write-Host "      Import successful" -ForegroundColor Green
}

Write-Host ""

# --- Step 3: Start the server ---
Write-Host "[3/3] Starting microscope command server..." -ForegroundColor Cyan
Write-Host "      The server will open in a new window." -ForegroundColor White
Write-Host ""
Write-Host "      NOTE: Micro-Manager must be running before the server" -ForegroundColor Yellow
Write-Host "      can connect. If it is not running yet, start it now --" -ForegroundColor Yellow
Write-Host "      the server will retry the connection." -ForegroundColor Yellow
Write-Host ""

Start-Process -FilePath `$venvPython -ArgumentList "-m", "microscope_command_server.server.qp_server"

Start-Sleep -Seconds 2

# --- Launch QuPath ---
if (-not `$NoQuPath) {
    `$quPathExe = "$quPathExe"
    if (`$quPathExe -and (Test-Path `$quPathExe)) {
        Write-Host "[+] Launching QuPath..." -ForegroundColor Green
        Start-Process `$quPathExe
    } else {
        Write-Host "[!] QuPath not found - please launch it manually" -ForegroundColor Yellow
        if (`$quPathExe) {
            Write-Host "    Expected at: `$quPathExe" -ForegroundColor Gray
        }
        Write-Host "    To configure, re-run: .\PPM-QuPath.ps1 -QuPathDir ""C:\path\to\QuPath""" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  QPSC System Started" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Server: running in separate window" -ForegroundColor White
Write-Host "  To stop: close the server window or Ctrl+C" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to exit launcher (server will continue running)"
"@

$launcherPath = Join-Path $InstallDir "Launch-QPSC.ps1"
$launcherScript | Out-File -FilePath $launcherPath -Encoding UTF8
Write-Host "    Created: $launcherPath" -ForegroundColor Green

# Generate batch files for development mode
if ($Development) {
    Write-Host ""
    Write-Host "[+] Creating development batch files..." -ForegroundColor Cyan

    # --- start_server.bat ---
    $startServerBat = @"
@echo off
REM ============================================================
REM  Start QPSC Microscope Command Server (Development)
REM
REM  Prerequisites:
REM    1. Micro-Manager must be running with hardware loaded
REM    2. Python packages installed in editable mode
REM
REM  Usage:
REM    Double-click this file, or run from command prompt.
REM ============================================================

setlocal

REM -- Activate virtual environment --
set "VENV_DIR=$InstallDir\venv_qpsc"

if not exist "%VENV_DIR%\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found at %VENV_DIR%
    echo Run PPM-QuPath.ps1 -Development to set up the environment.
    pause
    exit /b 1
)

call "%VENV_DIR%\Scripts\activate.bat"

echo ============================================================
echo  QPSC Microscope Command Server (Development)
echo ============================================================
echo.
echo  Make sure Micro-Manager is running before proceeding.
echo  Press Ctrl+C to stop the server.
echo.

REM -- Start the server --
python -m microscope_command_server.server.qp_server

REM -- If server exits, pause so the user can see any error --
echo.
echo Server stopped.
pause
"@

    $startServerPath = Join-Path $InstallDir "start_server.bat"
    $startServerBat | Out-File -FilePath $startServerPath -Encoding ASCII
    Write-Host "    Created: $startServerPath" -ForegroundColor Green

    # --- update_env.bat ---
    $updateEnvBat = @"
@echo off
REM ============================================================
REM  Update QPSC Python Environment (Development)
REM
REM  Pulls latest code from all repos and reinstalls packages
REM  in editable mode. Run this after pulling updates.
REM
REM  Usage:
REM    Double-click this file, or run from command prompt.
REM    Optional: update_env.bat --analysis  (installs pandas extras)
REM ============================================================

setlocal

set "INSTALL_DIR=$InstallDir"
set "VENV_DIR=%INSTALL_DIR%\venv_qpsc"

if not exist "%VENV_DIR%\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found at %VENV_DIR%
    echo Run PPM-QuPath.ps1 -Development to set up the environment.
    pause
    exit /b 1
)

call "%VENV_DIR%\Scripts\activate.bat"

echo.
echo Active venv: %VIRTUAL_ENV%
echo.

REM -- Pull latest from all repos --
echo [1/6] Pulling latest code...
for %%R in (microscope_imageprocessing ppm_library microscope_control microscope_command_server microscope_configurations) do (
    if exist "%INSTALL_DIR%\%%R\.git" (
        echo    %%R: pulling...
        pushd "%INSTALL_DIR%\%%R"
        git pull --quiet 2>nul
        popd
    )
)
echo.

REM -- Check for --analysis flag --
set "PPM_EXTRAS="
if "%~1"=="--analysis" set "PPM_EXTRAS=[analysis]"

REM -- Install in dependency order --
echo [2/6] Installing microscope-imageprocessing ...
pip install -e "%INSTALL_DIR%\microscope_imageprocessing" --quiet
if errorlevel 1 (
    echo FAILED: microscope-imageprocessing install
    pause
    exit /b 1
)

echo [3/6] Installing ppm-library%PPM_EXTRAS% ...
pip install -e "%INSTALL_DIR%\ppm_library%PPM_EXTRAS%" --quiet
if errorlevel 1 (
    echo FAILED: ppm-library install
    pause
    exit /b 1
)

echo [4/6] Installing microscope-control ...
pip install -e "%INSTALL_DIR%\microscope_control" --quiet
if errorlevel 1 (
    echo FAILED: microscope-control install
    pause
    exit /b 1
)

echo [5/6] Installing microscope-command-server ...
pip install -e "%INSTALL_DIR%\microscope_command_server" --quiet
if errorlevel 1 (
    echo FAILED: microscope-command-server install
    pause
    exit /b 1
)

echo [6/6] Verifying ...
pip show microscope-imageprocessing ppm-library microscope-control microscope-command-server 2>nul | findstr /i "Name: Version:"

echo.
echo All packages updated successfully.
pause
"@

    $updateEnvPath = Join-Path $InstallDir "update_env.bat"
    $updateEnvBat | Out-File -FilePath $updateEnvPath -Encoding ASCII
    Write-Host "    Created: $updateEnvPath" -ForegroundColor Green
}

# Generate Installation Summary File
Write-Host ""
Write-Host "[+] Creating installation summary..." -ForegroundColor Cyan

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$summaryPath = Join-Path $InstallDir "INSTALLATION_SUMMARY.txt"

$summaryContent = @"
========================================
QPSC Installation Summary
========================================
Date: $timestamp
Setup Mode: $setupMode

========================================
INSTALLATION LOCATIONS
========================================

Installation Directory:
  $InstallDir

"@

if ($Development) {
    $venvPath = Join-Path $InstallDir "venv_qpsc"
    $summaryContent += @"
Python Virtual Environment:
  $venvPath

  To activate the virtual environment:
    Windows PowerShell:
      $venvPath\Scripts\Activate.ps1

    Command Prompt:
      $venvPath\Scripts\activate.bat

    Linux/macOS:
      source $venvPath/bin/activate

Python Packages (Editable Install):
  ppm-library:               $InstallDir\ppm_library
  microscope-control:        $InstallDir\microscope_control
  microscope-command-server:         $InstallDir\microscope_command_server

Configuration Repository:
  $InstallDir\microscope_configurations

"@
} else {
    # Production mode also uses venv now
    $venvPath = Join-Path $InstallDir "venv_qpsc"
    $summaryContent += @"
Python Virtual Environment:
  $venvPath

  To activate the virtual environment:
    Windows PowerShell:
      $venvPath\Scripts\Activate.ps1

    Command Prompt:
      $venvPath\Scripts\activate.bat

Python Packages (Installed from GitHub):
  ppm-library
  microscope-control
  microscope-command-server
  pycromanager

  Packages are installed in:
    $venvPath\Lib\site-packages

"@
}

$configDir = Join-Path $InstallDir "configurations"
$summaryContent += @"
Configuration Templates:
  $configDir

Launcher Script:
  $launcherPath

"@

if ($quPathExe) {
    # Get the actual extensions directory (user data directory, not installation directory)
    $localExtDir = Join-Path $InstallDir "extensions"
    $quPathUserDataDir = Get-ChildItem -Path "$env:USERPROFILE\QuPath\v*" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1

    if ($quPathUserDataDir) {
        $quPathExtDir = Join-Path $quPathUserDataDir.FullName "extensions"
    } else {
        $quPathExtDir = "$env:USERPROFILE\QuPath\extensions"
    }

    $summaryContent += @"
QuPath Installation:
  $quPathExe

Extension JAR Files:
  Local QPSC folder (always accessible):
    $localExtDir

  QuPath user data directory:
    $quPathExtDir

  NOTE: JAR files are downloaded to your QPSC installation folder first,
        then automatically copied to QuPath's extensions directory.

        If QuPath was already running when extensions were installed,
        you must restart QuPath for the QPSC menu to appear.

        If you use a custom extensions directory in QuPath, manually
        copy the JARs from the local QPSC folder.

"@
} else {
    $summaryContent += @"
QuPath Installation:
  Not found during setup
  Extensions will need to be installed manually

"@
}

$summaryContent += @"

========================================
VERIFICATION COMMANDS
========================================

1. Verify Python Packages:
"@

if ($Development) {
    $summaryContent += @"
   # Activate virtual environment first:
   $venvPath\Scripts\Activate.ps1

"@
}

$summaryContent += @"
   # Then check installed packages:
   pip show microscope-command-server
   pip show microscope-control
   pip show ppm-library
   pip show pycromanager

2. List All QPSC Packages:
   pip list | Select-String "microscope|ppm"

3. Test Python Import:
"@

if ($Development) {
    $summaryContent += @"
   # With venv activated:
   python -c "import microscope_command_server; print('OK:', microscope_command_server.__file__)"
   python -c "import microscope_control; print('OK:', microscope_control.__file__)"
   python -c "import ppm_library; print('OK:', ppm_library.__file__)"
"@
} else {
    $summaryContent += @"
   python -c "import microscope_command_server; print('OK:', microscope_command_server.__file__)"
   python -c "import microscope_control; print('OK:', microscope_control.__file__)"
   python -c "import ppm_library; print('OK:', ppm_library.__file__)"
"@
}

$summaryContent += @"


4. Check QuPath Extensions:
   - Launch QuPath
   - Go to: Extensions menu
   - Look for: "QPSC" menu item

========================================
INSTALLED COMPONENTS
========================================
"@

if ($Development) {
    $summaryContent += @"
[+] Python Virtual Environment (venv_qpsc)
[+] Python Packages (editable mode):
    - ppm-library
    - microscope-control
    - microscope-command-server
    - pycromanager
[+] Source Code Repositories:
    - ppm_library/
    - microscope_control/
    - microscope_command_server/
    - microscope_configurations/
"@
} else {
    $summaryContent += @"
[+] Python Packages (from GitHub releases):
    - ppm-library
    - microscope-control
    - microscope-command-server
    - pycromanager
"@
}

$summaryContent += @"
[+] Configuration Templates
[+] Launch Script (Launch-QPSC.ps1)
"@

if (-not $SkipQuPath) {
    if ($quPathExe) {
        $summaryContent += "[+] QuPath Extensions (downloaded to extensions folder)`n"
    } else {
        $summaryContent += "[!] QuPath Extensions (SKIPPED - QuPath not found)`n"
    }
}

$summaryContent += @"

========================================
NEXT STEPS
========================================
"@

if ($Development) {
    $summaryContent += @"

1. Configure Your Microscope:
   Edit: $configDir\config_template.yml

2. Build QuPath Extensions:
   cd $InstallDir\qupath-extension-qpsc
   .\gradlew build

3. Copy Built JARs to QuPath Extensions Folder

4. Start the Server:
   Double-click: $InstallDir\start_server.bat

5. After Pulling Updates:
   Double-click: $InstallDir\update_env.bat

Batch Files:
   start_server.bat  - Activates venv and starts the microscope command server
   update_env.bat    - Pulls latest code and reinstalls all packages
"@
} else {
    $summaryContent += @"

1. Configure Your Microscope:
   Edit: $configDir\config_template.yml
"@
}

$summaryContent += @"

2. Set Up Micro-Manager Device Adapters

3. Launch QPSC:
   $launcherPath

   Server-only (no QuPath):
   $launcherPath --no-qupath

   3b. If QuPath is in a non-standard location:
       Re-run setup with -QuPathDir parameter:
       .\PPM-QuPath.ps1 -QuPathDir "D:\YourPath\QuPath-0.6.0"

       Or manually copy extension JARs to your QuPath extensions folder

========================================
TROUBLESHOOTING
========================================

If packages are not found:
"@

# Both modes use venv now
$summaryContent += @"
  - Make sure to use venv Python: $venvPath\Scripts\python.exe
  - Check packages: $venvPath\Scripts\pip.exe list
  - Test import: $venvPath\Scripts\python.exe -c "import microscope_command_server"
"@

$summaryContent += @"

If server won't start:
  - Check if port 5000 is already in use: netstat -ano | findstr :5000
  - Verify Micro-Manager is installed
  - Check Python can import packages (see verification commands above)

QuPath extensions not appearing:
  - Verify JAR files are in QuPath extensions folder
  - Restart QuPath completely
  - Check: Extensions menu in QuPath

========================================
DOCUMENTATION
========================================

Full Documentation: https://github.com/uw-loci/QPSC
Uninstall Guide:    $InstallDir\UNINSTALL.md (if downloaded)
                    https://github.com/uw-loci/QPSC/blob/main/UNINSTALL.md

Report Issues:      https://github.com/uw-loci/QPSC/issues

========================================
"@

$summaryContent | Out-File -FilePath $summaryPath -Encoding UTF8
Write-Host "    Created: $summaryPath" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installation Directory:" -ForegroundColor Cyan
Write-Host "  $InstallDir" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  DETAILED INSTALLATION SUMMARY" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "A complete installation summary has been saved to:" -ForegroundColor White
Write-Host "  $summaryPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "This file contains:" -ForegroundColor White
Write-Host "  - Python environment location and activation commands" -ForegroundColor Gray
Write-Host "  - Package installation paths" -ForegroundColor Gray
Write-Host "  - Verification commands to test your installation" -ForegroundColor Gray
Write-Host "  - Troubleshooting tips" -ForegroundColor Gray
Write-Host ""
Write-Host "Open it to verify your installation!" -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Setup Mode:" -ForegroundColor Cyan
Write-Host "  $setupMode" -ForegroundColor White
Write-Host ""
Write-Host "Installed Components:" -ForegroundColor Cyan

if ($Development) {
    Write-Host "  [+] Python packages (editable mode in venv_qpsc)" -ForegroundColor White
    Write-Host "  [+] All repositories cloned for development" -ForegroundColor White
    Write-Host "  [+] start_server.bat and update_env.bat" -ForegroundColor White
} else {
    Write-Host "  [+] Python packages (from GitHub in venv_qpsc)" -ForegroundColor White
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
Write-Host "Python Environment:" -ForegroundColor Cyan

# Both Development and Production now use venv
$venvPath = Join-Path $InstallDir "venv_qpsc"
Write-Host "  Location: $venvPath" -ForegroundColor White
Write-Host ""
Write-Host "  To activate:" -ForegroundColor White
Write-Host "    $venvPath\Scripts\Activate.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "  To verify packages:" -ForegroundColor White
Write-Host "    $venvPath\Scripts\pip.exe list | Select-String ""microscope|ppm""" -ForegroundColor Yellow
Write-Host ""
Write-Host "  To test import:" -ForegroundColor White
Write-Host "    $venvPath\Scripts\python.exe -c ""import microscope_command_server; print('OK')""" -ForegroundColor Yellow

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan

if ($Development) {
    Write-Host "  1. Configure your microscope:" -ForegroundColor White
    Write-Host "     Edit: $configDir\config_template.yml" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  2. Build QuPath extensions:" -ForegroundColor White
    Write-Host "     cd $InstallDir\qupath-extension-qpsc" -ForegroundColor Yellow
    Write-Host "     .\gradlew build" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  3. Copy built JAR files to QuPath extensions folder" -ForegroundColor White
    Write-Host ""
    Write-Host "  4. Start the server:" -ForegroundColor White
    Write-Host "     Double-click: $InstallDir\start_server.bat" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  5. After pulling updates, re-install packages:" -ForegroundColor White
    Write-Host "     Double-click: $InstallDir\update_env.bat" -ForegroundColor Yellow
} else {
    Write-Host "  1. Configure your microscope:" -ForegroundColor White
    Write-Host "     Edit: $configDir\config_template.yml" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Set up Micro-Manager device adapters for your hardware" -ForegroundColor White
Write-Host ""

if ($Development) {
    Write-Host "  Batch files created:" -ForegroundColor Cyan
    Write-Host "     start_server.bat  - Start the microscope command server" -ForegroundColor Gray
    Write-Host "     update_env.bat    - Pull updates and reinstall packages" -ForegroundColor Gray
} else {
    Write-Host "  Launch QPSC (starts server + QuPath):" -ForegroundColor White
    Write-Host "     $launcherPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "     Server only (no QuPath):" -ForegroundColor White
    Write-Host "     $launcherPath --no-qupath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "     If QuPath is in a non-standard location:" -ForegroundColor White
    Write-Host "         .\PPM-QuPath.ps1 -QuPathDir ""D:\YourPath\QuPath-0.6.0""" -ForegroundColor Yellow
}

Write-Host ""

# Launch if requested
if ($Launch) {
    Write-Host "[+] Launching QPSC..." -ForegroundColor Green
    & $launcherPath
}
