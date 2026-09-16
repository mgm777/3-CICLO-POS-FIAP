# Bootstrap: cria o bucket GCS que guarda o terraform.tfstate remoto da
# infraestrutura principal.
#
# Este modulo e o unico com state LOCAL — nao da para guardar o state do
# bucket dentro do proprio bucket. Rode uma vez, depois use o bucket em
# ../backend.tf.
#
#   terraform init && terraform apply -var project_id=fiap-3-508723

terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

resource "google_storage_bucket" "tfstate" {
  name          = "${var.project_id}-tfstate"
  location      = var.region
  force_destroy = false

  # Guarda o historico do state: permite voltar atras se um apply corromper
  # o arquivo (equivalente ao versioning do bucket S3).
  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  # Bloqueia qualquer tentativa de tornar o state publico.
  public_access_prevention = "enforced"

  lifecycle_rule {
    condition {
      num_newer_versions = 20
    }
    action {
      type = "Delete"
    }
  }
}

output "bucket_name" {
  description = "Use este valor no bloco backend \"gcs\" de ../backend.tf."
  value       = google_storage_bucket.tfstate.name
}
