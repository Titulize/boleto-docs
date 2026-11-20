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
| Gradle | pinada | o Gradle Wrapper de cada projeto |
| Extensões do Kiro e do VS Code | lista em `bootstrap/extensions.txt` | o script |

O mise instala as ferramentas em uma pasta do seu usuário, sem precisar de administrador, e não mexe no Java ou no Node que já existem na máquina.

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
6. Diagnostica o resultado.

O script é idempotente: rodar de novo não reinstala nem duplica configuração.

Depois de instalar, **abra um novo terminal** e reinicie o Kiro ou o VS Code, para eles lerem o `JAVA_HOME` e o `PATH` novos.

### Opções

| Opção (PowerShell / Bash) | Efeito |
|---|---|
| `-NoPersist` / `--no-persist` | Não altera variáveis do usuário, arquivos do shell nem o padrão global do mise |
| `-Clone` / `--clone` | Clona os repositórios que faltarem ao lado do `boleto-docs` (exige acesso ao GitHub) |
| `-Editor kiro\|code\|none` / `--editor ...` | Escolhe o editor das extensões (padrão: os que forem encontrados) |

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
| `java`, `JAVA_HOME` e `node` do terminal atual | | apontam para outra versão |
| Extensões do editor | | ausentes |
| Repositórios ao lado do `boleto-docs` | | ausentes |

## Pontos de atenção

- **Windows, PATH da máquina:** o Windows coloca o PATH da máquina antes do PATH do usuário. Um Java ou Node instalado para todos os usuários (por exemplo `C:\Program Files\nodejs`) ganharia do mise. Por isso o script ativa o mise no perfil do PowerShell, e nos terminais do PowerShell (inclusive os do Kiro e do VS Code) as versões certas valem. No `cmd.exe` continua valendo o da máquina. O `JAVA_HOME` do usuário vale para Gradle e para os IDEs de qualquer forma.
- **Windows, política de execução:** o perfil só carrega se a política permitir scripts. Se precisar: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
- **Linux:** o Node precisa da biblioteca `libatomic`. Instalar exige root, então o script só avisa: `sudo dnf install libatomic` ou `sudo apt-get install libatomic1`.
- **Pelo projeto:** os repositórios de aplicação ganham um `mise.toml` com as versões que usam (gerado pela [sincronização](./versoes.md)). Com o mise ativado, entrar na pasta já seleciona o Java ou o Node certos.
- **Isolar para testar:** `BOLETO_DEV_HOME=/tmp/dev` (ou `$env:BOLETO_DEV_HOME`) instala tudo nessa pasta e não altera nada do usuário.
- **Atualizar versões:** o script lê `.platform/versions.env`, gerado pelo `npm run sync`. Para mudar uma versão, altere o `versions.toml`, rode a sincronização e o `install` de novo.

## Como o script é testado

A CI roda o `install` e o `doctor` em pasta isolada no Ubuntu (com ShellCheck) e no Windows PowerShell 5.1. Na criação, o fluxo Linux também foi testado em um Amazon Linux 2023 limpo.
