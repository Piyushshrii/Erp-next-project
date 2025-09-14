# 🌐 GCP GKE Setup with Terraform + NGINX Ingress Controller

This guide provisions **Google Kubernetes Engine (GKE)** with Terraform and configures an **NGINX Ingress Controller** with a static IP for domain mapping.  
ERPNext (or any app) can later be deployed on this cluster.

---

## ✅ Prerequisites

Install on your local machine:

- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.5
- [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

Enable required GCP APIs:

```sh
gcloud services enable container.googleapis.com \
  compute.googleapis.com \
  dns.googleapis.com
🔑 Authentication
Option 1: Service Account (Recommended)
Create a service account with roles:

roles/editor

roles/container.admin

roles/iam.serviceAccountUser

roles/dns.admin

Download the key JSON → save as Terraform/terraform-key.json.

Option 2: User Login
sh
Copy code
gcloud auth login
gcloud auth application-default login
⚙️ Terraform Setup
Create a Terraform/terraform.tfvars file with your values:

hcl
Copy code
project_id       = "eighth-pen-462206-k3"
region           = "us-central1"
zone             = "us-central1-a"

domain           = "piyush-web-app.co.in"
email            = "you@domain.com"

credentials_file = "terraform-key.json"
🚀 Provision Infrastructure
Step 1: Init Terraform
sh
Copy code
cd Terraform
terraform init
Step 2: Preview Plan
sh
Copy code
terraform plan
Step 3: Apply Infrastructure
sh
Copy code
terraform apply -auto-approve
This provisions:

VPC + Subnets

Cloud NAT

Static IP (for ingress)

GKE cluster

📤 Outputs
After terraform apply, check outputs:

sh
Copy code
terraform output
Expected:

static_ip → reserved IP for ingress controller

kubeconfig → automatically updated entry for your GKE cluster

Verify cluster access:

sh
Copy code
kubectl get nodes
🌍 Install NGINX Ingress Controller
Add the Helm repo:

sh
Copy code
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
Create namespace:

sh
Copy code
kubectl create namespace ingress-nginx
Install ingress controller with static IP:

sh
Copy code
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.loadBalancerIP=$(terraform output -raw static_ip) \
  --set controller.publishService.enabled=true
Check service:

sh
Copy code
kubectl get svc -n ingress-nginx
🔗 Domain Mapping
Go to your domain provider (e.g., GoDaddy, Namecheap, Cloudflare).

Create an A record pointing your domain/subdomain → to the static_ip output from Terraform.

Example:

css
Copy code
erp.piyush-web-app.co.in   A   <STATIC_IP_FROM_OUTPUT>
Propagation can take 5–15 minutes.

🧹 Cleanup
To destroy all resources:

sh
Copy code
cd Terraform
terraform destroy -auto-approve
✅ Your GCP architecture is ready with a GKE cluster + NGINX ingress controller + static IP for domain mapping.
ERPNext (or any workload) can now be deployed on top of this.

yaml
Copy code

---

Do you want me to also generate the **matching `outputs.tf`** so it prints both the `static_ip` and the `kubeconfig` entry right after apply?







Ask ChatGPT
