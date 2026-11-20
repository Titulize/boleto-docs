<#
  Testes da lógica de PATH do bootstrap.ps1. Não grava nada no ambiente do usuário.
  Roda no PowerShell 7 e no Windows PowerShell 5.1:
    pwsh -NoProfile -File bootstrap/tests/path.tests.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/path.tests.ps1
#>
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '..\bootstrap.ps1'

# Carrega só as peças puras do script, sem executá-lo.
$tokens = $null; $errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errs)
if ($errs.Count -gt 0) { throw "erro de sintaxe em bootstrap.ps1: $($errs[0].Message)" }
$wanted = @('Get-NewUserPath')
foreach ($n in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
  if ($wanted -contains $n.Name) { . ([scriptblock]::Create($n.Extent.Text)) }
}
$assign = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq '$SameDir' }, $true) | Select-Object -First 1
if (-not $assign) { throw '$SameDir não encontrado em bootstrap.ps1' }
. ([scriptblock]::Create($assign.Extent.Text))

$fails = 0
function Check($name, $actual, $expected) {
  if ("$actual" -ceq "$expected") { Write-Host "[ OK ] $name" }
  else { Write-Host "[FAIL] $name`n       esperado: $expected`n       obtido:   $actual"; $script:fails++ }
}
function Empty-List { return @() }   # como Get-StalePaths quando não há nada para limpar

$bin = 'C:\Users\u\AppData\Local\boleto-dev\bin'
$shims = 'C:\Users\u\AppData\Local\mise\shims'

# O caso que falhou na instalação real: modo padrão, nada para limpar.
$r = Get-NewUserPath 'C:\a;C:\b' @($bin, $shims) (Empty-List)
Check 'lista de remoção vazia vinda de função (vira $null)' $r.Path "$bin;$shims;C:\a;C:\b"
Check 'nada removido' $r.Removed 0

$r = Get-NewUserPath 'C:\a' @($bin, $shims) $null
Check 'remoção $null' $r.Path "$bin;$shims;C:\a"

$r = Get-NewUserPath $null @($bin, $shims) @()
Check 'PATH do usuário inexistente' $r.Path "$bin;$shims"

$r = Get-NewUserPath '' @($bin, $shims) @()
Check 'PATH do usuário vazio' $r.Path "$bin;$shims"

$r = Get-NewUserPath "C:\a;$($bin.ToUpper())\;C:\b;$shims" @($bin, $shims) @()
Check 'não duplica (maiúsculas e barra final)' $r.Path "$bin;$shims;C:\a;C:\b"
Check 'reordenar não conta como remoção' $r.Removed 0

$old = 'D:\tools\bin'; $oldShims = 'D:\tools\mise\data\shims'
$r = Get-NewUserPath "$old;C:\a;$oldShims;C:\b" @($bin, $shims) @($old, $oldShims, 'X:\nao-esta-no-path')
Check 'remove pastas da instalação anterior' $r.Path "$bin;$shims;C:\a;C:\b"
Check 'conta só o que estava no PATH' $r.Removed 2

$r = Get-NewUserPath 'C:\a;;C:\b;' @($bin) @($null, '')
Check 'ignora entradas vazias' $r.Path "$bin;C:\a;C:\b"

$r = Get-NewUserPath "C:\a;$bin" @($bin, $shims) @($bin)
Check 'pasta em add e remove fica (add vence)' $r.Path "$bin;$shims;C:\a"
Check 'pasta em add e remove não conta como removida' $r.Removed 0

Check '$SameDir com nulo' (& $SameDir $null 'C:\a') $false

if ($fails -gt 0) { Write-Host "$fails teste(s) falharam"; exit 1 }
Write-Host 'Todos os testes passaram.'
