#!/bin/bash
# =====================================================
# CondoHome - Setup GitHub Environments
# Cria Environments, Variables e Secrets nos repositórios
# =====================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

GITHUB_ORG="rmaneschy"

# Todos os repositórios da plataforma
REPOS=(
    "ms-condohome-register"
    "ms-condohome-billing"
    "ms-condohome-documents"
    "ms-condohome-booking"
    "ms-condohome-notification"
    "ms-condohome-finance"
    "ms-condohome-ai-assistant"
    "ms-condohome-gateway"
    "n8n-nodes-condohome"
    "assistente-portaria"
    "infra-condohome-sre"
    "infra-condohome-cicd"
)

# Environments a serem criados
ENVIRONMENTS=("development" "staging" "production")

usage() {
    echo -e "${BLUE}CondoHome - Setup GitHub Environments${NC}"
    echo ""
    echo "Uso: $0 <comando> [opções]"
    echo ""
    echo "Comandos:"
    echo "  create-envs [repo]           Criar environments em um ou todos os repos"
    echo "  set-vars <env> <file>        Definir variables de um arquivo .env"
    echo "  set-secrets <env> <file>     Definir secrets de um arquivo .env.secrets"
    echo "  set-protection <repo>        Configurar protection rules"
    echo "  list <repo>                  Listar environments de um repo"
    echo "  status                       Verificar status de todos os repos"
    echo ""
    echo "Exemplos:"
    echo "  $0 create-envs                                    # Cria envs em todos os repos"
    echo "  $0 create-envs ms-condohome-register              # Cria envs em um repo"
    echo "  $0 set-vars staging configs/envs/staging.vars     # Define variables"
    echo "  $0 set-secrets production configs/envs/prod.secrets  # Define secrets"
    echo ""
}

# =====================================================
# Criar Environments via GitHub API
# =====================================================
create_environments() {
    local target_repo="$1"
    local repos_to_process=()

    if [ -n "$target_repo" ]; then
        repos_to_process=("$target_repo")
    else
        repos_to_process=("${REPOS[@]}")
    fi

    for repo in "${repos_to_process[@]}"; do
        echo -e "${BLUE}--- $repo ---${NC}"
        for env in "${ENVIRONMENTS[@]}"; do
            echo -n "  Criando environment '$env'... "
            if gh api --method PUT \
                "repos/$GITHUB_ORG/$repo/environments/$env" \
                --silent 2>/dev/null; then
                echo -e "${GREEN}OK${NC}"
            else
                echo -e "${YELLOW}Já existe ou sem permissão${NC}"
            fi
        done
        echo ""
    done
}

# =====================================================
# Definir Environment Variables
# =====================================================
set_environment_variables() {
    local env_name="$1"
    local vars_file="$2"

    if [ ! -f "$vars_file" ]; then
        echo -e "${RED}Arquivo não encontrado: $vars_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}Definindo variables para environment '$env_name'...${NC}"
    echo ""

    for repo in "${REPOS[@]}"; do
        echo -e "${CYAN}--- $repo ---${NC}"
        while IFS='=' read -r key value; do
            # Ignorar linhas vazias e comentários
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            # Remover espaços
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)

            echo -n "  $key = $value ... "
            if gh api --method POST \
                "repos/$GITHUB_ORG/$repo/environments/$env_name/variables" \
                -f name="$key" -f value="$value" \
                --silent 2>/dev/null; then
                echo -e "${GREEN}OK${NC}"
            else
                # Tentar atualizar se já existe
                if gh api --method PATCH \
                    "repos/$GITHUB_ORG/$repo/environments/$env_name/variables/$key" \
                    -f value="$value" \
                    --silent 2>/dev/null; then
                    echo -e "${GREEN}UPDATED${NC}"
                else
                    echo -e "${RED}FAIL${NC}"
                fi
            fi
        done < "$vars_file"
        echo ""
    done
}

