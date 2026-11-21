---
title: 'ADR 0021: Cache das imagens Docker na CI'
---
# ADR 0021: Cache das imagens Docker na CI

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

No commit `6650ff5` da `main`, o job `Compose de desenvolvimento (Linux)` falhou na primeira tentativa, no passo de pull das imagens. O log mostra `error from registry: Data limit exceeded` no pull do PostgreSQL (`public.ecr.aws`), nas três tentativas do passo, em cerca de 65 segundos. A reexecução passou. A causa é o limite de transferência para pulls anônimos do registro, que os runners compartilhados do GitHub consomem. Não foi o Docker Hub, como se supôs de início. O Valkey e o Mailpit (`docker.io`) continuam sujeitos ao limite anônimo do Docker Hub ([ADR 0006](./0006-valkey.md)).

## Decisão

- O job `Compose de desenvolvimento (Linux)` guarda as imagens no cache do GitHub Actions (`actions/cache`, fixada por SHA).
- **O que é salvo:** o resultado de `docker save` das imagens listadas por `docker compose config --images` (hoje PostgreSQL, Valkey e Mailpit, cerca de 196 MB sem compressão), em um único arquivo `.tar`.
- **Chave:** `imagens-compose-v1-<SO>-<arquitetura>-<sha256 da lista de imagens>`. A lista tem tag e digest, vindos do `.platform/versions.env`. Trocar um digest no `versions.toml` (e sincronizar) muda a lista, muda a chave e o cache antigo deixa de valer. Mudar uma versão que o compose não usa (por exemplo, Corretto) não invalida nada. O `v1` serve para invalidar o cache à mão.
- **Passo a passo:** restaura o cache. Com acerto (`CACHE HIT`), faz `docker load`, confere cada imagem com `docker image inspect` e não faz pull. Com falha (`CACHE MISS`), faz o pull (até 3 tentativas, com espera de 30, 60 e 90 segundos), salva o `.tar` e grava o cache logo em seguida, antes dos testes. Assim uma falha de teste não perde o cache. O log imprime `CACHE HIT` ou `CACHE MISS` e a chave.
- **Alcance:** só o job `Compose de desenvolvimento (Linux)` baixa imagens de contêiner. Os outros jobs (`Bootstrap`, `Compose (Windows PowerShell 5.1)`, `Validar versions.toml`, `Conventional Commits`) e o `docs.yml` não fazem pull, então não usam este cache. Quem passar a baixar imagens (por exemplo, a CI do `boleto-migrations` com PostgreSQL) deve reaproveitar este padrão.
- **Escopo do cache:** um PR lê o cache da própria branch e o da `main`. A `main` não lê o de um PR. Por isso o cache fica quente depois do primeiro push na `main` com aquela lista de imagens, e o primeiro PR que troca um digest paga um pull.
- **Limites:** o GitHub guarda até 10 GB por repositório e remove caches sem acesso há 7 dias. Três imagens ocupam cerca de 0,2 GB, longe do limite. Se a `main` ficar mais de 7 dias sem CI, o próximo run é um `CACHE MISS`.
- **Sem cache e com registro recusando:** o passo faz até 3 tentativas e falha se todas falharem, como antes. Esse caso continua possível quando o cache não existe (primeira execução, troca de digest, expiração em 7 dias). Nesse caso, reexecute o job. O cache deixa o caso raro, não o elimina.
- **Imagens continuam por digest.** O cache não muda o que é executado: o `docker load` traz o conteúdo salvo de um pull anterior pelo mesmo digest, e o passo confere que as referências com digest existem antes de seguir.

## Consequências

- O job deixa de depender do registro na maior parte das execuções e fica mais rápido.
- O cache usa a cota de armazenamento do GitHub (gratuita, dentro do limite de 10 GB). Sem custo.
- O profile `observability` (Task 11, Grafana LGTM, imagem de mais de 1 GB) aumentará o cache. O tamanho deve ser reavaliado nessa tarefa.
- **Descoberto na prova do cache (PR #5):** depois do `docker load` o Docker no runner Linux conhece as imagens pelo ID (igual ao digest), mas não pelo nome `repo:tag@digest`. Por isso o `compose up` do `dev up` ainda imprime `Pulling` e `Pulled` para as três imagens, em cerca de 0,5 s e sem baixar camadas. Isso é uma consulta ao registro para resolver o digest, não o download das imagens. O cache elimina a transferência de dados (a causa do `Data limit exceeded`), mas não zera as consultas ao Docker Hub. A conferência do passo de carga usa o ID por esse motivo.
- O cache não protege o desenvolvedor local, que continua sujeito aos limites anônimos (ver o guia de [Compose de desenvolvimento](../guias/compose-dev.md)).

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| `docker login` no Docker Hub com conta gratuita | Exige criar a conta e guardar um segredo no repositório. Só cobre o Docker Hub, e a falha observada foi no `public.ecr.aws`. Fica como opção se o cache não bastar |
| Autenticar no Amazon ECR Public | Exige conta AWS, fora do escopo de custo zero desta fase |
| Mais tentativas e esperas maiores | Reduz a falha, mas continua dependendo do registro e deixa o job lento |
| Espelho próprio das imagens no GHCR | Exige um fluxo de publicação e manutenção só para isso. Reavaliar no Task 14 |
| Cache de `/var/lib/docker` | Exige `sudo`, o que o padrão do projeto evita, e é frágil entre versões do Docker |
