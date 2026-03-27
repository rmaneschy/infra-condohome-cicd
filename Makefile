# =====================================================
# CondoHome CI/CD - Makefile
# =====================================================

.PHONY: help install-all install list create-envs set-vars set-secrets env-status release

help: ## Mostrar ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# =====================================================
# Workflows
# =====================================================

install-all: ## Instalar workflows em todos os repositórios
	@./scripts/setup-workflows.sh install-all

install: ## Instalar workflow em um repo (make install REPO=ms-condohome-register)
	@./scripts/setup-workflows.sh install $(REPO)

list: ## Listar repositórios e tecnologias
	@./scripts/setup-workflows.sh list

# =====================================================
# GitHub Environments
# =====================================================

create-envs: ## Criar environments em todos os repos
	@./scripts/setup-environments.sh create-envs

create-env: ## Criar environments em um repo (make create-env REPO=ms-condohome-register)
	@./scripts/setup-environments.sh create-envs $(REPO)

set-vars-dev: ## Definir variables de development
	@./scripts/setup-environments.sh set-vars development configs/envs/development.vars

set-vars-staging: ## Definir variables de staging
	@./scripts/setup-environments.sh set-vars staging configs/envs/staging.vars

set-vars-prod: ## Definir variables de production
	@./scripts/setup-environments.sh set-vars production configs/envs/production.vars

set-secrets: ## Definir secrets de um environment (make set-secrets ENV=staging FILE=path/to/secrets)
	@./scripts/setup-environments.sh set-secrets $(ENV) $(FILE)

env-status: ## Verificar status dos environments em todos os repos
	@./scripts/setup-environments.sh status

env-list: ## Listar environments de um repo (make env-list REPO=ms-condohome-register)
	@./scripts/setup-environments.sh list $(REPO)

set-protection: ## Configurar protection rules (make set-protection REPO=ms-condohome-register)
	@./scripts/setup-environments.sh set-protection $(REPO)

# =====================================================
# Setup completo
# =====================================================

setup-all: create-envs set-vars-dev set-vars-staging set-vars-prod install-all ## Setup completo (envs + vars + workflows)
	@echo ""
	@echo "\033[32mSetup completo! Falta apenas configurar os secrets:\033[0m"
	@echo "  make set-secrets ENV=development FILE=configs/envs/dev.secrets"
	@echo "  make set-secrets ENV=staging FILE=configs/envs/staging.secrets"
	@echo "  make set-secrets ENV=production FILE=configs/envs/prod.secrets"

# =====================================================
# Releases
# =====================================================

release: ## Criar release (make release REPO=ms-condohome-register VERSION=1.0.0)
	@./scripts/create-release.sh $(REPO) $(VERSION)
