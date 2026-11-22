<#
  Testes do hook commit-msg instalado pelo bootstrap (ADR 0043).

  Pressupõe que o bootstrap.ps1 install já rodou (com o mesmo BOLETO_DEV_HOME, se houver) e que
  existem, ao lado do boleto-docs, o boleto-backend (com um commit inicial) e o boleto-frontend
  (vazio). A CI cria os dois como repositórios de teste. Só altera esses dois repositórios.
  Roda no PowerShell 7 e no Windows PowerShell 5.1:
    pwsh -NoProfile -File bootstrap/tests/hook.tests.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/hook.tests.ps1
#>
$ErrorActionPreference = 'Continue'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Ws = Split-Path -Parent $Root
$Boot = Join-Path $Root 'bootstrap\bootstrap.ps1'
$Back = Join-Path $Ws 'boleto-backend'
$Front = Join-Path $Ws 'boleto-frontend'
$HostExe = (Get-Process -Id $PID).Path
$script:fails = 0

function Pass($name) { Write-Host "[ OK ] $name" }
function Bad($name) { Write-Host "[FAIL] $name"; $script:fails++ }
function Check($name, [bool]$cond) { if ($cond) { Pass $name } else { Bad $name } }

# Roda o git num repositório e devolve @{ Code; Out } (stderr junto, sem erro fatal no 5.1).
function Invoke-GitIn([string]$dir, [string[]]$gitArgs) {
  $all = @('-C', $dir, '-c', 'user.name=ci', '-c', 'user.email=ci@example.invalid', '-c', 'commit.gpgsign=false') + $gitArgs
  $out = (& git @all 2>&1 | ForEach-Object { "$_" }) -join "`n"
  return @{ Code = $LASTEXITCODE; Out = $out }
}
function Get-CommonHook([string]$repo) {
  $d = (& git -C $repo rev-parse --git-common-dir 2>$null)
  $d = "$d".Trim()
  if (-not [IO.Path]::IsPathRooted($d)) { $d = Join-Path $repo $d }
  return (Join-Path $d 'hooks\commit-msg')
}
function Count-Commits([string]$repo) {
  $n = (& git -C $repo rev-list --count HEAD 2>$null)
  if ($LASTEXITCODE -ne 0) { return 0 }
  return [int]"$n".Trim()
}
function Sha([string]$p) { (Get-FileHash $p -Algorithm SHA256).Hash }
function Run-Boot([string]$cmd) {
  $out = (& $HostExe -NoProfile -ExecutionPolicy Bypass -File $Boot $cmd -Editor none 2>&1 | ForEach-Object { "$_" }) -join "`n"
  return @{ Code = $LASTEXITCODE; Out = $out }
}
$Enc = New-Object Text.UTF8Encoding($false)

foreach ($d in $Back, $Front) {
  if (-not (Test-Path (Join-Path $d '.git'))) { Write-Host "[FAIL] repositório de teste ausente: $d"; exit 1 }
}
& git -C $Back rev-parse --verify -q HEAD *> $null
if ($LASTEXITCODE -ne 0) { Write-Host '[FAIL] o boleto-backend de teste precisa de um commit inicial'; exit 1 }

# 1. Hook com o marcador, em LF e sem BOM, nos três repositórios.
foreach ($r in $Root, $Back, $Front) {
  $h = Get-CommonHook $r
  $ok = $false
  if (Test-Path $h) {
    $bytes = [IO.File]::ReadAllBytes($h)
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    $ok = $text.Contains('# boleto-hook: commit-msg') -and -not $text.Contains("`r") -and ($bytes[0] -eq 0x23)
  }
  Check "1. hook com marcador, LF e sem BOM em $(Split-Path -Leaf $r)" $ok
}

# 2. Mensagem inválida no backend: recusada, sem commit novo.
$before = Count-Commits $Back
$r = Invoke-GitIn $Back @('commit', '--allow-empty', '-m', 'mensagem invalida')
Check '2. mensagem inválida recusada, com a saída do commitlint, sem commit novo' (($r.Code -ne 0) -and $r.Out.Contains('type may not be empty') -and ((Count-Commits $Back) -eq $before))

# 3. Linha de corpo de 101 colunas recusada, de 100 aceita.
$l101 = 'a' * 101; $l100 = 'a' * 100
$r = Invoke-GitIn $Back @('commit', '--allow-empty', '-m', 'chore: corpo longo', '-m', $l101)
Check '3. linha de corpo com 101 colunas recusada' (($r.Code -ne 0) -and $r.Out.Contains('longer than 100'))
$r = Invoke-GitIn $Back @('commit', '--allow-empty', '-m', 'chore: corpo no limite', '-m', $l100)
Check '3. linha de corpo com 100 colunas aceita' ($r.Code -eq 0)

