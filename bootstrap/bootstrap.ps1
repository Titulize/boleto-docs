<#
.SYNOPSIS
  Prepara a máquina do desenvolvedor (Windows).

.DESCRIPTION
  install   (padrão) instala o mise, Java e Node nas versões do versions.toml,
            configura o PATH e o JAVA_HOME do usuário e instala as extensões do Kiro e do VS Code.
  doctor    só diagnostica, sem alterar nada. Sai com código 1 se algo essencial faltar.

  Requisito: Docker Desktop (com Compose) e Git já instalados. O resto este script instala.

  Nada aqui exige administrador: tudo vai para pastas e variáveis do seu usuário.

  O install também grava o hook commit-msg (commitlint) em cada repositório presente e instala o
  commitlint do boleto-docs (npm ci, uma vez). O doctor mostra o estado do hook (ADR 0043).
  Rode o install no checkout principal do boleto-docs, não num worktree.

  A variável de ambiente BOLETO_DEV_HOME instala tudo dentro de uma pasta, isolado
  (útil para testes). Implica -NoPersist e não pode ser combinada com -InstallDir.

.PARAMETER Command
  install ou doctor.

.PARAMETER NoPersist
  Não altera o PATH/JAVA_HOME do usuário nem a configuração global do mise.

.PARAMETER InstallDir
  Pasta onde ficam o mise, o Java e o Node (por exemplo C:\dev\tools). O JAVA_HOME, o PATH e o
  mise do usuário passam a apontar para ela. A escolha fica gravada (variável BOLETO_INSTALL_DIR
  do usuário) e vale nas próximas execuções. Sem esta opção, usa %LOCALAPPDATA%.

.PARAMETER Clone
  Clona os repositórios que faltarem ao lado do boleto-docs.

.PARAMETER Editor
  kiro, code ou none. Padrão: todos os que forem encontrados.

.EXAMPLE
  .\bootstrap\bootstrap.ps1 doctor

.EXAMPLE
  .\bootstrap\bootstrap.ps1 install -InstallDir C:\dev\tools
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('install', 'doctor')]
  [string]$Command = 'install',
  [switch]$NoPersist,
  [string]$InstallDir = '',
  [switch]$Clone,
  [ValidateSet('', 'kiro', 'code', 'none')]
  [string]$Editor = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$WorkspaceDir = Split-Path -Parent $RepoRoot
$EnvFile = Join-Path $RepoRoot '.platform\versions.env'
$ExtFile = Join-Path $ScriptDir 'extensions.txt'
$GithubOrg = 'Titulize'
$Repos = @('boleto-docs', 'boleto-backend', 'boleto-frontend', 'boleto-migrations')

$script:Fails = 0
$script:Warns = 0
$script:Mise = $null

# --- saída ---------------------------------------------------------------

function Write-Ok($m) { Write-Host '[ OK ] ' -ForegroundColor Green -NoNewline; Write-Host $m }
function Write-Warn($m) { Write-Host '[WARN] ' -ForegroundColor Yellow -NoNewline; Write-Host $m; $script:Warns++ }
function Write-Fail($m) { Write-Host '[FAIL] ' -ForegroundColor Red -NoNewline; Write-Host $m; $script:Fails++ }
# Na CI (sem Docker utilizável) BOLETO_IGNORE_DOCKER=1 rebaixa as falhas do Docker para aviso.
function Write-DockerProblem($m) { if ($env:BOLETO_IGNORE_DOCKER) { Write-Warn $m } else { Write-Fail $m } }
function Write-Info($m) { Write-Host "       $m" }
function Write-Step($m) { Write-Host ''; Write-Host "== $m" }
function Stop-Bootstrap($m) { Write-Host "[ERRO] $m" -ForegroundColor Red; exit 2 }

# --- versões -----------------------------------------------------------------

function Read-Versions {
  if (-not (Test-Path $EnvFile)) { Stop-Bootstrap "$EnvFile não existe. Rode: npm run sync" }
  $v = @{}
  foreach ($line in Get-Content $EnvFile) {
    if ($line -match '^\s*(#|$)') { continue }
    $i = $line.IndexOf('=')
    if ($i -gt 0) { $v[$line.Substring(0, $i)] = $line.Substring($i + 1).Trim() }
  }
  foreach ($k in 'JAVA_MAJOR', 'JAVA_CORRETTO_BUILD', 'NODE_VERSION', 'GRADLE_VERSION', 'MISE_VERSION', 'MISE_URL_WINDOWS_X64', 'MISE_SHA256_WINDOWS_X64') {
    if (-not $v[$k]) { Stop-Bootstrap "variável $k ausente em $EnvFile. Rode: npm run sync" }
  }
  return $v
}

