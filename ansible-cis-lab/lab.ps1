# Host-side wrapper for Windows (PowerShell 7+ / Windows PowerShell 5.1)
# Lifecycle via docker compose, everything else is forwarded to 'lab' in the control node.
param([Parameter(Position = 0)][string]$Command = 'help',
      [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest)
$ErrorActionPreference = 'Stop'
$CallerPwd = (Get-Location -PSProvider FileSystem).ProviderPath
Set-Location -Path $PSScriptRoot
if (-not $env:LAB_UID) { $env:LAB_UID = '1000' }
if (-not $env:LAB_GID) { $env:LAB_GID = '1000' }
$Targets = 'debian','ubuntu','rocky','alma','fedora','opensuse','arch','alpine'

switch ($Command) {
  'up' {
    docker compose up -d --build
    Write-Host 'Waiting for targets to accept SSH ...'
    for ($i = 0; $i -lt 60; $i++) {
      docker compose exec -T -u learner control ansible targets -m ansible.builtin.raw -a true *> $null
      if ($LASTEXITCODE -eq 0) { break }
      Start-Sleep -Seconds 3
    }
    docker compose exec -T -u learner control lab status
    Write-Host "`nReady. Next: .\lab.ps1 shell   then   lab placement   or   lab show 0.01"
  }
  'down'    { docker compose down }
  'destroy' { docker compose down -v --rmi local }
  'reset' {
    if (-not $Rest) { Write-Host 'usage: .\lab.ps1 reset <host...|all>'; exit 1 }
    $hosts = if ($Rest[0] -eq 'all') { $Targets } else { $Rest }
    docker compose up -d --force-recreate --no-deps @hosts
  }
  'shell' { docker compose exec -u learner control bash }
  'view' {
    if (-not $Rest -or $Rest.Count -ne 1) { Write-Host 'usage: .\lab.ps1 view <file.md>'; exit 1 }
    # relative paths are resolved against the caller's location
    $full = (Resolve-Path -LiteralPath (Join-Path $CallerPwd $Rest[0]) -ErrorAction SilentlyContinue)
    if (-not $full) { $full = Resolve-Path -LiteralPath $Rest[0] -ErrorAction SilentlyContinue }
    if (-not $full) { Write-Host "file not found: $($Rest[0])"; exit 1 }
    $full = $full.ProviderPath
    $root = (Resolve-Path -LiteralPath $PSScriptRoot).ProviderPath.TrimEnd('\', '/')
    if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
      Write-Host "only files inside the lab ($root) can be shown"; exit 1
    }
    $rel = $full.Substring($root.Length + 1) -replace '\\', '/'
    docker compose exec -u learner -w /lab control lab-view "/lab/$rel"
  }
  'ps'    { docker compose ps }
  'logs'  { docker compose logs @Rest }
  default { docker compose exec -u learner control lab $Command @Rest }
}
