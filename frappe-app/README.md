# 🚀 ERPNext + HRMS — Production GKE Deployment (Helm + NFS + Ingress)


##Deployment solution Architecture
<img width="2266" height="1077" alt="diagram-export-9-15-2025-12_41_36-AM" src="https://github.com/user-attachments/assets/7d17b5ad-46c5-46bf-b9f3-38c660991c8c" />


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

---

## 🔁 High-level flow

1. Build custom Docker image (Frappe + ERPNext + HRMS) and push to DockerHub.
2. Provision NFS provisioner inside GKE (creates StorageClass: nfs supporting ReadWriteMany).
3. Update Helm `values.yaml` (image, persistence using nfs, ingress host).
4. Modify `job-create-site.yaml` so the create-site job installs hrms, runs `bench build`, and clears cache.
5. Install NGINX ingress controller bound to a reserved static IP.
6. Install the ERPNext Helm chart with the modified values.
7. Verify create-site job finishes and `sites/apps.txt` contains hrms.
8. Map domain A record to static IP and enable TLS (cert-manager).

---

## 1️⃣ Build & Push Custom Docker Image (ERPNext + HRMS)

Move to frappe-app directory
```
cd frappe-app
```

Create an `apps.json` that lists the apps you want installed by the image-builder:

**Docker/apps.json**
```json
[
  { "url": "https://github.com/frappe/erpnext", "branch": "version-15" },
  { "url": "https://github.com/frappe/hrms",     "branch": "version-15" }
]
```

Encode it and build:

```sh
export APPS_JSON_BASE64=$(base64 -w 0 Docker/apps.json)

docker build   --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe   --build-arg=FRAPPE_BRANCH=version-15   --build-arg=PYTHON_VERSION=3.11.6   --build-arg=NODE_VERSION=18.18.2   --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64   --tag=<your-dockerhub-username>/frappe:erpnext-hrms   --file=Docker/Dockerfile .

docker login
docker push <your-dockerhub-username>/frappe:erpnext-hrms
```

---

## 2️⃣ Provision NFS Storage (in-cluster)

ERPNext's `sites/` directory must be shared (ReadWriteMany). Install the NFS server provisioner:

```sh
kubectl create namespace nfs

helm repo add nfs-ganesha-server-and-external-provisioner   https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner
helm repo update

helm upgrade --install in-cluster nfs-ganesha-server-and-external-provisioner/nfs-server-provisioner   -n nfs   --set 'storageClass.mountOptions={vers=4.1}'   --set persistence.enabled=true   --set persistence.size=20Gi
```

Verify StorageClass `nfs` is present:

```sh
kubectl get storageclass
```

---

## 3️⃣ Prepare Helm Chart Changes

Clone the upstream Helm chart and edit the values.yaml for production:

```sh
git clone https://github.com/frappe/helm.git
cd helm/erpnext
```

Then edit `values.yaml` and `job-create-site.yaml` as shown above.

---

---

## 4️⃣ Deploy ERPNext via Helm

```sh
kubectl create namespace erpnext

helm upgrade --install frappe-bench ./ -n erpnext -f values.yaml

kubectl get pods -n erpnext -w
```

Wait until the `create-site` job completes successfully.

---

## 5️ Verify Site Creation & Installed Apps

```sh
kubectl logs -n erpnext <frappe-bench-erpnext-new-site-podName>

kubectl exec -it -n erpnext <frappe-bench-erpnext-worker-d-podName> -- sh
# inside container:
ls sites/
cat sites/apps.txt
```

You should find `erp.piyush-web-app.co.in` and `apps.txt` includes: frappe, erpnext, hrms.

---

## 6️ DNS & Access (production domain + TLS)

Point DNS A record to your reserved static IP.

Check TLS certificates with cert-manager and verify ingress.

Open your site:

```sh
https://erp.piyush-web-app.co.in
```

---

## 7️⃣ Optional: Argo CD (GitOps)

Install ArgoCD:

```sh
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl port-forward -n argocd svc/argocd-server 8083:443
```

Then configure an Application manifest to sync this repo.

---

## 🛠 Troubleshooting & Tips

- **CrashLoopBackOff / apps.txt not found:** Likely NFS not mounted properly.
- **Redis errors:** Ensure redis-cache and redis-queue pods are running or configure external Redis.
- **StorageClass binding issues:** Use a StorageClass with `Immediate` binding if WaitForFirstConsumer blocks scheduling.
- **Secrets:** Use Kubernetes Secrets for passwords.

---

## 📌 Example Commands Summary

```sh
# Build Image
docker build -t <user>/frappe:erpnext-hrms .
docker push <user>/frappe:erpnext-hrms

# Install NFS provisioner
kubectl create namespace nfs
helm repo add nfs-ganesha-server-and-external-provisioner https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner
helm upgrade --install in-cluster nfs-ganesha-server-and-external-provisioner/nfs-server-provisioner -n nfs --set persistence.enabled=true --set persistence.size=20Gi

# Install ingress controller
kubectl create namespace ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx --namespace ingress-nginx --set controller.service.loadBalancerIP=$(terraform output -raw static_ip) --set controller.publishService.enabled=true

# Deploy ERPNext
kubectl create namespace erpnext
helm upgrade --install frappe-bench ./helm/erpnext -n erpnext -f helm/erpnext/values.yaml
```

---

This README is designed for **production GKE deployments** and follows best practices for persistence, ingress, and site automation.