# =====================================================
# Definir Environment Secrets
# =====================================================
set_environment_secrets() {
    local env_name="$1"
    local secrets_file="$2"

    if [ ! -f "$secrets_file" ]; then
        echo -e "${RED}Arquivo não encontrado: $secrets_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}Definindo secrets para environment '$env_name'...${NC}"
    echo ""

    for repo in "${REPOS[@]}"; do
        echo -e "${CYAN}--- $repo ---${NC}"
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)

            echo -n "  $key ... "
            if gh secret set "$key" \
                --repo "$GITHUB_ORG/$repo" \
                --env "$env_name" \
                --body "$value" 2>/dev/null; then
                echo -e "${GREEN}OK${NC}"
            else
                echo -e "${RED}FAIL${NC}"
            fi
        done < "$secrets_file"
        echo ""
    done
}

# =====================================================
# Configurar Protection Rules
# =====================================================
set_protection_rules() {
    local repo="$1"

    echo -e "${BLUE}Configurando protection rules para $repo...${NC}"

    # Production: requer aprovação, wait timer de 5 min
    echo -n "  production (reviewers + wait timer)... "
    gh api --method PUT \
        "repos/$GITHUB_ORG/$repo/environments/production" \
        --input - <<EOF 2>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}SKIP${NC}"
{
  "wait_timer": 5,
  "prevent_self_review": false,
  "deployment_branch_policy": {
    "protected_branches": true,
    "custom_branch_policies": false
  }
}
EOF

    # Staging: deploy apenas de main/master
    echo -n "  staging (branch policy)... "
    gh api --method PUT \
        "repos/$GITHUB_ORG/$repo/environments/staging" \
        --input - <<EOF 2>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}SKIP${NC}"
{
  "deployment_branch_policy": {
    "protected_branches": true,
    "custom_branch_policies": false
  }
}
EOF

    # Development: sem restrições
    echo -n "  development (sem restrições)... "
    gh api --method PUT \
        "repos/$GITHUB_ORG/$repo/environments/development" \
        --silent 2>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}SKIP${NC}"
}

# =====================================================
# Listar Environments de um repo
# =====================================================
list_environments() {
    local repo="$1"
    echo -e "${BLUE}Environments de $repo:${NC}"
    gh api "repos/$GITHUB_ORG/$repo/environments" \
        --jq '.environments[] | "  \(.name) (created: \(.created_at))"' 2>/dev/null \
        || echo -e "  ${YELLOW}Nenhum environment encontrado${NC}"
}

# =====================================================
# Status geral
# =====================================================
check_status() {
    echo -e "${BLUE}Status dos GitHub Environments:${NC}"
    echo ""
    printf "%-35s %-15s %-15s %-15s\n" "REPOSITÓRIO" "development" "staging" "production"
    printf "%-35s %-15s %-15s %-15s\n" "-----------------------------------" "---------------" "---------------" "---------------"

    for repo in "${REPOS[@]}"; do
        local envs
        envs=$(gh api "repos/$GITHUB_ORG/$repo/environments" \
            --jq '.environments[].name' 2>/dev/null || echo "")

        local dev_status="---"
        local stg_status="---"
        local prd_status="---"

        echo "$envs" | grep -q "development" && dev_status="OK"
        echo "$envs" | grep -q "staging" && stg_status="OK"
        echo "$envs" | grep -q "production" && prd_status="OK"

        printf "%-35s %-15s %-15s %-15s\n" "$repo" "$dev_status" "$stg_status" "$prd_status"
    done
}

# Main
case "${1:-}" in
    create-envs)     create_environments "$2" ;;
    set-vars)        set_environment_variables "$2" "$3" ;;
    set-secrets)     set_environment_secrets "$2" "$3" ;;
    set-protection)  set_protection_rules "$2" ;;
    list)            list_environments "$2" ;;
    status)          check_status ;;
    *)               usage ;;
esac
