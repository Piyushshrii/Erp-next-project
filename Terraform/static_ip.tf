resource "google_compute_address" "erp_static" {
  name   = var.static_ip_name
  region = var.region
}
