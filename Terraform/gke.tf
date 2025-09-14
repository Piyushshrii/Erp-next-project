#########################
# GKE Cluster
#########################
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.cluster_name}-pods"
    services_secondary_range_name = "${var.cluster_name}-svc"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false  # ✅ allow public master endpoint
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = local.my_public_ip
      display_name = "piyush-laptop"
    }
  }
}

#########################
# Node Pool
#########################
resource "google_container_node_pool" "primary_nodes" {
  name               = "primary-node-pool"
  cluster            = google_container_cluster.primary.name
  location           = var.zone
  initial_node_count = var.cluster_node_count

  node_config {
    machine_type = var.node_machine_type

    # ✅ Added these to avoid SSD quota issue
    disk_type    = "pd-standard"   # use standard disks instead of SSD
    disk_size_gb = 30              # reduce disk size per node

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    tags = ["erpnext-node"]
  }
}
