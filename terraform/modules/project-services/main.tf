variable "project_id" {
  type = string
}

variable "apis" {
  description = "APIs do Google Cloud que precisam estar habilitadas antes de qualquer outro recurso."
  type        = list(string)
}

resource "google_project_service" "this" {
  for_each = toset(var.apis)

  project = var.project_id
  service = each.value

  # Nao desabilita a API no destroy: desabilitar container.googleapis.com
  # derruba clusters de outros ambientes no mesmo projeto.
  disable_on_destroy = false
}

output "enabled" {
  description = "Usado como depends_on pelos demais modulos."
  value       = [for s in google_project_service.this : s.id]
}
