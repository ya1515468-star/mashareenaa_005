param(
  [string]$ZipPath = (Join-Path $PSScriptRoot '..\..\MASHAREENA_SANITIZED_ARM64_READY.zip'),
  [string]$RepoUrl = 'https://github.com/ya1515468-star/mashareenaa_005.git'
)
$ErrorActionPreference = 'Stop'

$ZipPath = [System.IO.Path]::GetFullPath($ZipPath)
if (!(Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
  throw "ZIP not found: $ZipPath"
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'Git is not installed or not on PATH.'
}

$work = Join-Path $env:TEMP ('mashareena_push_' + [guid]::NewGuid().ToString('N'))
$src = Join-Path $work 'src'
$repo = Join-Path $work 'repo'
New-Item -ItemType Directory -Force $src, $repo | Out-Null

try {
  Write-Host "Using ZIP: $ZipPath"
  Write-Host "Target:    $RepoUrl"
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $src -Force

  $root = Join-Path $src 'MASHAREEN'
  if (!(Test-Path -LiteralPath $root -PathType Container)) {
    throw 'Expected MASHAREEN directory was not found inside ZIP.'
  }

  Write-Host 'Verifying forbidden files before push...'
  $blocked = Get-ChildItem -Path $root -Recurse -Force -File | Where-Object {
    $_.Name -match '^\.env($|\.)|\.jks$|\.keystore$|\.p12$|\.pfx$|\.pem$|^key\.properties$|^local\.properties$|google-services\.json$|GoogleService-Info\.plist$|service-account.*\.json$'
  }
  if ($blocked) {
    $blocked | ForEach-Object { Write-Host $_.FullName }
    throw 'Sensitive-like files detected. Push aborted.'
  }

  Set-Location $repo
  git init -b main | Out-Null
  git remote add origin $RepoUrl
  git config user.name 'MASHAREENA Release Bot'
  git config user.email 'actions@users.noreply.github.com'
  Copy-Item (Join-Path $root '*') $repo -Recurse -Force -ErrorAction Stop

  if (!(Test-Path -LiteralPath (Join-Path $repo '.gitignore') -PathType Leaf)) {
    throw '.gitignore missing after extraction.'
  }

  git add .
  $staged = @(git diff --cached --name-only --diff-filter=A,M,R,C)
  foreach ($path in $staged) {
    if ($path -match '(^|/)(\.env($|\.)|.*\.(jks|keystore|p12|pfx|pem)$|key\.properties|local\.properties|google-services\.json|GoogleService-Info\.plist)$') {
      throw "Blocked sensitive path staged: $path"
    }
  }

  git commit -m 'chore: import sanitized MASHAREENA production source' | Out-Null
  Write-Host "Pushing to $RepoUrl ..."
  git push -u origin main --force
  Write-Host 'PUSH COMPLETE'
  Write-Host 'Next: open GitHub Actions and run MASHAREENA Android ARM64 Release.'
}
finally {
  Set-Location $PSScriptRoot
  if (Test-Path -LiteralPath $work) {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
  }
}
