#!/bin/bash
# ============================================================================
# RAPID DEPLOY & TEARDOWN GUIDE for CIS Cassandra on Azure
# ============================================================================
# This script provides all commands needed for quick testing
# Copy-paste each section into your terminal

# ============================================================================
# SECTION 1: PRE-FLIGHT CHECKS
# ============================================================================

# 1. Check if Azure CLI is installed
az --version

# 2. Login to Azure (if not already logged in)
az login

# 3. Check if Terraform is installed
terraform --version

# 4. Set your preferred Azure region (or use Southeast Asia like the project)
REGION="Southeast Asia"
echo "Using region: $REGION"


# ============================================================================
# SECTION 2: GENERATE SSH KEY (one-time)
# ============================================================================

# 1. Create SSH key pair (if you don't have one)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cis_key -N ""

# 2. Verify the key was created
ls -lh ~/.ssh/cis_key*


# ============================================================================
# SECTION 3: CREATE TERRAFORM VARIABLES FILE
# ============================================================================

# Navigate to terraform directory
cd j:\CloudProjects\cis-cassandra-main\terraform

# Create terraform.tfvars (replace values as needed)
cat > terraform.tfvars << 'EOF'
project_name        = "cis-cassandra"
resource_group_name = "cis-cassandra-rg"
location             = "Southeast Asia"
vm_size              = "Standard_B2als_v2"
ssh_public_key_path  = "~/.ssh/cis_key.pub"

# Add your public IP to allow SSH access
# Find your IP: curl ifconfig.me
allowed_ssh_ips      = ["YOUR_PUBLIC_IP/32"]
EOF

# Example: If your IP is 203.0.113.45:
# allowed_ssh_ips      = ["203.0.113.45/32"]


# ============================================================================
# SECTION 4: DEPLOY INFRASTRUCTURE
# ============================================================================

# 1. Initialize Terraform (first time only)
terraform init

# 2. Validate the configuration
terraform validate

# 3. Preview what will be created (IMPORTANT: review this!)
terraform plan -out=tfplan

# 4. Apply and deploy (takes 5-10 minutes)
# This creates: VNet, 4 VMs, NSG, Cassandra cluster
terraform apply tfplan

# 5. Save outputs (you'll need these to access nodes)
terraform output > deployment-outputs.txt
cat deployment-outputs.txt


# ============================================================================
# SECTION 5: WAIT FOR CLUSTER BOOTSTRAP
# ============================================================================

# Cassandra takes 3-5 minutes to bootstrap on first startup
# Check the outputs for the master node's public IP
MASTER_IP=$(terraform output -raw public_ips | grep -o '"master" = "[^"]*' | cut -d'"' -f4)
echo "Master node public IP: $MASTER_IP"

# Test SSH connectivity (should work immediately)
ssh -i ~/.ssh/cis_key -o ConnectTimeout=5 cassandra@$MASTER_IP "echo 'SSH working!'"

# Wait a couple minutes, then verify Cassandra is running
sleep 120

# SSH into master and check Cassandra status
ssh -i ~/.ssh/cis_key cassandra@$MASTER_IP << 'SSHCOMMAND'
  # Inside the master node
  echo "=== Checking Cassandra status on all nodes ==="
  
  # Jump to DB1 and check status
  ssh 10.0.1.11 "sudo nodetool status"
  
  # You should see output like:
  # Datacenter: datacenter1
  # ===============================
  # Status=Up/Down
  # |/ State=Normal/Leaving/Joining/Moving
  # --  Address      Load       Tokens  Owns (effective)  Host ID                               Rack
  # UN  10.0.1.11   103.88 KB  256     33.3%             12345678-1234-1234-1234-123456789012  rack1
  # UN  10.0.1.12   102.45 KB  256     33.3%             87654321-4321-4321-4321-210987654321  rack1
  # UN  10.0.1.13   101.92 KB  256     33.3%             abcdefgh-abcd-abcd-abcd-abcdefghijkl  rack1
SSHCOMMAND


# ============================================================================
# SECTION 6: START BACKEND & FRONTEND LOCALLY
# ============================================================================

# Terminal 1: Start the backend (targets remote Azure cluster)
cd j:\CloudProjects\cis-cassandra-main\backend

# Install dependencies
pip install -r requirements.txt

# Create .env file with Azure node IPs
cat > .env << 'EOF'
CIS_SSH_KEY=~/.ssh/cis_key
CIS_SSH_USER=cassandra
NODE_IPS=10.0.1.11,10.0.1.12,10.0.1.13
EOF

