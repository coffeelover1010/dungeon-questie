$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$addons = 'C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns'
if (-not (Test-Path -LiteralPath $addons -PathType Container)) { throw 'Forever addon directory not found.' }
$destination = Join-Path $addons 'DungeonGuideForever'
if (Test-Path -LiteralPath $destination) {
    $backup = Join-Path (Split-Path $source -Parent) ('addon-backups\DungeonGuideForever-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Path $backup | Out-Null
    Copy-Item -LiteralPath $destination -Destination $backup -Recurse
    Write-Output "Backup: $backup"
}
$files = @('DungeonGuideForever.toc', 'README.md', 'AI-RESEARCH-README.md', 'RESEARCH-2026-10-02.md', 'WALKTHROUGHS.md', 'LICENSE', 'THIRD-PARTY-NOTICES.md', 'SOURCE-REBUILD.md', 'licenses\ClassicDB-LICENSE.md', 'licenses\ClassicDB-COPYRIGHT.md', 'licenses\ClassicDB-AUTHORS', 'licenses\world-coords-MIT.txt', 'Libs\NOTICE.txt', 'Libs\Ace3-LICENSE.txt')
$files += Get-Content -LiteralPath (Join-Path $source 'DungeonGuideForever.toc') | Where-Object { $_ -and -not $_.StartsWith('#') }
$files += 'RESEARCH-2026-10-03.md'
$files += 'RESEARCH-2026-10-09.md'
foreach ($file in $files) {
    $from = Join-Path $source $file
    $to = Join-Path $destination $file
    New-Item -ItemType Directory -Path (Split-Path $to -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $from -Destination $to -Force
    if ((Get-FileHash -LiteralPath $from).Hash -ne (Get-FileHash -LiteralPath $to).Hash) { throw "Installed hash mismatch: $file" }
}
Write-Output "Installed and SHA-256 verified $($files.Count) runtime/documentation files: $destination"

