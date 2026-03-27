# CondoHome Platform - CI/CD Pipelines

Este repositório centraliza todos os workflows do GitHub Actions, templates e scripts de automação de CI/CD para a plataforma **CondoHome**.

A abordagem utilizada é a de **Reusable Workflows** (Workflows Reutilizáveis), o que significa que a lógica de build, teste e deploy fica centralizada aqui, e os repositórios dos microserviços apenas "chamam" estes workflows. Isso garante padronização e facilita a manutenção.

## Estrutura do Repositório

| Diretório | Descrição |
|---|---|
| `workflows/` | Workflows reutilizáveis separados por tecnologia (Spring Boot, React, Python, Node, Docker) |
| `templates/` | Arquivos `ci-cd.yml` prontos para serem copiados para os repositórios finais |
| `scripts/` | Scripts de automação para instalar workflows e gerenciar releases |
| `Makefile` | Atalhos rápidos para os comandos |

## Tecnologias Suportadas

### 1. Spring Boot (Java 21 + Maven)
- **CI:** Checkout, Setup JDK 21, Cache Maven, Build, Test, Upload Artifacts
- **CD:** Build JAR, Setup Docker Buildx, Login GHCR, Build & Push Docker Image (com tags `latest` e `sha`)

### 2. React / Vite (Node.js + pnpm)
- **CI:** Checkout, Setup pnpm, Install, Lint, Type-check, Build, Test
- **CD:** Build & Push Docker Image para GHCR **ou** Deploy estático para GitHub Pages

### 3. Python (pip / poetry / uv)
- **CI:** Checkout, Setup Python, Install dependencies, Lint (Ruff), Type-check (mypy), Test (pytest + coverage)
- **CD:** Build & Push Docker Image para GHCR

### 4. Node.js (n8n custom nodes / npm packages)
- **CI:** Checkout, Setup pnpm, Install, Lint, Build, Test
- **CD:** Publish para GitHub Packages (npm registry)

## Como Usar nos Repositórios

Você não precisa copiar a lógica inteira para cada repositório. Basta usar o script de instalação automatizada:

```bash
# Instalar workflow em um repositório específico
make install REPO=ms-condohome-register

# Instalar workflows em TODOS os repositórios da plataforma
make install-all
```

O script irá identificar a tecnologia do repositório, copiar o template correto para `.github/workflows/ci-cd.yml` e substituir os placeholders (como `<SERVICE_NAME>`).

### Exemplo de uso em um microserviço (Spring Boot)

O arquivo `.github/workflows/ci-cd.yml` gerado no repositório ficará assim:

```yaml
name: CI/CD

on:
  push:
    branches: [main, master, develop]
  pull_request:
    branches: [main, master]

jobs:
  ci:
    uses: rmaneschy/ms-condohome-cicd/.github/workflows/spring-boot-ci.yml@main
    with:
      java-version: '21'

  cd:
    needs: ci
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master'
    uses: rmaneschy/ms-condohome-cicd/.github/workflows/spring-boot-cd.yml@main
    with:
      image-name: ms-condohome-register
    secrets:
      GHCR_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Gestão de Releases

Para criar uma release semântica (ex: `v1.0.0`) em qualquer repositório da plataforma, com geração automática de changelog:

```bash
make release REPO=ms-condohome-register VERSION=v1.0.0
```

## Container Registry

Todas as imagens Docker são publicadas no **GitHub Container Registry (GHCR)** sob a organização/usuário `rmaneschy`.

Formato da imagem: `ghcr.io/rmaneschy/<nome-do-repo>:<tag>`

---
*Desenvolvido por Debug Software*
