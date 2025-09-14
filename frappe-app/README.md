# 🚀 ERPNext + HRMS — Production GKE Deployment (Helm + NFS + Ingress)

This repository shows a production-grade deployment of **Frappe / ERPNext** with the **HRMS** app on **Google Kubernetes Engine (GKE)** using Helm charts.  
Key production patterns included:

- Build a custom Docker image that bundles ERPNext + HRMS
- Shared `sites/` directory using an **NFS** provisioner (ReadWriteMany)
- In-cluster MariaDB (Bitnami) or option to use external DB
- NGINX Ingress Controller exposed on a reserved static IP (Terraform output)
- Automatic site creation via Helm `job-create-site` and installing `hrms` inside the job
- Optional Argo CD for GitOps

> **Note:** Replace `<...>` placeholders with your real values (DockerHub username, domain, project-id, etc.). Do **not** commit any secret files (service-account JSON, passwords, etc.) to git.

---

## Table of Contents

- [Prerequisites](#-prerequisites)
- [High-level flow](#-high-level-flow)
- [1. Build & Push Custom Docker Image (ERPNext + HRMS)](#1-build--push-custom-docker-image-erpnext--hrms)
- [2. Provision NFS Storage (in-cluster) — ReadWriteMany](#2-provision-nfs-storage-in-cluster--readwritemany)
- [3. Prepare Helm Chart Changes (values.yaml + job-create-site)](#3-prepare-helm-chart-changes-valuesyaml--job-create-site)
- [4. Install Ingress Controller (NGINX) with a Static IP](#4-install-ingress-controller-nginx-with-a-static-ip)
- [5. Deploy ERPNext via Helm](#5-deploy-erpnext-via-helm)
- [6. Verify Site Creation & Apps (apps.txt)](#6-verify-site-creation--apps)
- [7. DNS & Access (production domain + TLS)](#7-dns--access-production-domain--tls)
- [8. Optional: Argo CD](#8-optional-argo-cd)
- [Troubleshooting & Tips](#troubleshooting--tips)

---

## ✅ Prerequisites

On your local machine:

- `gcloud` (Google Cloud SDK) configured for the target project
- `kubectl`
- `helm`
- `docker` (to build & push images)
- Terraform (if you use Terraform to reserve the static IP and provision GKE)
- GKE cluster already created and accessible (`kubectl get nodes` must work)

GCP APIs required:
```sh
gcloud services enable container.googleapis.com compute.googleapis.com dns.googleapis.com
```

... (content truncated for brevity, keep full in real file)
