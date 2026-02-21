# PowerShell script to manually download Gradle distribution
# This script downloads Gradle 8.12 to the correct location

Write-Host "Starting Gradle 8.12 download..." -ForegroundColor Green

# Define URLs to try (in order of preference)
$urls = @(
    "https://downloads.gradle-dn.com/distributions/gradle-8.12-all.zip",
    "https://services.gradle.org/distributions/gradle-8.12-all.zip",
    "https://downloads.gradle.org/distributions/gradle-8.12-all.zip"
)

# Define destination path
$gradleUserHome = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { "$env:USERPROFILE\.gradle" }
$destinationDir = "$gradleUserHome\wrapper\dists\gradle-8.12-all"
$destinationFile = "$destinationDir\gradle-8.12-all.zip"

Write-Host "Creating directory: $destinationDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null

Write-Host "Attempting to download Gradle from available mirrors..." -ForegroundColor Yellow

$downloadSuccess = $false
foreach ($url in $urls) {
    try {
        Write-Host "Trying: $url" -ForegroundColor Cyan
        Invoke-WebRequest -Uri $url -OutFile $destinationFile -TimeoutSec 300
        $downloadSuccess = $true
        Write-Host "Download successful!" -ForegroundColor Green
        break
    } catch {
        Write-Host "Failed to download from $url" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if (-not $downloadSuccess) {
    Write-Host "ERROR: Failed to download Gradle from all mirrors." -ForegroundColor Red
    Write-Host "Please try manually downloading from https://gradle.org/releases/" -ForegroundColor Yellow
    exit 1
}

Write-Host "Extracting Gradle distribution..." -ForegroundColor Yellow
try {
    # Extract the zip file
    Expand-Archive -Path $destinationFile -DestinationPath $destinationDir -Force
    Write-Host "Extraction completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to extract Gradle distribution" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Gradle 8.12 has been successfully installed to $destinationDir" -ForegroundColor Green
Write-Host "You can now try running your Flutter app again." -ForegroundColor Green