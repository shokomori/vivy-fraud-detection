$root = 'c:\Users\YUKI\Documents\Vivy'
$exclude = @('.git', '.venv', '.venv311', 'vivy_app/build', 'vivy_app/.dart_tool', 'vivy_app/.idea', 'vivy_app/.flutter-plugins', 'vivy_app/.flutter-plugins-dependencies')
$files = Get-ChildItem -Path $root -File -Recurse -Force | Where-Object {
  $rel = $_.FullName.Substring($root.Length + 1)
  $parts = $rel -split '[\\/]'
  -not ($parts | Where-Object { $exclude -contains $_ }) -and
  $rel -notmatch 'node_modules' -and
  $rel -notmatch '__pycache__'
}
$files | Select-Object FullName, Length | Sort-Object Length -Descending | Format-Table -AutoSize
Write-Host '---TOTAL---'
Write-Host ($files | Measure-Object Length -Sum).Sum
