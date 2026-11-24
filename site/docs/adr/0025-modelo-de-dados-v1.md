---
title: 'ADR 0025: Modelo de dados da V1'
---

# ADR 0025: Modelo de dados da V1

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

A primeira migração (`V1`) do `boleto-migrations` cria a base de identidade e segurança sobre a qual o backend (Task 8 em diante) mapeia as entidades. Ela precisa atender o [ADR 0007](./0007-auditoria-envers.md) (auditoria com usuário, tenant, data e hora), o [ADR 0008](./0008-multitenancy.md) (`tenant_id` e RLS) e o [ADR 0012](./0012-autenticacao.md) (convite por e-mail, token de 256 bits guardado só como hash, "esqueci minha senha" pelo mesmo mecanismo). O admin da plataforma (a empresa Titulize) precisa assumir uma empresa gestora pela barra superior, então o banco distingue o tenant de origem (da Titulize) do tenant efetivo (da empresa escolhida).

## Decisão

- **Schema e chaves:** tudo no schema `boleto`. Ids são UUID gerados por `uuidv7()`. Toda tabela tem `criado_em`, `atualizado_em` e `versao` (bloqueio otimista do Hibernate).
- **`tenant_id` em toda tabela de negócio**, com chave estrangeira para `empresa_gestora`. As tabelas têm `unique (tenant_id, id)` e as ligações entre elas usam chaves compostas, para que nenhuma ligação cruze tenants.
- **`empresa_gestora`:** é o tenant (o `id` é o tenant). CNPJ aceita o formato numérico e o alfanumérico de 2026 (`check` de formato; o dígito verificador fica na aplicação). A coluna `plataforma` marca a Titulize, única (índice único parcial). A Titulize nasce no seed, com UUID fixo. O CNPJ do seed é um valor de teste, configurável por variável de ambiente sem nova migração, a ser trocado pelo CNPJ real.
- **`usuario`:** sempre ligado a uma empresa gestora. E-mail único em toda a plataforma, em minúsculas. A situação é `CONVIDADO`, `ATIVO`, `BLOQUEADO` ou `INATIVO`, e `ATIVO` exige senha. O hash da senha é nulo enquanto o usuário só foi convidado. A aplicação nunca apaga usuário: inativar é `situacao = 'INATIVO'`.
- **`perfil`:** por empresa, com nome único dentro do tenant. As permissões seguem o [ADR 0029](./0029-permissao-por-tela.md).
- **`token_usuario`:** finalidades `CONVITE` e `RECUPERACAO_SENHA`. Guarda o SHA-256 do token (32 bytes, único), expiração e data de uso. O token nunca é gravado. A tabela não é auditada, por ser artefato de segurança.
- **Auditoria:** `revinfo` com revisão customizada (usuário, `tenant_id` efetivo, `tenant_origem_id` quando um admin da plataforma atua em outra empresa, e data e hora em milissegundos). Uma tabela `<tabela>_aud` por entidade auditada, sem restrições nas colunas da entidade, imutável para a aplicação (só `SELECT` e `INSERT`). A tabela de usuário auditada não leva o hash da senha. A sequence da revisão tem incremento 50, como o Hibernate 7 espera. O Task 8 confirma com `ddl-auto=validate`.
- **Origem e efetivo:** a aplicação define `app.tenant_origem_id` (empresa do admin) e `app.tenant_id` (empresa escolhida). O RLS filtra pelo efetivo. A busca de empresas e o `INSERT` de empresa exigem origem na plataforma. O `revinfo` grava os dois.
- **Caminho administrativo explícito (exceção ao [ADR 0008](./0008-multitenancy.md)):** a resolução do tenant antes do login (por e-mail ou por token) não tem tenant ativo. Ela passa por funções `SECURITY DEFINER` que devolvem só o `tenant_id` (ver [ADR 0026](./0026-roles-e-rls.md)), sem abrir leitura de outras linhas.
- **CPF:** a V1 não tem CPF. Ele entra numa migração posterior, criptografado em coluna com blind index ([ADR 0015](./0015-lgpd.md)). *Nota (2026-11-24): essa migração acabou sendo a V3, porque a V2 foi usada pelo [ADR 0042](./0042-v2-tenant-da-auditoria-da-empresa.md). Ver o [ADR 0056](./0056-v3-cpf-do-usuario.md).*

## Consequências

- Não há como gravar uma ligação entre dois tenants: a chave composta recusa.
- O desenho do `revinfo` e dos `_aud` precisa ser conferido pelo Task 8 contra o Hibernate Envers real. Se divergir, entra uma migração nova, não uma edição da `V1`.
- E-mail único na plataforma impede o mesmo e-mail em duas empresas. É a regra pedida, porque o login resolve o tenant pelo e-mail.
- O CNPJ de teste da Titulize precisa ser trocado antes de produção. O README do `boleto-migrations` diz como.
- O catálogo de telas e a reorganização feita pela tela "Cadastro de Telas" não são auditados pelo Envers na V1. Fica anotado como pendência para o Task 8.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Usuário sem tenant fixo (vários tenants por usuário) | Complica o RLS e o login. Um usuário pertence a uma empresa |
| Identificadores `bigserial` | Expõem a ordem de criação e dificultam a mesclagem entre ambientes |
| `tenant_id` só nas tabelas filhas | O RLS por política única deixa de valer para a tabela raiz |
| Tabelas de auditoria geradas pelo Hibernate | O schema inteiro pertence ao `boleto-migrations` e o backend usa `ddl-auto=validate` |
| Guardar o token em claro com expiração curta | Quem lê o banco passa a poder usar o convite. O hash resolve |
