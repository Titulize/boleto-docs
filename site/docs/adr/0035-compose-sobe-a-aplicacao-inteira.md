---
title: 'ADR 0035: O Compose sobe a aplicação inteira no `up` padrão'
---

# ADR 0035: O Compose sobe a aplicação inteira no `up` padrão

- **Status:** Aceito
- **Data:** 2026-11-22
- **Substitui em parte:** [ADR 0022](./0022-compose-unico.md), [ADR 0027](./0027-migracao-primeiro-passo.md) e [ADR 0034](./0034-servico-backend-no-compose.md)

## Contexto

O [ADR 0022](./0022-compose-unico.md) deixou `docker compose up -d --wait` subir só a infraestrutura. O [ADR 0027](./0027-migracao-primeiro-passo.md) pôs o `flyway` no profile `migrations` e o [ADR 0034](./0034-servico-backend-no-compose.md) pôs o `backend` no profile `backend`. Para subir a aplicação, o desenvolvedor precisava de `docker compose --profile backend up -d --build --wait`, e `docker compose down` sem o profile deixava o backend rodando. O desenvolvedor pediu que o `docker compose up` comum suba tudo já configurado.

## Decisão

- **Sem profile para `flyway` e `backend`.** Eles sobem no `docker compose up -d` padrão, e `docker compose down` e `down -v` derrubam tudo. Só o `docs` continua no profile `docs`.
- **Comandos do dia a dia:**
  - `docker compose up -d` sobe infraestrutura, migração e backend, e constrói as imagens no primeiro uso.
  - `docker compose up -d --build` reconstrói depois de mudar código do backend ou das migrações.
  - `docker compose down` derruba tudo e mantém os dados.
  - `docker compose down -v` derruba tudo e apaga os dados.
- **`--build` continua manual.** O `up` não força a reconstrução: ela custa minutos (Gradle) e a maioria dos `up` não muda código. O custo é o dev esquecer o `--build` depois de mudar código. O guia traz esse caso em "Problemas conhecidos".
- **CI do `boleto-docs` nomeia os serviços.** Sem acesso aos repositórios privados `boleto-backend` e `boleto-migrations`, o job `Compose de desenvolvimento (Linux)` roda `docker compose up -d --wait postgres valkey mailpit`, e usa `config --images` e `pull` com os mesmos três nomes. A lista de imagens fica idêntica à de antes, então a chave do cache ([ADR 0021](./0021-cache-imagens-ci.md)) não muda e o cache continua dando hit. `docker compose config -q` não valida a pasta de contexto de build e continua passando na CI.
- **Sem os repositórios ao lado, erro do próprio Compose.** `up -d` falha com `unable to prepare context: path "<caminho>" not found`, que já nomeia a pasta que falta. O guia, o README e o comentário do `docker-compose.yml` explicam a causa e as saídas (clonar o repositório ao lado, apontar `BACKEND_CONTEXT` e `MIGRATIONS_CONTEXT`, ou subir só a infraestrutura).

### Pontos em aberto, e a escolha

1. **`up -d --wait` continua recomendado?** Passa a ser opcional. O `up -d` do guia devolve o terminal assim que os containers iniciam, e o backend leva cerca de 20 s (até 60 s) para ficar saudável. `up -d --wait` continua válido e é o indicado em scripts e na CI: ele espera os healthchecks e aceita o `flyway` que termina com código 0 (medido nesta mudança: saiu 0 em 23 s com `flyway` em `Exited (0)` e o backend `healthy`). O padrão para o dia a dia é o `up -d` que o desenvolvedor pediu.
2. **Mensagem melhor quando faltam os repositórios?** Não. Qualquer aviso prévio exigiria um script de verificação, o que contraria o [ADR 0022](./0022-compose-unico.md) (só comandos padrão). O erro do Compose já traz o caminho que falta. `${BACKEND_CONTEXT:?mensagem}` só pega variável vazia, não pasta ausente. A mensagem é documentada. Com a imagem local já construída, o `up -d` (sem `--build`) não precisa da pasta.
3. **Só a migração, só a infraestrutura.** Os dois continuam documentados, com comandos padrão: `docker compose run --build --rm flyway` (só a migração, sobe o PostgreSQL se preciso, sai com o código do Flyway; não use `up --exit-code-from`, que para o PostgreSQL) e `docker compose up -d --wait postgres valkey mailpit` (só a infraestrutura, o que a CI usa).

## Consequências

- Um comando sobe e outro derruba a aplicação inteira, sem profile e sem `--wait`.
- O `up` padrão exige `../boleto-backend` e `../boleto-migrations` (ou `BACKEND_CONTEXT` e `MIGRATIONS_CONTEXT`) e o primeiro `up` constrói duas imagens. Quem só quer a infraestrutura nomeia os serviços.
- O `flyway` roda a cada `up`. A migração é idempotente ([ADR 0027](./0027-migracao-primeiro-passo.md)). O `down -v` apaga o banco e o `up` seguinte o recria.
- O que permanece do ADR 0022: Compose único, `name: boleto-dev`, imagens no bloco gerado, `docs` em profile (com `docker compose --profile docs down` para pará-lo) e o `observability` do Task 11. O que permanece do ADR 0027: migração como passo anterior ao backend, `restart: 'no'` e `run --rm`. O que permanece do ADR 0034: build por `BACKEND_CONTEXT`, `depends_on`, porta e healthcheck.
- `scripts/compose.test.mjs` passa a exigir o `up` padrão com `postgres`, `valkey`, `mailpit`, `flyway` e `backend` (sem `profiles`), o `docs` no profile `docs`, e que a CI nomeie só a infraestrutura.
- O ambiente `boleto-dev` existente continua com os mesmos volumes. O próximo `docker compose up -d` nele passa a criar o `flyway` e o `backend`.

## Demonstração

Projeto `boleto-t35`, portas `25435`, `26381`, `21027`, `28027` e `18081` (sem tocar o `boleto-dev`), com `BACKEND_CONTEXT` e `MIGRATIONS_CONTEXT` apontando para os repositórios:

| Passo | Resultado |
|---|---|
| `docker compose -p boleto-t35 up -d` (sem profile) | subiu `postgres`, `valkey`, `mailpit`, `flyway` (`Exited (0)`) e `backend`; `http://localhost:18081/actuator/health` respondeu `UP` com `db` `UP` |
| `docker compose -p boleto-t35 up -d --wait` | saiu 0 em 23 s, com o `flyway` em `Exited (0)` e o backend `healthy` |
| `docker compose -p boleto-t35 down` | removeu os cinco containers e manteve os volumes `boleto-t35_postgres_data` e `boleto-t35_valkey_data` |
| `docker compose -p boleto-t35 down -v` | removeu os volumes |
| `docker compose build flyway` sem `MIGRATIONS_CONTEXT` (em worktree) | `unable to prepare context: path "...\boleto-migrations" not found` |

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Manter os profiles `migrations` e `backend` | É o que o desenvolvedor pediu para sair: `up` e `down` não cobriam a aplicação |
| Forçar a reconstrução a cada `up` (`pull_policy: build` ou `up --build` fixo) | Decisão do desenvolvedor: `--build` fica manual |
| Script que checa as pastas antes do `up` | Contraria o ADR 0022 (só comandos padrão) |
| A CI do `boleto-docs` subir tudo | Os repositórios `boleto-backend` e `boleto-migrations` são privados e o `boleto-docs` é público: o job não tem acesso |
| Tornar `--wait` obrigatório | O `up -d` simples já basta no dia a dia, e o `--wait` bloqueia o terminal até 60 s |
