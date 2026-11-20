<#
  Usado só pela CI. Simula um terminal novo: monta o ambiente a partir das variáveis
  gravadas no usuário (um passo novo do runner não as recarrega) e confere se apontam
  para a instalação esperada.

  -ExpectedDir <pasta>  instalação com -InstallDir nessa pasta.
  -DefaultMode          instalação no local padrão (%LOCALAPPDATA%), sem -InstallDir.
  -StaleDir <pastas>    pastas de instalações anteriores que não podem restar no PATH.
#>
param(
  [string]$ExpectedDir = '',
  [switch]$DefaultMode,
  [string[]]$StaleDir = @()
)
$ErrorActionPreference = 'Stop'
$fail = 0
function Check($ok, $msg) { if ($ok) { Write-Host "[ OK ] $msg" } else { Write-Host "[FAIL] $msg"; $script:fail++ } }
function Under($path, $dir) { $path -and $dir -and $path.TrimEnd('\').StartsWith($dir.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase) }

if ($DefaultMode) {
  if ($ExpectedDir) { throw 'use -ExpectedDir ou -DefaultMode, não os dois' }
  $base = $env:LOCALAPPDATA
  foreach ($k in 'BOLETO_INSTALL_DIR', 'MISE_DATA_DIR', 'MISE_CONFIG_DIR', 'MISE_CACHE_DIR', 'MISE_STATE_DIR') {
    $v = [Environment]::GetEnvironmentVariable($k, 'User')
    Check (-not $v) "$k não gravada no modo padrão ($v)"
    Remove-Item -Path "Env:$k" -ErrorAction SilentlyContinue
  }
  $vars = @('JAVA_HOME')
} else {
  if (-not $ExpectedDir) { throw 'informe -ExpectedDir ou -DefaultMode' }
  $base = $ExpectedDir
  $vars = @('BOLETO_INSTALL_DIR', 'MISE_DATA_DIR', 'MISE_CONFIG_DIR', 'MISE_CACHE_DIR', 'MISE_STATE_DIR', 'JAVA_HOME')
}
foreach ($k in $vars) {
  $v = [Environment]::GetEnvironmentVariable($k, 'User')
  Check (Under $v $base) "$k=$v"
  Set-Item -Path "Env:$k" -Value $v
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$entries = @($userPath -split ';' | Where-Object { $_ })
Check ((Under $entries[0] $base) -and (Under $entries[1] $base)) "duas primeiras entradas do PATH do usuário na instalação: $($entries[0]); $($entries[1])"
$dups = @($entries | Group-Object { $_.TrimEnd('\').ToLower() } | Where-Object { $_.Count -gt 1 })
Check ($dups.Count -eq 0) "PATH do usuário sem entradas duplicadas"
foreach ($s in $StaleDir) {
  $stale = @($entries | Where-Object { Under $_ $s })
  Check ($stale.Count -eq 0) "PATH do usuário sem entradas de $s ($($stale -join ', '))"
}

# Terminal novo: PATH do usuário na frente (como o perfil do PowerShell deixa).
$env:Path = $userPath + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
$javaLine = (cmd /c "java -version 2>&1" | Select-Object -First 1)
Check ($javaLine -match 'version "25') "java do PATH: $javaLine"
$nodeLine = (cmd /c 'node --version')
Check ($nodeLine -match '^v26\.') "node do PATH: $nodeLine"

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '..\bootstrap.ps1') doctor -Editor none
Check ($LASTEXITCODE -eq 0) 'doctor sem falhas'

if ($fail -gt 0) { Write-Host "$fail verificação(ões) falharam"; exit 1 }
