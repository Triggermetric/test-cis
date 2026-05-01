# ============================================================================
# RAPID DEPLOY & TEARDOWN FOR WINDOWS USERS
# ============================================================================
# Save this as DEPLOY_QUICK.ps1
# Run in PowerShell (NOT PowerShell ISE): powershell -ExecutionPolicy Bypass -File DEPLOY_QUICK.ps1

# ============================================================================
# SECTION 1: PRE-FLIGHT CHECKS
# ============================================================================

Write-Host "=== Checking Prerequisites ===" -ForegroundColor Green

# Check Azure CLI
try {
    $azVersion = az --version
    Write-Host "✓ Azure CLI installed" -ForegroundColor Green
} catch {
    Write-Host "✗ Azure CLI NOT found. Install from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows" -ForegroundColor Red
    exit
}

# Check Terraform
try {
    $tfVersion = terraform version
    Write-Host "✓ Terraform installed" -ForegroundColor Green
} catch {
    Write-Host "✗ Terraform NOT found. Install from: https://www.terraform.io/downloads" -ForegroundColor Red
    exit
}

# Check SSH key
$sshKeyPath = "$env:USERPROFILE\.ssh\cis_key"
if (Test-Path $sshKeyPath) {
    Write-Host "✓ SSH key found at $sshKeyPath" -ForegroundColor Green
} else {
    Write-Host "⚠ SSH key NOT found. Creating one..." -ForegroundColor Yellow
    Write-Host "When prompted, press Enter to use default passphrase (none)" -ForegroundColor Yellow
    ssh-keygen -t rsa -b 4096 -f $sshKeyPath -N ""
    Write-Host "✓ SSH key created" -ForegroundColor Green
}

# ============================================================================
# SECTION 2: SETUP TERRAFORM
# ============================================================================

$terraformDir = "j:\CloudProjects\cis-cassandra-main\terraform"
Set-Location $terraformDir
Write-Host "Working in: $terraformDir" -ForegroundColor Cyan

# Check for terraform.tfvars
if (!(Test-Path "terraform.tfvars")) {
    Write-Host "Creating terraform.tfvars..." -ForegroundColor Yellow
    
    # Get public IP
    $publicIp = (Invoke-WebRequest -Uri "https://ifconfig.me" -UseBasicParsing).Content.Trim()
    Write-Host "Your public IP: $publicIp" -ForegroundColor Cyan
    
    $tfvarsContent = @"
project_name        = "cis-cassandra"
resource_group_name = "cis-cassandra-rg"
location             = "Southeast Asia"
vm_size              = "Standard_B2als_v2"
ssh_public_key_path  = "$env:USERPROFILE\.ssh\cis_key.pub"
allowed_ssh_ips      = ["$publicIp/32"]
"@
    
    Set-Content -Path "terraform.tfvars" -Value $tfvarsContent
    Write-Host "✓ terraform.tfvars created with your IP: $publicIp" -ForegroundColor Green
} else {
    Write-Host "✓ terraform.tfvars already exists" -ForegroundColor Green
}

# ============================================================================
# SECTION 3: DEPLOY INFRASTRUCTURE
# ============================================================================

Write-Host "`n=== Initializing Terraform ===" -ForegroundColor Green
terraform init

Write-Host "`n=== Validating Configuration ===" -ForegroundColor Green
terraform validate

Write-Host "`n=== Planning Deployment ===" -ForegroundColor Green
terraform plan -out=tfplan

$confirm = Read-Host "Ready to deploy? This will create 4 VMs in Azure. Continue? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Deployment cancelled" -ForegroundColor Yellow
    exit
}

Write-Host "`n=== Deploying Infrastructure ===" -ForegroundColor Green
Write-Host "This takes 5-10 minutes. Grab some coffee..." -ForegroundColor Cyan
terraform apply tfplan

# ============================================================================
# SECTION 4: GET DEPLOYMENT DETAILS
# ============================================================================

Write-Host "`n=== Getting Deployment Details ===" -ForegroundColor Green

$outputs = terraform output -json | ConvertFrom-Json
$masterIp = $outputs.public_ips.value.master
$dbIps = @($outputs.private_ips.value.db1, $outputs.private_ips.value.db2, $outputs.private_ips.value.db3)

Write-Host "Master Public IP: $masterIp" -ForegroundColor Cyan
Write-Host "DB Node IPs: $($dbIps -join ', ')" -ForegroundColor Cyan

# Save outputs
terraform output | Out-File -FilePath "deployment-outputs.txt"
Write-Host "✓ Outputs saved to deployment-outputs.txt" -ForegroundColor Green

# ============================================================================
# SECTION 5: WAIT FOR CASSANDRA BOOTSTRAP
# ============================================================================

