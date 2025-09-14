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
🔁 High-level flow
Build custom Docker image (Frappe + ERPNext + HRMS) and push to DockerHub.

Provision NFS provisioner inside GKE (creates StorageClass: nfs supporting ReadWriteMany).

Update Helm values.yaml (image, persistence using nfs, ingress host).

Modify job-create-site.yaml so the create-site job installs hrms, runs bench build, and clears cache.

Install NGINX ingress controller bound to a reserved static IP.

Install the erpnext Helm chart with the modified values.

Verify create-site job finishes and sites/apps.txt contains hrms.

Map domain A record to static IP and enable TLS (cert-manager).

1) Build & Push Custom Docker Image (ERPNext + HRMS)
Create an apps.json that lists the apps you want installed by the image-builder:

Docker/apps.json

json
Copy code
[
  { "url": "https://github.com/frappe/erpnext", "branch": "version-15" },
  { "url": "https://github.com/frappe/hrms",     "branch": "version-15" }
]
Encode it and build:

sh
Copy code
export APPS_JSON_BASE64=$(base64 -w 0 Docker/apps.json)

docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --build-arg=PYTHON_VERSION=3.11.6 \
  --build-arg=NODE_VERSION=18.18.2 \
  --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
  --tag=<your-dockerhub-username>/frappe:erpnext-hrms \
  --file=Docker/Dockerfile .
Push to DockerHub:

sh
Copy code
docker login
docker push <your-dockerhub-username>/frappe:erpnext-hrms
Replace <your-dockerhub-username> and the tag as you prefer.

2) Provision NFS Storage (in-cluster)
ERPNext's sites/ directory must be shared (ReadWriteMany) among workers, scheduler and create-site job. Install the NFS server provisioner:

sh
Copy code
kubectl create namespace nfs

helm repo add nfs-ganesha-server-and-external-provisioner \
  https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner
helm repo update

helm upgrade --install in-cluster nfs-ganesha-server-and-external-provisioner/nfs-server-provisioner \
  -n nfs \
  --set 'storageClass.mountOptions={vers=4.1}' \
  --set persistence.enabled=true \
  --set persistence.size=20Gi
Verify StorageClass nfs is present:

sh
Copy code
kubectl get storageclass
3) Prepare Helm Chart Changes
Clone the upstream Helm chart and edit the values.yaml for production:

sh
Copy code
git clone https://github.com/frappe/helm.git
cd helm/erpnext
Example production values.yaml (FULL updated sample)
This file is adapted from the standard chart and the sample you provided. Replace secrets and placeholders.

yaml
Copy code
# values.yaml - production (example)
image:
  repository: <your-dockerhub-username>/frappe
  tag: erpnext-hrms
  pullPolicy: IfNotPresent

nginx:
  replicaCount: 2
  autoscaling:
    enabled: false
  environment:
    upstreamRealIPAddress: "0.0.0.0"
    upstreamRealIPRecursive: "off"
    upstreamRealIPHeader: "X-Forwarded-For"
    frappeSiteNameHeader: erp.piyush-web-app.co.in
    proxyReadTimeout: "120"
    clientMaxBodySize: "200m"
  livenessProbe:
    tcpSocket:
      port: 8080
  readinessProbe:
    tcpSocket:
      port: 8080
  service:
    type: ClusterIP
    port: 8080

worker:
  gunicorn:
    replicaCount: 2
    livenessProbe:
      tcpSocket: { port: 8000 }
    readinessProbe:
      tcpSocket: { port: 8000 }
    service:
      type: ClusterIP
      port: 8000
  default:
    replicaCount: 2
  short:
    replicaCount: 1
  long:
    replicaCount: 1
  scheduler:
    replicaCount: 1
  defaultTopologySpread:
    maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule

socketio:
  replicaCount: 1
  livenessProbe:
    tcpSocket: { port: 9000 }
  readinessProbe:
    tcpSocket: { port: 9000 }
  service:
    type: ClusterIP
    port: 9000

persistence:
  worker:
    enabled: true
    size: 10Gi
    storageClass: "nfs"
    accessModes:
      - ReadWriteMany
  logs:
    enabled: true
    size: 8Gi
    accessModes:
      - ReadWriteMany

ingress:
  ingressName: erpnext-ingress
  className: nginx
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: erp.piyush-web-app.co.in
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: erpnext-tls
      hosts:
        - erp.piyush-web-app.co.in

