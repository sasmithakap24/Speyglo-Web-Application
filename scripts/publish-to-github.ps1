<#
Publish to GitHub automation script

What it does:
 - Runs `flatten-assets.ps1` to copy/move files from `assets/` and `icons/` into the repo root (optional Move/DeleteFolders via flags)
 - Creates `.nojekyll` to prevent Jekyll filtering
 - Initializes a Git repo (if not already), creates `main` branch, and commits files
 - Optionally creates a GitHub repository using `gh` (GitHub CLI) OR accepts an existing remote URL
 - Pushes the `main` branch to the remote and sets upstream

Usage examples:
  # Dry run (shows actions without executing remote operations)
  ./scripts/publish-to-github.ps1 -DryRun

  # Run everything, copy files (no folder deletion), create repo via gh when confirmed
  ./scripts/publish-to-github.ps1 -FlattenCopy -CreateRepoWithGH

  # Move files (delete originals) and remove empty folders, then push
  ./scripts/publish-to-github.ps1 -FlattenMove -DeleteFolders -CreateRepoWithGH -Force

Notes:
 - Requires PowerShell on Windows. For GitHub repo creation, `gh` (GitHub CLI) should be installed and authenticated.
 - The script is interactive and will ask for confirmation at key steps. Use -Force to skip confirmations.
 - You must have permission to create repos under the specified account/organization.
#>
param(
  [switch]$DryRun,
  [switch]$FlattenCopy,
  [switch]$FlattenMove,
  [switch]$DeleteFolders,
  [switch]$CreateRepoWithGH,
  [string]$RemoteUrl,
  [switch]$Force
)

function Confirm-OrExit([string]$Message){
  if($Force){ Write-Host "(force) $Message"; return $true }
  $r = Read-Host "$Message (y/n)"
  if($r -match '^[yY]'){ return $true }
  Write-Host "Aborted by user." -ForegroundColor Yellow
  exit 1
}

$root = (Get-Location).Path
Write-Host "Project root: $root"

# 1) Flatten assets
if($FlattenMove -and -not $FlattenCopy){
  $flattenArgs = '-Move'
} elseif($FlattenCopy){
  $flattenArgs = ''
} else {
  # default to copy only (non-destructive)
  $flattenArgs = ''
}
if($DeleteFolders){ $flattenArgs += ' -DeleteFolders' }
if($Force){ $flattenArgs += ' -Force' }

if(Test-Path "scripts/flatten-assets.ps1"){
  Write-Host "Found flatten-assets script. Will run: scripts/flatten-assets.ps1 $flattenArgs"
  if(-not $DryRun){
    if($FlattenMove -or $DeleteFolders){ Confirm-OrExit "This will move files from assets/icons to the root (may delete originals). Continue?" }
    & ./scripts/flatten-assets.ps1 @($flattenArgs -split ' ')
  }
} else {
  Write-Host "No flatten-assets.ps1 found. Skipping flatten step." -ForegroundColor Yellow
}

# 2) Add .nojekyll
$nojekyll = Join-Path $root '.nojekyll'
if(-not (Test-Path $nojekyll)){
  Write-Host "Creating .nojekyll"
  if(-not $DryRun){ New-Item -Path $nojekyll -ItemType File -Force | Out-Null }
} else { Write-Host ".nojekyll already exists" }

# 3) Initialize git if needed
if(-not (Test-Path (Join-Path $root '.git'))){
  Write-Host "Initializing new git repository"
  if(-not $DryRun){
    git init
    git checkout -b main
  }
} else { Write-Host "Git repository already initialized" }

# 4) Ensure git user is set (warn only)
if(-not $DryRun){
  $name = git config user.name
  $email = git config user.email
  if(-not $name -or -not $email){
    Write-Host "WARNING: Git user.name and/or user.email not set. Commits will use system/global settings if available." -ForegroundColor Yellow
  }
}

# 5) Add & commit
Write-Host "Staging files for commit"
if(-not $DryRun){
  git add .
  $status = git status --porcelain
  if(-not $status){ Write-Host "No changes to commit." } else {
    git commit -m "Publish site: initial commit"
  }
}

# 6) Create or use remote
if($CreateRepoWithGH){
  if(-not (Get-Command gh -ErrorAction SilentlyContinue)){
    Write-Host "GitHub CLI 'gh' not found. Install it or provide a remote URL with -RemoteUrl" -ForegroundColor Red
    exit 1
  }
  # Ask for repo name details
  $owner = Read-Host "Enter the GitHub username or organization to create the repo in (default: current user)"
  $repoName = Read-Host "Enter repository name (e.g., contactus)"
  if(-not $repoName){ Write-Host "Repository name required" -ForegroundColor Red; exit 1 }
  $visibility = Read-Host "Public or private? (enter public or private, default public)"
  if(-not $visibility){ $visibility = 'public' }
  $ghCreateCmd = "gh repo create $owner/$repoName --$visibility --source=. --remote=origin --push --yes"
  Write-Host "Will run: $ghCreateCmd"
  if(-not $DryRun){
    if(Confirm-OrExit "Proceed to create GitHub repo and push (requires gh auth)?"){ 
      Invoke-Expression $ghCreateCmd
    }
  }
} elseif($RemoteUrl){
  Write-Host "Using provided remote: $RemoteUrl"
  if(-not $DryRun){
    if(-not (git remote get-url origin 2>$null)){
      git remote add origin $RemoteUrl
    } else {
      Write-Host "An origin remote already exists. Skipping add." -ForegroundColor Yellow
    }
    if(Confirm-OrExit "Push 'main' to origin and set upstream?"){ git push -u origin main }
  }
} else {
  Write-Host "No remote specified. If you want to publish to GitHub, run with -CreateRepoWithGH or -RemoteUrl <url>" -ForegroundColor Yellow
}

Write-Host "Done. Verify Pages in the repository settings to confirm the published URL." -ForegroundColor Green