# --- ambiente isolado ou padrão -------------------------------------------

$MiseDirVars = @('MISE_DATA_DIR', 'MISE_CONFIG_DIR', 'MISE_CACHE_DIR', 'MISE_STATE_DIR')

# Pastas do mise dentro de uma pasta base, na ordem de $MiseDirVars.
function Get-MiseDirs($base) {
  @{
    MISE_DATA_DIR   = Join-Path $base 'mise\data'
    MISE_CONFIG_DIR = Join-Path $base 'mise\config'
    MISE_CACHE_DIR  = Join-Path $base 'mise\cache'
    MISE_STATE_DIR  = Join-Path $base 'mise\state'
  }
}

function Resolve-InstallDir([string]$dir, [bool]$create) {
  if ($dir.Contains(';')) { Stop-Bootstrap "o caminho não pode conter ';' (separador do PATH): $dir" }
  if (-not [IO.Path]::IsPathRooted($dir)) { Stop-Bootstrap "use um caminho absoluto em -InstallDir: $dir" }
  $full = [IO.Path]::GetFullPath($dir).TrimEnd('\')
  if ($create) {
    try { New-Item -ItemType Directory -Force -Path $full | Out-Null }
    catch { Stop-Bootstrap "não consegui criar $full. Escolha uma pasta do seu usuário (ex.: C:\dev\tools)" }
    $probe = Join-Path $full ('.boleto-write-test-' + [Guid]::NewGuid().ToString('N'))
    try { [IO.File]::WriteAllText($probe, ''); Remove-Item $probe -Force }
    catch { Stop-Bootstrap "sem permissão de escrita em $full. Escolha uma pasta do seu usuário (ex.: C:\dev\tools)" }
  }
  return $full
}

function Initialize-Dirs {
  $script:CustomDir = $false
  if ($env:BOLETO_DEV_HOME) {
    if ($InstallDir) { Stop-Bootstrap 'BOLETO_DEV_HOME e -InstallDir não podem ser usados juntos' }
    $script:BoletoHome = $env:BOLETO_DEV_HOME
    $script:SkipPersist = $true
    $script:InstallMode = 'isolada (BOLETO_DEV_HOME)'
  } else {
    # A escolha gravada no usuário vale quando -InstallDir não é passado.
    $chosen = $InstallDir
    $origin = '-InstallDir'
    if (-not $chosen) {
      $chosen = [Environment]::GetEnvironmentVariable('BOLETO_INSTALL_DIR', 'User')
      $origin = 'BOLETO_INSTALL_DIR do usuário'
    }
    if ($chosen) {
      $script:BoletoHome = Resolve-InstallDir $chosen ($Command -eq 'install')
      $script:CustomDir = $true
      $script:InstallMode = "escolhida ($origin)"
    } else {
      $script:BoletoHome = Join-Path $env:LOCALAPPDATA 'boleto-dev'
      $script:MiseData = Join-Path $env:LOCALAPPDATA 'mise'
      $script:InstallMode = 'padrão (%LOCALAPPDATA%)'
    }
  }
  if ($env:BOLETO_DEV_HOME -or $script:CustomDir) {
    $dirs = Get-MiseDirs $script:BoletoHome
    foreach ($k in $MiseDirVars) { Set-Item -Path "Env:$k" -Value $dirs[$k] }
    $script:MiseData = $dirs.MISE_DATA_DIR
  }
  $script:BinDir = Join-Path $script:BoletoHome 'bin'
  $script:Shims = Join-Path $script:MiseData 'shims'
  $env:MISE_YES = '1'
  $env:MISE_NO_ANALYTICS = '1'
}

function Find-Mise {
  # Chamadas nativas aqui escrevem no stderr. No Windows PowerShell 5.1, stderr redirecionado
  # com EAP=Stop vira erro fatal, então estas funções usam Continue e checam LASTEXITCODE.
  $ErrorActionPreference = 'Continue'
  $own = Join-Path $script:BinDir 'mise.exe'
  if (Test-Path $own) { $script:Mise = $own; return }
  $cmd = Get-Command mise -ErrorAction SilentlyContinue
  if ($cmd) { $script:Mise = $cmd.Source } else { $script:Mise = $null }
}

function Get-MiseVersion {
  # Chamadas nativas aqui escrevem no stderr. No Windows PowerShell 5.1, stderr redirecionado
  # com EAP=Stop vira erro fatal, então estas funções usam Continue e checam LASTEXITCODE.
  $ErrorActionPreference = 'Continue'
  ((& $script:Mise --version 2>$null) -split '\s+')[0]
}

function Invoke-Mise {
  # Chama o mise e falha se o código de saída não for zero.
  & $script:Mise @args
  if ($LASTEXITCODE -ne 0) { throw "mise $($args -join ' ') falhou (código $LASTEXITCODE)" }
}

# --- etapas ------------------------------------------------------------------

function Test-Prereqs {
  # Chamadas nativas aqui escrevem no stderr. No Windows PowerShell 5.1, stderr redirecionado
  # com EAP=Stop vira erro fatal, então estas funções usam Continue e checam LASTEXITCODE.
  $ErrorActionPreference = 'Continue'
  Write-Step 'Pré-requisitos'
  if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Ok ('Git ' + ((git --version) -replace 'git version ', ''))
  } else {
    Write-Fail 'Git não encontrado. Instale em https://git-scm.com/downloads'
  }
  if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Ok ('Docker ' + ((docker --version) -replace 'Docker version ', '' -replace ',.*', ''))
    & docker compose version *> $null
    if ($LASTEXITCODE -eq 0) { Write-Ok ('Docker Compose ' + (& docker compose version --short)) } else { Write-DockerProblem 'Docker Compose (plugin v2) não encontrado' }
    & docker info *> $null
    if ($LASTEXITCODE -eq 0) { Write-Ok 'daemon do Docker em execução' } else { Write-DockerProblem 'daemon do Docker parado. Inicie o Docker Desktop' }
  } else {
    Write-DockerProblem 'Docker não encontrado. Instale em https://docs.docker.com/desktop/setup/install/windows-install/'
  }
}

