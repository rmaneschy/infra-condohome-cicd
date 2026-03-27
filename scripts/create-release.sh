#!/bin/bash
# =====================================================
# CondoHome - Create Release
# Cria uma release com tag semântica em um repositório
# =====================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GITHUB_ORG="rmaneschy"

usage() {
    echo -e "${BLUE}CondoHome - Create Release${NC}"
    echo ""
    echo "Uso: $0 <repo> <version> [notes]"
    echo ""
    echo "Exemplos:"
    echo "  $0 ms-condohome-register v1.0.0"
    echo "  $0 ms-condohome-register v1.1.0 'Adicionado suporte a veículos'"
    echo ""
}

create_release() {
    local repo="$1"
    local version="$2"
    local notes="${3:-Release $version}"

    echo -e "${BLUE}Criando release $version para $repo...${NC}"

    # Gerar notas de release automaticamente
    gh release create "$version" \
        --repo "$GITHUB_ORG/$repo" \
        --title "$repo $version" \
        --notes "$notes" \
        --generate-notes

    echo -e "${GREEN}Release $version criada com sucesso!${NC}"
    echo -e "URL: https://github.com/$GITHUB_ORG/$repo/releases/tag/$version"
}

if [ -z "$1" ] || [ -z "$2" ]; then
    usage
    exit 1
fi

create_release "$1" "$2" "$3"
