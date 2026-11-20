<#
.SYNOPSIS
  Prepara a máquina do desenvolvedor (Windows).

.DESCRIPTION
  install   (padrão) instala o mise, Java e Node nas versões do versions.toml,
            configura o PATH e o JAVA_HOME do usuário e instala as extensões do Kiro e do VS Code.
  doctor    só diagnostica, sem alterar nada. Sai com código 1 se algo essencial faltar.

  Requisito: Docker Desktop (com Compose) e Git já instalados. O resto este script instala.

  A variável de ambiente BOLETO_DEV_HOME instala tudo dentro de uma pasta, isolado
  (útil para testes). Implica -NoPersist.

.PARAMETER Command
  install ou doctor.

.PARAMETER NoPersist
  Não altera o PATH/JAVA_HOME do usuário nem a configuração global do mise.

.PARAMETER Clone
  Clona os repositórios que faltarem ao lado do boleto-docs.

.PARAMETER Editor
  kiro, code ou none. Padrão: todos os que forem encontrados.

.EXAMPLE
  .\bootstrap\bootstrap.ps1 doctor
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('install', 'doctor')]
  [string]$Command = 'install',
  [switch]$NoPersist,
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

function Initialize-Dirs {
  if ($env:BOLETO_DEV_HOME) {
    $script:BoletoHome = $env:BOLETO_DEV_HOME
    $script:SkipPersist = $true
    $env:MISE_DATA_DIR = Join-Path $script:BoletoHome 'mise\data'
    $env:MISE_CONFIG_DIR = Join-Path $script:BoletoHome 'mise\config'
    $env:MISE_CACHE_DIR = Join-Path $script:BoletoHome 'mise\cache'
    $env:MISE_STATE_DIR = Join-Path $script:BoletoHome 'mise\state'
    $script:MiseData = $env:MISE_DATA_DIR
  } else {
    $script:BoletoHome = Join-Path $env:LOCALAPPDATA 'boleto-dev'
    $script:MiseData = Join-Path $env:LOCALAPPDATA 'mise'
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
  Find-Mise
  if ($script:Mise) {
    $have = Get-MiseVersion
    if ($have -eq $V.MISE_VERSION) { Write-Ok "mise $have já instalado ($($script:Mise))" }
    else { Write-Warn "mise $have encontrado em $($script:Mise) (versão pinada: $($V.MISE_VERSION)). Mantendo a existente" }
    return
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
  Invoke-Mise install $java $node
  if (-not $script:SkipPersist) {
    Invoke-Mise use -g $java $node
    Write-Ok 'versões definidas como padrão do usuário (mise use -g)'
  } else {
    Write-Info '-NoPersist: padrão global do mise não alterado'
  }
  Write-Info "Gradle $($V.GRADLE_VERSION) vem pelo Gradle Wrapper de cada projeto"
}

function Add-UserPath($dir) {
  $current = [Environment]::GetEnvironmentVariable('Path', 'User')
  $parts = @()
  if ($current) { $parts = $current -split ';' | Where-Object { $_ -and ($_.TrimEnd('\') -ne $dir.TrimEnd('\')) } }
  [Environment]::SetEnvironmentVariable('Path', ((@($dir) + $parts) -join ';'), 'User')
}

function Set-UserEnvironment($V) {
  Write-Step 'PATH e JAVA_HOME do usuário'
  if ($script:SkipPersist) { Write-Info '-NoPersist: variáveis do usuário não alteradas'; return }
  Add-UserPath $script:Shims
  Add-UserPath $script:BinDir
  $javaHomePath = (& $script:Mise where "java@corretto-$($V.JAVA_CORRETTO_BUILD)").Trim()
  [Environment]::SetEnvironmentVariable('JAVA_HOME', $javaHomePath, 'User')
  Write-Ok "JAVA_HOME=$javaHomePath"
  Write-Ok 'PATH do usuário atualizado (mise e shims)'
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
    "if (Test-Path '$($script:Mise)') { (& '$($script:Mise)' activate pwsh) | Out-String | Invoke-Expression }",
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

function Test-Tools($V) {
  # Chamadas nativas aqui escrevem no stderr. No Windows PowerShell 5.1, stderr redirecionado
  # com EAP=Stop vira erro fatal, então estas funções usam Continue e checam LASTEXITCODE.
  $ErrorActionPreference = 'Continue'
  Write-Step 'Ferramentas do desenvolvedor'
  Find-Mise
  if (-not $script:Mise) { Write-Fail 'mise não encontrado. Rode: bootstrap\bootstrap.ps1 install'; return }
  $have = Get-MiseVersion
  if ($have -eq $V.MISE_VERSION) { Write-Ok "mise $have" } else { Write-Warn "mise $have (pinada: $($V.MISE_VERSION))" }

  $javaHome = (& $script:Mise where "java@corretto-$($V.JAVA_CORRETTO_BUILD)" 2>$null)
  if ($LASTEXITCODE -eq 0 -and $javaHome -and (Test-Path (Join-Path $javaHome.Trim() 'bin\java.exe'))) {
    Write-Ok "Java Corretto $($V.JAVA_CORRETTO_BUILD) instalado ($($javaHome.Trim()))"
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
  if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) { Write-Ok "JAVA_HOME=$($env:JAVA_HOME)" } else { Write-Warn 'JAVA_HOME não definido neste terminal' }
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
    Test-Prereqs
    Install-Mise $V
    Install-Tools $V
    Set-UserEnvironment $V
    Sync-EditorExtensions 'install'
    Sync-Repos
    Write-Step 'Verificação final'
    $script:Fails = 0; $script:Warns = 0
    Test-Prereqs
    Test-Tools $V
    Write-Summary
  }
  'doctor' {
    Test-Prereqs
    Test-Tools $V
    Sync-EditorExtensions 'doctor'
    Sync-Repos
    Write-Summary
  }
}
