#!/bin/bash
# =====================================================
# CondoHome CI/CD - Requirements Validator
# Valida pré-requisitos para operação do repositório
# de CI/CD de acordo com o contexto informado
#
# Uso:
#   bash scripts/validate-requirements.sh local
#   bash scripts/validate-requirements.sh pipeline
#   bash scripts/validate-requirements.sh full
#
# Contextos:
#   local    - Máquina do desenvolvedor/operador
#   pipeline - Runner do GitHub Actions
#   full     - Validação completa (local + pipeline + repos)
#
# Autor: Debug Software
# =====================================================
set -euo pipefail

# =====================================================
# Cores e formatação
# =====================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

GITHUB_ORG="rmaneschy"

REPOS=(
    "ms-condohome-register"
    "ms-condohome-billing"
    "ms-condohome-booking"
    "ms-condohome-documents"
    "ms-condohome-notification"
    "ms-condohome-finance"
    "ms-condohome-ai-assistant"
    "ms-condohome-gateway"
    "portal-condohome-web"
    "n8n-nodes-condohome"
)

# =====================================================
# Detecção de SO
# =====================================================
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -qi microsoft /proc/version 2>/dev/null; then
            OS="wsl"
            OS_LABEL="WSL (Windows Subsystem for Linux)"
        elif [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian) OS="debian" ; OS_LABEL="$PRETTY_NAME" ;;
                fedora|rhel|centos|rocky|alma) OS="rhel" ; OS_LABEL="$PRETTY_NAME" ;;
                arch|manjaro) OS="arch" ; OS_LABEL="$PRETTY_NAME" ;;
                alpine) OS="alpine" ; OS_LABEL="$PRETTY_NAME" ;;
                *) OS="linux" ; OS_LABEL="$PRETTY_NAME" ;;
            esac
        else
            OS="linux"
            OS_LABEL="Linux (desconhecido)"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        OS_LABEL="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
    else
        OS="unknown"
        OS_LABEL="Sistema Operacional não identificado"
    fi
}

# =====================================================
# Funções de log
# =====================================================
log_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}$1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
}

log_section() {
    echo ""
    echo -e "${BLUE}── $1 ──${NC}"
}

log_pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "  ${GREEN}✓${NC} $1"
}

log_warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    echo -e "  ${YELLOW}⚠${NC} $1"
}

log_fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "  ${RED}✗${NC} $1"
}

log_fix() {
    echo -e "    ${YELLOW}→ Solução:${NC} $1"
}

log_fix_multi() {
    echo -e "    ${YELLOW}→ Solução:${NC}"
    while IFS= read -r line; do
        echo -e "      $line"
    done <<< "$1"
}

log_info() {
    echo -e "    ${CYAN}ℹ${NC} $1"
}

# =====================================================
# Funções de verificação de comandos
# =====================================================
check_command() {
    local cmd="$1"
    local label="${2:-$cmd}"
    local min_version="${3:-}"

    if ! command -v "$cmd" &>/dev/null; then
        log_fail "$label não encontrado"
        install_instructions "$cmd"
        return 1
    fi

    if [ -n "$min_version" ]; then
        local current_version
        current_version=$(get_version "$cmd")
        if [ -n "$current_version" ]; then
            if version_lt "$current_version" "$min_version"; then
                log_warn "$label encontrado (v$current_version), mas versão mínima é v$min_version"
                install_instructions "$cmd"
                return 1
            fi
            log_pass "$label v$current_version (>= v$min_version)"
        else
            log_pass "$label encontrado (versão não detectada)"
        fi
    else
        log_pass "$label encontrado"
    fi
    return 0
}

get_version() {
    local cmd="$1"
    case "$cmd" in
        git)
            git --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        gh)
            gh --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        bash)
            bash --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        curl)
            curl --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        jq)
            jq --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1
            ;;
        make)
            make --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1
            ;;
        docker)
            docker version --format '{{.Server.Version}}' 2>/dev/null || \
            docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        java)
            java -version 2>&1 | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1 || \
            java -version 2>&1 | head -1 | grep -oP '"(\d+)' | tr -d '"' | head -1
            ;;
        node)
            node --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        *)
            echo ""
            ;;
    esac
}