# Start FastAPI backend (runs on localhost:8000)
uvicorn main:app --reload --host 0.0.0.0 --port 8000


# Terminal 2: Start the frontend (in another terminal)
cd j:\CloudProjects\cis-cassandra-main\frontend

# Install dependencies
npm install

# Set API URL for remote backend
# On Windows, use:
set VITE_API_URL=http://localhost:8000

# On macOS/Linux, use:
export VITE_API_URL=http://localhost:8000

# Start dev server (runs on localhost:5173)
npm run dev


# ============================================================================
# SECTION 7: ACCESS THE DASHBOARD
# ============================================================================

# Open browser:
# http://localhost:5173

# Features to test:
# 1. Dashboard: Shows fixture data (73% baseline compliance)
# 2. Click "Audit All Nodes" to run real audit against Azure cluster
# 3. Demo tab: Quick scenario audits
# 4. Compliance tab: Detailed check results
# 5. Monitoring tab: Node health status


# ============================================================================
# SECTION 8: MANUAL CLUSTER ACCESS
# ============================================================================

# SSH into Master node
MASTER_IP=$(terraform output -raw public_ips | grep -o '"master" = "[^"]*' | cut -d'"' -f4)
ssh -i ~/.ssh/cis_key cassandra@$MASTER_IP

# Once in master, jump to a DB node
ssh 10.0.1.11

# Check Cassandra status
nodetool status
nodetool info

# Check Cassandra version
cassandra -v

# Check system health
free -h
df -h
sudo systemctl status cassandra


# ============================================================================
# SECTION 9: VIEW LOGS
# ============================================================================

# 1. Cassandra logs (on any DB node)
ssh -i ~/.ssh/cis_key cassandra@$MASTER_IP << 'SSHCOMMAND'
  ssh 10.0.1.11 "sudo tail -100 /var/log/cassandra/system.log"
SSHCOMMAND

# 2. Cloud-init bootstrap logs (how nodes were set up)
ssh -i ~/.ssh/cis_key cassandra@$MASTER_IP << 'SSHCOMMAND'
  ssh 10.0.1.11 "sudo tail -50 /var/log/cloud-init-output.log"
SSHCOMMAND

# 3. Backend logs (running locally in terminal)
# Already visible in Terminal 1 where uvicorn is running

# 4. Frontend browser console
# Open DevTools: F12 or Ctrl+Shift+I
# Check Console and Network tabs


# ============================================================================
# SECTION 10: RUN TESTS
# ============================================================================

# Backend tests
cd j:\CloudProjects\cis-cassandra-main\backend
pytest -v

# Frontend tests
cd j:\CloudProjects\cis-cassandra-main\frontend
npm test


# ============================================================================
# SECTION 11: QUICK TEARDOWN (DELETE EVERYTHING)
# ============================================================================

# Go back to terraform directory
cd j:\CloudProjects\cis-cassandra-main\terraform

# DESTROY all Azure resources (this is IRREVERSIBLE)
# Review the output - it will list everything to be deleted
terraform plan -destroy

# Actually destroy (type 'yes' when prompted)
terraform destroy

# Verify everything is deleted in Azure
az group list --query "[].name" | grep cis-cassandra


# ============================================================================
# SECTION 12: TROUBLESHOOTING
# ============================================================================

# Issue: "Cassandra not responding to nodetool"
# Solution: Wait 2-3 more minutes, Cassandra can take time to bootstrap

# Issue: "SSH: Permission denied"
# Solution: Check SSH key permissions
chmod 600 ~/.ssh/cis_key
chmod 644 ~/.ssh/cis_key.pub

# Issue: "SSH: Network unreachable"
# Solution: 
# - Verify your public IP is in allowed_ssh_ips
# - Check Azure NSG inbound rules
az network nsg rule list -g cis-cassandra-rg -n cis-cassandra-nsg

# Issue: "Audit fails: Connection timeout"
# Solution: Ensure backend can reach Azure cluster
# - Verify NODE_IPS in .env file
# - Check SSH key is correct
# - Test manually: ssh -i ~/.ssh/cis_key cassandra@10.0.1.11

# Issue: "Frontend can't connect to backend"
# Solution: 
# - Backend should be running on http://localhost:8000
# - Check terminal 1 for uvicorn errors
# - Verify VITE_API_URL is set correctly

echo "=== DEPLOYMENT GUIDE COMPLETE ==="
