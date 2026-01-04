<#
Flatten assets and icons into the project root

Usage:
  - Run from PowerShell in the repo (or execute this script). Examples:
    ./scripts/flatten-assets.ps1            # copy files to root (no overwrite)
    ./scripts/flatten-assets.ps1 -Force    # copy and overwrite existing files in root
    ./scripts/flatten-assets.ps1 -Move     # move files (copy then delete originals)
    ./scripts/flatten-assets.ps1 -Move -DeleteFolders  # move and remove now-empty folders

Notes:
  - This script will process the `assets` and `icons` folders if they exist.
  - It only operates on files (not subfolders). If there are naming conflicts, use -Force to overwrite.
#>
param(
  [switch]$Move,
  [switch]$DeleteFolders,
  [switch]$Force
)

# Determine project root (parent of the scripts folder)
$projectRoot = Resolve-Path -Path (Join-Path $PSScriptRoot "..")
$projectRoot = $projectRoot.Path
Write-Host "Project root: $projectRoot"

$folders = @('assets', 'icons')
$copied = 0
$skipped = 0

foreach($f in $folders){
  $srcFolder = Join-Path $projectRoot $f
  if(-not (Test-Path $srcFolder)){
    Write-Host "Skipping: $f not found" -ForegroundColor Yellow
    continue
  }

  Get-ChildItem -Path $srcFolder -File | ForEach-Object {
    $dest = Join-Path $projectRoot $_.Name
    if(Test-Path $dest -and -not $Force){
      Write-Host "Skipping existing file: $($_.Name) (use -Force to overwrite)" -ForegroundColor Yellow
      $skipped++
    } else {
      Copy-Item -Path $_.FullName -Destination $dest -Force
      Write-Host "Copied: $($_.Name) -> $projectRoot"
      $copied++
      if($Move){ Remove-Item -Path $_.FullName -Force } 
    }
  }

  if($DeleteFolders){
    # Remove folder if empty now
    $filesLeft = Get-ChildItem -Path $srcFolder -File -ErrorAction SilentlyContinue | Measure-Object
    if($filesLeft.Count -eq 0){
      Remove-Item -Path $srcFolder -Recurse -Force
      Write-Host "Removed empty folder: $srcFolder" -ForegroundColor Green
    } else {
      Write-Host "$srcFolder not empty; not removing" -ForegroundColor Yellow
    }
  }
}

Write-Host "Done. Files copied: $copied, skipped: $skipped" -ForegroundColor Green
