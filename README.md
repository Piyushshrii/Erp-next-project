# 🌐 GCP GKE Setup with Terraform + NGINX Ingress Controller

This guide provisions **Google Kubernetes Engine (GKE)** with Terraform and configures an **NGINX Ingress Controller** with a static IP for domain mapping.  
ERPNext (or any app) can later be deployed on this cluster.

   ##                GCP Infrastructure Architecture 
<p align="center">
  <img src="https://github.com/user-attachments/assets/b31391e8-1901-44ff-aadf-11940bc64a82" width="590">
</p>




---

## ✅ Prerequisites

Install on your local machine:

- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.5
- [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

Enable required GCP APIs:

```sh
gcloud services enable container.googleapis.com   compute.googleapis.com   dns.googleapis.com
```

---

## 🔑 Authentication

### Option 1: Service Account (Recommended)
1. Create a service account with roles:
   - `roles/editor`
   - `roles/container.admin`
   - `roles/iam.serviceAccountUser`
   - `roles/dns.admin`
2. Download the key JSON → save as `Terraform/terraform-key.json`.

### Option 2: User Login
```sh
gcloud auth login
gcloud auth application-default login
```

---

## ⚙️ Terraform Setup

Create a `Terraform/terraform.tfvars` file with your values:

```hcl
project_id       = "eighth-pen-462206-k3"
region           = "us-central1"
zone             = "us-central1-a"

domain           = "piyush-web-app.co.in"
email            = "you@domain.com"

credentials_file = "terraform-key.json"
```

---

## 🚀 Provision Infrastructure

### Step 1: Init Terraform
```sh
cd Terraform
terraform init
```

### Step 2: Preview Plan
```sh
terraform plan
```

### Step 3: Apply Infrastructure
```sh
terraform apply -auto-approve
```

This provisions:
- VPC + Subnets
- Cloud NAT
- Static IP (for ingress)
- GKE cluster

---

## 📤 Outputs

After `terraform apply`, check outputs:
```sh
terraform output
```

Expected:
- `static_ip` → reserved IP for ingress controller  
- `kubeconfig` → automatically updated entry for your GKE cluster

Add cluster entry in your local machine to acces the cluster
```
gcloud container clusters get-credentials <CLUSTER_NAME> \
  --region <REGION> \
  --project <PROJECT_ID>
```

Verify cluster access:
```sh
kubectl get nodes
```

---

## 🌍 Install NGINX Ingress Controller

Add the Helm repo:
```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

Create namespace:
```sh
kubectl create namespace ingress-nginx
```

Install ingress controller with static IP:
```sh
helm install nginx-ingress ingress-nginx/ingress-nginx   --namespace ingress-nginx   --set controller.service.loadBalancerIP=$(terraform output -raw static_ip)   --set controller.publishService.enabled=true
```

Check service:
```sh
kubectl get svc -n ingress-nginx
```

---

## 🔗 Domain Mapping

- Go to your domain provider (e.g., GoDaddy, Namecheap, Cloudflare).  
- Create an **A record** pointing your domain/subdomain → to the `static_ip` output from Terraform.  

Example:
```
erp.piyush-web-app.co.in   A   <STATIC_IP_FROM_OUTPUT>
```

Propagation can take 5–15 minutes.

---

## 🧹 Cleanup

To destroy all resources:
```sh
cd Terraform
terraform destroy -auto-approve
```

---

✅ Your GCP architecture is ready with a GKE cluster + NGINX ingress controller + static IP for domain mapping.  
ERPNext (or any workload) can now be deployed on top of this.
