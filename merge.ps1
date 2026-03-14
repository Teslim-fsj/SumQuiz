$orig = Get-Content 'lib\views\screens\create_content_screen.dart' -Encoding UTF8
$redesign = Get-Content 'lib\views\screens\create_content_screen_redesign.dart' -Encoding UTF8

$out = @()
$cancelTokenIndex = [array]::IndexOf($orig, ($orig -match 'CancellationToken\? _cancelToken;')[0])
$out += $orig[0..$cancelTokenIndex]
$out += ""

$newStateStart = [array]::IndexOf($redesign, ($redesign -match '// New design state')[0])
$newStateEnd = $newStateStart
while($redesign[$newStateEnd].Trim() -ne '];') { $newStateEnd++ }
$out += $redesign[$newStateStart..$newStateEnd]
$out += ""

$initStateIndex = [array]::IndexOf($orig, ($orig -match 'void initState\(\) \{')[0])
$buildOrigIndex = [array]::IndexOf($orig, ($orig -match 'Widget build\(BuildContext context\) \{')[0])

$overrideIndex = $initStateIndex - 1
$out += $orig[$overrideIndex..($buildOrigIndex - 1)]

$buildRedesIndex = [array]::IndexOf($redesign, ($redesign -match 'Widget build\(BuildContext context\) \{')[0])
$out += $redesign[$buildRedesIndex..($redesign.Length - 1)]

$out | Set-Content 'lib\views\screens\create_content_screen.dart' -Encoding UTF8