version_lt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ] && [ "$1" != "$2" ]
}

# =====================================================
# Instruções de instalação por SO
# =====================================================
install_instructions() {
    local tool="$1"

    case "$tool" in
        git)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y git" ;;
                rhel) log_fix "sudo dnf install -y git" ;;
                arch) log_fix "sudo pacman -S git" ;;
                alpine) log_fix "sudo apk add git" ;;
                macos) log_fix "brew install git  # ou: xcode-select --install" ;;
                *) log_fix "Acesse https://git-scm.com/downloads para instruções" ;;
            esac
            ;;

        gh)
            case "$OS" in
                debian|wsl)
                    log_fix_multi "$(cat <<'EOF'
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update && sudo apt-get install -y gh
gh auth login
EOF
)"
                    ;;
                rhel) log_fix "sudo dnf install -y gh && gh auth login" ;;
                arch) log_fix "sudo pacman -S github-cli && gh auth login" ;;
                macos) log_fix "brew install gh && gh auth login" ;;
                alpine)
                    log_fix_multi "$(cat <<'EOF'
wget https://github.com/cli/cli/releases/latest/download/gh_*_linux_amd64.tar.gz
tar -xzf gh_*_linux_amd64.tar.gz
sudo mv gh_*/bin/gh /usr/local/bin/
gh auth login
EOF
)"
                    ;;
                *) log_fix "Acesse https://cli.github.com/ para instruções de instalação" ;;
            esac
            ;;

        bash)
            case "$OS" in
                macos) log_fix "brew install bash  # macOS vem com Bash 3.x, recomendamos 5.x" ;;
                *) log_fix "Bash geralmente já vem instalado. Verifique sua instalação do sistema." ;;
            esac
            ;;

        curl)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y curl" ;;
                rhel) log_fix "sudo dnf install -y curl" ;;
                arch) log_fix "sudo pacman -S curl" ;;
                alpine) log_fix "sudo apk add curl" ;;
                macos) log_fix "brew install curl" ;;
                *) log_fix "Instale curl para seu sistema operacional" ;;
            esac
            ;;

        jq)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y jq" ;;
                rhel) log_fix "sudo dnf install -y jq" ;;
                arch) log_fix "sudo pacman -S jq" ;;
                macos) log_fix "brew install jq" ;;
                alpine) log_fix "sudo apk add jq" ;;
                *) log_fix "Acesse https://jqlang.github.io/jq/download/ para instruções" ;;
            esac
            ;;

        make)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y make" ;;
                rhel) log_fix "sudo dnf install -y make" ;;
                arch) log_fix "sudo pacman -S make" ;;
                macos) log_fix "xcode-select --install  # ou: brew install make" ;;
                alpine) log_fix "sudo apk add make" ;;
                *) log_fix "Instale o GNU Make para seu sistema operacional" ;;
            esac
            ;;

        docker)
            case "$OS" in
                debian|wsl)
                    log_fix_multi "$(cat <<'EOF'
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
EOF
)"
                    ;;
                rhel)
                    log_fix_multi "$(cat <<'EOF'
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl start docker && sudo systemctl enable docker
sudo usermod -aG docker $USER
EOF
)"
                    ;;
                arch) log_fix "sudo pacman -S docker docker-compose docker-buildx && sudo systemctl enable --now docker" ;;
                macos) log_fix "brew install --cask docker  # ou baixe Docker Desktop em https://www.docker.com/products/docker-desktop" ;;
                *) log_fix "Acesse https://docs.docker.com/engine/install/ para instruções" ;;
            esac
            ;;

        java)
            case "$OS" in
                debian|wsl) log_fix "sudo apt-get install -y openjdk-21-jdk" ;;
                rhel) log_fix "sudo dnf install -y java-21-openjdk-devel" ;;
                arch) log_fix "sudo pacman -S jdk21-openjdk" ;;
                macos) log_fix "brew install openjdk@21" ;;
                alpine) log_fix "sudo apk add openjdk21" ;;
                *) log_fix "Acesse https://adoptium.net/ para instruções" ;;
            esac
            ;;

        node)
            case "$OS" in
                debian|wsl)
                    log_fix_multi "$(cat <<'EOF'
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
corepack enable
EOF
)"
                    ;;
                rhel)
                    log_fix_multi "$(cat <<'EOF'
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
sudo dnf install -y nodejs
corepack enable
EOF
)"
                    ;;
                macos) log_fix "brew install node@22 && corepack enable" ;;
                *) log_fix "Acesse https://nodejs.org/ para instruções" ;;
            esac
            ;;

        *)
            log_fix "Instale '$tool' manualmente para seu sistema operacional"
            ;;
    esac
}

