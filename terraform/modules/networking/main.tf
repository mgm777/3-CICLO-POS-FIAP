resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.name_prefix}-subnet"
  network       = google_compute_network.vpc.id
  region        = var.region
  ip_cidr_range = var.subnet_cidr

  # Permite que nodes sem IP externo alcancem APIs do Google (Artifact
  # Registry, Cloud Logging) sem passar pela internet publica.
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# --- Private Service Access --------------------------------------------------
# Cloud SQL e Memorystore sao servicos gerenciados que vivem em um projeto da
# Google; o acesso privado a eles se da por VPC peering sobre esta faixa
# reservada. E o equivalente GCP de manter o RDS/ElastiCache em subnet privada.
resource "google_compute_global_address" "private_service_range" {
  name          = "${var.name_prefix}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}

# --- Cloud Router + Cloud NAT ------------------------------------------------
# Saida para a internet para os nodes do GKE (pull de imagens de base,
# download de modulos) sem expor IP publico em cada node.
resource "google_compute_router" "router" {
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.name_prefix}-nat"
  router = google_compute_router.router.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
