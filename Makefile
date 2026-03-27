# =====================================================
# CondoHome Platform - CI/CD Makefile
# =====================================================

.PHONY: help install install-all list release

help: ## Exibir ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Instalar workflow em um repo (uso: make install REPO=ms-condohome-register)
	@bash scripts/setup-workflows.sh install $(REPO)

install-all: ## Instalar workflows em todos os repos
	@bash scripts/setup-workflows.sh install-all

list: ## Listar repos e suas tecnologias
	@bash scripts/setup-workflows.sh list

release: ## Criar release (uso: make release REPO=ms-condohome-register VERSION=v1.0.0)
	@bash scripts/create-release.sh $(REPO) $(VERSION) "$(NOTES)"
