<#
.SYNOPSIS
  Atalhos do Compose de desenvolvimento (PostgreSQL, Valkey e Mailpit). Windows.

.DESCRIPTION
  up              sobe os serviços e espera todos ficarem saudáveis
  down            para e remove os containers (os dados continuam nos volumes)
  reset           apaga containers e volumes (dados do PostgreSQL e do Valkey) e sobe de novo.
                  Pede confirmação. Não apaga imagens nem o compose\.env
  ps              mostra o estado dos serviços
  logs [serviço]  mostra as últimas 100 linhas de log (de todos ou de um serviço)
  help            mostra esta ajuda

  Funciona de qualquer pasta. Na primeira execução cria compose\.env a partir do .env.example.
  As imagens vêm de .platform\versions.env (gerado a partir do versions.toml).
  Roda no PowerShell 7 e no Windows PowerShell 5.1, sem administrador.

.PARAMETER Command
  up, down, reset, ps, logs ou help.

.PARAMETER Service
  No logs, o serviço (postgres, valkey ou mailpit).

.PARAMETER Yes
  No reset, dispensa a confirmação.

.EXAMPLE
  .\compose\dev.ps1 up

.EXAMPLE
  .\compose\dev.ps1 reset -Yes
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Command = 'help',
  [Parameter(Position = 1)]
  [string]$Service = '',
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ComposeDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ComposeDir
$VersionsEnv = Join-Path $RepoRoot '.platform/versions.env'
$EnvFile = Join-Path $ComposeDir '.env'
$EnvExample = Join-Path $ComposeDir '.env.example'
$Project = 'boleto-dev'
$WaitTimeout = 120

# --- saída ---------------------------------------------------------------

function Write-Ok($m) { Write-Host '[ OK ] ' -ForegroundColor Green -NoNewline; Write-Host $m }
function Write-Warn($m) { Write-Host '[WARN] ' -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Write-Fail($m) { Write-Host '[FAIL] ' -ForegroundColor Red -NoNewline; Write-Host $m }
function Write-Info($m) { Write-Host "       $m" }
function Stop-Dev($m) { Write-Host "[ERRO] $m" -ForegroundColor Red; exit 2 }

# --- funções puras (testadas em compose/tests/dev.tests.ps1) ---------------

# Lê um arquivo KEY=valor. Ignora comentários e linhas vazias. O valor pode conter '='.
function Read-EnvFile([string]$Path) {
  $values = @{}
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $values }
  foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
    $line = $line.TrimEnd("`r")
    if ($line -match '^\s*(#|$)') { continue }
    $i = $line.IndexOf('=')
    if ($i -gt 0) { $values[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1) }
  }
  return $values
}

# Valor de uma variável: ambiente > compose\.env > padrão (mesma precedência do Compose).
function Get-EnvValue([string]$Key, $FileValues, [string]$Default) {
  $fromEnv = [Environment]::GetEnvironmentVariable($Key)
  if ($fromEnv) { return $fromEnv }
  if ($FileValues -and $FileValues.ContainsKey($Key) -and $FileValues[$Key]) { return $FileValues[$Key] }
  return $Default
}

function Test-ResetAnswer([string]$Answer) {
  if ($null -eq $Answer) { return $false }
  return @('s', 'sim', 'y', 'yes') -contains $Answer.Trim().ToLowerInvariant()
}

function Get-ComposeArgs([string]$ComposeDir, [string]$VersionsEnv, [string]$EnvFile) {
  return @(
    'compose',
    '--project-directory', $ComposeDir,
    '-f', (Join-Path $ComposeDir 'docker-compose.yml'),
    '--env-file', $VersionsEnv,
    '--env-file', $EnvFile
  )
}

# --- Docker ------------------------------------------------------------------

# O Windows PowerShell 5.1 trata o stderr de programa nativo como erro fatal sob 'Stop'.
# Por isso a chamada roda com 'Continue' e o resultado vem do código de saída.
function Invoke-Docker([string[]]$Arguments, [switch]$Quiet) {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $lines = @(& docker @Arguments 2>&1 | ForEach-Object {
        $s = "$_"
        if (-not $Quiet) { Write-Host $s }
        $s
      })
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $old
  }
  return [pscustomobject]@{ Code = $code; Output = $lines }
}

function Invoke-Compose([string[]]$Arguments, [switch]$Quiet) {
  $all = @(Get-ComposeArgs $ComposeDir $VersionsEnv $EnvFile) + $Arguments
  return Invoke-Docker $all -Quiet:$Quiet
}

