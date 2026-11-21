<#
.SYNOPSIS
  Verifica o Compose de desenvolvimento já em execução (não sobe nem derruba nada).

.DESCRIPTION
  1. Espera todos os serviços do compose ficarem healthy. Falha se algum serviço não tiver
     healthcheck.
  2. Sondagens: select 1 no PostgreSQL, PONG no Valkey com senha e NOAUTH sem senha,
     HTTP 200 na interface e na API do Mailpit, e conexão TCP em todas as portas publicadas.

  Sai com código 0 se tudo passou e 1 se algo falhou. Roda no PowerShell 7 e no 5.1.

.PARAMETER TimeoutSeconds
  Tempo máximo de espera pela saúde dos serviços. Padrão: 120.

.EXAMPLE
  .\compose\tests\verify.ps1
#>
[CmdletBinding()]
param([int]$TimeoutSeconds = 120)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ComposeDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$RepoRoot = Split-Path -Parent $ComposeDir
$EnvFile = Join-Path $ComposeDir '.env'
if (-not (Test-Path -LiteralPath $EnvFile)) { $EnvFile = Join-Path $ComposeDir '.env.example' }
$script:Fails = 0

function Write-Ok($m) { Write-Host "[ OK ] $m" }
function Write-Fail($m) { Write-Host "[FAIL] $m"; $script:Fails++ }

# Mesmo motivo do dev.ps1: no 5.1 o stderr nativo vira erro fatal sob 'Stop'.
function Invoke-Native([string[]]$Arguments) {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $out = @(& docker @Arguments 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $old }
  return [pscustomobject]@{ Code = $code; Text = ($out -join "`n").Trim() }
}

function Invoke-Compose([string[]]$Arguments) {
  $base = @('compose', '--project-directory', $ComposeDir, '-f', (Join-Path $ComposeDir 'docker-compose.yml'),
    '--env-file', (Join-Path $RepoRoot '.platform/versions.env'), '--env-file', $EnvFile)
  return Invoke-Native ($base + $Arguments)
}

function Get-Health([string]$Svc) {
  $id = (Invoke-Compose @('ps', '-q', $Svc)).Text
  if (-not $id) { return 'parado' }
  $fmt = '{{if .State.Health}}{{.State.Health.Status}}{{else}}sem-healthcheck{{end}}'
  return (Invoke-Native @('inspect', '-f', $fmt, $id)).Text
}

# --- 1. saúde -------------------------------------------------------------------

$cfg = Invoke-Compose @('config', '--services')
if ($cfg.Code -ne 0) { Write-Fail "docker compose config falhou: $($cfg.Text)"; exit 1 }
$services = @($cfg.Text -split "`r?`n" | Where-Object { $_ })
if ($services.Count -eq 0) { Write-Fail 'nenhum serviço no compose'; exit 1 }

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ($true) {
  $pending = @()
  foreach ($s in $services) {
    $h = Get-Health $s
    if ($h -eq 'sem-healthcheck') { Write-Fail "$s não tem healthcheck"; exit 1 }
    if ($h -ne 'healthy') { $pending += "$s=$h" }
  }
  if ($pending.Count -eq 0) { break }
  if ((Get-Date) -ge $deadline) { Write-Fail "serviços não ficaram healthy em ${TimeoutSeconds}s: $($pending -join ' ')"; exit 1 }
  Start-Sleep -Seconds 2
}
Write-Ok "todos os serviços healthy: $($services -join ' ')"

# --- 2. sondagens -----------------------------------------------------------------

# Sem aspas duplas dentro dos argumentos: o Windows PowerShell 5.1 não as escapa ao chamar
# programas nativos, e o comando chegaria quebrado ao container.
$r = Invoke-Compose @('exec', '-T', 'postgres', 'sh', '-c', 'psql -U $POSTGRES_USER -d $POSTGRES_DB -tAc ''select 1''')
if ($r.Text -eq '1') { Write-Ok 'PostgreSQL responde a select 1' } else { Write-Fail "PostgreSQL: $($r.Text)" }

$r = Invoke-Compose @('exec', '-T', 'valkey', 'sh', '-c', 'valkey-cli -a $VALKEY_PASSWORD --no-auth-warning ping')
if ($r.Text -eq 'PONG') { Write-Ok 'Valkey responde PONG com senha' } else { Write-Fail "Valkey com senha: $($r.Text)" }

$r = Invoke-Compose @('exec', '-T', 'valkey', 'valkey-cli', 'ping')
if ($r.Text -match 'NOAUTH') { Write-Ok 'Valkey recusa comando sem senha (NOAUTH)' } else { Write-Fail "Valkey sem senha deveria recusar: $($r.Text)" }

function Get-Published([string]$Svc, [int]$Port) {
  return ((Invoke-Compose @('port', $Svc, "$Port")).Text -split "`r?`n")[0]
}

$ui = Get-Published 'mailpit' 8025
$uiPort = $ui.Substring($ui.LastIndexOf(':') + 1)
foreach ($path in '/', '/api/v1/info') {
  $url = "http://localhost:$uiPort$path"
  try {
    $code = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10).StatusCode
  } catch { $code = "erro: $($_.Exception.Message)" }
  if ($code -eq 200) { Write-Ok "Mailpit $url responde 200" } else { Write-Fail "Mailpit ${path}: HTTP $code" }
}

foreach ($pair in @(@('postgres', 5432), @('valkey', 6379), @('mailpit', 1025), @('mailpit', 8025))) {
  $svc = $pair[0]; $port = $pair[1]
  $addr = Get-Published $svc $port
  $i = $addr.LastIndexOf(':')
  $hostPart = if ($i -gt 0) { $addr.Substring(0, $i) } else { '' }
  if ($hostPart -ne '127.0.0.1') { Write-Fail "${svc}:$port publicado em '$addr' (esperado 127.0.0.1)"; continue }
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $client.Connect('127.0.0.1', [int]$addr.Substring($i + 1))
    Write-Ok "${svc}:$port aceita conexão em $addr"
  } catch {
    Write-Fail "${svc}:$port não aceita conexão em $addr"
  } finally { $client.Close() }
}

if ($script:Fails -gt 0) { Write-Host "$($script:Fails) verificação(ões) falharam"; exit 1 }
Write-Host 'Todas as verificações passaram.'
