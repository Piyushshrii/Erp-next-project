output "static_ip" {
  description = "Reserved static IP address"
  value       = google_compute_address.erp_static.address
}

output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "kube_endpoint" {
  value = google_container_cluster.primary.endpoint
}
