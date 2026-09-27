param(
  [string]$ZipPath = "$PSScriptRoot\MASHAREENA_SANITIZED_ARM64_READY.zip",
  [string]$RepoUrl = "https://github.com/ya1515468-star/mashareenaa_03.git"
)
$ErrorActionPreference='Stop'
if (!(Test-Path $ZipPath)) { throw "ZIP not found: $ZipPath" }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is not installed or not on PATH." }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Write-Warning "GitHub CLI (gh) not found. Make sure you are authenticated with Git: gh auth login, or use your normal Git credentials." }
$work=Join-Path $env:TEMP ('mashareena_push_'+[guid]::NewGuid().ToString('N'))
$src=Join-Path $work 'src'
$repo=Join-Path $work 'repo'
New-Item -ItemType Directory -Force $src,$repo | Out-Null
Expand-Archive -LiteralPath $ZipPath -DestinationPath $src -Force
$root=Join-Path $src 'MASHAREEN'
if (!(Test-Path $root)) { throw 'Expected MASHAREEN directory was not found inside ZIP.' }
Write-Host 'Verifying forbidden files before push...'
$blocked = Get-ChildItem -Path $root -Recurse -Force -File | Where-Object { $_.Name -match '^\.env($|\.)|\.jks$|\.keystore$|\.p12$|\.pfx$|\.pem$|^key\.properties$|^local\.properties$|google-services\.json$|GoogleService-Info\.plist$|service-account.*\.json$' }
if ($blocked) { $blocked | ForEach-Object { Write-Host $_.FullName }; throw 'Sensitive-like files detected. Push aborted.' }
Set-Location $repo
git init -b main | Out-Null
git remote add origin $RepoUrl
git config user.name 'MASHAREENA Release Bot'
git config user.email 'actions@users.noreply.github.com'
Copy-Item "$root\*" $repo -Recurse -Force -ErrorAction Stop
if (!(Test-Path (Join-Path $repo '.gitignore'))) { throw '.gitignore missing after extraction.' }
git add .
git status --short
git diff --cached --name-only --diff-filter=A,M,R,C | ForEach-Object { if ($_ -match '(^|/)(\.env($|\.)|.*\.(jks|keystore|p12|pfx|pem)$|key\.properties|local\.properties|google-services\.json|GoogleService-Info\.plist)$') { throw "Blocked sensitive path staged: $_" } }
git commit -m 'chore: import sanitized MASHAREENA production source' | Out-Null
Write-Host "Pushing to $RepoUrl ..."
git fetch origin main 2>$null || $true
git push -u origin main --force
Write-Host 'PUSH COMPLETE'
Write-Host 'Next: open GitHub Actions and run MASHAREENA Android ARM64 Release.'
