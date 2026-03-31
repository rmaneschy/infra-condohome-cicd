# Guia de Operacionalização CI/CD

Este documento detalha a operação prática do repositório `infra-condohome-cicd`, que centraliza todos os pipelines de Integração Contínua (CI) e Entrega Contínua (CD) da plataforma CondoHome.

**Desenvolvido por:** Debug Software

---

## 1. Visão Geral da Arquitetura

A arquitetura de CI/CD foi desenhada seguindo o padrão de **Reusable Workflows** do GitHub Actions. Isso significa que a lógica do pipeline reside apenas neste repositório (`infra-condohome-cicd`), enquanto os repositórios dos microserviços apenas "chamam" esses workflows.

### Vantagens desta abordagem:
- **Manutenção Centralizada:** Atualizar um step de build afeta todos os repositórios instantaneamente.
- **Padronização:** Garante que todos os serviços Spring Boot, por exemplo, sejam testados e empacotados da mesma forma.
- **Segurança:** Segredos e variáveis são gerenciados via GitHub Environments, reduzindo o risco de vazamento.

---

## 2. Estrutura de Ambientes (Environments)

A plataforma utiliza 3 ambientes no GitHub, cada um com regras específicas:

| Ambiente | Gatilho (Trigger) | Regras de Proteção | Destino do Deploy |
|---|---|---|---|
| `development` | Push na branch `develop` | Nenhuma (Deploy Automático) | Ambiente local/dev |
| `staging` | Push nas branches `main` ou `master` | Restrito a branches protegidas | Servidor VPS de Staging |
| `production` | Manual (após sucesso em staging) | Requer aprovação manual + Wait timer (5 min) | Cluster Kubernetes de Produção |

---

## 3. Passo a Passo: Setup Inicial de um Novo Repositório

Quando um novo microserviço é criado, siga estes passos para integrá-lo à esteira de CI/CD:

### Passo 3.1: Criar os Environments
Execute o comando abaixo para criar os ambientes `development`, `staging` e `production` no novo repositório:

```bash
make create-env REPO=ms-condohome-novo-servico
```

### Passo 3.2: Configurar Regras de Proteção
Configure as regras de aprovação e restrição de branches:

```bash
make set-protection REPO=ms-condohome-novo-servico
```

### Passo 3.3: Injetar Variáveis de Ambiente
Injete as variáveis não-sensíveis (URLs, portas, profiles) para cada ambiente:

```bash
make set-vars-dev
make set-vars-staging
make set-vars-prod
```

### Passo 3.4: Injetar Segredos (Secrets)
Crie arquivos `.secrets` baseados no template e injete-os:

```bash
# Exemplo para staging
make set-secrets ENV=staging FILE=configs/envs/staging.secrets
```

### Passo 3.5: Instalar o Workflow
Copie o template de workflow correspondente à tecnologia do repositório:

```bash
make install REPO=ms-condohome-novo-servico
```
*(O script perguntará qual tecnologia usar: spring-boot, react, python ou node)*

---

## 4. Gestão de Releases

Para criar uma nova versão oficial de um componente, utilizamos o script de release que gera a tag semântica e as notas de lançamento automaticamente.

```bash
make release REPO=ms-condohome-register VERSION=v1.2.0
```

Isso irá:
1. Criar a tag `v1.2.0` no repositório especificado.
2. Compilar as notas de release baseadas nos PRs mergeados.
3. Disparar o pipeline de CI/CD (se configurado para rodar em tags).

---

## 5. Melhorias Profissionais Implementadas

Para elevar o nível de maturidade da operação, as seguintes práticas foram adotadas:

1. **Validação de Requisitos:** Antes de executar scripts locais, o comando `make validate` verifica se ferramentas como `gh` (GitHub CLI) e `jq` estão instaladas.
2. **Separação Estrita:** Variáveis de configuração (URLs, flags) usam *Environment Variables*, enquanto credenciais usam *Environment Secrets*.
3. **Princípio do Menor Privilégio:** O token do GitHub (`GITHUB_TOKEN`) recebe apenas as permissões estritamente necessárias (`contents: read`, `packages: write`).
4. **Cache de Build:** Utilização de `cache-from` e `cache-to` do Docker Buildx com backend do GitHub Actions (`type=gha`) para acelerar builds subsequentes.
5. **Tags Semânticas no GHCR:** Imagens Docker recebem tags claras (`development`, `staging`, `latest`) e tags imutáveis baseadas no SHA do commit (`dev-a1b2c3d`).

---

## 6. Troubleshooting Comum

### Erro: "Resource not accessible by integration" ao fazer push no GHCR
**Causa:** O `GITHUB_TOKEN` não tem permissão para escrever pacotes.
**Solução:** Verifique se o workflow possui o bloco `permissions: packages: write`. Além disso, nas configurações da organização no GitHub, garanta que Actions têm permissão de leitura/escrita em pacotes.

### Erro: "Environment not found" ou deploy travado
**Causa:** O repositório não possui o environment criado ou o nome está incorreto.
**Solução:** Rode `make env-list REPO=<nome>` para verificar. Se faltar, rode `make create-env REPO=<nome>`.

### Erro: "Secret X is missing"
**Causa:** O workflow tenta acessar um secret que não foi injetado no environment.
**Solução:** Verifique os secrets com `gh secret list --repo rmaneschy/<nome> --env <ambiente>`. Injete o secret faltante usando `make set-secrets`.
