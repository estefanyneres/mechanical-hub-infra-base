# mechanical-hub-infra-base

Camada de infraestrutura mais fundamental do projeto mechanical-hub: é o primeiro
repositório a ser aplicado, e todos os outros dependem dos recursos que ele cria para funcionar.

Recursos de base do projeto mechanical-hub: VPC, subnets, Internet Gateway, route
tables, os security groups (`alb`, `app`, `rds`, `lambda_auth`) e os repositórios
ECR — o do monolito legado e, desde a Fase 4, mais 4 (`mechanical-hub-core-service`,
`mechanical-hub-repair-service`, `mechanical-hub-stock-service`,
`mechanical-hub-billing-service`), um por microsserviço.

## Tecnologias

- **Terraform** (`hashicorp/aws ~> 5.0`) — toda a infraestrutura deste repo.
- **AWS**: VPC, subnets, Internet Gateway, route tables, Security Groups, 5 repositórios ECR (monolito + 4 microsserviços).
- **GitHub Actions** — pipelines de validação (feature) e apply/destroy (main).
- **S3** — backend remoto do state Terraform (`mechanical-hub-tfstate`), com locking nativo (`use_lockfile`) e versionamento, criado e gerenciado pela própria pipeline deste repo.

## Diagrama de arquitetura

![Infraestrutura AWS - Fase 3](docs/desenhos/mechanical-hub-infraestrutura-fase-03.jpg)

## Passos para execução e deploy

**Este repo não depende de nenhum outro — é o primeiro a ser aplicado.** Todos os
demais repos de infraestrutura (`infra-k8s`, `infra-database`, `auth-lambda`,
`api-gateway`) dependem dele, consumindo VPC/subnets/security groups/ECR via data
source. Ordem completa de subida, do primeiro ao último: **infra-base → infra-k8s →
infra-database → auth-lambda → api-gateway** (e só depois o repo da aplicação,
`mechanical-hub`, que precisa do EKS e do RDS no ar). Para derrubar tudo ao fim da
sessão do AWS Academy, a ordem é a inversa: api-gateway → auth-lambda →
infra-database → infra-k8s → infra-base.

![Ordem de apply e destroy entre os repositorios](docs/desenhos/mechanical-hub-apply-destroy-repos-fase-03.jpg)

Mesmo padrão operacional do repo da aplicação: um arquivo commitado (`infra/pipeline.conf`)
decide o que a pipeline faz, e todo push em `main` dispara a esteira.

1. Configurar no repositório os secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e
   `AWS_SESSION_TOKEN` com as credenciais AWS Academy.
2. No início da sessão do AWS Academy, garantir `infra/pipeline.conf` com
   `DESTROY=false`, commitar na sua branch feature e depois merge em `main`.
3. A pipeline cria (se ainda não existir) e ativa o versionamento do bucket
   `mechanical-hub-tfstate`, inicializa o backend na key
   `infra-base/terraform.tfstate` e aplica `vpc.tf`, `sg.tf` e `ecr.tf`.
4. Conferir os outputs publicados ao final do job (`terraform output`) ou na aba do
   workflow.
5. Os repos de ciclo curto (infra-k8s, infra-database, api-gateway) passam a consumir
   estes recursos via data source — não duplicar a criação de VPC, SGs ou ECR neles.
6. Antes da sessão do AWS Academy encerrar (janela de 4h), mudar
   `infra/pipeline.conf` para `DESTROY=true` e subir até a branch `main` — a pipeline roda
   `terraform destroy`.

## Decisões arquiteturais relacionadas

RFCs e ADRs ficam centralizados no repo da aplicação, para não duplicar/desincronizar entre os 6 repositórios. As diretamente relevantes para este repo:

- [RFC-001 — Escolha da nuvem e restrições do AWS Academy Learner Lab](https://github.com/estefanyneres/mechanical-hub/blob/main/src/docs/fase3/documentacao/rfcs.md)
- [RFC-005 — Credenciais estáticas renovadas por sessão (OIDC inviável)](https://github.com/estefanyneres/mechanical-hub/blob/main/src/docs/fase3/documentacao/rfcs.md)
- [ADR-002 — Descoberta entre repositórios via data source](https://github.com/estefanyneres/mechanical-hub/blob/main/src/docs/fase3/documentacao/adrs.md)
- [ADR-003 — Security groups centralizados em `infra-base`](https://github.com/estefanyneres/mechanical-hub/blob/main/src/docs/fase3/documentacao/adrs.md)
- [ADR-005 — Separação de repositórios por taxa de mudança](https://github.com/estefanyneres/mechanical-hub/blob/main/src/docs/fase3/documentacao/adrs.md)

## Descoberta entre repos

Via **data source**, não via remote state. Data source consulta o estado real na AWS;
remote state lê o que o Terraform acha que existe. Exemplo de lookup em outro repo:

```hcl
data "aws_vpc" "base" {
  filter {
    name   = "tag:Name"
    values = ["mechanical-hub"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.base.id]
  }
  tags = { Tier = "private" }
}

data "aws_security_group" "app" {
  filter {
    name   = "tag:Name"
    values = ["mechanical-hub-app-sg"]
  }
}

data "aws_ecr_repository" "app" {
  name = "mechanical-hub"
}
```

## Outputs publicados

| Output               | Descrição                              |
|-----------------------|-----------------------------------------|
| `vpc_id`              | ID da VPC                              |
| `public_subnet_ids`   | IDs das subnets públicas               |
| `private_subnet_ids`  | IDs das subnets privadas               |
| `alb_sg_id`           | ID do security group do ALB            |
| `app_sg_id`           | ID do security group da aplicação      |
| `rds_sg_id`           | ID do security group do RDS            |
| `lambda_auth_sg_id`   | ID do security group da Lambda de autenticação |
| `ecr_url`             | URL do repositório ECR do monolito legado |
| `microservices_ecr_urls` | URLs dos 4 repositórios ECR dos microsserviços (mapa, por nome) |

## Pipelines

- `pipeline-infra-feature.yml`: dispara em push para `feature/*`. Roda
  `terraform fmt -check`, `init -backend=false` e `validate` — checagem de
  sintaxe/consistência do HCL, sem credenciais AWS e sem depender do bucket
  do state já existir. Abre PR automático para `main` se tudo passar —
  equivalente ao `feature.yml` do repo da aplicação (build+test), só que
  validando a infra em vez de compilar Java.
- `pipeline-infra-main.yml`: dispara em push para `main` (ou
  `workflow_dispatch`). Cria/versiona o bucket do state, roda `terraform
  init` contra o backend real e lê `infra/pipeline.conf` pra aplicar ou
  destruir conforme `DESTROY` — equivalente ao `main.yml` do repo da
  aplicação. É o único ponto que fala com a AWS de verdade; por isso não
  repete o `validate` que já rodou na feature.

## Estrutura

```
mechanical-hub-infra-base/
├── .github/workflows/
│   ├── pipeline-infra-feature.yml
│   └── pipeline-infra-main.yml
├── docs/
│   ├── desenhos/
│   │   ├── mechanical-hub-infraestrutura-fase-03.jpg
│   │   └── mechanical-hub-apply-destroy-repos-fase-03.jpg
├── infra/
│   ├── providers.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── sg.tf
│   ├── ecr.tf
│   ├── outputs.tf
│   └── pipeline.conf
├── .gitignore
└── README.md
```