# =====================================================
# Verificações específicas do CI/CD
# =====================================================
check_gh_auth() {
    if gh auth status &>/dev/null; then
        local user
        user=$(gh auth status 2>&1 | grep -oP 'Logged in to github.com account \K\S+' | head -1 || echo "")
        if [ -n "$user" ]; then
            log_pass "GitHub CLI autenticado como: $user"
        else
            log_pass "GitHub CLI autenticado"
        fi
        return 0
    else
        log_fail "GitHub CLI não autenticado"
        log_fix "gh auth login --web"
        return 1
    fi
}

check_gh_permissions() {
    log_info "Verificando permissões do token GitHub..."

    # Verificar acesso à organização/usuário
    if gh api "users/$GITHUB_ORG" &>/dev/null; then
        log_pass "Acesso ao owner '$GITHUB_ORG' confirmado"
    else
        log_fail "Sem acesso ao owner '$GITHUB_ORG'"
        log_fix "Verifique se o token tem escopo 'repo' e 'admin:org'"
        return 1
    fi

    # Verificar escopo do token
    local scopes
    scopes=$(gh auth status 2>&1 | grep -oP "Token scopes: '\K[^']*" || echo "")
    if [ -n "$scopes" ]; then
        log_info "Escopos do token: $scopes"
    fi
}

check_repo_access() {
    local repo="$1"
    if gh repo view "$GITHUB_ORG/$repo" &>/dev/null; then
        log_pass "Acesso ao repositório: $repo"
        return 0
    else
        log_fail "Sem acesso ao repositório: $repo"
        log_fix "Verifique se o repositório existe e se você tem permissão: gh repo view $GITHUB_ORG/$repo"
        return 1
    fi
}

check_repo_environments() {
    local repo="$1"
    local envs
    envs=$(gh api "repos/$GITHUB_ORG/$repo/environments" --jq '.environments[].name' 2>/dev/null || echo "")

    local has_dev=false has_stg=false has_prd=false
    echo "$envs" | grep -q "development" && has_dev=true
    echo "$envs" | grep -q "staging" && has_stg=true
    echo "$envs" | grep -q "production" && has_prd=true

    if $has_dev && $has_stg && $has_prd; then
        log_pass "$repo: development ✓ | staging ✓ | production ✓"
    else
        local missing=""
        $has_dev || missing+="development "
        $has_stg || missing+="staging "
        $has_prd || missing+="production "
        log_warn "$repo: faltam environments: $missing"
        log_fix "make create-env REPO=$repo"
    fi
}

check_repo_workflows() {
    local repo="$1"
    local workflows
    workflows=$(gh api "repos/$GITHUB_ORG/$repo/actions/workflows" --jq '.workflows | length' 2>/dev/null || echo "0")

    if [ "$workflows" -gt 0 ]; then
        log_pass "$repo: $workflows workflow(s) configurado(s)"
    else
        log_warn "$repo: nenhum workflow encontrado"
        log_fix "make install REPO=$repo"
    fi
}

