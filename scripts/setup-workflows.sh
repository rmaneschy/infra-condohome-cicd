#!/bin/bash
# =====================================================
# CondoHome - Setup CI/CD Workflows
# Copia os templates de workflow para os repositórios
# =====================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CICD_DIR="$(dirname "$SCRIPT_DIR")"
PLATFORM_DIR="$(dirname "$CICD_DIR")"

# Mapeamento: repositório -> tecnologia
declare -A REPO_TECH=(
    ["ms-condohome-register"]="spring-boot"
    ["ms-condohome-billing"]="spring-boot"
    ["ms-condohome-documents"]="spring-boot"
    ["ms-condohome-booking"]="spring-boot"
    ["ms-condohome-notification"]="spring-boot"
    ["ms-condohome-finance"]="spring-boot"
    ["ms-condohome-ai-assistant"]="spring-boot"
    ["ms-condohome-gateway"]="spring-boot"
    ["n8n-nodes-condohome"]="node"
    ["assistente-portaria"]="react"
    ["portal-condohome-web"]="react"
)

usage() {
    echo -e "${BLUE}CondoHome - Setup CI/CD Workflows${NC}"
    echo ""
    echo "Uso: $0 <comando> [repo]"
    echo ""
    echo "Comandos:"
    echo "  install <repo>    Instalar workflow em um repositório específico"
    echo "  install-all       Instalar workflows em todos os repositórios"
    echo "  list              Listar repositórios e suas tecnologias"
    echo ""
}

install_workflow() {
    local repo="$1"
    local tech="${REPO_TECH[$repo]}"

    if [ -z "$tech" ]; then
        echo -e "${RED}Repositório desconhecido: $repo${NC}"
        return 1
    fi

    local repo_dir="$PLATFORM_DIR/$repo"
    if [ ! -d "$repo_dir" ]; then
        echo -e "${YELLOW}[SKIP] $repo - diretório não encontrado${NC}"
        return 1
    fi

    local template="$CICD_DIR/templates/$tech/ci-cd.yml"
    if [ ! -f "$template" ]; then
        echo -e "${RED}Template não encontrado: $template${NC}"
        return 1
    fi

    # Criar diretório .github/workflows
    mkdir -p "$repo_dir/.github/workflows"

    # Copiar e substituir placeholders
    local service_name="$repo"
    sed "s/<SERVICE_NAME>/$service_name/g; s/<APP_NAME>/$service_name/g; s/<PACKAGE_NAME>/$service_name/g" \
        "$template" > "$repo_dir/.github/workflows/ci-cd.yml"

    echo -e "${GREEN}[OK] $repo ($tech)${NC}"
}

install_all() {
    echo -e "${BLUE}Instalando workflows com GitHub Environments em todos os repositórios...${NC}"
    echo ""
    for repo in $(echo "${!REPO_TECH[@]}" | tr ' ' '\n' | sort); do
        install_workflow "$repo"
    done
    echo ""
    echo -e "${GREEN}Workflows instalados!${NC}"
    echo -e "${YELLOW}Próximos passos:${NC}"
    echo -e "  1. Commitar e fazer push em cada repositório"
    echo -e "  2. Criar environments: ./scripts/setup-environments.sh create-envs"
    echo -e "  3. Configurar variables: ./scripts/setup-environments.sh set-vars <env> <file>"
    echo -e "  4. Configurar secrets: ./scripts/setup-environments.sh set-secrets <env> <file>"
}

list_repos() {
    echo -e "${BLUE}Repositórios e tecnologias:${NC}"
    echo ""
    printf "%-35s %-15s\n" "REPOSITÓRIO" "TECNOLOGIA"
    printf "%-35s %-15s\n" "-----------------------------------" "---------------"
    for repo in $(echo "${!REPO_TECH[@]}" | tr ' ' '\n' | sort); do
        printf "%-35s %-15s\n" "$repo" "${REPO_TECH[$repo]}"
    done
}

case "${1:-}" in
    install)      install_workflow "$2" ;;
    install-all)  install_all ;;
    list)         list_repos ;;
    *)            usage ;;
esac
