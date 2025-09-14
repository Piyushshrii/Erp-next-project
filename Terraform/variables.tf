variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "erpnext-vpc"
}

variable "subnet_name" {
  description = "subnet name"
  type        = string
  default     = "erpnext-subnet"
}

variable "subnet_cidr" {
  description = "primary subnet CIDR"
  type        = string
  default     = "10.10.0.0/20"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "erpnext-cluster"
}

variable "cluster_node_count" {
  description = "node pool initial node count"
  type        = number
  default     = 3
}

variable "node_machine_type" {
  description = "node machine type"
  type        = string
  default     = "e2-standard-4"
}

variable "static_ip_name" {
  description = "name for reserved static IP"
  type        = string
  default     = "erpnext-static-ip"
}

variable "domain" {
  description = "primary domain"
  type        = string
}

variable "email" {
  description = "email for cert-manager"
  type        = string
}

variable "credentials_file" {
  description = "Path to GCP Service Account JSON key file"
  type        = string
}