check_repo_secrets() {
    local repo="$1"
    local env="$2"
    local secrets
    secrets=$(gh api "repos/$GITHUB_ORG/$repo/environments/$env/secrets" --jq '.secrets | length' 2>/dev/null || echo "0")

    if [ "$secrets" -gt 0 ]; then
        log_pass "$repo ($env): $secrets secret(s) configurado(s)"
    else
        log_warn "$repo ($env): nenhum secret configurado"
        log_fix "make set-secrets ENV=$env FILE=configs/envs/${env}.secrets"
    fi
}

check_vars_file() {
    local env_name="$1"
    local file="$2"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local cicd_dir
    cicd_dir="$(dirname "$script_dir")"
    local full_path="$cicd_dir/$file"

    if [ ! -f "$full_path" ]; then
        log_fail "Arquivo de variáveis não encontrado: $file"
        log_fix "Crie o arquivo $file com as variáveis do ambiente $env_name"
        return 1
    fi

    local var_count
    var_count=$(grep -cE '^[A-Z_]+=' "$full_path" 2>/dev/null || echo "0")

    if [ "$var_count" -eq 0 ]; then
        log_warn "$file: nenhuma variável encontrada"
    else
        log_pass "$file: $var_count variável(is) definida(s)"
    fi

    # Verificar variáveis essenciais
    local essential_vars=("API_URL" "SPRING_PROFILE" "IMAGE_TAG" "VITE_API_URL")
    for var in "${essential_vars[@]}"; do
        if ! grep -q "^${var}=" "$full_path" 2>/dev/null; then
            log_warn "$file: variável essencial '$var' não encontrada"
        fi
    done
}

check_secrets_template() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local cicd_dir
    cicd_dir="$(dirname "$script_dir")"
    local template="$cicd_dir/configs/envs/secrets.template"

    if [ ! -f "$template" ]; then
        log_fail "Template de secrets não encontrado: configs/envs/secrets.template"
        return 1
    fi

    log_pass "Template de secrets encontrado"

    # Verificar se não há valores reais no template
    if grep -qE '=(?!CHANGE_ME).+' "$template" 2>/dev/null; then
        local real_values
        real_values=$(grep -cE '=(?!CHANGE_ME).+' "$template" 2>/dev/null || echo "0")
        if [ "$real_values" -gt 0 ]; then
            log_fail "ALERTA DE SEGURANÇA: Template de secrets contém $real_values valor(es) que não são 'CHANGE_ME'"
            log_fix "Substitua todos os valores reais por CHANGE_ME no arquivo configs/envs/secrets.template"
        fi
    else
        log_pass "Template de secrets não contém valores reais (seguro)"
    fi
}

check_line_endings() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local cicd_dir
    cicd_dir="$(dirname "$script_dir")"

    local crlf_count=0
    while IFS= read -r -d '' file; do
        if file "$file" | grep -q "CRLF"; then
            crlf_count=$((crlf_count + 1))
        fi
    done < <(find "$cicd_dir/scripts" -type f -name "*.sh" -print0 2>/dev/null)

    if [ "$crlf_count" -gt 0 ]; then
        log_fail "$crlf_count script(s) com final de linha CRLF (Windows)"
        case "$OS" in
            debian|wsl|rhel|arch)
                log_fix_multi "$(cat <<'EOF'
sudo apt-get install -y dos2unix  # ou: sudo dnf install dos2unix
find scripts/ -name "*.sh" -exec dos2unix {} \;
EOF
)"
                ;;
            macos)
                log_fix_multi "$(cat <<'EOF'
brew install dos2unix
find scripts/ -name "*.sh" -exec dos2unix {} \;
EOF
)"
                ;;
            *)
                log_fix "Converta os scripts para LF: sed -i 's/\r$//' scripts/**/*.sh"
                ;;
        esac
    else
        log_pass "Todos os scripts usam final de linha LF (Unix)"
    fi
}

