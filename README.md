# task-manager-deployment
 
Infrastructure and deployment automation for the [task-manager-app](https://github.com/kacper-przybyla/task-manager-app).
 
## Overview
 
This repository contains everything needed to provision and configure the production environment for the Task Manager application.
 
| Tool | Purpose |
|------|---------|
| Terraform | Provisions AWS infrastructure (VPC, EC2, networking) |
| Ansible | Configures the server and deploys the application |
 
**Application repo:** [task-manager-app](https://github.com/kacper-przybyla/task-manager-app)  
**Registry:** `ghcr.io/kacper-przybyla/task-manager-{backend,frontend,proxy}`
 
---
 
## Repository Structure
 
```
task-manager-deployment/
├── terraform/
│   ├── modules/
│   │   ├── networking/     # VPC, subnet, internet gateway, route tables
│   │   └── ec2/            # EC2 instance, security group, key pair
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf        # AWS provider + S3 backend configuration
└── ansible/
    ├── deploy.yml           # Main deployment playbook
    ├── ansible.cfg
    ├── inventory/
    │   └── aws_ec2.yml      # Dynamic inventory via amazon.aws.aws_ec2 plugin
    ├── group_vars/
    │   └── app_servers.yml  # Non-secret variables
    ├── vault/
    │   └── secrets.yml      # Ansible Vault encrypted secrets
    ├── templates/
    │   └── docker-compose.yml.j2  # Jinja2 template rendered on the server
    └── files/
        └── database/init/   # PostgreSQL migration scripts
```
 
---
 
## Infrastructure
 
**Provider:** AWS (`eu-central-1`)  
**Instance:** `t3.micro`, Ubuntu 24.04 LTS  
**Networking:** VPC (`10.0.0.0/16`), public subnet (`10.0.1.0/24`)  
**Open ports:** 22 (SSH), 80 (HTTP), 443 (HTTPS)  
**State backend:** S3 (`kacper-przybyla-terraform-state/task-manager/terraform.tfstate`)
 
EC2 instances are tagged with `Project: task-manager` and `ManagedBy: terraform`, which the Ansible dynamic inventory uses to discover them automatically.
 
---
 
## Prerequisites
 
- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Ansible >= 2.14
- Python packages: `boto3`, `botocore`, `docker`
- Ansible collections: `amazon.aws`, `community.docker`
Install collections:
```bash
ansible-galaxy collection install amazon.aws community.docker
```
 
Install Python dependencies:
```bash
pip3 install boto3 botocore docker --break-system-packages
```
 
---
 
## Provisioning Infrastructure
 
```bash
cd terraform/
terraform init
terraform plan
terraform apply
```
 
Terraform state is stored remotely in S3. No local state file is committed.
 
To destroy infrastructure:
```bash
terraform destroy
```
 
---
 
## Deploying the Application
 
The Ansible playbook deploys the full application stack (PostgreSQL, FastAPI backend, React frontend, Nginx proxy) using pre-built Docker images from GHCR.
 
**Deploy latest:**
```bash
cd ansible/
ansible-playbook deploy.yml --ask-vault-pass
```
 
**Deploy specific version (recommended for production):**
```bash
ansible-playbook deploy.yml --ask-vault-pass -e "app_version=<commit-sha>"
```
 
The playbook:
1. Ensures the application directory exists
2. Installs Docker, Docker Compose, and Python Docker SDK
3. Copies database migration scripts
4. Renders `docker-compose.yml` from Jinja2 template with secrets injected
5. Pulls images and starts the stack with `docker compose up`
6. Verifies the application responds on port 80
### Dynamic Inventory
 
Ansible automatically discovers EC2 instances via the `amazon.aws.aws_ec2` plugin — no hardcoded IPs. When Terraform provisions a new instance, Ansible picks it up on the next run without any manual configuration.
 
### Secrets Management
 
Sensitive values (database credentials) are stored in `ansible/vault/secrets.yml`, encrypted with Ansible Vault (AES-256). The vault password is never committed to the repository.
 
To view or edit secrets:
```bash
ansible-vault view ansible/vault/secrets.yml
ansible-vault edit ansible/vault/secrets.yml
```
 
---
 
## Architecture
 
```
Internet
    │
    ▼
[Nginx Proxy :80]
    │
    ├──► [React Frontend :80]
    │
    └──► [FastAPI Backend :8000]
              │
              ▼
        [PostgreSQL :5432]
```
 
All services run as Docker containers on a single EC2 instance, connected via Docker networks. The proxy handles routing: `/api/*` → backend, `/*` → frontend.
 
---
 
## Environment Variables
 
Non-secret variables are defined in `ansible/group_vars/app_servers.yml`. Secret variables are in the encrypted vault file. See `.env.example` in the application repository for the full list of required variables.