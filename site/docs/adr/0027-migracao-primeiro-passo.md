---
title: 'ADR 0027: A migração é o primeiro passo do deploy'
---

# ADR 0027: A migração é o primeiro passo do deploy

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

O banco precisa estar no schema esperado antes de o backend subir, e o frontend só faz sentido com um backend saudável. O desenvolvedor pediu que o Flyway seja o primeiro passo da pipeline: roda, valida as migrações, aplica as pendentes e, só se der certo, o backend e depois o frontend são publicados. Em produção (AWS, fora desta fase) a migração roda dentro da VPC. Em desenvolvimento, o desenvolvedor usa só comandos padrão do Docker Compose ([ADR 0022](./0022-compose-unico.md)).

## Decisão

- **Contrato da imagem:** a imagem do `boleto-migrations` roda uma vez e sai. Ela executa `migrate` (que valida checksums e pendências antes de aplicar) e depois `validate`. Qualquer erro termina com código diferente de zero: migração com SQL inválido, migração aplicada e depois alterada, banco inacessível, senha errada, pendência não aplicada.
- **Configuração por ambiente:** a conexão vem de variáveis de ambiente nativas do Flyway (`FLYWAY_URL`, `FLYWAY_USER`, `FLYWAY_PASSWORD`). Os placeholders vêm de `FLYWAY_PLACEHOLDERS_*`. A pasta das migrações é `FLYWAY_LOCATIONS` (padrão `filesystem:/flyway/sql`). Nenhum segredo fica na imagem.
- **`clean` desligado:** `cleanDisabled=true`. A imagem nunca apaga o banco.
- **Pipeline de produção (Task 14):** migração, depois build e deploy do backend, depois do frontend, encadeados com `needs`. Se a migração falhar, nada mais é publicado. Na AWS, a migração roda como tarefa do ECS Fargate (ou Lambda) na VPC. Nada de AWS agora.
- **Desenvolvimento:** o serviço `flyway` do `docker-compose.yml` fica no profile `migrations`, com `restart: "no"`. `docker compose up -d --wait`, `down` e `down -v` continuam subindo e apagando só a infraestrutura. A migração é um comando à parte: `docker compose up --build --exit-code-from flyway flyway`, que sobe o PostgreSQL saudável antes e termina com o código do Flyway. O Compose espera o `boleto-migrations` na pasta vizinha (`../boleto-migrations`).
- **Regra expand/contract:** cada migração precisa ser compatível com a versão anterior do backend, porque durante o deploy o backend antigo ainda roda sobre o schema novo. Acrescentar é permitido (tabela, coluna anulável ou com valor padrão, índice). Remover ou renomear coluna, ou tornar uma coluna `NOT NULL` sem valor padrão, é feito em duas migrações separadas por um deploy do backend: primeiro o backend deixa de usar a coluna (expand), depois uma migração a remove (contract). A regra está no [padrão do projeto](../guias/padrao-do-projeto.md) e o lint de SQL ([ADR 0028](./0028-lint-sql-e-testes.md)) bloqueia o que a quebra.

## Consequências

- Uma migração com problema impede o deploy inteiro. É o objetivo.
- Reverter o backend para a versão anterior continua possível, porque o schema é compatível com ela.
- O dev precisa lembrar de rodar a migração depois de subir a infraestrutura. O guia de migrações traz o comando, e o `flyway` não roda sozinho para não quebrar os comandos padrão.
- Remover uma coluna custa duas migrações e dois deploys.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Flyway dentro do backend (Spring Boot, na subida) | O backend passaria a ter DDL e o deploy não teria um marco separado de migração. Várias instâncias subindo juntas disputariam a migração |
| Serviço `flyway` sem profile | `docker compose up -d --wait` o executaria e o `down -v` passaria a depender dele. Quebra o uso dos comandos padrão |
| Migração manual pelo desenvolvedor, fora do Compose | Fácil de esquecer e impossível de reproduzir na CI e em produção |