check_git_config() {
    if git config --global core.autocrlf &>/dev/null; then
        local autocrlf
        autocrlf=$(git config --global core.autocrlf)
        if [ "$autocrlf" = "true" ]; then
            log_warn "git core.autocrlf=true pode causar problemas de CRLF"
            log_fix "git config --global core.autocrlf input"
        else
            log_pass "git core.autocrlf=$autocrlf"
        fi
    fi

    if [ -f ".gitattributes" ]; then
        log_pass ".gitattributes presente no repositório"
    else
        log_warn ".gitattributes não encontrado"
        log_fix "echo '* text=auto eol=lf' > .gitattributes && git add .gitattributes"
    fi
}

check_workflow_templates() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local cicd_dir
    cicd_dir="$(dirname "$script_dir")"

    local techs=("spring-boot" "react" "python" "node")
    for tech in "${techs[@]}"; do
        local ci_file="$cicd_dir/workflows/$tech/ci.yml"
        local cd_file="$cicd_dir/workflows/$tech/cd.yml"
        local template_file="$cicd_dir/templates/$tech/ci-cd.yml"

        if [ -f "$ci_file" ] && [ -f "$cd_file" ]; then
            log_pass "Workflows $tech: ci.yml ✓ | cd.yml ✓"
        else
            [ ! -f "$ci_file" ] && log_fail "Workflow ausente: workflows/$tech/ci.yml"
            [ ! -f "$cd_file" ] && log_fail "Workflow ausente: workflows/$tech/cd.yml"
        fi

        if [ -f "$template_file" ]; then
            log_pass "Template $tech: ci-cd.yml ✓"
        else
            log_warn "Template ausente: templates/$tech/ci-cd.yml"
        fi
    done

    # Docker generic
    if [ -f "$cicd_dir/workflows/docker/build-push.yml" ]; then
        log_pass "Workflow docker: build-push.yml ✓"
    else
        log_warn "Workflow ausente: workflows/docker/build-push.yml"
    fi
}

# =====================================================
# Validações por contexto
# =====================================================
validate_local() {
    log_header "Validação: Operador Local (CI/CD Management)"
    echo -e "  SO detectado: ${BOLD}$OS_LABEL${NC}"

    log_section "Ferramentas Essenciais"
    check_command "git" "Git" "2.30.0"
    check_command "gh" "GitHub CLI" "2.40.0"
    check_command "bash" "Bash" "4.0.0"
    check_command "curl" "cURL"
    check_command "jq" "jq (JSON processor)"
    check_command "make" "GNU Make"

    log_section "Autenticação GitHub"
    check_gh_auth
    check_gh_permissions

    log_section "Arquivos de Configuração"
    check_vars_file "development" "configs/envs/development.vars"
    check_vars_file "staging" "configs/envs/staging.vars"
    check_vars_file "production" "configs/envs/production.vars"
    check_secrets_template

    log_section "Workflow Templates"
    check_workflow_templates

    log_section "Integridade do Repositório"
    check_line_endings
    check_git_config
}

validate_pipeline() {
    log_header "Validação: Pipeline (GitHub Actions Runner)"
    echo -e "  SO detectado: ${BOLD}$OS_LABEL${NC}"

    log_section "Ferramentas de Build"
    check_command "docker" "Docker Engine" "24.0.0"
    check_command "git" "Git"
    check_command "curl" "cURL"

    log_section "Ferramentas por Tecnologia"
    echo -e "  ${CYAN}Spring Boot:${NC}"
    check_command "java" "  JDK" "21.0.0" || true

    echo -e "  ${CYAN}React/Node:${NC}"
    check_command "node" "  Node.js" "20.0.0" || true

    log_section "Autenticação"
    check_gh_auth || true

    log_section "Docker Registry"
    if docker info 2>/dev/null | grep -q "ghcr.io"; then
        log_pass "Autenticado no GitHub Container Registry (GHCR)"
    else
        log_warn "Não autenticado no GHCR"
        log_fix 'echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_ACTOR --password-stdin'
    fi
}

