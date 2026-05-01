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

Fully automated testing and manual deployment workflows via GitHub Actions.

### Architecture Overview

Three separate workflows, all **manual-triggered** for safety:

1. **Deploy Infrastructure** (`deploy-infrastructure.yml`)
   - Runs `terraform apply` to create VMs
   - Triggered manually to prevent accidental infrastructure changes

2. **Deploy to Master VM** (`deploy-to-production.yml`)
   - Runs tests, builds frontend, deploys code to Master
   - Automatically extracts Master IP from Terraform outputs
   - No MASTER_IP secret needed!

3. **Destroy Infrastructure** (`destroy-infrastructure.yml`)
   - Runs `terraform destroy` to delete all VMs
   - Double-confirmation required

### Prerequisites

1. Repository must be on GitHub
2. SSH key for Master VM access (uses same key as Terraform: `ssh/id_rsa`)
3. Azure service account configured with OIDC (one-time setup)

---

### Part 1: Azure OIDC Setup (One-Time)

The workflows authenticate to Azure using OIDC (no credentials stored in GitHub — more secure).

#### Step 1: Create Azure Service Principal

```bash
# Create service principal
az ad app create --display-name "cis-cassandra-github-actions"
# Save the appId from output

# Get your Azure IDs
$TENANT_ID = $(az account show --query tenantId -o tsv)
$SUBSCRIPTION_ID = $(az account show --query id -o tsv)
$APP_ID = "<paste-appId-from-above>"
```

#### Step 2: Create OIDC Federated Credential

```bash
az ad app federated-credential create \
  --id $APP_ID \
  --parameters @-
{
  "name": "github-actions",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR_GITHUB_ORG/cis-cassandra-main:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
```

#### Step 3: Grant Azure Permissions

```bash
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID
```

#### Step 4: Add GitHub Secrets

1. Go to GitHub Repo → Settings → Secrets and variables → Actions
2. Create these secrets:

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | $APP_ID from Step 1 |
| `AZURE_TENANT_ID` | $TENANT_ID from Step 1 |
| `AZURE_SUBSCRIPTION_ID` | $SUBSCRIPTION_ID from Step 1 |
| `MASTER_SSH_PRIVATE_KEY` | Full contents of `ssh/id_rsa` |

---

### Part 2: Deploy Infrastructure (Manual Workflow)

Creates all Azure VMs and networking for your Cassandra cluster.

#### Trigger Deployment:

1. Go to GitHub → **Actions** tab
2. Click **Deploy Infrastructure (Terraform Apply)**
3. Click **Run workflow**
4. Enter confirmation: `deploy-infrastructure` (exactly)
5. Click **Run workflow**

#### What Happens:

```
✅ Checkout code
✅ Initialize Terraform
✅ Validate configuration
✅ Plan infrastructure (shows what will be created)
✅ Apply Terraform (creates 4 VMs across 2 Azure regions)
✅ Save outputs to infra-outputs.json
✅ Wait 60 seconds for VMs to boot
✅ Test SSH connectivity
```

#### Expected Output:

```json
{
  "master_public_ip": { "value": "20.195.123.45" },
  "node_ips": { "value": ["10.0.1.11", "10.0.1.12", "10.1.1.13"] },
  ...
}
```

#### Next Step:

Wait 3-5 minutes for Cassandra to bootstrap, then proceed to **Part 3**.

---

### Part 3: Deploy Application to Master VM (Manual Workflow)

Deploys CIS Cassandra frontend + backend to the Master VM created by Part 2.

#### Trigger Deployment:

1. Go to **Actions** tab
2. Click **Deploy to Master VM (Manual)**
3. Click **Run workflow**
4. Choose environment: `production` or `staging`
5. Click **Run workflow**

#### What Happens:

```
✅ Extract Master IP from terraform.tfstate (NO SECRET NEEDED!)
✅ Run all tests (Python + JavaScript)
✅ Build React frontend
✅ SSH to Master VM using ssh/id_rsa private key
✅ Execute deployment script
✅ Verify backend health endpoint
✅ Verify frontend is accessible
✅ Report success with URLs
```