function Test-Docker {
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Fail 'docker não encontrado no PATH'; exit 1 }
  if ((Invoke-Docker @('compose', 'version') -Quiet).Code -ne 0) { Write-Fail 'docker compose não encontrado'; exit 1 }
  if ((Invoke-Docker @('info') -Quiet).Code -ne 0) {
    Write-Fail 'o daemon do Docker não responde. Abra o Docker Desktop'
    exit 1
  }
  if (-not (Test-Path -LiteralPath $VersionsEnv)) { Write-Fail "$VersionsEnv não existe. Rode: npm run sync"; exit 1 }
}

function Initialize-EnvFile {
  if (-not (Test-Path -LiteralPath $EnvFile)) {
    Copy-Item -LiteralPath $EnvExample -Destination $EnvFile
    Write-Ok 'compose\.env criado a partir do .env.example'
  }
}

function Test-NonInteractive {
  if ([Console]::IsInputRedirected) { return $true }
  foreach ($a in [Environment]::GetCommandLineArgs()) { if ($a -match '^-noni') { return $true } }
  return $false
}

# --- comandos ----------------------------------------------------------------

function Invoke-Up {
  $r = Invoke-Compose @('up', '-d', '--wait', '--wait-timeout', "$WaitTimeout")
  if ($r.Code -ne 0) {
    if (($r.Output -join "`n") -match 'port is already allocated|address already in use|ports are not available') {
      Write-Fail "porta ocupada no host. Mude a porta em $EnvFile"
      Write-Info 'variáveis: POSTGRES_PORT, VALKEY_PORT, MAILPIT_SMTP_PORT, MAILPIT_UI_PORT'
    } else {
      Write-Fail "algum serviço não ficou saudável em ${WaitTimeout}s"
      $null = Invoke-Compose @('ps', '-a')
      $null = Invoke-Compose @('logs', '--tail', '30')
    }
    exit 1
  }
  $v = Read-EnvFile $EnvFile
  Write-Ok 'serviços saudáveis'
  Write-Info "Mailpit (interface): http://localhost:$(Get-EnvValue 'MAILPIT_UI_PORT' $v '8025')"
  Write-Info "Mailpit (SMTP):      localhost:$(Get-EnvValue 'MAILPIT_SMTP_PORT' $v '1025')"
  Write-Info "PostgreSQL:          localhost:$(Get-EnvValue 'POSTGRES_PORT' $v '5432'), banco $(Get-EnvValue 'POSTGRES_DB' $v 'boleto')"
  Write-Info "Valkey:              localhost:$(Get-EnvValue 'VALKEY_PORT' $v '6379') (com senha)"
}

function Invoke-Reset {
  if (-not $Yes) {
    $volumes = @((Invoke-Docker @('volume', 'ls', '-q', '--filter', "label=com.docker.compose.project=$Project") -Quiet).Output |
        Where-Object { $_ })
    Write-Warn "o reset apaga os containers e os volumes do projeto ${Project}:"
    if ($volumes.Count -gt 0) { foreach ($vol in $volumes) { Write-Host "         $vol" } }
    else { Write-Info '(nenhum volume existe ainda)' }
    if (Test-NonInteractive) { Stop-Dev 'terminal não interativo: confirme com -Yes' }
    $answer = Read-Host 'Apagar os dados e recriar? [s/N]'
    if (-not (Test-ResetAnswer $answer)) { Write-Info 'reset cancelado'; exit 0 }
  }
  $r = Invoke-Compose @('down', '--volumes', '--remove-orphans')
  if ($r.Code -ne 0) { Write-Fail 'falha ao remover containers e volumes'; exit 1 }
  Write-Ok 'containers e volumes removidos'
  Invoke-Up
}

# --- principal -----------------------------------------------------------------

$valid = @('up', 'down', 'reset', 'ps', 'logs', 'help')
if ($valid -notcontains $Command) { Stop-Dev "comando desconhecido: $Command (use help)" }
if ($Service -and $Command -ne 'logs') { Stop-Dev "argumento desconhecido: $Service (use help)" }

if ($Command -eq 'help') {
  Get-Help $MyInvocation.MyCommand.Path -Detailed | Out-String | Write-Host
  exit 0
}

Test-Docker
Initialize-EnvFile

switch ($Command) {
  'up' { Invoke-Up }
  'down' {
    $r = Invoke-Compose @('down', '--remove-orphans')
    if ($r.Code -ne 0) { exit 1 }
    Write-Ok 'serviços parados (os dados continuam nos volumes)'
  }
  'reset' { Invoke-Reset }
  'ps' { $r = Invoke-Compose @('ps', '-a'); exit $r.Code }
  'logs' {
    $a = @('logs', '--tail', '100')
    if ($Service) { $a += $Service }
    $r = Invoke-Compose $a
    exit $r.Code
  }
}
exit 0