jobs:
  volumePermissions:
    enabled: true
  configure:
    enabled: true
    fixVolume: true
  createSite:
    enabled: true
    siteName: "erp.piyush-web-app.co.in"
    adminPassword: "ChangeYourStrongPassword123!"
    installApps:
      - "erpnext"
      - "hrms"
    dbType: "mariadb"
  dropSite:
    enabled: false
  backup:
    enabled: false
  migrate:
    enabled: false
  custom:
    enabled: false

imagePullSecrets: []
serviceAccount:
  create: true

redis-cache:
  enabled: true
  architecture: standalone
  auth:
    enabled: false
  master:
    persistence:
      enabled: false

redis-queue:
  enabled: true
  architecture: standalone
  auth:
    enabled: false
  master:
    persistence:
      enabled: false

mariadb:
  enabled: true
  auth:
    rootPassword: "ChangeThisRootPass"
    username: "erpnext"
    password: "ChangeThisDBPass"
    replicationPassword: "ChangeThisRepPass"
  primary:
    service:
      ports:
        mysql: 3306
    extraFlags: >-
      --skip-character-set-client-handshake
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci

postgresql:
  enabled: false
Key items

image.repository → replace with your DockerHub image produced earlier.

persistence.worker.storageClass → nfs (ensures ReadWriteMany).

ingress.hosts[0].host and createSite.siteName → set to your production domain erp.piyush-web-app.co.in (or your chosen subdomain).

mariadb.enabled → true uses in-cluster Bitnami MariaDB. If you prefer external cloud SQL or Memorystore, set mariadb.enabled=false and follow the external DB/Redis configuration steps below.

job-create-site.yaml modification
Open helm/erpnext/templates/job-create-site.yaml and ensure the create-site container adds install-app hrms plus bench build and clear-website-cache. Replace the existing args block with the following snippet (or add the bench lines after bench new-site completes):

yaml
Copy code
          args:
            - >
              set -ex;
              bench_output=$(bench new-site ${SITE_NAME} \
                --no-mariadb-socket \
                --db-type=${DB_TYPE} \
                --db-host=${DB_HOST} \
                --db-port=${DB_PORT} \
                --admin-password=${ADMIN_PASSWORD} \
                --mariadb-root-username=${DB_ROOT_USER} \
                --mariadb-root-password=${DB_ROOT_PASSWORD} \
                {{- if .Values.jobs.createSite.installApps }}
                  {{- range .Values.jobs.createSite.installApps }}
                  --install-app={{ . }} \
                  {{- end }}
                {{- end }}
              | tee /dev/stderr);
              bench_exit_status=$?;
              if [ $bench_exit_status -ne 0 ]; then
                if [[ $bench_output == *"already exists"* ]]; then
                  echo "Site already exists, continuing...";
                else
                  echo "Error in bench new-site: $bench_output";
                  exit $bench_exit_status;
                fi
              fi
              set -e;
              # Install HRMS (or other apps) & finalize
              bench --site ${SITE_NAME} install-app hrms || true;
              bench build || true;
              bench --site ${SITE_NAME} clear-website-cache || true;
This ensures that after the site is created, the HRMS app will be installed and static assets are built.

4) Install Ingress Controller (NGINX) with Static IP (Terraform output)
If you reserved a static IP via Terraform, get it like:

sh
Copy code
terraform output -raw static_ip
Install the ingress controller using that static IP:

sh
Copy code
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

kubectl create namespace ingress-nginx

helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.loadBalancerIP=$(terraform output -raw static_ip) \
  --set controller.publishService.enabled=true
Verify the service:

sh
Copy code
kubectl get svc -n ingress-nginx
Then create an A record at your DNS provider pointing erp.piyush-web-app.co.in → <static_ip>.

5) Deploy ERPNext via Helm
Create namespace and install:

sh
Copy code
kubectl create namespace erpnext

# From inside helm/erpnext (where Chart.yaml lives)
helm upgrade --install frappe-bench ./ -n erpnext -f values.yaml
Watch pods:

sh
Copy code
kubectl get pods -n erpnext -w
The site creation job will run (frappe-bench-erpnext-new-site-*). Wait until it completes successfully (Status Completed).

6) Verify Site Creation & Installed Apps
Logs for create-site job:

