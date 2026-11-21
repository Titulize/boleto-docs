---
sidebar_position: 5
title: Modelo de dados (V1)
---

# Modelo de dados (V1)

Schema `boleto`, criado pela migração `V1__schema_inicial.sql` do `boleto-migrations`. As decisões estão nos [ADR 0025](../adr/0025-modelo-de-dados-v1.md), [ADR 0026](../adr/0026-roles-e-rls.md) e [ADR 0029](../adr/0029-permissao-por-tela.md). O Task 8 mapeia estas tabelas em entidades.

```mermaid
erDiagram
  empresa_gestora ||--o{ usuario : "tenant_id"
  empresa_gestora ||--o{ perfil : "tenant_id"
  usuario ||--o{ usuario_perfil : ""
  perfil ||--o{ usuario_perfil : ""
  perfil ||--o{ perfil_tela_permissao : ""
  tela ||--o{ perfil_tela_permissao : "tela_codigo"
  usuario ||--o{ token_usuario : ""
  revinfo ||--o{ usuario_aud : "rev"
  revinfo ||--o{ perfil_aud : "rev"
  revinfo ||--o{ empresa_gestora_aud : "rev"
  revinfo ||--o{ perfil_tela_permissao_aud : "rev"
  revinfo ||--o{ usuario_perfil_aud : "rev"
```

## Convenções

- `id uuid primary key default uuidv7()`, exceto `tela` (chave `codigo`), `revinfo` (`rev`) e as tabelas de ligação.
- `criado_em` e `atualizado_em` (`timestamptz`) e `versao bigint` (lock otimista do Hibernate) nas tabelas de negócio.
- Toda tabela de negócio tem `tenant_id uuid not null`. Onde há ligação entre tabelas do mesmo tenant, a chave estrangeira é composta `(tenant_id, id)`, para que uma ligação nunca cruze empresas.
- RLS ligado e forçado (`ENABLE` e `FORCE ROW LEVEL SECURITY`) em toda tabela com `tenant_id` e em `empresa_gestora`. Sem `app.tenant_id` nenhuma linha passa.
- Nenhum dado de CPF na V1. O CPF entra na V2, criptografado ([ADR 0015](../adr/0015-lgpd.md)).

## Tabelas

| Tabela | Conteúdo e restrições principais |
|---|---|
| `empresa_gestora` | O `id` é o tenant. `nome`, `cnpj varchar(14)` único (12 caracteres `0-9A-Z` e 2 dígitos, aceita o CNPJ alfanumérico), `plataforma` (só uma `true`, a Titulize), `ativa` (a plataforma é sempre ativa). Sem `tenant_id` |
| `usuario` | `tenant_id`, `nome`, `email` único em toda a plataforma e sempre em minúsculas, `senha_hash` (nulo enquanto `CONVIDADO`), `situacao` (`CONVIDADO`, `ATIVO`, `BLOQUEADO`, `INATIVO`; `ATIVO` exige senha). A aplicação não apaga usuário: inativa |
| `perfil` | `tenant_id`, `nome` (único por empresa, sem diferenciar maiúsculas), `descricao` |
| `tela` | Catálogo global, sem `tenant_id`. `codigo`, `nome`, `menu`, `ordem`, `somente_plataforma`, `permite_incluir`, `permite_alterar`, `permite_excluir`, `ativa`. Criado só por migração. A aplicação lê tudo e altera apenas `nome`, `menu` e `ordem`, e só com origem na plataforma |
| `perfil_tela_permissao` | Permissão por tela e por ação (`visualizar`, `incluir`, `alterar`, `excluir`) concedida ao perfil. Qualquer ação exige `visualizar`. Um gatilho recusa ação que a tela não permite e tela `somente_plataforma` para perfil de empresa que não é a plataforma |
| `usuario_perfil` | Liga usuário e perfil do mesmo tenant. O usuário herda a união das permissões dos perfis. Não há permissão direta no usuário |
| `token_usuario` | Convite e recuperação de senha. Guarda só o SHA-256 do token (`token_hash bytea`, 32 bytes, único), `finalidade`, `expira_em` e `usado_em`. Não é auditada |
| `revinfo` | Revisão do Envers: `rev` (sequence `revinfo_seq`, incremento 50), `revtstmp` (epoch em ms), `usuario_id`, `tenant_id` (efetivo) e `tenant_origem_id` (preenchido quando o admin da plataforma atua em outra empresa) |
| `*_aud` | `empresa_gestora_aud`, `usuario_aud` (sem `senha_hash`), `perfil_aud`, `perfil_tela_permissao_aud`, `usuario_perfil_aud`. `rev`, `revtype` (0, 1 ou 2) e as colunas da entidade. A aplicação só faz `SELECT` e `INSERT` |

O catálogo `tela` não é auditado pelo Envers na V1: ele muda só por migração, que o `flyway_schema_history` registra. A reorganização de nome, menu e ordem pela tela "Cadastro de Telas" fica fora da auditoria até o Task 8 decidir.

## Dados da V1

| Dado | Valor |
|---|---|
| Empresa da plataforma | Titulize, `plataforma = true`, UUID fixo `00000000-0000-7000-8000-000000000001`. O CNPJ é de teste e configurável (variável `FLYWAY_PLACEHOLDERS_TITULIZE_CNPJ`, aplicada a cada execução pelo `afterMigrate`) |
| Telas | `USUARIOS`, `PERFIS`, `EMPRESA_GESTORA` e `AUDITORIA` (menu Administração), `PLATAFORMA_EMPRESAS` e `TELAS` (menu Plataforma, `somente_plataforma`) |
| Perfil | `Administrador da plataforma`, na Titulize, com todas as telas e todas as ações que cada tela permite. O admin inicial do Task 9 recebe este perfil |
| Usuários | Nenhum |

"Assumir empresa" (a barra do admin) é a ação `visualizar` da tela `PLATAFORMA_EMPRESAS`. O banco só deixa conceder essa tela a perfis da Titulize.

## Funções e papéis

| Objeto | Uso |
|---|---|
| `tenant_atual()`, `tenant_origem_atual()` | Leem `app.tenant_id` e `app.tenant_origem_id` (nulo se vazio) |
| `eh_plataforma(uuid)` | Diz se a empresa é a da plataforma |
| `resolver_tenant_por_email(text)`, `resolver_tenant_por_token(bytea)` | Resolvem o tenant antes do login. Devolvem só o `tenant_id`. O token só vale se não expirou e não foi usado |
| `buscar_empresas_gestoras(termo, limite)` | Busca para a barra do admin. Só devolve linhas com origem na plataforma |
| `boleto_owner`, `boleto_app`, `boleto_funcoes` | Dona dos objetos, role do backend (só DML, sem `BYPASSRLS`) e dona das funções `SECURITY DEFINER` |

## Dados pessoais (LGPD)

Não existe página de inventário de dados pessoais no site (previsto no Task 15). Os campos pessoais da V1 são: `usuario.nome`, `usuario.email`, `usuario.senha_hash` (Argon2id, gravado pelo backend) e `token_usuario.token_hash` (SHA-256 do token, o token nunca é gravado). O nome e o e-mail também ficam em `usuario_aud`. O Task 15 incorpora esta lista ao inventário.
