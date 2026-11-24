---
sidebar_position: 8
title: Inventário LGPD
---

# Inventário de dados pessoais (LGPD)

Lista dos dados pessoais que a plataforma guarda ou move, com finalidade, proteção, retenção e quem acessa. A regra geral está no [ADR 0015](../adr/0015-lgpd.md). Cada novo campo pessoal entra aqui no mesmo PR que o cria. O Task 10 criou esta página; o Task 15 a completa e fecha a política de retenção.

Esta página não traz valores reais: só descreve campos. O `boleto-docs` é público.

## Banco de dados (PostgreSQL)

| Dado | Titular | Finalidade | Onde fica | Proteção | Retenção | Quem acessa |
|---|---|---|---|---|---|---|
| `usuario.nome` | Usuário | Identificar a pessoa na plataforma e nos e-mails | `boleto.usuario` | RLS por tenant. Nunca em log em claro ([ADR 0055](../adr/0055-mascara-de-dados-pessoais-nos-logs.md)) | Enquanto o usuário existir. A aplicação não apaga usuário: inativa. Política de exclusão pendente | Backend (`boleto_app`), só do próprio tenant. Administradores da empresa, pela API |
| `usuario.email` | Usuário | Login, convite e recuperação de senha | `boleto.usuario` | RLS por tenant. Único na plataforma, em minúsculas. Em log só mascarado | Idem | Backend. Função `resolver_tenant_por_email` devolve só o tenant |
| `usuario.senha_hash` | Usuário | Autenticar | `boleto.usuario` | Argon2id. Fora da auditoria (`@NotAudited`). Nunca em log nem na API | Enquanto o usuário existir. Substituído a cada troca de senha | Backend |
| `usuario.cpf_cifrado`, `cpf_indice`, `cpf_chave_versao` | Usuário (opcional) | Identificação do usuário. Consulta por CPF | `boleto.usuario` (V3) | AES-256-GCM com AAD por tenant e blind index HMAC-SHA256 com chave separada ([ADR 0054](../adr/0054-cpf-criptografado-e-blind-index.md)). O banco não vê o CPF nem as chaves. Fora do `usuario_aud` e do log | Enquanto o usuário existir. Política de exclusão pendente | Backend decifra com a chave do ambiente. A API devolve só `cpfMascarado` |
| `usuario_aud.nome`, `usuario_aud.email` | Usuário | Trilha de auditoria das alterações | `boleto.usuario_aud` | RLS por tenant. A aplicação só faz `SELECT` e `INSERT`. Sem senha e sem CPF | Sem prazo definido: a trilha não se apaga. Decidir no Task 15 como atender pedido de exclusão | Backend (consulta de auditoria) |
| `token_usuario.token_hash` | Usuário | Convite e recuperação de senha | `boleto.token_usuario` | É credencial, não dado pessoal: guarda só o SHA-256 do token, que nunca é gravado nem logado ([ADR 0051](../adr/0051-tokens-de-convite-e-recuperacao-de-senha.md)). Liga ao `usuario_id` | Expira em 72 h (convite) ou 30 min (recuperação). As linhas continuam no banco: **limpeza pendente** | Backend |

## Valkey

| Chave | Dado pessoal? | Conteúdo | Retenção |
|---|---|---|---|
| `refresh:{hash}`, `refresh-usado:{hash}` | Só ids | `sid`, id do usuário, tenant de origem e fim da sessão. O texto do refresh nunca é gravado | Até 8 h, limitado ao fim da sessão |
| `sessao-revogada:{sid}`, `sessoes-usuario:{usuarioId}` | Só ids | Sessões revogadas e o conjunto de `sid` de cada usuário | Até 25 h |
| `limite:email:{sha256(email)}`, `login-falhas:{sha256(email)}`, `limite:esqueci:{sha256(email)}` | Pseudonimização fraca | SHA-256 do e-mail sem sal e o estado do contador. Quem conhece o e-mail confirma o hash | Minutos (1 a 15) |
| `limite:ip:{ip}` | Sim (endereço IP) | Estado do balde por IP | Minutos |

## E-mails enviados

| Dado | Finalidade | Proteção | Retenção |
|---|---|---|---|
| Nome (primeiro nome), nome da empresa gestora e link com o token | Convite e recuperação de senha | O token vai no fragmento da URL ([ADR 0053](../adr/0053-email-smtp-link-e-modelos.md)). Validade curta e uso único. O assunto não leva dado pessoal | Na caixa do destinatário, fora do nosso controle. No Mailpit (só dev) enquanto o container existir. Não há cópia no banco |

## Logs

| Dado | Regra |
|---|---|
| E-mail, CPF, nome | Nunca em claro. Quando for preciso, só mascarados (`a***@dominio`, `***.456.789-**`, `A*** S***`) |
| Senha, token, hash de senha, chave | Nunca em log |
| Identificação | Id do usuário e `traceId` |
| Exceções de JavaMail, driver e Hibernate | Só o nome da classe, porque a mensagem pode trazer o endereço ou o valor |

Não há filtro de saída automático: a defesa é a máscara explícita e os testes que varrem a saída ([ADR 0055](../adr/0055-mascara-de-dados-pessoais-nos-logs.md)).

## Pendências

- **Retenção e limpeza de `token_usuario`:** definir o prazo e a rotina que apaga tokens expirados ou usados (Task 15).
- **Exportação e exclusão a pedido do titular:** ficam para as fases seguintes ([ADR 0015](../adr/0015-lgpd.md)). Hoje não há exclusão de usuário, só inativação.
- **Retenção de `usuario_aud`:** conciliar a trilha de auditoria, que não se apaga, com o pedido de exclusão (Task 15).
- **Rotação das chaves de CPF e backup das chaves:** procedimento no runbook do Task 15 ([Chaves de CPF](../guias/chaves-de-cpf.md)).
- **Dados de pagadores e CPF/CNPJ de títulos:** entram com os módulos de títulos e CNAB, nas próximas fases.
