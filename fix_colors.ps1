$files = Get-ChildItem 'lib\views\widgets\create_content' -Filter '*.dart'
foreach ($file in $files) {
    $c = Get-Content $file.FullName -Raw
    if ($c -match '0xFF4F46E5') {
        # Add import if missing
        if ($c -notmatch 'theme_provider') {
            $c = $c -replace "(import 'package:flutter/material.dart';)", "`$1`nimport 'package:sumquiz/providers/theme_provider.dart';"
        }
        $c = $c -replace 'const Color\(0xFF4F46E5\)', 'ThemeProvider.primaryDeepBlue'
        $c = $c -replace 'Color\(0xFF4F46E5\)', 'ThemeProvider.primaryDeepBlue'
        Set-Content $file.FullName $c -NoNewline
        Write-Host "Updated: $($file.Name)"
    }
}
Write-Host "Done."