**No manual IP configuration needed** — automatically fetched from Terraform! 🎯

#### Expected Result:

```
✅ DEPLOYMENT SUCCESSFUL

🎉 Your application is live!
   Frontend:  http://20.195.123.45
   Backend:   http://20.195.123.45/api
   API Docs:  http://20.195.123.45/api/docs
```

---

### Part 4: Destroy Infrastructure (Manual Workflow)

Permanently deletes all VMs and Azure resources.

#### Trigger Destruction:

1. Go to **Actions** tab
2. Click **Destroy Infrastructure (Terraform)**
3. Click **Run workflow**
4. Enter confirmation: `destroy-all-infrastructure` (exactly)
5. Click **Run workflow**

#### What Happens:

```
✅ Safety check (requires confirmation)
✅ Back up terraform.tfstate
✅ Gracefully stop services on Master VM
✅ Run terraform destroy -auto-approve
✅ Verify all resources deleted
```

---

## SSH Key Security & Architecture

Your setup uses the **SAME SSH key throughout**:

```
GitHub Actions
  ↓ (uses MASTER_SSH_PRIVATE_KEY secret)
  └─ SSH to cassandra@<MASTER_IP>
     ├─ Deploy script clones/pulls repo
     ├─ Builds frontend
     └─ Restarts services
        └─ Master VM has /home/cassandra/.ssh/id_rsa
           ↓ (same key, configured by Terraform)
           ├─ SSH to db1 (10.0.1.11) for CIS audits
           ├─ SSH to db2 (10.1.1.12)
           └─ SSH to db3 (10.1.1.13)
```

### Best Practices:

✅ **DO:**
- Keep `ssh/id_rsa` in `.gitignore` (already done)
- Use strong passphrase if key is local
- Rotate keys periodically
- Audit SSH access: `sudo journalctl -u ssh -f`

❌ **DON'T:**
- Commit `ssh/id_rsa` to Git
- Share the private key
- Use same key for multiple projects
- Leave keys with empty passphrases on shared machines

---

## Workflow Comparison

| Workflow | Trigger | Purpose | Auto IP |
|----------|---------|---------|---------|
| Deploy Infrastructure | Manual only | Create VMs | N/A |
| Deploy to Master VM | Manual only | Test + Deploy code | ✅ Yes |
| Destroy Infrastructure | Manual only | Delete all resources | N/A |

**Why Manual?** Prevents accidental deployments/destruction from code commits.

---

## Troubleshooting

### "terraform.tfstate not found"

**Cause:** Infrastructure not deployed yet

**Fix:** Run "Deploy Infrastructure" workflow first

---

### "Permission denied (publickey)"

**Cause:** SSH key not configured correctly

**Fix:** Verify `MASTER_SSH_PRIVATE_KEY` secret contains the full key (BEGIN...END)

---

### "Master IP extraction failed"

**Cause:** Terraform outputs format changed

**Fix:** Check `infra-outputs.json` artifact in workflow run

---

### Cassandra cluster not forming

**Cause:** VMs still booting

**Fix:** Wait 3-5 minutes and re-run deployment workflow

---

## Manual Deployment (When Workflows Fail)

If automation fails, deploy manually:

```bash
# Get Master IP from terraform
cd terraform
terraform output -raw master_public_ip

# Deploy manually
bash scripts/deploy-to-master.sh <MASTER_IP> ssh/id_rsa
```

---

## Next Steps After First Deploy

1. ✅ Set up Azure OIDC (Part 1)
2. ✅ Run "Deploy Infrastructure" workflow (Part 2)
3. ✅ Wait 5 minutes for Cassandra bootstrap
4. ✅ Run "Deploy to Master VM" workflow (Part 3)
5. ✅ Access application at `http://<MASTER_IP>`

Enjoy! 🚀

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