# 4. Frontend vazio: inválida recusada, primeiro commit aceito.
$r = Invoke-GitIn $Front @('commit', '--allow-empty', '-m', 'mensagem invalida')
Check '4. frontend vazio recusa mensagem inválida' ($r.Code -ne 0)
$r = Invoke-GitIn $Front @('commit', '--allow-empty', '-m', 'feat: primeiro commit')
& git -C $Front rev-parse --verify -q HEAD *> $null
Check '4. frontend vazio aceita o primeiro commit válido' (($r.Code -eq 0) -and ($LASTEXITCODE -eq 0))

# 5. Worktree do backend usa o mesmo hook.
$wt = Join-Path $Back '.worktrees\hook-test'
& git -C $Back worktree add -q $wt -b chore/hook-test *> $null
if (Test-Path $wt) {
  $r = Invoke-GitIn $wt @('commit', '--allow-empty', '-m', 'mensagem invalida')
  Check '5. worktree recusa mensagem inválida' ($r.Code -ne 0)
  Check '5. worktree compartilha o hook do repositório' ((Get-CommonHook $wt) -ieq (Get-CommonHook $Back))
  & git -C $Back worktree remove --force $wt *> $null
  & git -C $Back branch -D chore/hook-test *> $null
} else { Bad '5. não consegui criar o worktree de teste' }

# 6. Idempotência: segundo install mantém o hook e diz que já está ativo.
$h = Get-CommonHook $Back
$sum1 = Sha $h
$r = Run-Boot 'install'
Check '6. install repetido mantém o hook (sha256 igual)' (((Sha $h) -eq $sum1) -and $r.Out.Contains('boleto-backend: hook já ativo'))

# 7. commit-msg alheio: install mantém e avisa; doctor avisa.
[IO.File]::WriteAllText($h, "#!/bin/sh`nexit 0`n", $Enc)
$sum2 = Sha $h
$r = Run-Boot 'install'
Check '7. install não sobrescreve commit-msg alheio e avisa' (((Sha $h) -eq $sum2) -and $r.Out.Contains('boleto-backend: commit-msg de outro autor'))
$r = Run-Boot 'doctor'
Check '7. doctor avisa do commit-msg alheio' $r.Out.Contains('boleto-backend: commit-msg de outro autor')
Remove-Item $h -Force

# 8. core.hooksPath no frontend: install não grava e avisa.
$hf = Get-CommonHook $Front
Remove-Item $hf -Force
& git -C $Front config core.hooksPath /nonexistent-hooks
$r = Run-Boot 'install'
Check '8. core.hooksPath: install não grava e avisa' ((-not (Test-Path $hf)) -and $r.Out.Contains('boleto-frontend: core.hooksPath'))
& git -C $Front config --unset core.hooksPath

# 9. Hook removido: doctor sai com 1; install restaura (backend e frontend).
$r = Run-Boot 'doctor'
Check "9. doctor sai com 1 e diz 'hook não instalado'" (($r.Code -eq 1) -and $r.Out.Contains('boleto-frontend: hook não instalado'))
$null = Run-Boot 'install'
$restored = (Test-Path $hf) -and (Test-Path $h) -and ([IO.File]::ReadAllText($hf).Contains('# boleto-hook: commit-msg')) -and ([IO.File]::ReadAllText($h).Contains('# boleto-hook: commit-msg'))
Check '9. install restaura o hook removido' $restored

# 11. Node gravado inexistente: cai no node do PATH.
$text = [IO.File]::ReadAllText($h) -replace "(?m)^BOLETO_NODE=.*$", "BOLETO_NODE='C:/nonexistent/node.exe'"
[IO.File]::WriteAllText($h, $text, $Enc)
$r = Invoke-GitIn $Back @('commit', '--allow-empty', '-m', 'mensagem invalida')
Check '11. Node gravado inexistente cai no node do PATH' (($r.Code -ne 0) -and $r.Out.Contains('type may not be empty'))
$null = Run-Boot 'install'

# 10. --no-verify pula o hook (comportamento documentado; a CI continua recusando).
$before = Count-Commits $Back
$r = Invoke-GitIn $Back @('commit', '--no-verify', '--allow-empty', '-m', 'mensagem invalida')
Check '10. --no-verify pula o hook' (($r.Code -eq 0) -and ((Count-Commits $Back) -gt $before))

Write-Host ''
if ($script:fails -gt 0) { Write-Host "$($script:fails) falha(s)."; exit 1 }
Write-Host 'Todos os cenários do hook passaram.'
