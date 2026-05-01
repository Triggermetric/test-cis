# CIS Cassandra — Complete Setup & Deployment Guide

Complete guide for local development and production deployment. Choose your path below.

---

## Table of Contents

1. [Quick Overview](#quick-overview)
2. [Infrastructure Setup (Terraform)](#infrastructure-setup-terraform)
3. [Local Development](#local-development)
4. [Production Deployment to Master VM](#production-deployment-to-master-vm)
5. [Troubleshooting](#troubleshooting)
6. [Command Reference](#command-reference)

---

## Quick Overview

**CIS Cassandra** is a compliance auditing and hardening dashboard for Apache Cassandra 4.0 clusters.

**Architecture:**
- **Frontend**: React 18 + TypeScript + Vite (5173) / nginx (80/443)
- **Backend**: FastAPI (8000)
- **Database**: Apache Cassandra 4.0 (3 nodes across 2 Azure regions)
- **Infrastructure**: Terraform + Azure (VNets, NSGs, VMs)

**Key Features:**
- CIS benchmark auditing via SSH
- Automated hardening
- Student data management (demo CRUD on Cassandra)
- Real-time compliance monitoring

---

## Infrastructure Setup (Terraform)

### Prerequisites

- Azure CLI (`az` command)
- Terraform
- SSH key pair (`ssh/id_rsa`, `ssh/id_rsa.pub`)

### Step 1: Configure Terraform

Edit `terraform/terraform.tfvars`:

```hcl
project_name        = "cis-cassandra"
resource_group_name = "cis-cassandra-rg"
location             = "Korea Central"            # Primary region
secondary_location   = "Southeast Asia"          # Secondary region (avoid quota issues)
vm_size              = "Standard_B2as_v2"
ssh_public_key_path  = "J:/CloudProjects/cis-cassandra-main/ssh/id_rsa.pub"
allowed_ssh_ips      = ["YOUR.IP.ADDRESS/32"]    # Your public IP
```

Get your IP: `curl -s https://api.ipify.org`

### Step 2: Deploy Infrastructure

```bash
cd terraform

# Initialize
terraform init

# Preview changes
terraform plan -out=tfplan

# Deploy (this takes ~10 min)
terraform apply tfplan

# Save outputs
terraform output -json > ../infra-outputs.json
```

**Output includes:**
- `master_public_ip` — SSH entry point
- `node_ips` — Private cluster IPs (10.0.1.11, 10.0.1.12, 10.0.1.13)

### Step 3: Verify Cluster Health

SSH into master and check Cassandra:

```bash
# PowerShell: Start SSH agent
Start-Service ssh-agent
ssh-add "J:/CloudProjects/cis-cassandra-main/ssh/id_rsa"

# SSH into master with agent forwarding
$MASTER_IP = "YOUR_MASTER_PUBLIC_IP"
ssh -A cassandra@$MASTER_IP
```

Once inside master:

```bash
# Check cluster status
cqlsh localhost
SELECT * FROM system.peers;
EXIT;

# All 3 nodes should appear (including db2, db3 from secondary region)
```

---

## Local Development

For development with hot reload and easy debugging.

### Start Backend

**Terminal 1:**

```bash
cd j:\CloudProjects\cis-cassandra-main\backend

# The start-backend.sh script handles everything
bash start-backend.sh
```

This:
- Creates `.env` with defaults
- Installs dependencies
- Starts uvicorn on `localhost:8000`

### Start Frontend

**Terminal 2:**

```bash
cd j:\CloudProjects\cis-cassandra-main\frontend

# The start-frontend.sh script handles everything
bash start-frontend.sh
```

This:
- Installs npm dependencies
- Starts Vite dev server on `localhost:5173`

### Access Application

```
Frontend: http://localhost:5173
Backend API docs: http://localhost:8000/docs
```

### Configure Backend Connection

The frontend needs to know where the backend is. By default it points to `http://localhost:8000`.

If backend is elsewhere:

```bash
cd frontend
VITE_API_URL=http://your-backend:8000 npm run dev
```

### Testing

**Add a student** (tests database connectivity):
1. Click **Data** tab (📚)
2. Fill form: John Doe, john@example.com, STU001
3. Click **✓ Add Student**
4. Record appears in table

**Run audit** (tests cluster SSH):
1. Click **Audit Live** tab (⚡)
2. Click **Start Audit**
3. Real-time progress streams in

---

## Production Deployment to Master VM

Deploy both frontend and backend on the master VM behind nginx.

### Quick Deploy (One Command)

From your PC:

```bash
bash scripts/deploy-to-master.sh <MASTER_PUBLIC_IP> J:/CloudProjects/cis-cassandra-main/ssh/id_rsa
```

This:
- Clones repo on master
- Installs Python & npm dependencies
- Builds React frontend
- Creates systemd service for backend
- Configures nginx as reverse proxy
- Starts all services

### Manual Deploy (if script fails)

SSH into master:

```bash
ssh -A cassandra@<MASTER_PUBLIC_IP>
```

Then follow the steps in `scripts/deploy-to-master.sh` (it's all bash commands).

### Verify Deployment

```bash
# From your PC
curl http://<MASTER_PUBLIC_IP>/          # Frontend
curl http://<MASTER_PUBLIC_IP>/api/health # Backend health
```

Should see:
- HTML response from frontend
- `{"status":"ok","service":"cis-cassandra-dashboard"}` from backend

### Architecture on Master

```
Internet → nginx (port 80/443)
           ├─ / → frontend static files
           ├─ /api/* → FastAPI (localhost:8000)
           └─ /api/docs → API documentation

FastAPI Backend (systemd service)
└─ Cassandra (localhost:9042)
```

### Monitoring Services on Master

```bash
ssh cassandra@<MASTER_PUBLIC_IP>

# Backend status
sudo systemctl status cis-backend
sudo journalctl -u cis-backend -f    # Live logs

# nginx status
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log

# Cassandra
cqlsh localhost
SELECT * FROM demo.students;
EXIT;
```

### Update Deployed Code

After pushing changes to GitHub:

```bash
ssh cassandra@<MASTER_PUBLIC_IP>

# Pull latest
cd ~/app && git pull origin main

# Rebuild frontend
cd frontend && npm run build

# Restart services
sudo systemctl restart cis-backend
sudo systemctl reload nginx
```

### HTTPS/SSL (Optional)

Set up Let's Encrypt on master:

```bash
ssh cassandra@<MASTER_PUBLIC_IP>

# Install certbot
sudo apt update && sudo apt install -y certbot python3-certbot-nginx

# Get certificate (requires DNS pointing to master IP)
sudo certbot --nginx -d your-domain.com

# Auto-renewal enabled automatically
```

nginx will auto-redirect HTTP → HTTPS.

---

## GitHub Actions CI/CD Automation

Fully automated deployment and infrastructure management via GitHub Actions.

### Prerequisites

1. Repository must be on GitHub
2. SSH key for Master VM access (uses same key as Terraform: `ssh/id_rsa`)
3. Azure service account configured with OIDC (for infrastructure destruction)

---

### Part 1: Set Up SSH Secrets (For Deployment Workflow)

**⚠️ IMPORTANT: SSH Key Security**

The SSH private key in `ssh/id_rsa` is used by:
- GitHub Actions to deploy to Master VM
- Master VM to communicate with Cassandra nodes (db1, db2, db3)
- CIS audit scripts to SSH into cluster nodes

**This is the SAME key configured in `terraform/terraform.tfvars`.**

#### Step 1: Prepare Your SSH Private Key

```bash
# On your machine, get the contents of your SSH private key
cat ssh/id_rsa
```

#### Step 2: Add to GitHub Secrets

1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Click **New repository secret**
4. Create these secrets:

| Secret Name | Value |
|---|---|
| `MASTER_IP` | Your Master VM public IP (e.g., `20.195.123.45`) |
| `MASTER_SSH_PRIVATE_KEY` | Full contents of `ssh/id_rsa` file (BEGIN RSA PRIVATE KEY...END RSA PRIVATE KEY) |

**Example:**
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA3k7G8j9K...
[... rest of key ...]
-----END RSA PRIVATE KEY-----
```

#### Step 3: Verify Secret Configuration

```bash
# After adding secrets, verify SSH works from GitHub Actions
# This is automatic when you push to main or manually trigger the workflow
```

---

### Part 2: Deployment Workflow (`deploy-to-production.yml`)

Automatically tests and deploys your code when you push to `main`.

**What it does:**
1. ✅ Runs all Python tests (backend)
2. ✅ Runs all JavaScript tests (frontend)
3. ✅ Builds React frontend
4. ✅ SSHes into Master VM with `ssh/id_rsa` private key
5. ✅ Executes `scripts/deploy-to-master.sh`
6. ✅ Verifies backend and frontend are running
7. ✅ Reports success/failure

**Trigger deployment:**

```bash
# Option 1: Automatic on push to main
git push origin main

# Option 2: Manual trigger from GitHub Actions tab
# Actions → Deploy to Production → Run workflow
```

**Monitor progress:**
- Go to GitHub repository
- Click **Actions** tab
- Click the active workflow run
- Watch real-time logs

**SSH Key Flow in Deployment Workflow:**
```
GitHub Actions Runner
  ↓ (uses MASTER_SSH_PRIVATE_KEY secret)
  ├─ SSH to Master (cassandra@<MASTER_IP>)
  │   ↓
  │   └─ Deploy script clones/pulls repo
  │   └─ Installs dependencies
  │   └─ Builds frontend
  │   └─ Starts backend systemd service
  │   └─ Reloads nginx
  │
  └─ Master VM has ssh/id_rsa
      ↓ (same key, configured in Master during Terraform)
      ├─ SSH to db1 (10.0.1.11) for CIS audits
      ├─ SSH to db2 (10.1.1.12)
      └─ SSH to db3 (10.1.1.13)
```

**Example Workflow Output:**
```
✅ Checkout code
✅ Set up Python 3.12
✅ Install backend dependencies
✅ Run backend tests (pytest)
✅ Set up Node 20
✅ Install frontend dependencies
✅ Run frontend tests (vitest)
✅ Build frontend (Vite)
✅ Configure SSH for deployment
✅ Test SSH connectivity to Master
✅ Deploy application to Master VM
✅ Wait for services to stabilize
✅ Verify backend health
✅ Verify frontend is accessible
✅ Check service status on Master

✅ DEPLOYMENT SUCCESSFUL
   Frontend:  http://20.195.123.45
   Backend:   http://20.195.123.45/api
   API Docs:  http://20.195.123.45/api/docs
```

---

### Part 3: Infrastructure Destruction Workflow (`destroy-infrastructure.yml`)

⚠️ **DANGER: This permanently deletes all Azure infrastructure**

**What it does:**
1. ✅ Requires manual confirmation
2. ✅ Backs up Terraform state before destruction
3. ✅ Gracefully stops services on Master VM
4. ✅ Authenticates to Azure via OIDC
5. ✅ Runs `terraform destroy -auto-approve`
6. ✅ Saves destruction report

**When to use:**
- End of project/semester
- Cost reduction
- Testing terraform reproducibility
- Cleaning up dev environments

**Trigger destruction:**

```bash
# ONLY via GitHub Actions Manual Trigger
# Actions → Destroy Infrastructure → Run workflow
# When prompted for confirmation, type: destroy-all-infrastructure
```

**OIDC Setup (One-time, required for destroy workflow):**

The destroy workflow uses Azure OIDC for secure authentication (no stored credentials).

#### Step 1: Create Azure Service Principal

```bash
# In Azure CLI, create a service principal for GitHub Actions
az ad app create --display-name "cis-cassandra-github-actions"
# Save the output, especially the Application ID

# Get your Azure Tenant ID
az account show --query tenantId -o tsv

# Get your subscription ID
az account show --query id -o tsv
```

#### Step 2: Create OIDC Federated Credential

Replace `<APP_ID>` with the Application ID from Step 1:

```bash
# Create OIDC credential
az ad app federated-credential create \
  --id <APP_ID> \
  --parameters '{
    "name": "github-actions",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_ORG/cis-cassandra-main:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

#### Step 3: Grant Azure Role to Service Principal

```bash
# Assign Contributor role to the service principal
az role assignment create \
  --assignee <APP_ID> \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

#### Step 4: Add GitHub Secrets for Azure OIDC

1. Go to GitHub → Settings → Secrets and variables → Actions
2. Add these secrets:

| Secret Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | Application ID from Step 1 |
| `AZURE_TENANT_ID` | Tenant ID from Step 1 |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID from Step 1 |

#### Step 5: Verify OIDC Setup

```bash
# Test by manually triggering the workflow
# Actions → Destroy Infrastructure → Run workflow (don't confirm yet)
# It should reach the "Show destruction warning" step

# Then Cancel and re-run with proper confirmation
```

---

### SSH Key Management Best Practices

Since the same SSH key is used throughout the infrastructure:

#### ✅ DO:
- Keep `ssh/id_rsa` in `.gitignore` (already done)
- Use strong passphrase if key is unencrypted locally
- Rotate keys periodically (create new key pair, update Terraform, re-encrypt)
- Grant minimal permissions (read-only where possible)
- Audit SSH access logs on Master VM: `sudo journalctl -u ssh`

#### ❌ DON'T:
- Commit `ssh/id_rsa` to Git
- Share the private key in messages/emails
- Use the same key for multiple projects
- Leave SSH keys with empty passphrases on shared machines

#### View SSH Usage on Master VM:

```bash
ssh cassandra@<MASTER_IP>

# Check SSH login history
sudo journalctl -u ssh -n 50

# Monitor real-time SSH connections
sudo journalctl -u ssh -f

# Check which nodes were accessed
grep "Accepted publickey\|Accepted password" /var/log/auth.log | tail -20
```

---

### Troubleshooting CI/CD Workflows

#### Deployment fails with "Permission denied (publickey)"

```bash
# SSH key is not correctly configured
# Check:
1. MASTER_SSH_PRIVATE_KEY secret contains full key (BEGIN...END)
2. MASTER_IP secret is correct
3. Key matches the public key on Master VM (~/.ssh/authorized_keys)

# Verify locally:
ssh -i ssh/id_rsa cassandra@<MASTER_IP> "echo 'Test'"
```

#### Tests fail but deployment still proceeds

```bash
# Tests are marked as continue-on-error in the workflow
# To make tests blocking:
# Edit .github/workflows/deploy-to-production.yml
# Change "continue-on-error: true" to "continue-on-error: false"
```

#### Terraform destroy fails with "authorization denied"

```bash
# Azure OIDC token expired or permissions insufficient
# Verify:
1. AZURE_CLIENT_ID, AZURE_TENANT_ID are correct
2. Service principal has Contributor role
3. Subscription ID is correct
4. OIDC credential hasn't expired (check Azure Portal)

# Redeploy OIDC if needed:
az ad app delete --id <APP_ID>
# Then follow OIDC setup steps again
```

#### Master VM becomes unreachable

```bash
# If SSH hangs or times out:
1. Verify Master is still running in Azure Portal
2. Check if IP changed (get from terraform output -json)
3. Update MASTER_IP secret in GitHub
4. Update security group rules in Azure if your IP changed
5. Verify ~/.ssh/known_hosts doesn't have stale entries

# From your machine:
ssh-keygen -R <OLD_MASTER_IP>
```

---

### Manual Deployment (When Automation Fails)

If the CI/CD workflow fails, you can deploy manually:

```bash
# On your machine (with ssh/id_rsa)
bash scripts/deploy-to-master.sh <MASTER_IP> ssh/id_rsa

# Or manually SSH and run deployment steps:
ssh -A cassandra@<MASTER_IP>
cd ~/app/cis-cassandra-main
git pull origin main
cd backend && pip install -r requirements.txt
cd ../frontend && npm ci && npm run build
sudo systemctl restart cis-backend nginx
```

---

### Next Steps

1. ✅ Configure SSH secrets (`MASTER_IP`, `MASTER_SSH_PRIVATE_KEY`)
2. ✅ (Optional) Set up Azure OIDC for destroy workflow
3. ✅ Push code to main branch
4. ✅ Watch deployment in Actions tab
5. ✅ Access application at `http://<MASTER_IP>`

---

## Troubleshooting

### SSH Connection Issues

**Problem**: `Permission denied (publickey)`

**Solution**:
```powershell
# Add key to agent
ssh-add "J:/CloudProjects/cis-cassandra-main/ssh/id_rsa"

# Verify
ssh-add -L

# Try SSH again
ssh -A cassandra@$MASTER_IP
```

### Backend Can't Connect to Cassandra

**Problem**: `Cassandra connection failed`

**Cause**: `CASSANDRA_CONTACT_POINT` in `.env` is wrong

**Solution**:
```bash
# Check .env
cat backend/.env

# Update if needed
# If running locally on PC: CASSANDRA_CONTACT_POINT=10.0.1.11 (master's private IP)
# If running on master: CASSANDRA_CONTACT_POINT=localhost

# Restart
bash backend/start-backend.sh
```

### Frontend Shows API Error

**Problem**: Frontend can't reach backend

**Solution**:
```bash
# Check backend is running
curl http://localhost:8000/health

# Check VITE_API_URL is correct
cd frontend
echo $VITE_API_URL

# Restart with explicit URL
VITE_API_URL=http://localhost:8000 npm run dev
```

### Cassandra Not Ready

**Problem**: "Connection refused" when starting backend

**Cause**: Cassandra takes 1-2 minutes to start on fresh VMs

**Solution**: Wait a few minutes, then restart backend:
```bash
bash backend/start-backend.sh
```

### Nginx Shows "502 Bad Gateway"

**Problem**: Can't access backend through nginx on master

**Cause**: FastAPI backend crashed or not listening

**Solution**:
```bash
ssh cassandra@<MASTER_IP>

# Check backend
sudo systemctl status cis-backend
sudo systemctl restart cis-backend

# Check logs
sudo journalctl -u cis-backend -n 50

# Check nginx config
sudo nginx -t
```

### Port Already in Use

**Problem**: `Address already in use` when starting backend/frontend

**Solution**:
```bash
# Find what's using the port
# PowerShell
Get-NetTCPConnection -LocalPort 8000

# Kill the process
Stop-Process -Id <PID> -Force

# Or use different ports
bash backend/start-backend.sh      # Uses 8000
VITE_PORT=5174 npm run dev         # Use 5174 instead of 5173
```

### NSG Rules Not Working

**Problem**: Can't access ports 80, 443, 8000, 5173 on master

**Cause**: NSG rules not applied yet

**Solution**:
```bash
cd terraform

# Reapply NSG rules
terraform apply -target=azurerm_network_security_group.cassandra_primary
terraform apply -target=azurerm_network_security_group.cassandra_secondary

# Verify
az network nsg rule list -g cis-cassandra-rg -n cis-cassandra-nsg
```

### Can't SSH to Secondary Nodes

**Problem**: db2, db3 unreachable from local PC

**Cause**: They're in secondary region, only reachable through master's private network

**Solution**: Jump through master:
```bash
# SSH to master, then from master:
ssh cassandra@10.0.1.12  # db2 (uses agent forwarding)
ssh cassandra@10.0.1.13  # db3
```

Or use ProxyJump:
```bash
ssh -J cassandra@<MASTER_PUBLIC_IP> cassandra@10.0.1.12
```

---

## Command Reference

### Terraform

```bash
cd terraform

# Initialize
terraform init

# Validate
terraform validate

# Plan changes
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Get outputs
terraform output

# Destroy all
terraform destroy -auto-approve
```

### SSH / Connection

```powershell
# PowerShell SSH setup
Start-Service ssh-agent
ssh-add "J:/CloudProjects/cis-cassandra-main/ssh/id_rsa"
ssh -A cassandra@<MASTER_IP>
```

### Backend

```bash
cd backend

# Start (with auto-reload)
bash start-backend.sh

# Or manually
python -m pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend

```bash
cd frontend

# Start (with hot reload)
bash start-frontend.sh

# Or manually
npm install
VITE_API_URL=http://localhost:8000 npm run dev

# Build for production
npm run build
```

### Cassandra (on master)

```bash
ssh cassandra@<MASTER_IP>

# Connect
cqlsh localhost

# Inside cqlsh:
DESCRIBE KEYSPACES;
USE demo;
SELECT * FROM students;
SELECT * FROM system.peers;  # Show cluster nodes
EXIT;
```

### Service Management (on master)

```bash
ssh cassandra@<MASTER_IP>

# Backend
sudo systemctl status cis-backend
sudo systemctl restart cis-backend
sudo journalctl -u cis-backend -f

# nginx
sudo systemctl status nginx
sudo systemctl reload nginx
sudo tail -f /var/log/nginx/error.log

# Cassandra
sudo systemctl status cassandra
sudo tail -f /var/log/cassandra/system.log
```

### Deployment

```bash
# Quick deploy
bash scripts/deploy-to-master.sh <MASTER_IP> <SSH_KEY_PATH>

# Destroy everything
bash scripts/destroy-all.sh
```

---

## Architecture Diagram

### Local Development

```
Your PC
├─ Frontend (localhost:5173)
│  └─ Hot reload, live updates
├─ Backend (localhost:8000)
│  └─ Auto-reload on code changes
└─ SSH tunnel to master
   └─ Cassandra (10.0.1.11:9042)
```

### Production (on Master)

```
Internet
  ↓
Master VM (public IP)
  ├─ nginx (80/443)
  │  ├─ Static frontend files
  │  └─ /api/* → FastAPI
  ├─ FastAPI (localhost:8000, systemd)
  └─ Cassandra (localhost:9042)

db2 VM (secondary region, private)
  └─ Cassandra
     ↑ network peering ↑

db3 VM (secondary region, private)
  └─ Cassandra
```

---

## File Structure

```
j:\CloudProjects\cis-cassandra-main\
├── backend/
│   ├── start-backend.sh         ← Run this for dev
│   ├── main.py
│   ├── routers/
│   │   ├── data.py              ← Student CRUD
│   │   ├── audit.py             ← CIS auditing
│   │   └── ...
│   └── requirements.txt
│
├── frontend/
│   ├── start-frontend.sh         ← Run this for dev
│   ├── vite.config.ts
│   ├── src/
│   │   ├── pages/
│   │   │   ├── DataManagementPage.tsx  ← Student UI
│   │   │   └── ...
│   │   └── ...
│   └── package.json
│
├── terraform/
│   ├── main.tf
│   ├── nsg.tf                   ← Firewall rules
│   ├── vms.tf
│   ├── terraform.tfvars         ← YOUR CONFIG
│   └── ...
│
├── scripts/
│   ├── deploy-to-master.sh      ← Production deploy
│   ├── destroy-all.sh           ← Cleanup
│   ├── ssh-connect.sh           ← SSH helper
│   └── start-all.sh             ← Orchestration
│
├── .github/workflows/
│   └── deploy.yml               ← GitHub Actions CI/CD
│
└── SETUP.md                     ← This file
```

---

## Common Workflows

### Scenario 1: Local Development

```bash
# Terminal 1
bash backend/start-backend.sh

# Terminal 2
bash frontend/start-frontend.sh

# Browser: http://localhost:5173
# Make code changes → hot reload
```

### Scenario 2: Deploy to Azure & Test

```bash
# 1. Deploy infrastructure
cd terraform && terraform apply

# 2. SSH to master
ssh -A cassandra@<MASTER_IP>

# 3. Verify cluster
cqlsh localhost && SELECT * FROM system.peers; EXIT;

# 4. Deploy application (from your PC)
bash scripts/deploy-to-master.sh <MASTER_IP> <KEY_PATH>

# 5. Test in browser
# http://<MASTER_IP>/
```

### Scenario 3: Update Deployed Code

```bash
# Push to GitHub
git push origin main

# If GitHub Actions is set up, deployment runs automatically
# Otherwise, manually:

bash scripts/deploy-to-master.sh <MASTER_IP> <KEY_PATH>
```

### Scenario 4: Clean Up / Stop Paying

```bash
bash scripts/destroy-all.sh
# Type 'destroy' to confirm
```

---

## Performance Tips

1. **Use Standard_B2as_v2 or larger** for Cassandra nodes (avoid B1s due to quota limits)
2. **Split nodes across regions** if hitting per-region core limits
3. **Enable SSH agent forwarding** for seamless multi-hop SSH
4. **Use tmux/screen** on master for long-running operations
5. **Monitor Cassandra logs** for compaction/GC pauses

---

## Security Considerations

1. **NSG rules**: Restrict `allowed_ssh_ips` in `terraform.tfvars` to only your IP
2. **SSH key**: Never commit `ssh/id_rsa` (private) to GitHub; only `.pub` is safe
3. **Backend**: Listens on localhost only; only nginx can access it
4. **Cassandra**: Default auth enabled (cassandra/cassandra); change in production
5. **HTTPS**: Set up with Let's Encrypt (see HTTPS section above)
6. **.env files**: Never commit to repo; add to `.gitignore`

---

## Next Steps

- **Audit your cluster**: Click **Audit Live** tab
- **Harden it**: Follow recommended fixes from audit report
- **Monitor**: Set up Prometheus/Grafana for metrics
- **Scale**: Add more nodes by editing `terraform/variables.tf`
- **Backup**: Configure Cassandra backups for disaster recovery

---

## Support

For issues:

1. Check [Troubleshooting](#troubleshooting) section
2. Review logs: `sudo journalctl -u cis-backend -f`
3. Verify connectivity: `curl http://localhost:8000/health`
4. Check NSG rules: `az network nsg rule list -g cis-cassandra-rg`
5. SSH debug: `ssh -vvv cassandra@<IP>`

---

**Last updated**: April 30, 2026
