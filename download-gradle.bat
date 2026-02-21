@echo off
echo Starting Gradle 8.12 download...

REM Define destination path
set GRADLE_USER_HOME=%USERPROFILE%\.gradle
set DESTINATION_DIR=%GRADLE_USER_HOME%\wrapper\dists\gradle-8.12-all
set DESTINATION_FILE=%DESTINATION_DIR%\gradle-8.12-all.zip

echo Creating directory: %DESTINATION_DIR%
mkdir "%DESTINATION_DIR%" 2>nul

echo Downloading Gradle 8.12 from official source...
powershell -Command "& {
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri 'https://services.gradle.org/distributions/gradle-8.12-all.zip' -OutFile '%DESTINATION_FILE%' -TimeoutSec 600
        Write-Host 'Download successful!'
        
        Write-Host 'Extracting Gradle distribution...'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory('%DESTINATION_FILE%', '%DESTINATION_DIR%', $true)
        Write-Host 'Extraction completed successfully!'
        Write-Host 'Gradle 8.12 has been successfully installed.'
        Write-Host 'You can now try running your Flutter app again.'
    } catch {
        Write-Host 'ERROR: Failed to download/extract Gradle' -ForegroundColor Red
        Write-Host 'Error: $($_.Exception.Message)' -ForegroundColor Red
    }
}"

pause