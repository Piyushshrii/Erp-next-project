resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  # Secondary ranges must match the cluster ip_allocation_policy names below
  secondary_ip_range {
    range_name    = "${var.cluster_name}-pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "${var.cluster_name}-svc"
    ip_cidr_range = "10.30.0.0/20"
  }
}

# Allow internal communication within subnet (adjust if you want stricter rules)
resource "google_compute_firewall" "internal" {
  name    = "${var.vpc_name}-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  source_ranges = [var.subnet_cidr]
}

# Allow HTTPS (for ingress). You can narrow this later.
resource "google_compute_firewall" "https" {
  name    = "${var.vpc_name}-allow-https"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = ["0.0.0.0/0"]
}