function Install-Mise($V) {
  Write-Step "mise $($V.MISE_VERSION)"
  # Só a cópia dentro da pasta de instalação conta: é ela que o PATH do usuário e o perfil vão usar.
  # Um mise de outra pasta (ou de uma instalação anterior) não é reaproveitado.
  $own = Join-Path $script:BinDir 'mise.exe'
  if (Test-Path $own) {
    $script:Mise = $own
    $have = Get-MiseVersion
    if ($have -eq $V.MISE_VERSION) { Write-Ok "mise $have já instalado ($own)"; return }
    Write-Info "mise $have em $own difere da versão pinada; atualizando"
  }
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('boleto-mise-' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp | Out-Null
  try {
    $zip = Join-Path $tmp 'mise.zip'
    Write-Info "baixando $($V.MISE_URL_WINDOWS_X64)"
    Invoke-WebRequest -Uri $V.MISE_URL_WINDOWS_X64 -OutFile $zip -UseBasicParsing
    $got = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    if ($got -ne $V.MISE_SHA256_WINDOWS_X64) {
      Stop-Bootstrap "sha256 do mise não confere (esperado $($V.MISE_SHA256_WINDOWS_X64), obtido $got). Download descartado"
    }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Force -Path $script:BinDir | Out-Null
    Copy-Item (Join-Path $tmp 'mise\bin\mise.exe') $script:BinDir -Force
    Copy-Item (Join-Path $tmp 'mise\bin\mise-shim.exe') $script:BinDir -Force
  } finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
  Find-Mise
  Write-Ok "mise $(Get-MiseVersion) instalado em $($script:Mise) (sha256 conferido)"
}

function Install-Tools($V) {
  Write-Step "Java $($V.JAVA_MAJOR) (Corretto $($V.JAVA_CORRETTO_BUILD)) e Node $($V.NODE_VERSION)"
  $java = "java@corretto-$($V.JAVA_CORRETTO_BUILD)"
  $node = "node@$($V.NODE_VERSION)"
  # Roda a partir da pasta do usuário: dentro de um projeto, o mise.toml dele geraria avisos.
  Push-Location $env:USERPROFILE
  try {
    if (-not $script:SkipPersist) {
      Invoke-Mise use -g $java $node   # instala e define como padrão do usuário
      Write-Ok 'Java e Node instalados e definidos como padrão do usuário (mise use -g)'
    } else {
      Invoke-Mise install $java $node
      Write-Info '-NoPersist: padrão global do mise não alterado'
    }
  } finally {
    Pop-Location
  }
  Write-Info "Gradle $($V.GRADLE_VERSION) vem pelo Gradle Wrapper de cada projeto"
}

$SameDir = { param($a, $b) ($null -ne $a) -and ($null -ne $b) -and ($a.TrimEnd('\') -ieq $b.TrimEnd('\')) }

# Calcula o novo PATH sem gravar nada: $add vai para o início, $remove sai.
# Listas vazias ou nulas são aceitas (uma função que devolve @() entrega $null ao chamador).
function Get-NewUserPath([string]$current, $add, $remove) {
  $add = @(@($add) | Where-Object { $_ })
  $remove = @(@($remove) | Where-Object { $_ })
  $parts = @(@("$current" -split ';') | Where-Object { $_ })
  $isIn = { param($p, $list) [bool](@($list | Where-Object { & $SameDir $p $_ })).Count }
  $removed = @($parts | Where-Object { (& $isIn $_ $remove) -and -not (& $isIn $_ $add) }).Count
  $kept = @($parts | Where-Object { -not (& $isIn $_ ($add + $remove)) })
  return [pscustomobject]@{ Path = (($add + $kept) -join ';'); Removed = $removed }
}

# Coloca as pastas no início do PATH do usuário e tira as que ficaram de uma instalação anterior.
function Set-UserPath($add, $remove) {
  $r = Get-NewUserPath ([Environment]::GetEnvironmentVariable('Path', 'User')) $add $remove
  [Environment]::SetEnvironmentVariable('Path', $r.Path, 'User')
  return $r.Removed
}

# Pastas bin e shims das instalações que não são a atual (padrão e escolha gravada anterior).
function Get-StalePaths {
  $bases = @(@{ Bin = (Join-Path $env:LOCALAPPDATA 'boleto-dev\bin'); Shims = (Join-Path $env:LOCALAPPDATA 'mise\shims') })
  $prev = [Environment]::GetEnvironmentVariable('BOLETO_INSTALL_DIR', 'User')
  if ($prev) { $bases += @{ Bin = (Join-Path $prev 'bin'); Shims = (Join-Path $prev 'mise\data\shims') } }
  $stale = @()
  foreach ($b in $bases) {
    foreach ($d in $b.Bin, $b.Shims) {
      if (-not ((& $SameDir $d $script:BinDir) -or (& $SameDir $d $script:Shims))) { $stale += $d }
    }
  }
  return $stale
}

function Set-UserEnvironment($V) {
  Write-Step 'PATH e JAVA_HOME do usuário'
  if ($script:SkipPersist) { Write-Info '-NoPersist: variáveis do usuário não alteradas'; return }
  $removed = Set-UserPath @($script:BinDir, $script:Shims) (Get-StalePaths)
  if ($script:CustomDir) {
    $dirs = Get-MiseDirs $script:BoletoHome
    foreach ($k in $MiseDirVars) { [Environment]::SetEnvironmentVariable($k, $dirs[$k], 'User') }
    [Environment]::SetEnvironmentVariable('BOLETO_INSTALL_DIR', $script:BoletoHome, 'User')
    Write-Ok "pasta de instalação gravada: BOLETO_INSTALL_DIR=$($script:BoletoHome)"
    Write-Ok 'variáveis do mise (MISE_DATA_DIR, MISE_CONFIG_DIR, MISE_CACHE_DIR, MISE_STATE_DIR) apontam para ela'
  }
  $javaHomePath = (& $script:Mise where "java@corretto-$($V.JAVA_CORRETTO_BUILD)").Trim()
  [Environment]::SetEnvironmentVariable('JAVA_HOME', $javaHomePath, 'User')
  Write-Ok "JAVA_HOME=$javaHomePath"
  Write-Ok 'PATH do usuário atualizado (mise e shims)'
  if ($removed -gt 0) { Write-Info "$removed pasta(s) de uma instalação anterior removida(s) do PATH (os arquivos antigos não foram apagados)" }
  Set-ProfileBlock
  Write-Info 'abra um novo terminal (e reinicie o Kiro/VS Code) para valer'
}

# No Windows o PATH da máquina vem antes do PATH do usuário, então um Java ou Node instalado
# na máquina "ganharia" do mise. O perfil do PowerShell ativa o mise e corrige isso nos terminais.
function Set-ProfileBlock([string]$DocsDir = [Environment]::GetFolderPath('MyDocuments')) {
  $docs = $DocsDir
  $profiles = @((Join-Path $docs 'PowerShell\profile.ps1'), (Join-Path $docs 'WindowsPowerShell\profile.ps1'))
  $start = '# >>> boleto-dev'
  $end = '# <<< boleto-dev'
  $block = @(
    "$start (gerenciado por bootstrap.ps1, não edite)",
    "if (Test-Path '$($script:Mise -replace "'", "''")') { (& '$($script:Mise -replace "'", "''")' activate pwsh) | Out-String | Invoke-Expression }",
    $end
  ) -join "`r`n"
  foreach ($p in $profiles) {
    $dir = Split-Path -Parent $p
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $content = ''
    if (Test-Path $p) { $content = [IO.File]::ReadAllText($p) }
    $pattern = '(?s)\r?\n?' + [regex]::Escape($start) + '.*?' + [regex]::Escape($end)
    $content = [regex]::Replace($content, $pattern, '').TrimEnd()
    $content = ($content + "`r`n" + $block + "`r`n").TrimStart()
    [IO.File]::WriteAllText($p, $content, (New-Object Text.UTF8Encoding($true)))
    Write-Ok "mise ativado no perfil do PowerShell ($p)"
  }
  Write-Info 'se o perfil não carregar, libere scripts: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
}

function Get-Editors {
  switch ($Editor) {
    'none' { return @() }
    'kiro' { if (Get-Command kiro -ErrorAction SilentlyContinue) { return @('kiro') } else { return @() } }
    'code' { if (Get-Command code -ErrorAction SilentlyContinue) { return @('code') } else { return @() } }
  }
  $found = @()
  if (Get-Command kiro -ErrorAction SilentlyContinue) { $found += 'kiro' }
  if (Get-Command code -ErrorAction SilentlyContinue) { $found += 'code' }
  return $found
}

function Get-ExtensionList {
  Get-Content $ExtFile | Where-Object { $_ -notmatch '^\s*(#|$)' } | ForEach-Object { ($_ -split '\s+')[0] }
}

function Sync-EditorExtensions($mode) {
  # Chamadas nativas aqui escrevem no stderr. No Windows PowerShell 5.1, stderr redirecionado
  # com EAP=Stop vira erro fatal, então estas funções usam Continue e checam LASTEXITCODE.
  $ErrorActionPreference = 'Continue'
  Write-Step 'Extensões do editor'
  if ($Editor -eq 'none') { Write-Info '-Editor none: extensões ignoradas'; return }
  $editors = @(Get-Editors)
  if ($editors.Count -eq 0) { Write-Warn 'nenhum editor encontrado (comandos kiro ou code no PATH)'; return }
  foreach ($cli in $editors) {
    $installed = @(& $cli --list-extensions 2>$null | ForEach-Object { $_.ToLower() })
    foreach ($ext in Get-ExtensionList) {
      if ($installed -contains $ext.ToLower()) {
        if ($mode -eq 'doctor') { Write-Ok "${cli}: $ext" }
        continue
      }
      if ($mode -eq 'install') {
        & $cli --install-extension $ext *> $null
        if ($LASTEXITCODE -eq 0) { Write-Ok "${cli}: $ext instalada" } else { Write-Warn "${cli}: não consegui instalar $ext" }
      } else {
        Write-Warn "${cli}: extensão $ext não instalada"
      }
    }
  }
}

function Sync-Repos {
  # Chamadas nativas aqui escrevem no stderr. No Windows PowerShell 5.1, stderr redirecionado
  # com EAP=Stop vira erro fatal, então estas funções usam Continue e checam LASTEXITCODE.
  $ErrorActionPreference = 'Continue'
  Write-Step 'Repositórios (ao lado do boleto-docs)'
  foreach ($r in $Repos) {
    $dir = Join-Path $WorkspaceDir $r
    if (Test-Path (Join-Path $dir '.git')) { Write-Ok $r; continue }
    if ($Clone -and $Command -eq 'install') {
      & git clone -q "git@github.com:$GithubOrg/$r.git" $dir 2>$null
      if ($LASTEXITCODE -ne 0) { & git clone -q "https://github.com/$GithubOrg/$r.git" $dir 2>$null }
      if ($LASTEXITCODE -eq 0) { Write-Ok "$r clonado" } else { Write-Warn "${r}: não consegui clonar (repositório privado exige acesso ao GitHub)" }
    } else {
      Write-Warn "$r não encontrado em $WorkspaceDir (use -Clone)"
    }
  }
}

# --- hook commit-msg (ADR 0043) ----------------------------------------------

$HookMark = '# boleto-hook: commit-msg'

# Diretório de hooks compartilhado (vale para os worktrees do repositório).
function Get-HooksDir([string]$repo) {
  $ErrorActionPreference = 'Continue'
  $d = (& git -C $repo rev-parse --git-common-dir 2>$null)
  if ($LASTEXITCODE -ne 0 -or -not $d) { return $null }
  $d = "$d".Trim()
  if (-not [IO.Path]::IsPathRooted($d)) { $d = Join-Path $repo $d }
  return (Join-Path $d 'hooks')
}

# Pasta do Node do mise. Vazio se ainda não estiver instalado.
function Get-NodeHome($V) {
  $ErrorActionPreference = 'Continue'
  if (-not $script:Mise) { return '' }
  $h = (& $script:Mise where "node@$($V.NODE_VERSION)" 2>$null)
  if ($LASTEXITCODE -eq 0 -and $h -and (Test-Path (Join-Path "$h".Trim() 'node.exe'))) { return "$h".Trim() }
  return ''
}

# O texto do hook: cabeçalho gerado (caminhos com / entre aspas simples) e o corpo versionado, em LF.
function Get-HookText($V) {
  $nodeHome = Get-NodeHome $V
  $node = ''
  if ($nodeHome) { $node = (Join-Path $nodeHome 'node.exe') -replace '\\', '/' }
  $root = $RepoRoot -replace '\\', '/'
  $body = ([IO.File]::ReadAllText((Join-Path $ScriptDir 'hooks\commit-msg.sh'))) -replace "`r", ''
  $head = "#!/bin/sh`n$HookMark v1`n" +
    "# Gerado pelo bootstrap (ADR 0043). Não edite: rode o install para atualizar.`n" +
    "BOLETO_DOCS_DIR='$root'`nBOLETO_NODE='$node'`n`n"
  return $head + $body
}

function Get-CommitlintWanted {
  $m = [regex]::Match([IO.File]::ReadAllText((Join-Path $RepoRoot 'package.json')), '"@commitlint/cli"\s*:\s*"([^"]*)"')
  if ($m.Success) { return $m.Groups[1].Value } else { return '' }
}

function Get-CommitlintHave {
  $p = Join-Path $RepoRoot 'node_modules\@commitlint\cli\package.json'
  if (-not (Test-Path $p)) { return '' }
  $m = [regex]::Match([IO.File]::ReadAllText($p), '"version"\s*:\s*"([^"]*)"')
  if ($m.Success) { return $m.Groups[1].Value } else { return '' }
}

# Instala o commitlint do boleto-docs (versão e hashes do package-lock.json). Só usa rede se faltar.
function Install-CommitlintDeps($V) {
  $ErrorActionPreference = 'Continue'
  $want = Get-CommitlintWanted
  $have = Get-CommitlintHave
  if (-not $want) { Stop-Bootstrap "@commitlint/cli não consta em $(Join-Path $RepoRoot 'package.json')" }
  if ($want -eq $have) { Write-Ok "commitlint $have já instalado (node_modules do boleto-docs)"; return }
  $nodeHome = Get-NodeHome $V
  $npmCli = Join-Path $nodeHome 'node_modules\npm\bin\npm-cli.js'
  if (-not $nodeHome -or -not (Test-Path $npmCli)) { Write-Fail 'commitlint não instalado e não achei o Node do mise. Rode o install de novo'; return }
  Write-Info "instalando o commitlint $want (npm ci, só desta vez)"
  # Roda a partir da pasta do usuário e chama o npm do Node do mise direto, sem depender do PATH.
  Push-Location $env:USERPROFILE
  try {
    & (Join-Path $nodeHome 'node.exe') $npmCli --prefix $RepoRoot ci --ignore-scripts --no-audit --no-fund *> $null
    $code = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  if ($code -eq 0) { Write-Ok "commitlint $(Get-CommitlintHave) instalado (node_modules do boleto-docs)" }
  else { Write-Fail 'npm ci falhou no boleto-docs. Confira a rede e rode o install de novo' }
}

# Grava o hook num repositório temporário e prova que recusa a mensagem inválida e aceita a válida.
function Test-HookSelfTest([string]$text) {
  $ErrorActionPreference = 'Continue'
  $t = Join-Path ([IO.Path]::GetTempPath()) ('boleto-hook-' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $t | Out-Null
  try {
    & git init -q $t *> $null
    $hooks = Join-Path $t '.git\hooks'
    [IO.File]::WriteAllText((Join-Path $hooks 'commit-msg'), $text, (New-Object Text.UTF8Encoding($false)))
    $g = @('-C', $t, '-c', ('core.hooksPath=' + ($hooks -replace '\\', '/')), '-c', 'user.name=hook-test',
      '-c', 'user.email=hook-test@example.invalid', '-c', 'commit.gpgsign=false')
    $bad = $false
    & git @g commit -q --allow-empty -m 'mensagem invalida' *> $null
    if ($LASTEXITCODE -eq 0) { Write-Fail 'hook não recusa mensagem inválida (autoteste)'; $bad = $true }
    & git @g commit -q --allow-empty -m 'chore: teste do hook' *> $null
    if ($LASTEXITCODE -ne 0) { Write-Fail 'hook recusa mensagem válida (autoteste)'; $bad = $true }
    if (-not $bad) { Write-Ok 'autoteste: mensagem inválida recusada, válida aceita' }
  } finally {
    Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# install: grava o hook em cada repositório presente. doctor: só lê e diagnostica.
function Sync-Hooks($mode, $V) {
  $ErrorActionPreference = 'Continue'
  Write-Step 'Hook commit-msg (commitlint)'
  if ($mode -eq 'install') {
    Install-CommitlintDeps $V
  } else {
    $have = Get-CommitlintHave
    if ($have -and $have -eq (Get-CommitlintWanted)) { Write-Ok "commitlint $have (node_modules do boleto-docs)" }
    else { Write-Fail 'commitlint não instalado no boleto-docs. Rode: bootstrap\bootstrap.ps1 install' }
  }
  $text = Get-HookText $V
  if ($RepoRoot.Contains("'") -or $RepoRoot.Contains("`n") -or (Get-NodeHome $V).Contains("'")) {
    Write-Fail 'o caminho do boleto-docs ou do Node tem aspas simples ou quebra de linha. Mude a pasta'
    return
  }
  $enc = New-Object Text.UTF8Encoding($false)
  foreach ($r in $Repos) {
    $dir = Join-Path $WorkspaceDir $r
    if (-not (Test-Path (Join-Path $dir '.git'))) { Write-Warn "${r}: sem hook (repositório ausente)"; continue }
    $hp = (& git -C $dir config --get core.hooksPath 2>$null)
    if ($hp) { Write-Warn "${r}: core.hooksPath=$hp (hook não gravado, o .git/hooks não é usado)"; continue }
    $hdir = Get-HooksDir $dir
    if (-not $hdir) { Write-Fail "${r}: não achei o diretório de hooks do Git"; continue }
    $hook = Join-Path $hdir 'commit-msg'
    $current = $null
    if (Test-Path $hook) { $current = [IO.File]::ReadAllText($hook) }
    if ($null -ne $current -and -not $current.Contains($HookMark)) {
      Write-Warn "${r}: commit-msg de outro autor (não sobrescrito)"; continue
    }
    if ($null -ne $current -and $current -ceq $text) {
      if ($mode -eq 'install') { Write-Ok "${r}: hook já ativo" } else { Write-Ok "${r}: hook ativo" }
    } elseif ($mode -eq 'install') {
      New-Item -ItemType Directory -Force -Path $hdir | Out-Null
      [IO.File]::WriteAllText($hook, $text, $enc)
      Write-Ok "${r}: hook instalado ou atualizado"
    } elseif ($null -ne $current) {
      Write-Warn "${r}: hook desatualizado. Rode: bootstrap\bootstrap.ps1 install"
    } else {
      Write-Fail "${r}: hook não instalado. Rode: bootstrap\bootstrap.ps1 install"
    }
    $cfg = Join-Path $dir 'commitlint.config.mjs'
    if ($mode -eq 'doctor' -and $r -ne 'boleto-docs' -and (Test-Path $cfg)) {
      $a = ([IO.File]::ReadAllText($cfg)) -replace "`r", ''
      $b = ([IO.File]::ReadAllText((Join-Path $RepoRoot 'commitlint.config.mjs'))) -replace "`r", ''
      if ($a -cne $b) { Write-Warn "${r}: commitlint.config.mjs difere do boleto-docs (o hook usa o do boleto-docs, a CI usa o do repositório)" }
    }
  }
  if ($mode -eq 'doctor' -and (Test-Path (Join-Path $RepoRoot 'node_modules\@commitlint\cli\cli.js'))) {
    Test-HookSelfTest $text
  }
}

function Test-Tools($V) {
  # Chamadas nativas aqui escrevem no stderr. No Windows PowerShell 5.1, stderr redirecionado
  # com EAP=Stop vira erro fatal, então estas funções usam Continue e checam LASTEXITCODE.
  $ErrorActionPreference = 'Continue'
  Write-Step 'Ferramentas do desenvolvedor'
  Write-Info "pasta de instalação: $($script:BoletoHome) ($($script:InstallMode))"
  if ($script:CustomDir -and -not $script:SkipPersist) {
    $dirs = Get-MiseDirs $script:BoletoHome
    $wrong = @($MiseDirVars | Where-Object { -not ([Environment]::GetEnvironmentVariable($_, 'User') -ieq $dirs[$_]) })
    if ($wrong.Count -gt 0) {
      Write-Warn "variáveis do usuário não apontam para a pasta escolhida: $($wrong -join ', '). Rode o install de novo"
    }
  }
  Find-Mise
  if (-not $script:Mise) { Write-Fail 'mise não encontrado. Rode: bootstrap\bootstrap.ps1 install'; return }
  $have = Get-MiseVersion
  if ($have -eq $V.MISE_VERSION) { Write-Ok "mise $have" } else { Write-Warn "mise $have (pinada: $($V.MISE_VERSION))" }

  $expectedJavaHome = $null
  $javaHome = (& $script:Mise where "java@corretto-$($V.JAVA_CORRETTO_BUILD)" 2>$null)
  if ($LASTEXITCODE -eq 0 -and $javaHome -and (Test-Path (Join-Path $javaHome.Trim() 'bin\java.exe'))) {
    $expectedJavaHome = $javaHome.Trim()
    Write-Ok "Java Corretto $($V.JAVA_CORRETTO_BUILD) instalado ($expectedJavaHome)"
  } else {
    Write-Fail "Java Corretto $($V.JAVA_CORRETTO_BUILD) não instalado. Rode: bootstrap\bootstrap.ps1 install"
  }
  $nodeHome = (& $script:Mise where "node@$($V.NODE_VERSION)" 2>$null)
  if ($LASTEXITCODE -eq 0 -and $nodeHome -and (Test-Path (Join-Path $nodeHome.Trim() 'node.exe'))) {
    Write-Ok "Node $($V.NODE_VERSION) instalado ($($nodeHome.Trim()))"
  } else {
    Write-Fail "Node $($V.NODE_VERSION) não instalado. Rode: bootstrap\bootstrap.ps1 install"
  }

  # O que este terminal enxerga agora.
  $cmd = Get-Command java -ErrorAction SilentlyContinue
  if ($cmd) {
    $line = (& java -version 2>&1 | Select-Object -First 1).ToString()
    if ($line -match 'version "(\d+)') {
      if ($Matches[1] -eq $V.JAVA_MAJOR) { Write-Ok "java no PATH deste terminal: $line" }
      else { Write-Warn "java no PATH deste terminal é $($Matches[1]), esperado $($V.JAVA_MAJOR). Abra um novo terminal do PowerShell (o perfil ativa o mise). No cmd.exe um Java instalado na máquina continua na frente" }
    }
  } else {
    Write-Warn 'java fora do PATH deste terminal. Abra um novo terminal'
  }
  if (-not ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe')))) {
    Write-Warn 'JAVA_HOME não definido neste terminal'
  } elseif ($expectedJavaHome -and -not (& $SameDir $env:JAVA_HOME $expectedJavaHome)) {
    Write-Warn "JAVA_HOME deste terminal ($($env:JAVA_HOME)) é de outra instalação. Abra um novo terminal"
  } else {
    Write-Ok "JAVA_HOME=$($env:JAVA_HOME)"
  }
  if (Get-Command node -ErrorAction SilentlyContinue) {
    $nv = (& node --version).Trim()
    if ($nv -eq "v$($V.NODE_VERSION)") { Write-Ok "node no PATH deste terminal: $nv" } else { Write-Warn "node no PATH deste terminal é $nv, esperado v$($V.NODE_VERSION)" }
  }
  Write-Info "Gradle $($V.GRADLE_VERSION) vem pelo Gradle Wrapper de cada projeto"
}

function Write-Summary {
  Write-Host ''
  if ($script:Fails -gt 0) {
    Write-Host "Resultado: $($script:Fails) falha(s), $($script:Warns) aviso(s)." -ForegroundColor Red
    exit 1
  }
  if ($script:Warns -gt 0) { Write-Host "Resultado: tudo essencial em ordem, $($script:Warns) aviso(s)." -ForegroundColor Yellow }
  else { Write-Host 'Resultado: tudo em ordem.' -ForegroundColor Green }
}

# --- principal -----------------------------------------------------------------

$script:SkipPersist = [bool]$NoPersist
$V = Read-Versions
Initialize-Dirs

switch ($Command) {
  'install' {
    # O hook grava o caminho deste checkout, então o install não roda a partir de um worktree.
    if (Test-Path -PathType Leaf (Join-Path $RepoRoot '.git')) {
      Stop-Bootstrap "rode o install no checkout principal do boleto-docs, não num worktree ($RepoRoot)"
    }
    Test-Prereqs
    Install-Mise $V
    Install-Tools $V
    Set-UserEnvironment $V
    Sync-EditorExtensions 'install'
    Sync-Repos
    Sync-Hooks 'install' $V
    Write-Step 'Verificação final'
    $script:Fails = 0; $script:Warns = 0
    Test-Prereqs
    Test-Tools $V
    Sync-Hooks 'doctor' $V
    Write-Summary
  }
  'doctor' {
    Test-Prereqs
    Test-Tools $V
    Sync-EditorExtensions 'doctor'
    Sync-Repos
    Sync-Hooks 'doctor' $V
    Write-Summary
  }
}
