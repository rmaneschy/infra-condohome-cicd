# infra-condohome-cicd

Pipelines de CI/CD da plataforma **CondoHome**, organizados por tecnologia e integrados com **GitHub Environments**, **Environment Variables** e **Environment Secrets**.

**Desenvolvido por:** Debug Software

---

## 📚 Documentação

- [Guia de Operacionalização](docs/operationalization.md) - Passo a passo completo, arquitetura e troubleshooting.
- [Configuração de Novo Repositório](docs/new-repository-setup.md) - Guia passo a passo para integrar um novo repositório à esteira de CI/CD.

---

## Arquitetura de Environments

A plataforma utiliza 3 GitHub Environments com regras de proteção progressivas:

| Environment | Trigger | Proteção | Uso |
|---|---|---|---|
| `development` | Push em `develop` | Nenhuma (auto-deploy) | Testes do desenvolvedor |
| `staging` | Push em `main`/`master` | Branch policy (protected branches) | Validação pré-produção |
| `production` | Após staging (manual) | Aprovação obrigatória + wait timer 5min | Ambiente de produção |

### Fluxo de Deploy

```
develop branch ──push──> CI ──> Deploy Development (auto)
                                     │
main branch ───push──> CI ──> Deploy Staging (auto)
                                     │
                              Deploy Production (aprovação manual)
```

---

## Environment Variables vs Environment Secrets

### Quando usar Variables (não sensíveis)

Configurações que variam por ambiente mas não são confidenciais:

| Variable | development | staging | production |
|---|---|---|---|
| `API_URL` | `http://localhost:8080` | `https://staging-api.condohome.com.br` | `https://api.condohome.com.br` |
| `SPRING_PROFILE` | `dev` | `staging` | `prod` |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:3000` | `https://staging.condohome.com.br` | `https://condohome.com.br` |
| `VITE_API_URL` | `http://localhost:8080` | `https://staging-api.condohome.com.br` | `https://api.condohome.com.br` |
| `PORTAL_WEB_DOMAIN` | `localhost:3000` | `staging.condohome.com.br` | `condohome.com.br` |
| `PORTARIA_DOMAIN` | `localhost:3001` | `staging-portaria.condohome.com.br` | `portaria.condohome.com.br` |
| `IMAGE_TAG` | `development` | `staging` | `latest` |

### Quando usar Secrets (sensíveis)

Credenciais e chaves que devem ser protegidas:

| Secret | Descrição | Escopo recomendado |
|---|---|---|
| `DB_PASSWORD` | Senha do banco de dados | Environment Secret |
| `ASAAS_API_KEY` | Chave da API Asaas | Environment Secret |
| `OPENAI_API_KEY` | Chave da API OpenAI | Environment Secret |
| `MAIL_PASSWORD` | Senha SMTP | Environment Secret |
| `EVOLUTION_API_KEY` | Chave Evolution API | Environment Secret |
| `JWT_SECRET` | Segredo JWT | Environment Secret |
| `GITHUB_TOKEN` | Token GitHub | Automático (não configurar) |

---

## Estrutura do Repositório

```
infra-condohome-cicd/
├── workflows/                    # Reusable workflows (chamados por outros repos)
│   ├── spring-boot/
│   │   ├── ci.yml               # CI: Build, Test, Artifacts
│   │   └── cd.yml               # CD: Build Docker, Push GHCR (com environment)
│   ├── react/
│   │   ├── ci.yml               # CI: Lint, Typecheck, Build
│   │   └── cd.yml               # CD: Docker/Pages (com environment)
│   ├── python/
│   │   ├── ci.yml               # CI: Ruff, mypy, pytest
│   │   └── cd.yml               # CD: Docker Push (com environment)
│   ├── node/
│   │   ├── ci.yml               # CI: Lint, Build, Test
│   │   └── cd.yml               # CD: GitHub Packages (com environment)
│   └── docker/
│       └── build-push.yml       # Genérico: Docker multi-platform
├── templates/                    # Templates prontos para copiar
│   ├── spring-boot/ci-cd.yml    # CI + Development + Staging + Production
│   ├── react/ci-cd.yml
│   ├── python/ci-cd.yml
│   └── node/ci-cd.yml
├── configs/
│   └── envs/
│       ├── development.vars     # Variables para development
│       ├── staging.vars         # Variables para staging
│       ├── production.vars      # Variables para production
│       └── secrets.template     # Template de secrets (NUNCA preencher aqui)
├── scripts/
│   ├── setup-workflows.sh       # Instalar workflows nos repos
│   ├── setup-environments.sh    # Criar/gerenciar GitHub Environments
│   ├── create-release.sh        # Automação de releases
│   └── validate-requirements.sh # Validação de pré-requisitos
├── docs/
│   └── operationalization.md    # Guia de operação
└── Makefile                      # Atalhos rápidos
```