Write-Host "`n=== Waiting for Cassandra Cluster Bootstrap ===" -ForegroundColor Green
Write-Host "This typically takes 3-5 minutes..." -ForegroundColor Yellow

# Test SSH connectivity
$sshReady = $false
$maxRetries = 30
$retryCount = 0

while ($retryCount -lt $maxRetries) {
    try {
        ssh -i $sshKeyPath -o ConnectTimeout=3 -o StrictHostKeyChecking=no cassandra@$masterIp "echo OK" | Out-Null
        $sshReady = $true
        break
    } catch {
        $retryCount++
        Write-Host "Waiting for SSH... ($retryCount/$maxRetries)" -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
}

if ($sshReady) {
    Write-Host "✓ SSH is ready!" -ForegroundColor Green
} else {
    Write-Host "✗ SSH failed after timeout. Check master IP and security group rules." -ForegroundColor Red
    exit
}

# Check Cassandra cluster status
Write-Host "`nChecking Cassandra cluster status..." -ForegroundColor Cyan
ssh -i $sshKeyPath -o StrictHostKeyChecking=no cassandra@$masterIp `
    "ssh 10.0.1.11 'nodetool status'" 2>$null

# ============================================================================
# SECTION 6: CONFIGURE BACKEND
# ============================================================================

Write-Host "`n=== Configuring Backend ===" -ForegroundColor Green

$backendDir = "j:\CloudProjects\cis-cassandra-main\backend"
Set-Location $backendDir

# Create .env file
$envContent = @"
CIS_SSH_KEY=$sshKeyPath
CIS_SSH_USER=cassandra
NODE_IPS=10.0.1.11,10.0.1.12,10.0.1.13
"@

Set-Content -Path ".env" -Value $envContent
Write-Host "✓ .env file created" -ForegroundColor Green

# Install Python dependencies
Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt

# ============================================================================
# SECTION 7: INSTRUCTIONS FOR NEXT STEPS
# ============================================================================

Write-Host @"

=== ✓ DEPLOYMENT COMPLETE ===

Next steps (open new PowerShell windows):

TERMINAL 1 - Start Backend:
  cd $backendDir
  `$env:VITE_API_URL = 'http://localhost:8000'
  uvicorn main:app --reload --host 0.0.0.0 --port 8000

TERMINAL 2 - Start Frontend:
  cd j:\CloudProjects\cis-cassandra-main\frontend
  npm install (if needed)
  `$env:VITE_API_URL = 'http://localhost:8000'
  npm run dev

TERMINAL 3 - SSH into Cluster (optional):
  ssh -i $sshKeyPath cassandra@$masterIp
  
  # Then inside master:
  ssh 10.0.1.11  # Jump to DB1
  nodetool status
  sudo systemctl status cassandra
  sudo tail -100 /var/log/cassandra/system.log

THEN:
  Open: http://localhost:5173 in your browser
  
  Click "Audit All Nodes" to run real audit against your Azure cluster
  Or go to "Demo" tab for quick scenarios

=== VIEWING LOGS ===

Master Node Logs:
  ssh -i $sshKeyPath cassandra@$masterIp "ssh 10.0.1.11 'sudo tail -f /var/log/cassandra/system.log'"

Check Bootstrap Logs:
  ssh -i $sshKeyPath cassandra@$masterIp "ssh 10.0.1.11 'sudo tail -50 /var/log/cloud-init-output.log'"

=== QUICK CLEANUP ===

When done testing, destroy everything:
  cd $terraformDir
  terraform destroy
  
  Type 'yes' when prompted to delete all resources

=== TROUBLESHOOTING ===

If SSH fails:
  1. Check your IP is in terraform.tfvars allowed_ssh_ips
  2. Verify SSH key permissions:
     icacls $sshKeyPath /inheritance:r /grant:r "%USERDOMAIN%\%USERNAME%:F"
  
If Cassandra not responding:
  - Wait 2-3 more minutes and retry
  - Check: ssh -i $sshKeyPath cassandra@$masterIp "ssh 10.0.1.11 'sudo systemctl status cassandra'"

If frontend can't reach backend:
  - Make sure backend is running on http://localhost:8000
  - Check `$env:VITE_API_URL is set to http://localhost:8000
  
If audit fails:
  - SSH to master and manually test: ssh 10.0.1.11 "sudo bash /opt/cis/cis-tool.sh audit 2"

"@ -ForegroundColor Green

# Save a cleanup script
$cleanupScript = @"
# Cleanup script - run when done testing
cd $terraformDir
terraform destroy -auto-approve
Write-Host "✓ All resources deleted from Azure" -ForegroundColor Green
"@

Set-Content -Path "CLEANUP.ps1" -Value $cleanupScript
Write-Host "Cleanup script saved to: $terraformDir\CLEANUP.ps1" -ForegroundColor Cyan

pause
