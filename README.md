# mechanical-hub-infra-base

Recursos de base do projeto mechanical-hub: VPC, subnets, Internet Gateway, route
tables, os security groups (`alb`, `app`, `rds`, `lambda_auth`) e o repositorio ECR.

A sessao do AWS Academy encerra a cada 4h, entao este repo e destruido e recriado
diariamente (`terraform apply` no inicio da sessao, `terraform destroy` no fim),
pelo `pipeline.conf` igual ao repo da aplicacao. Por isso o ECR usa
`force_delete = true`, igual ao repo da aplicacao: o destroy diario precisa apagar
o repositorio mesmo com imagens publicadas dentro, sem falhar.

## Por que os security groups estao aqui

Hoje (no repo da aplicacao) `rds.tf` referencia o security group do cluster EKS
diretamente. A AWS nao deixa apagar um SG referenciado por regra de outro security
group, entao destruir um repo de infra de ciclo curto antes de outro falharia no meio,
com recursos parcialmente destruidos.

Com os SGs na base, os repos de ciclo curto (infra-k8s, infra-database, auth-lambda,
api-gateway) apenas consomem via **data source** — nunca criam o proprio SG. O
conflito e eliminado, nao contornado.

| SG            | Regra                                                  |
|---------------|----------------------------------------------------------|
| alb           | ingress 80/443 de `0.0.0.0/0`                          |
| app           | ingress 30080 com origem no SG do `alb`                |
| rds           | ingress 5432 com origem no SG do `app` e do `lambda_auth` |
| lambda_auth   | egress 5432 para o SG do `rds` (sem ingress proprio — nada precisa iniciar conexao com a Lambda por IP) |

O SG do ALB fica aqui mesmo o ALB em si morando no repo do API Gateway: se nascesse
la, o SG do `app` (que esta na base) teria que referenciar um SG de outro repo,
recriando a dependencia cruzada que este repo existe para eliminar. O mesmo raciocinio
vale pro `lambda_auth`: ele e criado aqui, pronto, e o repo `auth-lambda` so o busca
via data source e anexa na funcao — sem nunca precisar que a base "olhe pra frente"
pra Lambda.

Atencao tecnica: `lambda_auth` e `rds` se referenciam nos dois sentidos (rds libera
entrada do lambda_auth; lambda_auth libera saida pro rds). Regras inline dos dois
lados geram um ciclo que o Terraform rejeita — por isso a regra de saida do
`lambda_auth` esta declarada como um `aws_security_group_rule` solto, e nao inline
dentro do resource do SG.

## Descoberta entre repos

Via **data source**, nao via remote state. Data source consulta o estado real na AWS;
remote state le o que o Terraform acha que existe. Exemplo de lookup em outro repo:

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

## Atencao: ECR e credenciais

A `LabRole` tem acesso **somente leitura** ao ECR. O push da imagem funciona porque a
pipeline usa as credenciais do usuario `voclabs` (que tem escrita) — nunca fazer push
assumindo a `LabRole`.

## Ordem de execucao

Mesmo padrao operacional do repo da aplicacao: um arquivo commitado (`infra/pipeline.conf`)
decide o que a pipeline faz, e todo push em `main` dispara a esteira.

1. Configurar no repositorio os secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e
   `AWS_SESSION_TOKEN` com as credenciais do usuario `voclabs`.
2. No inicio da sessao do AWS Academy, garantir `infra/pipeline.conf` com
   `DESTROY=false` e dar push/merge em `main` (ou rodar `workflow_dispatch`
   manualmente).
3. A pipeline cria (se ainda nao existir) e ativa o versionamento do bucket
   `mechanical-hub-tfstate`, inicializa o backend na key
   `infra-base/terraform.tfstate` e aplica `vpc.tf`, `sg.tf` e `ecr.tf`.
4. Conferir os outputs publicados ao final do job (`terraform output`) ou na aba do
   workflow.
5. Os repos de ciclo curto (infra-k8s, infra-database, api-gateway) passam a consumir
   estes recursos via data source — nao duplicar a criacao de VPC, SGs ou ECR neles.
6. Antes da sessao do AWS Academy encerrar (janela de 4h), mudar
   `infra/pipeline.conf` para `DESTROY=true` e dar push em `main` — a pipeline roda
   `terraform destroy` (o ECR usa `force_delete = true`, entao apaga mesmo com
   imagens publicadas).

> Nota: a criacao do bucket de state (com `aws s3 mb ... || true`, sem versionamento)
> hoje esta duplicada no `main.yml` do repo da aplicacao. Ela deve ser removida de la
> depois que esta pipeline assumir a criacao/versionamento do bucket, para nao
> duplicar em cada repo.

## Outputs publicados

| Output               | Descricao                              |
|-----------------------|-----------------------------------------|
| `vpc_id`              | ID da VPC                              |
| `public_subnet_ids`   | IDs das subnets publicas               |
| `private_subnet_ids`  | IDs das subnets privadas               |
| `alb_sg_id`           | ID do security group do ALB            |
| `app_sg_id`           | ID do security group da aplicacao      |
| `rds_sg_id`           | ID do security group do RDS            |
| `lambda_auth_sg_id`   | ID do security group da Lambda de autenticacao |
| `ecr_url`             | URL do repositorio ECR                 |

## Pipelines

- `pipeline-infra-feature.yml`: dispara em push para `feature/*`. Roda
  `terraform fmt -check`, `init -backend=false` e `validate` — checagem de
  sintaxe/consistencia do HCL, sem credenciais AWS e sem depender do bucket
  do state ja existir. Abre PR automatico para `main` se tudo passar —
  equivalente ao `feature.yml` do repo da aplicacao (build+test), so que
  validando a infra em vez de compilar Java.
- `pipeline-infra-main.yml`: dispara em push para `main` (ou
  `workflow_dispatch`). Cria/versiona o bucket do state, roda `terraform
  init` contra o backend real e le `infra/pipeline.conf` pra aplicar ou
  destruir conforme `DESTROY` — equivalente ao `main.yml` do repo da
  aplicacao. E o unico ponto que fala com a AWS de verdade; por isso nao
  repete o `validate` que ja rodou na feature.

## Estrutura

```
mechanical-hub-infra-base/
├── .github/workflows/
│   ├── pipeline-infra-feature.yml
│   └── pipeline-infra-main.yml
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
