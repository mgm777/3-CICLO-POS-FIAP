# Requisito de Estado (Fase 3): o terraform.tfstate NAO fica local.
#
# O bloco backend nao aceita variaveis — o bucket abaixo e criado pelo
# modulo terraform/bootstrap (rode-o primeiro). Se voce mudar o nome do
# projeto, ajuste aqui tambem.
terraform {
  backend "gcs" {
    bucket = "fiap-3-508723-tfstate"
    prefix = "fase3/togglemaster"
  }
}
