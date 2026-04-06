param(
    [string]$WebFolder = 'guoxuanya',
    [string]$Package = 'com.example.guoxuanya',
    [string]$AppName = 'GuoxuanyaApp',
    [ValidateSet('debug','release')][string]$Configuration = 'debug'
)

# If JAVA_HOME not set, use the provided JDK 8 path
if (-not $env:JAVA_HOME -or $env:JAVA_HOME -eq '') {
    $env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-8.0.482.8-hotspot'
    $env:Path = "$env:JAVA_HOME\bin;" + $env:Path
}

Write-Host "Using JAVA_HOME=$env:JAVA_HOME"

# Verify javac
try {
    & "$env:JAVA_HOME\bin\javac" -version 2>&1 | Write-Host
} catch {
    Write-Host "javac not found at $env:JAVA_HOME. Trying system PATH..."
    $where = (where.exe javac 2>$null)
    if (-not $where) {
        Write-Error "javac not found. Please install JDK 8 and ensure JAVA_HOME/bin is on PATH."
        exit 1
    } else {
        Write-Host "Found javac: $where"
    }
}

# Verify cordova
try {
    cordova -v 2>&1 | Write-Host
} catch {
    Write-Error "Cordova not found. Install Cordova with: npm install -g cordova"
    exit 1
}

# Remove old build dir
if (Test-Path .\cordova_build) {
    Write-Host "Removing existing cordova_build/"
    Remove-Item -Recurse -Force .\cordova_build
}

# Create cordova project
Write-Host "Creating Cordova project"
& cordova create cordova_build $Package $AppName
if ($LASTEXITCODE -ne 0) { Write-Error "cordova create failed"; exit $LASTEXITCODE }

# Copy web files
if (-not (Test-Path $WebFolder)) {
    Write-Error "Web folder '$WebFolder' not found in repository root."
    exit 1
}

Write-Host "Copying web files from $WebFolder to cordova_build/www"
robocopy "$WebFolder" ".\cordova_build\www" /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null

# Add android platform
Write-Host "Adding Android platform"
Push-Location .\cordova_build
& cordova platform add android --no-interactive
if ($LASTEXITCODE -ne 0) { Write-Error "cordova platform add android failed"; Pop-Location; exit $LASTEXITCODE }

# Build
$buildFlag = if ($Configuration -eq 'debug') { '--debug' } else { '--release' }
Write-Host "Building Android ($Configuration)"
& cordova build android $buildFlag --verbose 2>&1 | Tee-Object -FilePath ..\cordova_build_build.log

Pop-Location

# Find APK
Write-Host "Searching for APK(s)"
$apks = Get-ChildItem -Path .\cordova_build -Recurse -Filter *.apk -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
if ($apks) {
    Write-Host "Found APK(s):"
    $apks | ForEach-Object { Write-Host $_ }
} else {
    Write-Error "No APK found. Check ..\cordova_build_build.log for build errors."
    exit 1
}

Write-Host "Done."
