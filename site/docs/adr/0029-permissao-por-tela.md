---
title: 'ADR 0029: Permissão por tela'
---

# ADR 0029: Permissão por tela

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

O [ADR 0012](./0012-autenticacao.md) define a autenticação, e o Task 9 define a autorização. O desenvolvedor decidiu que o acesso é concedido por tela, com ações por tela (visualizar, incluir, alterar, excluir), e não por uma lista de códigos de permissão. Além disso, o admin da plataforma precisa de um poder que um tenant comum nunca recebe: assumir uma empresa gestora pela barra superior.

## Decisão

- **Catálogo global `tela`:** tabela sem `tenant_id`, criada só por migração, junto com o código da tela. Cada tela tem código, nome, menu, ordem, se é `somente_plataforma` e quais ações permite além de `visualizar` (`permite_incluir`, `permite_alterar`, `permite_excluir`).
- **Permissão do perfil:** `perfil_tela_permissao` guarda as quatro ações por perfil e tela. Qualquer ação exige `visualizar`.
- **Herança:** o usuário recebe a união (OU) das permissões dos perfis que tem. Não existe permissão direta no usuário.
- **Validação no banco:** um gatilho de restrição rejeita ação que a tela não permite e rejeita qualquer permissão numa tela `somente_plataforma` quando o perfil não pertence à empresa da plataforma.
- **Cadastro de Telas:** a tela só lista e reorganiza (nome, menu, ordem), nunca cria tela, e só é acessível à plataforma. A aplicação tem `UPDATE` apenas nessas três colunas, e só quando o tenant de origem é da plataforma.
- **Assumir empresa:** é a ação `visualizar` da tela `PLATAFORMA_EMPRESAS`, marcada `somente_plataforma`. O banco só deixa essa tela ser concedida a perfis da Titulize. A aplicação confere a permissão do usuário no perfil (Task 9), e o banco garante que a busca de empresas e o `INSERT` de empresa exigem origem na plataforma.
- **Telas da V1:** `USUARIOS`, `PERFIS`, `EMPRESA_GESTORA`, `AUDITORIA`, `TELAS` e `PLATAFORMA_EMPRESAS`. O perfil `Administrador da plataforma`, da Titulize, nasce com todas as telas e ações permitidas. Telas de negócio (boletos, remessa, retorno, pagadores) entram em migrações dos tasks futuros.
- **Escopo do Task 6:** só o suporte no banco. A barra de administração é do frontend (Task 12 em diante), e a conferência da permissão é do Task 9.

## Consequências

- Não existe tela cadastrada sem implementação nem implementação sem permissão: a tela nasce na mesma migração do código que a usa.
- Reorganizar o menu é uma ação global, por isso fica restrita à plataforma.
- Excluir, na tela de usuários, significa inativar. A aplicação não tem `DELETE` em `usuario`.
- Para uma tela nova é preciso uma migração (`insert into boleto.tela`) e a concessão aos perfis que devem enxergá-la.
- A reorganização de nome, menu e ordem não é auditada pelo Envers na V1. O Task 8 decide.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| Lista de códigos de permissão por perfil | Duas formas de descrever acesso (tela e código) e códigos sem tela correspondente |
| Permissão avulsa `PLATAFORMA_ASSUMIR_EMPRESA` | Fica fora do modelo por tela e cria um segundo jeito de conceder acesso |
| Permissão direta no usuário, além dos perfis | Dificulta a auditoria de quem pode o quê. Perfis resolvem |
| Telas cadastradas pela aplicação | A tela existiria sem código. O catálogo por migração mantém os dois juntos |
