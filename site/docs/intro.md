---
slug: /
sidebar_position: 1
title: Plataforma de Boletos
---

# Plataforma de Boletos

Sistema próprio de controle de boletos, com geração de remessas e leitura de retornos no padrão CNAB 240. Os primeiros bancos suportados são Sicoob e Itaú.

## Estado atual

A Fase 1 entrega a fundação (repositórios, ambiente de desenvolvimento, versões centrais, documentação, CI) e o módulo de Login. Painel, Carteira e Configurações vêm nas fases seguintes.

## Repositórios

| Repositório | Conteúdo |
|---|---|
| [`boleto-docs`](https://github.com/Titulize/boleto-docs) | Esta documentação, `versions.toml`, Docker Compose de desenvolvimento e scripts de bootstrap |
| `boleto-backend` | API em Spring Boot (Java 25) |
| `boleto-frontend` | SPA em Angular com Angular Material |
| `boleto-migrations` | Migrações Flyway do PostgreSQL e imagem de migração (JAR do Flyway sobre Amazon Corretto) |

## Por onde começar

- [Progresso](./progresso/index.md): situação de cada tarefa da Fase 1.
- [Padrão do projeto](./guias/padrao-do-projeto.md): regras de trabalho, definição de pronto e atualização da documentação.
- [Visão de contexto](./arquitetura/contexto.md): quem usa o sistema e com o que ele conversa.
- [Containers](./arquitetura/containers.md): as peças que rodam e como se conectam.
- [Versões centrais](./guias/versoes.md): como as versões são controladas.
- [Decisões de arquitetura](./adr/index.md): o que foi decidido e por quê.

## Princípios

1. **Custo mínimo.** Desenvolvimento a custo zero e escolhas de AWS pelo menor custo.
2. **Reprodutibilidade.** Versões exatas, imagens por digest, uma fonte única de versões.
3. **Segurança por padrão.** Isolamento por empresa no banco, auditoria de alterações, dados pessoais protegidos.
4. **Documentação viva.** A documentação mora no repositório, é revisada em PR e publicada pela CI.