---

## Validação de Requisitos

Antes de iniciar a operação, valide se seu ambiente possui todas as ferramentas necessárias:

```bash
# Valida ferramentas locais (gh, jq, make) e autenticação
make validate CONTEXT=local

# Valida ferramentas do pipeline (docker, java, node)
make validate CONTEXT=pipeline

# Validação completa (local + acesso a todos os repositórios)
make validate CONTEXT=full
```

O script de validação fornece instruções de correção específicas para o seu sistema operacional (Ubuntu, macOS, Windows/WSL, etc).

---

## Quick Start

### 1. Validar Ambiente

```bash
make validate CONTEXT=local
```

### 2. Criar Environments em todos os repositórios

```bash
make create-envs
```

### 3. Configurar Environment Variables

```bash
make set-vars-dev        # development
make set-vars-staging    # staging
make set-vars-prod       # production
```

### 4. Configurar Environment Secrets

```bash
# Copie o template e preencha com valores reais
cp configs/envs/secrets.template configs/envs/dev.secrets
# Edite o arquivo com os valores reais
make set-secrets ENV=development FILE=configs/envs/dev.secrets
make set-secrets ENV=staging FILE=configs/envs/staging.secrets
make set-secrets ENV=production FILE=configs/envs/prod.secrets
```

### 5. Instalar workflows nos repositórios

```bash
make install-all         # Instala em todos os repos
make install REPO=ms-condohome-register  # Instala em um repo específico
```

### 6. Setup completo (tudo de uma vez)

```bash
make setup-all
```

---

## Workflows por Tecnologia

### Spring Boot (JDK 21 + Maven)

Cobre: `register`, `billing`, `documents`, `booking`, `notification`, `finance`, `ai-assistant`, `gateway`

- **CI:** Checkout → Setup JDK 21 → Maven Build & Test → Upload JAR
- **CD:** Build JAR → Docker Buildx → Push GHCR com tag do environment

### React/Vite (pnpm + Node 22)

Cobre: `assistente-portaria`, `portal-condohome-web`

- **CI:** Checkout → pnpm install → Lint → Typecheck → Build → Upload dist
- **CD:** Docker Build com `VITE_API_URL` do environment → Push GHCR

### Python (pip/poetry/uv)

Cobre: `ms-condohome-ai-assistant` (componentes Python)

- **CI:** Checkout → pip install → Ruff → mypy → pytest
- **CD:** Docker Build → Push GHCR

### Node.js (pnpm)

Cobre: `n8n-nodes-condohome`

- **CI:** Checkout → pnpm install → Lint → Build → Test
- **CD:** Publish no GitHub Packages (npm)

---

## Container Registry

Todas as imagens são publicadas no **GitHub Container Registry (GHCR)**:

```
ghcr.io/rmaneschy/<service>:<tag>
```

Tags por environment:

| Environment | Tag Pattern | Exemplo |
|---|---|---|
| development | `development`, `dev-<sha>` | `ghcr.io/rmaneschy/ms-condohome-register:development` |
| staging | `staging`, `staging-<sha>` | `ghcr.io/rmaneschy/ms-condohome-register:staging` |
| production | `latest`, `production`, `<sha>` | `ghcr.io/rmaneschy/ms-condohome-register:latest` |

---

## Melhores Práticas

1. **Secrets nunca em código:** Use Environment Secrets para credenciais
2. **Variables para configuração:** URLs, portas e flags por ambiente
3. **CI sem environment:** Testes rodam sem acesso a secrets de ambiente
4. **CD com environment:** Deploy só acontece no contexto do environment
5. **Production com aprovação:** Requer revisão manual antes do deploy
6. **Rotação de secrets:** Atualize credenciais a cada 90 dias
7. **Princípio do menor privilégio:** Cada environment tem apenas os secrets necessários
8. **`secrets: inherit`:** Use nos reusable workflows para propagar secrets do environment

---

## Comandos Disponíveis

```bash
make help                # Lista todos os comandos
make validate            # Valida requisitos (CONTEXT=local|pipeline|full)
make create-envs         # Criar environments em todos os repos
make set-vars-dev        # Definir variables de development
make set-vars-staging    # Definir variables de staging
make set-vars-prod       # Definir variables de production
make set-secrets         # Definir secrets (ENV=staging FILE=path)
make env-status          # Status dos environments
make install-all         # Instalar workflows em todos os repos
make install             # Instalar em um repo (REPO=...)
make list                # Listar repos e tecnologias
make release             # Criar release (REPO=... VERSION=...)
```
