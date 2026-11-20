<#
  Usado só pela CI. Simula um terminal novo: monta o ambiente a partir das variáveis
  gravadas no usuário (um passo novo do runner não as recarrega) e confere se apontam
  para a pasta escolhida no bootstrap.
#>
param(
  [Parameter(Mandatory)] [string]$ExpectedDir,
  [string]$StaleDir = ''
)
$ErrorActionPreference = 'Stop'
$fail = 0
function Check($ok, $msg) { if ($ok) { Write-Host "[ OK ] $msg" } else { Write-Host "[FAIL] $msg"; $script:fail++ } }
function Under($path, $dir) { $path -and $path.TrimEnd('\').StartsWith($dir.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase) }

foreach ($k in 'BOLETO_INSTALL_DIR', 'MISE_DATA_DIR', 'MISE_CONFIG_DIR', 'MISE_CACHE_DIR', 'MISE_STATE_DIR', 'JAVA_HOME') {
  $v = [Environment]::GetEnvironmentVariable($k, 'User')
  Check (Under $v $ExpectedDir) "$k=$v"
  Set-Item -Path "Env:$k" -Value $v
}
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$entries = @($userPath -split ';' | Where-Object { $_ })
Check (Under $entries[0] $ExpectedDir) "primeira entrada do PATH do usuário: $($entries[0])"
if ($StaleDir) {
  $stale = @($entries | Where-Object { Under $_ $StaleDir })
  Check ($stale.Count -eq 0) "PATH do usuário sem entradas da pasta antiga ($StaleDir): $($stale -join ', ')"
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
