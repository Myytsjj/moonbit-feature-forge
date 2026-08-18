param(
  [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

$counts = @{
  production = 0
  tests = 0
  cli = 0
}

$tracked = git -C $RepositoryRoot ls-files "*.mbt"
foreach ($relativePath in $tracked) {
  if ([string]::IsNullOrWhiteSpace($relativePath) -or $relativePath -like "_build/*") {
    continue
  }

  $absolutePath = Join-Path $RepositoryRoot $relativePath
  if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
    continue
  }

  $lineCount = (Get-Content -LiteralPath $absolutePath | Measure-Object -Line).Lines
  if ($relativePath -like "cmd/main/*") {
    $counts.cli += $lineCount
  } elseif ($relativePath -like "*_test.mbt" -or $relativePath -like "*_wbtest.mbt") {
    $counts.tests += $lineCount
  } else {
    $counts.production += $lineCount
  }
}

$total = $counts.production + $counts.tests + $counts.cli
Write-Output "production=$($counts.production)"
Write-Output "tests=$($counts.tests)"
Write-Output "cli=$($counts.cli)"
Write-Output "total=$total"