sh
Copy code
kubectl logs -n erpnext <frappe-bench-erpnext-new-site-podName>
Check sites/ inside worker pod:

sh
Copy code
kubectl exec -it -n erpnext <frappe-bench-erpnext-worker-d-podName> -- sh
# inside container shell:
ls sites/
cat sites/apps.txt
You should find erp.piyush-web-app.co.in and apps.txt includes: frappe, erpnext, hrms.

7) DNS & Access (production domain + TLS)
Ensure DNS A record erp.piyush-web-app.co.in → <static_ip>.

If you used the cert-manager annotation in values.yaml (cert-manager.io/cluster-issuer: letsencrypt-prod), cert-manager should provision TLS for the Ingress and create the erpnext-tls secret. Check:

sh
Copy code
kubectl describe certificate erpnext-tls -n erpnext
kubectl describe ingress erpnext-ingress -n erpnext
Then open:

arduino
Copy code
https://erp.piyush-web-app.co.in
8) Optional: Argo CD (GitOps)
Install ArgoCD:

sh
Copy code
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
Port-forward and access:

sh
Copy code
kubectl port-forward -n argocd svc/argocd-server 8083:443
# open http://localhost:8083
Create an Argo Application manifest pointing to your repo and apply:

sh
Copy code
kubectl apply -f ./argocd/app.yaml
Troubleshooting & Tips
CrashLoopBackOff / apps.txt Not Found
Usually caused by missing shared sites/ volume. Ensure the frappe-bench-erpnext PVC is Bound to an nfs PV and that createSite job writes the files there.

Redis Errors (ECONNREFUSED 127.0.0.1:6379)
If you use external Redis (Memorystore), set the REDIS envs in values.yaml to redis://<memorystore-ip>:6379. If using in-cluster Redis (chart values default), ensure redis-cache and redis-queue pods are running.

StorageClass binding problems
If your cluster's default StorageClass is WaitForFirstConsumer and pods can't schedule, either:

Use an explicit StorageClass with Immediate binding, or

Pre-create a PV bound to a PD and match its storageClassName.

Backing up DB & files
Use cron jobs to dump MariaDB to GCS and sync sites artifacts if needed.

Secrets
Create Kubernetes Secrets for DB root password and DB user password rather than embedding passwords in values.yaml. Example:

sh
Copy code
kubectl create secret generic erp-secrets \
  --from-literal=db-root-password='<rootpass>' \
  --from-literal=db-password='<dbpass>' \
  -n erpnext
Then reference them in values.yaml via valueFrom.secretKeyRef.

Example commands summary (quick copy)
sh
Copy code
# Build image
export APPS_JSON_BASE64=$(base64 -w 0 Docker/apps.json)
docker build --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 -t <user>/frappe:erpnext-hrms -f Docker/Dockerfile .
docker push <user>/frappe:erpnext-hrms

# NFS provisioner
kubectl create namespace nfs
helm repo add nfs-ganesha-server-and-external-provisioner https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner
helm repo update
helm upgrade --install in-cluster nfs-ganesha-server-and-external-provisioner/nfs-server-provisioner -n nfs --set 'storageClass.mountOptions={vers=4.1}' --set persistence.enabled=true --set persistence.size=20Gi

# Ingress (uses terraform output static_ip)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
kubectl create namespace ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx --namespace ingress-nginx --set controller.service.loadBalancerIP=$(terraform output -raw static_ip) --set controller.publishService.enabled=true

# Deploy ERPNEXT
kubectl create namespace erpnext
helm upgrade --install frappe-bench ./helm/erpnext -n erpnext -f helm/erpnext/values.yaml
kubectl get pods -n erpnext -w
Final notes
This README is written for production-style deployments on GKE (not local minikube).

If you prefer external managed services, swap mariadb.enabled and redis.* for external DB/Redis connection envs (Memorystore / Cloud SQL) and keep persistence.worker for file persistence or use GCS depending on your backup strategy.

Always test changes in a staging cluster before production.

If you want, I can:

produce an exact values.yaml and job-create-site.yaml files ready-to-apply (with placeholders replaced), or

add a small architecture diagram (PNG / ASCII) to the README.

Which would you like next?

yaml
Copy code

--- 

Would you like me to save that README.md into a file in your repo layout (I can produce the file here), or generate the final `values.yaml` and the `job-create-site.yaml` patch ready for you to paste into your chart?