validate_full() {
    log_header "Validação Completa: CI/CD + Repositórios"
    echo -e "  SO detectado: ${BOLD}$OS_LABEL${NC}"

    # Primeiro, validar local
    log_section "Ferramentas Essenciais"
    check_command "git" "Git" "2.30.0"
    check_command "gh" "GitHub CLI" "2.40.0"
    check_command "bash" "Bash" "4.0.0"
    check_command "curl" "cURL"
    check_command "jq" "jq (JSON processor)"
    check_command "make" "GNU Make"

    log_section "Autenticação GitHub"
    if ! check_gh_auth; then
        echo ""
        echo -e "  ${RED}Autenticação necessária para validar repositórios remotos.${NC}"
        echo -e "  ${RED}Execute: gh auth login${NC}"
        return 1
    fi

    log_section "Acesso aos Repositórios"
    for repo in "${REPOS[@]}"; do
        check_repo_access "$repo" || true
    done

    log_section "GitHub Environments"
    for repo in "${REPOS[@]}"; do
        check_repo_environments "$repo" || true
    done

    log_section "Workflows Instalados"
    for repo in "${REPOS[@]}"; do
        check_repo_workflows "$repo" || true
    done

    log_section "Secrets (Amostragem - Staging)"
    for repo in "${REPOS[@]}"; do
        check_repo_secrets "$repo" "staging" || true
    done

    log_section "Arquivos de Configuração"
    check_vars_file "development" "configs/envs/development.vars"
    check_vars_file "staging" "configs/envs/staging.vars"
    check_vars_file "production" "configs/envs/production.vars"
    check_secrets_template

    log_section "Workflow Templates"
    check_workflow_templates

    log_section "Integridade do Repositório"
    check_line_endings
    check_git_config
}

# =====================================================
# Resumo final
# =====================================================
print_summary() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD} Resumo da Validação${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}✓ Passou:${NC}   $PASS_COUNT"
    echo -e "  ${YELLOW}⚠ Avisos:${NC}   $WARN_COUNT"
    echo -e "  ${RED}✗ Falhou:${NC}   $FAIL_COUNT"
    echo ""

    if [ "$FAIL_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}CI/CD pronto para operação!${NC}"
    elif [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "  ${YELLOW}${BOLD}CI/CD funcional, mas com avisos. Revise os itens acima.${NC}"
    else
        echo -e "  ${RED}${BOLD}CI/CD com problemas. Corrija os itens marcados com ✗ antes de prosseguir.${NC}"
    fi
    echo ""
}

# =====================================================
# Main
# =====================================================
usage() {
    echo -e "${BOLD}CondoHome CI/CD - Validador de Requisitos${NC}"
    echo ""
    echo "Uso: $0 <contexto>"
    echo ""
    echo "Contextos disponíveis:"
    echo "  local      - Máquina do desenvolvedor/operador (gh, jq, make, configs)"
    echo "  pipeline   - Runner do GitHub Actions (docker, java, node)"
    echo "  full       - Validação completa (local + acesso remoto a todos os repos)"
    echo ""
    echo "Exemplos:"
    echo "  $0 local"
    echo "  $0 pipeline"
    echo "  $0 full"
}

main() {
    local context="${1:-}"

    if [ -z "$context" ]; then
        usage
        exit 1
    fi

    detect_os

    case "$context" in
        local|dev|operator)
            validate_local
            ;;
        pipeline|runner|ci|actions)
            validate_pipeline
            ;;
        full|all|complete)
            validate_full
            ;;
        *)
            echo -e "${RED}Contexto desconhecido: $context${NC}"
            echo ""
            usage
            exit 1
            ;;
    esac

    print_summary

    if [ "$FAIL_COUNT" -gt 0 ]; then
        exit 1
    fi
    exit 0
}

main "$@"
