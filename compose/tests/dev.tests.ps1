<#
  Testes da lógica do compose/dev.ps1, sem Docker. Não altera nada fora de uma pasta temporária.
  Roda no PowerShell 7 e no Windows PowerShell 5.1:
    pwsh -NoProfile -File compose/tests/dev.tests.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File compose/tests/dev.tests.ps1
#>
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '..\dev.ps1'

# Carrega só as funções puras do script, sem executá-lo.
$tokens = $null; $errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errs)
if ($errs.Count -gt 0) { throw "erro de sintaxe em dev.ps1: $($errs[0].Message)" }
$wanted = @('Read-EnvFile', 'Get-EnvValue', 'Test-ResetAnswer', 'Get-ComposeArgs')
$found = @()
foreach ($n in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
  if ($wanted -contains $n.Name) { . ([scriptblock]::Create($n.Extent.Text)); $found += $n.Name }
}
foreach ($w in $wanted) { if ($found -notcontains $w) { throw "$w não encontrada em dev.ps1" } }

$fails = 0
function Check($name, $actual, $expected) {
  if ("$actual" -ceq "$expected") { Write-Host "[ OK ] $name" }
  else { Write-Host "[FAIL] $name`n       esperado: $expected`n       obtido:   $actual"; $script:fails++ }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dev-tests-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  # --- Read-EnvFile ---
  $f = Join-Path $tmp 'a b.env'
  [System.IO.File]::WriteAllText($f, "# comentário`r`n`r`nA=1`r`n  # recuado`r`nB=x=y`r`nC=`r`nD=fim")
  $v = Read-EnvFile $f
  Check 'ignora comentários e linhas vazias' $v.Count 4
  Check 'CRLF não fica no valor' $v['A'] '1'
  Check 'valor com =' $v['B'] 'x=y'
  Check 'valor vazio' $v['C'] ''
  Check 'última linha sem quebra' $v['D'] 'fim'
  Check 'arquivo inexistente vira tabela vazia' (Read-EnvFile (Join-Path $tmp 'nao-existe')).Count 0

  # --- Get-EnvValue ---
  $key = 'BOLETO_DEV_TESTE_PORTA'
  [Environment]::SetEnvironmentVariable($key, $null)
  $file = @{ $key = '6000' }
  Check 'padrão quando não há .env nem ambiente' (Get-EnvValue $key @{} '5432') '5432'
  Check '.env vence o padrão' (Get-EnvValue $key $file '5432') '6000'
  Check '.env com valor vazio usa o padrão' (Get-EnvValue $key @{ $key = '' } '5432') '5432'
  [Environment]::SetEnvironmentVariable($key, '7000')
  Check 'ambiente vence o .env' (Get-EnvValue $key $file '5432') '7000'
  [Environment]::SetEnvironmentVariable($key, $null)

  # --- Test-ResetAnswer ---
  foreach ($a in 's', 'S', 'sim', ' Sim ', 'y', 'yes', 'YES') { Check "aceita '$a'" (Test-ResetAnswer $a) $true }
  foreach ($a in '', 'n', 'nao', 'não', 'x', $null) { Check "recusa '$a'" (Test-ResetAnswer $a) $false }

  # --- Get-ComposeArgs ---
  $dir = 'C:\pasta com espaço\boleto-docs\compose'
  $args1 = Get-ComposeArgs $dir 'C:\v.env' 'C:\e.env'
  Check 'quantidade de argumentos' $args1.Count 9
  Check 'começa por compose' $args1[0] 'compose'
  Check 'project-directory com espaço num argumento só' $args1[2] $dir
  Check 'arquivo do compose' $args1[4] (Join-Path $dir 'docker-compose.yml')
  Check 'versions.env antes do .env' "$($args1[5]) $($args1[6]) $($args1[7]) $($args1[8])" '--env-file C:\v.env --env-file C:\e.env'
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

if ($fails -gt 0) { Write-Host "$fails teste(s) falharam"; exit 1 }
Write-Host 'Todos os testes passaram.'
