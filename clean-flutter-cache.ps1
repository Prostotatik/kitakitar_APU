# Full Flutter cache cleanup
# Run: powershell -ExecutionPolicy Bypass -File clean-flutter-cache.ps1

Write-Host "=== Flutter cache cleanup ===" -ForegroundColor Cyan

# 1. Flutter clean in projects
Write-Host "`n[1/6] flutter clean in projects..." -ForegroundColor Yellow
$projects = @("center_web", "mobile")
foreach ($proj in $projects) {
    $path = Join-Path $PSScriptRoot $proj
    if (Test-Path (Join-Path $path "pubspec.yaml")) {
        Push-Location $path
        flutter clean 2>$null
        Pop-Location
        Write-Host "  OK $proj" -ForegroundColor Green
    }
}

# 2. Stop Gradle daemon
Write-Host "`n[2/6] Stopping Gradle daemon..." -ForegroundColor Yellow
$mobilePath = Join-Path $PSScriptRoot "mobile"
if (Test-Path (Join-Path $mobilePath "android\gradlew.bat")) {
    Push-Location (Join-Path $mobilePath "android")
    & .\gradlew.bat --stop 2>$null
    Pop-Location
    Write-Host "  OK Gradle stopped" -ForegroundColor Green
}

# 3. Gradle caches (frees 10-35 GB)
Write-Host "`n[3/6] Removing Gradle cache..." -ForegroundColor Yellow
$gradleDirs = @("caches", "daemon", "native", "workers", ".tmp")
foreach ($dir in $gradleDirs) {
    $fullPath = Join-Path "$env:USERPROFILE\.gradle" $dir
    if (Test-Path $fullPath) {
        Remove-Item -Recurse -Force $fullPath -ErrorAction SilentlyContinue
        Write-Host "  OK Removed: $dir" -ForegroundColor Green
    }
}

# 4. Pub cache clean
Write-Host "`n[4/6] Cleaning Pub cache..." -ForegroundColor Yellow
flutter pub cache clean 2>$null
Write-Host "  OK Pub cache cleaned" -ForegroundColor Green

# 5. Flutter precache --clean
Write-Host "`n[5/6] Cleaning Flutter SDK cache..." -ForegroundColor Yellow
flutter precache --clean 2>$null
Write-Host "  OK Flutter SDK cache cleaned" -ForegroundColor Green

# 6. Dart/Flutter analysis caches
Write-Host "`n[6/6] Cleaning Dart analysis cache..." -ForegroundColor Yellow
$analysisPaths = @(
    "$env:APPDATA\.dart-tool",
    "$env:LOCALAPPDATA\.dartServer"
)
foreach ($p in $analysisPaths) {
    if (Test-Path $p) {
        Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue
        Write-Host "  OK Removed: $p" -ForegroundColor Green
    }
}

Write-Host "`n=== Done! ===" -ForegroundColor Cyan
Write-Host "Next flutter run/pub get will re-download everything." -ForegroundColor Gray
