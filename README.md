# EKS HelloWorld — CI/CD + Terraform + ArgoCD

This repository contains GitHub Actions workflows and terraform modules to provision an EKS cluster, configure a remote Terraform backend (S3 + DynamoDB), and deploy the `helloworld` demo app via ArgoCD using a GitOps flow.

Prerequisites
- `gh` (GitHub CLI) configured and authenticated
- AWS credentials available in environment or GitHub secrets
- `kubectl` configured to talk to your EKS cluster (after cluster is created)
- Docker / access to the container registry used by CI

High-level run sequence
1. Bootstrap Terraform remote backend (S3 + DynamoDB)
   - Trigger: `.github/workflows/terraform-bootstrap.yaml`
   - Command (GitHub CLI):

     gh workflow run terraform-bootstrap.yaml --ref main

   - Purpose: create S3 bucket and DynamoDB table for Terraform state + locking.

2. Provision EKS
   - Trigger: `.github/workflows/provisioneks.yaml`
   - Command:

     gh workflow run provisioneks.yaml --ref main

   - Purpose: create EKS cluster and required infra using terraform modules.

3. Create ArgoCD / App namespaces in the cluster
   - Create namespaces used by ArgoCD-managed apps (one per environment):

     kubectl create namespace helloworld-dev
     kubectl create namespace helloworld-test
     kubectl create namespace helloworld-prod

   - Ensure ArgoCD is installed and has permissions to manage those namespaces.

4. Run CI/CD to build and deploy the app
   - Trigger: `.github/workflows/cicd.yaml`
   - Command:

     gh workflow run cicd.yaml --ref main

   - What it does:
     - Builds the Docker image and pushes it to the configured registry
     - Updates the `charts/helloworld/values*.yaml` file with the pushed image tag
     - Commits the updated values file back to the repo
     - ArgoCD detects the Git change and deploys to the target cluster/namespace

   - Note: If you want to redeploy using the same image, edit the appropriate `values-*.yaml` file (for example `charts/helloworld/values-dev.yaml`) to change the image tag, commit, and push — ArgoCD will detect the change and rollout the update.

5. Verify the app is running
   - Get the LoadBalancer external address:

     kubectl get svc -n helloworld-dev

   - Open the external address in your browser to test the app.

Teardown / Destroy
1. Remove Kubernetes-provisioned resources first
   - Example: delete services (and other k8s objects) created for the app in the app namespace(s):

     kubectl delete svc --all -n helloworld-dev
     kubectl delete deployment --all -n helloworld-dev

   - Repeat for other environments (`helloworld-test`, `helloworld-prod`) as needed.

2. Run the destroy workflow to remove EKS and AWS resources
   - Trigger: `.github/workflows/destroyeks.yaml`
   - Command:

     gh workflow run destroyeks.yaml --ref main

   - Note: The terraform bootstrap (S3 + DynamoDB) can be removed after EKS and related resources are destroyed if desired.

Helpful file locations
- Terraform bootstrap workflow: `.github/workflows/terraform-bootstrap.yaml`
- EKS provisioning workflow: `.github/workflows/provisioneks.yaml`
- CI/CD workflow: `.github/workflows/cicd.yaml`
- Helm chart: `charts/helloworld/`
- ArgoCD Application manifests: `k8s/argocd-helloworld-application*.yaml`
