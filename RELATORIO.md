# Relatório de Entrega — Tech Challenge Fase 3

## Participantes

- Guilherme Maurício Martins — RM `<PREENCHER>`

## Links

- **Repositório:** https://github.com/mgm777/togglemaster-gcp-fase3
- **Vídeo de demonstração:** `<PREENCHER>`
- **Documentação:** [README.md](./README.md) do próprio repositório

## Provedor de nuvem

O enunciado descreve a infraestrutura em AWS. A Fase 2 deste grupo foi entregue
no **Google Cloud**, e a Fase 3 é a continuação direta daquele ambiente — por
isso toda a automação foi feita em GCP, com os equivalentes diretos de cada
serviço pedido (a tabela de correspondência está no README). A restrição de IAM
do AWS Academy não se aplica: o projeto é uma conta pessoal com billing próprio,
o que corresponde à **Opção B** do enunciado, então as service accounts e os
papéis de IAM são todos criados via Terraform.

## Resumo dos desafios encontrados e decisões tomadas

### 1. State remoto e o problema do ovo e da galinha

O bucket que guarda o `terraform.tfstate` não pode ser criado pelo mesmo
Terraform que o usa como backend. A solução foi um módulo `terraform/bootstrap`
separado, com state local, cujo único trabalho é criar o bucket GCS versionado.
A partir daí, toda a infraestrutura principal usa `backend "gcs"` — o state sai
da máquina do desenvolvedor, que era exatamente a origem dos "conflitos de
versão" descritos no enunciado.

### 2. Acabar com as credenciais em arquivo de texto

Três camadas, nenhuma delas com segredo de longa duração em disco:

- As senhas do Cloud SQL são geradas por `random_password` e gravadas no
  **Secret Manager** pelo próprio Terraform. Ninguém digita nem vê a senha.
- Os pods usam **Workload Identity**: cada Deployment roda com uma KSA anotada
  para uma Google Service Account com permissão mínima (`cloudsql.client`,
  `pubsub.publisher`, `datastore.user`…). Nenhuma chave JSON dentro do container.
- O GitHub Actions autentica por **Workload Identity Federation (OIDC)**: troca
  o token do próprio workflow por um token de curta duração do GCP, com uma
  `attribute_condition` que restringe a federação a este repositório. Não existe
  `GCP_SA_KEY` nos secrets do repositório.

### 3. A regra de bloqueio do pipeline

O enunciado pede que uma vulnerabilidade **CRÍTICA** derrube o pipeline. Uma
primeira versão bloqueava também em `HIGH`, o que quebrava a esteira em CVEs
transitórios de imagem base sem correção disponível e tornaria a entrega
impossível de demonstrar. A decisão foi: `CRITICAL` bloqueia (`exit-code: 1`),
`HIGH` é escaneado e reportado no log sem falhar. Como `docker-build-push`
declara `needs: [build-test, lint, security-scan]`, uma CVE crítica impede que a
imagem chegue a ser construída — não só que seja publicada.

### 4. Ordem de criação entre Terraform e ArgoCD

Os `kubernetes_service_account` com anotação de Workload Identity precisam
existir antes do primeiro sync do ArgoCD, senão os pods sobem sem identidade e
falham ao falar com Cloud SQL/Pub/Sub. Por isso o namespace e as KSAs são
criados pelo Terraform (providers `kubernetes`/`helm` autenticados com o token
de curta duração do `google_client_config`), e os Deployments/Services ficam no
`gitops/`, sob responsabilidade do ArgoCD.

### 5. Pub/Sub e a "poison pill"

A subscription ganhou `dead_letter_policy` com 5 tentativas e um tópico de DLQ.
Sem isso, uma mensagem malformada ficaria em redelivery infinito — problema que
já existia na versão Fase 2 do worker.

### 6. `<PREENCHER com o que realmente aconteceu no apply>`

<Ex.: quota de CPUs da região, tempo de criação do peering de Private Service
Access, ajuste de versão do chart do ArgoCD, primeiro sync OutOfSync etc.>

## Estimativa de custos

`<Inserir print da estimativa — Google Cloud Pricing Calculator ou a tela de
Billing → Reports do projeto.>`

Composição aproximada do ambiente (`us-central1`, 24x7):

| Recurso | Configuração | Estimativa |
|---|---|---|
| GKE — node pool | 2x `e2-standard-2` | ~US$ 97/mês |
| GKE — cluster management fee | zonal | US$ 0 (primeiro cluster zonal é gratuito) |
| Cloud SQL | 3x `db-f1-micro`, 10 GB | ~US$ 30/mês |
| Memorystore Redis | BASIC, 1 GB | ~US$ 35/mês |
| Cloud NAT | 1 gateway | ~US$ 32/mês |
| Artifact Registry | < 10 GB | ~US$ 1/mês |
| Pub/Sub + Firestore | volume de demonstração | dentro do free tier |

> Para não queimar crédito depois da entrega: `terraform destroy` derruba tudo.
