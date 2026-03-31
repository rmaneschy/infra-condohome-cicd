# Guia de Configuração de Novo Repositório

Este guia detalha o passo a passo para integrar um novo repositório (microserviço, frontend ou infraestrutura) à esteira de CI/CD da plataforma CondoHome, seguindo as melhores práticas estabelecidas no [Guia de Operacionalização](operationalization.md).

**Desenvolvido por:** Debug Software

---

## Pré-requisitos

Antes de iniciar, certifique-se de que seu ambiente local atende a todos os requisitos. Execute o validador:

```bash
cd infra-condohome-cicd
make validate CONTEXT=local
```

Se o validador apontar alguma falha (ex: falta do GitHub CLI, jq, ou autenticação), siga as instruções fornecidas na tela para corrigir antes de prosseguir.

---

## Passo 1: Registrar o Repositório no CI/CD

O primeiro passo é informar ao repositório de CI/CD qual é a tecnologia do seu novo repositório, para que ele saiba qual template de workflow aplicar.

1. Abra o arquivo `scripts/setup-workflows.sh`
2. Localize o array associativo `REPO_TECH` (por volta da linha 15)
3. Adicione o seu novo repositório e a tecnologia correspondente:

```bash
declare -A REPO_TECH=(
    # ... repositórios existentes ...
    ["ms-condohome-novo-servico"]="spring-boot" # Adicione esta linha
)
```

As tecnologias suportadas atualmente são: `spring-boot`, `react`, `python` e `node`.

---

## Passo 2: Criar os GitHub Environments

A plataforma utiliza 3 ambientes isolados (`development`, `staging`, `production`). Para criá-los no seu novo repositório com as regras de proteção corretas:

```bash
# Cria os ambientes no repositório
make create-env REPO=ms-condohome-novo-servico

# Configura as regras de proteção (aprovação manual para produção, etc)
make set-protection REPO=ms-condohome-novo-servico
```

Para verificar se os ambientes foram criados corretamente:
```bash
make env-list REPO=ms-condohome-novo-servico
```

---

## Passo 3: Configurar Environment Variables (Não-sensíveis)

As variáveis de ambiente definem o comportamento da aplicação em cada ambiente (URLs, portas, profiles).

1. Verifique se o seu novo serviço precisa de variáveis específicas nos arquivos em `configs/envs/` (`development.vars`, `staging.vars`, `production.vars`).
2. Se precisar, adicione-as aos arquivos.
3. Injete as variáveis nos ambientes do GitHub:

```bash
# O script irá injetar as variáveis em TODOS os repositórios registrados,
# incluindo o seu novo repositório.
make set-vars-dev
make set-vars-staging
make set-vars-prod
```

---

## Passo 4: Configurar Environment Secrets (Sensíveis)

Segredos como senhas de banco de dados, chaves de API e tokens JWT **nunca** devem ser commitados.

1. Crie arquivos locais de secrets baseados no template (se ainda não os tiver):
```bash
cp configs/envs/secrets.template configs/envs/dev.secrets
cp configs/envs/secrets.template configs/envs/staging.secrets
cp configs/envs/secrets.template configs/envs/prod.secrets
```

2. Preencha os arquivos `.secrets` com os valores reais para cada ambiente.

3. Injete os segredos nos ambientes do GitHub:
```bash
make set-secrets ENV=development FILE=configs/envs/dev.secrets
make set-secrets ENV=staging FILE=configs/envs/staging.secrets
make set-secrets ENV=production FILE=configs/envs/prod.secrets
```

---

## Passo 5: Instalar o Workflow de CI/CD

Agora que os ambientes, variáveis e segredos estão configurados, instale o workflow que fará a ponte entre o seu repositório e os pipelines centralizados.

```bash
make install REPO=ms-condohome-novo-servico
```

Este comando irá:
1. Identificar a tecnologia do repositório (conforme configurado no Passo 1).
2. Copiar o template correto de `templates/<tecnologia>/ci-cd.yml`.
3. Substituir os placeholders (como `<SERVICE_NAME>`) pelo nome do seu repositório.
4. Salvar o arquivo em `../ms-condohome-novo-servico/.github/workflows/ci-cd.yml`.

---

## Passo 6: Commitar e Validar

O último passo é commitar o workflow no seu novo repositório e validar a execução.

1. Vá para o diretório do seu novo repositório:
```bash
cd ../ms-condohome-novo-servico
```

2. Faça o commit do novo workflow:
```bash
git add .github/workflows/ci-cd.yml
git commit -m "ci: add centralized ci/cd workflow"
git push origin main # ou a branch que estiver utilizando
```

3. Acompanhe a execução na aba **Actions** do seu repositório no GitHub.

### Validação do Fluxo

Para garantir que tudo está funcionando conforme a arquitetura:
- Um push na branch `develop` deve acionar o deploy automático para o ambiente `development`.
- Um push na branch `main` ou `master` deve acionar o deploy automático para o ambiente `staging`.
- O deploy para `production` deve ficar aguardando aprovação manual na interface do GitHub.

---

## Checklist de Conclusão

- [ ] Repositório adicionado ao `REPO_TECH` no script `setup-workflows.sh`
- [ ] Environments criados (`development`, `staging`, `production`)
- [ ] Regras de proteção configuradas (wait timer, reviewers)
- [ ] Variáveis de ambiente injetadas
- [ ] Segredos injetados
- [ ] Workflow instalado e commitado
- [ ] Pipeline executado com sucesso no GitHub Actions
