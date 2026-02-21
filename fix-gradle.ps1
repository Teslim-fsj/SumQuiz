# PowerShell script to fix Gradle network issue
Write-Host "Attempting to fix Gradle network issue..." -ForegroundColor Green

# Check if Gradle zip exists
if (Test-Path "gradle-8.12-all.zip") {
    Write-Host "Gradle zip found, moving to correct location..." -ForegroundColor Yellow
    
    # Define destination path
    $gradleUserHome = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { "$env:USERPROFILE\.gradle" }
    $destinationDir = "$gradleUserHome\wrapper\dists\gradle-8.12-all"
    
    Write-Host "Creating directory: $destinationDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    
    Write-Host "Moving gradle-8.12-all.zip to $destinationDir" -ForegroundColor Yellow
    Move-Item -Path "gradle-8.12-all.zip" -Destination $destinationDir -Force
    
    Write-Host "Extracting Gradle distribution..." -ForegroundColor Yellow
    Expand-Archive -Path "$destinationDir\gradle-8.12-all.zip" -DestinationPath $destinationDir -Force
    
    Write-Host "Gradle has been successfully installed!" -ForegroundColor Green
    Write-Host "You can now try running your Flutter app again with: flutter run" -ForegroundColor Cyan
} else {
    Write-Host "Gradle zip not found. Let's try downloading with a different approach..." -ForegroundColor Yellow
    
    # Try downloading with BITS (Background Intelligent Transfer Service) which is more reliable
    try {
        Write-Host "Using BITS to download Gradle..." -ForegroundColor Yellow
        $gradleUserHome = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { "$env:USERPROFILE\.gradle" }
        $destinationDir = "$gradleUserHome\wrapper\dists\gradle-8.12-all"
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        $destinationFile = "$destinationDir\gradle-8.12-all.zip"
        
        Start-BitsTransfer -Source "https://services.gradle.org/distributions/gradle-8.12-all.zip" -Destination $destinationFile
        Write-Host "Download completed successfully!" -ForegroundColor Green
        
        Write-Host "Extracting Gradle distribution..." -ForegroundColor Yellow
        Expand-Archive -Path $destinationFile -DestinationPath $destinationDir -Force
        
        Write-Host "Gradle has been successfully installed!" -ForegroundColor Green
        Write-Host "You can now try running your Flutter app again with: flutter run" -ForegroundColor Cyan
    } catch {
        Write-Host "ERROR: Failed to download Gradle using BITS" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please try manually downloading Gradle 8.12 from https://gradle.org/releases/" -ForegroundColor Yellow
    }
}