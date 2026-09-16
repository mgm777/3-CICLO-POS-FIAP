# --- ArgoCD ------------------------------------------------------------------
# Instalado via Helm no proprio apply da infraestrutura: "se nao esta no
# codigo, nao existe". Os providers kubernetes/helm usam o token de curta
# duracao do gcloud (ver versions.tf).

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [module.gke]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # ClusterIP + port-forward basta para a demonstracao; trocar para
  # LoadBalancer se quiser expor a UI publicamente.
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # O repositorio GitOps e publico: o ArgoCD nao precisa de credencial de git.
  timeout = 900
}

# Namespace onde os 5 microsservicos rodam. Criado aqui (e nao pelo ArgoCD)
# porque as KSAs com anotacao de Workload Identity precisam existir antes do
# primeiro sync.
resource "kubernetes_namespace" "togglemaster" {
  metadata {
    name = var.k8s_namespace
  }

  depends_on = [module.gke]
}

# Uma KSA por servico, anotada com a GSA correspondente — completa o par de
# Workload Identity configurado no modulo iam.
resource "kubernetes_service_account" "app" {
  for_each = toset(local.services)

  metadata {
    name      = "${each.value}-ksa"
    namespace = kubernetes_namespace.togglemaster.metadata[0].name

    annotations = {
      "iam.gke.io/gcp-service-account" = module.iam.service_account_emails[each.value]
    }
  }
}
