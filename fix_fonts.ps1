$files = Get-ChildItem 'lib\views\widgets\create_content' -Filter '*.dart'
foreach ($file in $files) {
    $c = Get-Content $file.FullName -Raw
    if ($c -match 'GoogleFonts\.outfit') {
        $c = $c -replace 'GoogleFonts\.outfit', 'GoogleFonts.poppins'
        Set-Content $file.FullName $c -NoNewline
        Write-Host "Updated: $($file.Name)"
    }
}
Write-Host "Done."
