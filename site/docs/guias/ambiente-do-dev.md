---
sidebar_position: 0
title: Ambiente do desenvolvedor
---

# Ambiente do desenvolvedor

O requisito mínimo na máquina é **Docker com Compose** e **Git**. Um script instala o resto, nas versões exatas do [`versions.toml`](./versoes.md).

| O que | Versão | Quem instala |
|---|---|---|
| Docker e Docker Compose | atual | você (o script só verifica) |
| Git | atual | você (o script só verifica) |
| [mise](https://mise.jdx.dev) | pinada | o script, com checagem de sha256 |
| Java (Amazon Corretto 25) | pinada | o mise |
| Node | pinada | o mise |
| Gradle | pinada | o Gradle Wrapper de cada projeto (`./gradlew` no Linux e macOS, `.\gradlew.bat` no Windows; o `boleto-backend` já o traz) |
| Extensões do Kiro e do VS Code | lista em `bootstrap/extensions.txt` | o script |

O mise instala as ferramentas em uma pasta do seu usuário e não mexe no Java ou no Node que já existem na máquina.

**Nenhum passo exige administrador.** Tudo vai para pastas e variáveis do seu usuário (no Windows, as variáveis de usuário, não as da máquina). A única exceção é a `libatomic` no Linux, que o script só verifica.

## Instalando

Na raiz do `boleto-docs`:

```powershell
# Windows (PowerShell)
.\bootstrap\bootstrap.ps1
```

```bash
# Linux e macOS
bootstrap/bootstrap.sh
```

O comando `install` (padrão) faz, em ordem:

1. Verifica Git, Docker, Compose e o daemon do Docker.
2. Baixa o mise na versão pinada e confere o sha256. Se o checksum não bater, o download é descartado.
3. Instala o Java e o Node pelo mise e os define como padrão do usuário.
4. Configura o ambiente:
   - **Windows:** `JAVA_HOME` e `PATH` do usuário, e a ativação do mise no perfil do PowerShell.
   - **Linux e macOS:** um bloco no `.bashrc`, `.profile` (e `.zshrc`) com o `PATH` e o `JAVA_HOME`.
5. Instala as extensões no Kiro e no VS Code que forem encontrados (comandos `kiro` e `code` no PATH).
6. Instala o commitlint do `boleto-docs` (uma vez) e grava o [hook `commit-msg`](#hook-de-commit-commitlint) nos repositórios presentes.
7. Diagnostica o resultado.

O script é idempotente: rodar de novo não reinstala nem duplica configuração.

Depois de instalar, **abra um novo terminal** e reinicie o Kiro ou o VS Code, para eles lerem o `JAVA_HOME` e o `PATH` novos.

Próximo passo: subir a aplicação inteira (infraestrutura, migração e backend) com `docker compose up -d` na raiz do `boleto-docs` (veja [Compose de desenvolvimento](./compose-dev.md)). O comando precisa do `boleto-backend` e do `boleto-migrations` ao lado do `boleto-docs` (`-Clone` ou `--clone` os clona). Sem eles, o Compose para com `unable to prepare context: path ... not found`; para subir só a infraestrutura, use `docker compose up -d --wait postgres valkey mailpit`.

O `docker compose up -d` cria o administrador de desenvolvimento (`admin@boleto.test`, senha padrão no `docker-compose.yml`) e liga a chave JWT efêmera; para trocar, use o `.env` (modelo em `.env.example`). Os testes do backend também sobem um Valkey por Testcontainers.

Para trabalhar no código do `boleto-backend`, rode `mise install` na pasta dele (Java 25 e Node nas versões do `mise.toml`) e `.\gradlew.bat test` ou `./gradlew test`, com o Docker ativo e o `boleto-migrations` clonado ao lado do `boleto-backend`. Os testes constroem a imagem de migração (`docker build -t boleto-migrations:teste ../boleto-migrations`), sobem um PostgreSQL por Testcontainers, aplicam o schema real e conectam como `boleto_app` ([ADR 0036](../adr/0036-schema-real-nos-testes-do-backend.md)). Se o `boleto-migrations` estiver em outra pasta (por exemplo, em um worktree), defina `MIGRATIONS_CONTEXT`; com uma imagem já construída, defina `MIGRATIONS_IMAGE` e o build é pulado. Sem `Dockerfile` na pasta, a tarefa `construirImagemMigracoes` aborta e nomeia a pasta. O Gradle não baixa JDK sozinho, ele usa o Java do mise.

```powershell
$env:MIGRATIONS_CONTEXT = 'C:\caminho\para\boleto-migrations'; .\gradlew.bat test
```

```bash
MIGRATIONS_CONTEXT=/caminho/para/boleto-migrations ./gradlew test
```

### Opções

| Opção (PowerShell / Bash) | Efeito |
|---|---|
| `-InstallDir <pasta>` / `--install-dir <pasta>` | Instala tudo nessa pasta e aponta o ambiente para ela (veja abaixo) |
| `-NoPersist` / `--no-persist` | Não altera variáveis do usuário, arquivos do shell nem o padrão global do mise |
| `-Clone` / `--clone` | Clona os repositórios que faltarem ao lado do `boleto-docs` (exige acesso ao GitHub) |
| `-Editor kiro\|code\|none` / `--editor ...` | Escolhe o editor das extensões (padrão: os que forem encontrados) |

## Escolhendo a pasta de instalação

Por padrão as ferramentas ficam em `%LOCALAPPDATA%` (Windows) ou em `~/.boleto-dev` e `~/.local/share/mise` (Linux e macOS). Para concentrar tudo em uma pasta sua:

```powershell
.\bootstrap\bootstrap.ps1 install -InstallDir C:\dev\tools
```

```bash
bootstrap/bootstrap.sh install --install-dir ~/dev/tools
```

O que fica na pasta:

```text
C:\dev\tools
├── bin\           mise
└── mise\
    ├── data\      Java, Node e shims
    ├── config\    versões padrão do usuário
    ├── cache\
    └── state\
```

O script aponta o ambiente para a pasta:

- **Windows:** grava, nas variáveis do seu usuário, `BOLETO_INSTALL_DIR`, `MISE_DATA_DIR`, `MISE_CONFIG_DIR`, `MISE_CACHE_DIR` e `MISE_STATE_DIR`, além do `JAVA_HOME` e do `PATH`. O perfil do PowerShell chama o mise dessa pasta.
- **Linux e macOS:** o bloco do `.bashrc`, `.profile`, `.bash_profile` e `.zshrc` exporta as mesmas variáveis.

Regras:

- A pasta precisa ser um caminho absoluto em que você tenha permissão de escrita. Pastas como `C:\Program Files` ou `/opt` são recusadas com uma mensagem, sem pedir elevação.
- A escolha fica gravada. Nas próximas execuções, `install` e `doctor` sem a opção continuam usando a mesma pasta.
- Para trocar, rode o `install` com outra pasta. O script instala tudo na nova e tira do `PATH` as entradas da anterior. Os arquivos da pasta antiga não são apagados. Remova a pasta quando quiser.
- Apagar a pasta desfaz a instalação das ferramentas. As variáveis do usuário (ou o bloco do shell) continuam lá até você rodar o `install` de novo.
- `BOLETO_DEV_HOME` (modo isolado de testes) não pode ser combinado com `-InstallDir`.

## Hook de commit (commitlint)

O `install` grava um hook Git `commit-msg` em cada repositório que estiver ao lado do `boleto-docs` (`boleto-docs`, `boleto-backend`, `boleto-migrations` e `boleto-frontend`). No `git commit`, o hook roda o commitlint e recusa a mensagem que não seguir o [Conventional Commits](./commits-e-releases.md) ou que tiver linha com mais de 100 colunas. A decisão está no [ADR 0043](../adr/0043-hook-commit-msg.md).

- **Worktrees.** O hook fica no diretório de hooks comum do repositório (`.git/hooks`), então vale também em `<repo>/.worktrees/<nome>`, sem passo extra.
- **Sem rede.** O `install` instala o commitlint do `boleto-docs` uma vez (`npm ci --ignore-scripts`, versão e hashes do `package-lock.json`). Depois disso o hook não usa rede. Ele usa o Node do mise (caminho gravado no hook) e, se esse arquivo sumir, o `node` do PATH.
- **Windows.** O Git executa o hook pelo `sh` do Git for Windows. Não é preciso instalar mais nada.
- **Falha fechada.** Se faltar o Node, o commitlint ou a configuração, o commit é recusado com a mensagem `rode ... install`. Rode o `install` no checkout principal do `boleto-docs` e tente de novo.
- **Reaplicar.** O `install` é idempotente e regrava o hook quando ele estiver ausente ou desatualizado. Rode-o de novo ao clonar um repositório novo ou ao mudar a pasta do `boleto-docs`. O `install` não roda a partir de um worktree do `boleto-docs`.
- **Respeito ao que já existe.** O `install` não grava o hook se o repositório tiver `core.hooksPath` (o `.git/hooks` não seria usado) e não sobrescreve um `commit-msg` que não seja o do bootstrap. Nos dois casos mostra um aviso.
- **Estado.** O `doctor` mostra o hook de cada repositório e faz um autoteste num repositório temporário: a mensagem inválida precisa ser recusada e a válida aceita.
- **Pular o hook.** `git commit --no-verify` (ou `-n`) pula o `commit-msg`. O `doctor` não detecta isso. A barreira seguinte é o job `Conventional Commits` da CI, que reprova o PR com mensagem fora do padrão.

Verificação rápida de uma série de commits, como a CI faz: `npx commitlint --from origin/main --to HEAD`.
## Diagnóstico: `doctor`

```powershell
.\bootstrap\bootstrap.ps1 doctor
```

```bash
bootstrap/bootstrap.sh doctor
```

O `doctor` não altera nada. Mostra `[ OK ]`, `[WARN]` ou `[FAIL]` para cada item e termina com código 1 se algo essencial faltar (falha). Avisos não derrubam o resultado.

| Item | Falha se | Aviso se |
|---|---|---|
| Git, Docker, Compose, daemon | ausente ou parado | |
| libatomic (só Linux) | ausente | |
| mise | ausente | versão diferente da pinada |
| Java e Node pinados | não instalados | |
| `java`, `JAVA_HOME` e `node` do terminal atual | | apontam para outra versão ou outra pasta de instalação |
| Variáveis do usuário (com `-InstallDir`, Windows) | | não apontam para a pasta escolhida |
| Extensões do editor | | ausentes |
| Repositórios ao lado do `boleto-docs` | | ausentes |
| commitlint no `node_modules` do `boleto-docs` | ausente ou em versão diferente do `package.json` | |
| Hook `commit-msg` de cada repositório presente | não instalado | desatualizado, `core.hooksPath` definido ou `commit-msg` de outro autor |
| Hook de um repositório ausente | | ausente |
| `commitlint.config.mjs` dos outros repositórios | | difere do `boleto-docs` |
| Autoteste do hook (repositório temporário) | recusa mensagem válida ou aceita inválida | |

## Pontos de atenção

- **Windows, PATH da máquina:** o Windows coloca o PATH da máquina antes do PATH do usuário. Um Java ou Node instalado para todos os usuários (por exemplo `C:\Program Files\nodejs`) ganharia do mise. Por isso o script ativa o mise no perfil do PowerShell, e nos terminais do PowerShell (inclusive os do Kiro e do VS Code) as versões certas valem. No `cmd.exe` continua valendo o da máquina. O `JAVA_HOME` do usuário vale para Gradle e para os IDEs de qualquer forma.
- **Windows, política de execução:** o perfil só carrega se a política permitir scripts. Se precisar: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
- **Linux:** o Node precisa da biblioteca `libatomic`. Instalar exige root, então o script só avisa: `sudo dnf install libatomic` ou `sudo apt-get install libatomic1`.
- **Pelo projeto:** os repositórios de aplicação ganham um `mise.toml` com as versões que usam (gerado pela [sincronização](./versoes.md)). Com o mise ativado, entrar na pasta já seleciona o Java ou o Node certos.
- **Isolar para testar:** `BOLETO_DEV_HOME=/tmp/dev` (ou `$env:BOLETO_DEV_HOME`) instala tudo nessa pasta e não altera nada do usuário.
- **Atualizar versões:** o script lê `.platform/versions.env`, gerado pelo `npm run sync`. Para mudar uma versão, altere o `versions.toml`, rode a sincronização e o `install` de novo.

## Como o script é testado

A CI roda, no Ubuntu (com ShellCheck) e no Windows PowerShell 5.1:

- `install` e `doctor` em pasta isolada;
- `install` no local padrão e com pasta escolhida, gravando no ambiente do usuário (o runner é descartável), e a conferência em um terminal novo;
- no Windows, a troca de pasta, conferindo que o `PATH` não guarda entradas da anterior nem duplicadas;
- no Windows, os testes da lógica de `PATH` (`bootstrap/tests/path.tests.ps1`) no PowerShell 7 e no 5.1;
- o hook `commit-msg`: ShellCheck de `bootstrap/hooks/commit-msg.sh` (`--shell=sh`), de `bootstrap/bootstrap.sh` e de `bootstrap/tests/hook.tests.sh`, e a sintaxe dos três scripts PowerShell. A CI cria repositórios de teste ao lado do checkout (`boleto-backend` com um commit e `boleto-frontend` vazio), roda o `install` e então `bootstrap/tests/hook.tests.sh` (Ubuntu) e `bootstrap/tests/hook.tests.ps1` (PowerShell 7 e 5.1, no Windows). Os cenários: mensagem inválida recusada, linha de corpo de 101 colunas recusada e de 100 aceita, repositório vazio, worktree, `install` repetido sem mudar o hook, `commit-msg` alheio, `core.hooksPath`, hook removido (o `doctor` sai com 1 e o `install` restaura), Node gravado inexistente e `--no-verify`. O autoteste do `doctor` também roda nos passos `install` e `doctor` e cobre o `sh` do Git for Windows no runner.

Na criação, o fluxo Linux também foi testado em um Amazon Linux 2023 limpo, com usuário comum sem `sudo`.
