# ============================================================================
# GitHub Actions CI/CD Setup Script for Windows (PowerShell)
# ============================================================================
# This script helps you configure GitHub Secrets for CI/CD workflows
# 
# Usage: powershell -ExecutionPolicy Bypass -File scripts/setup-github-actions.ps1

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  GitHub Actions CI/CD Setup for CIS Cassandra                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Part 1: Prepare SSH Key Secret
# ============================================================================

Write-Host "Step 1: SSH Key Configuration" -ForegroundColor Green
Write-Host "────────────────────────────────────────────────────────────────"
Write-Host ""

$sshKeyPath = "ssh\id_rsa"

if (!(Test-Path $sshKeyPath)) {
    Write-Host "❌ ERROR: ssh/id_rsa not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please generate SSH keys first:" -ForegroundColor Yellow
    Write-Host "  mkdir ssh"
    Write-Host "  ssh-keygen -t rsa -b 4096 -f ssh/id_rsa -N '`"''"
    exit 1
}

Write-Host "✓ SSH private key found at: $sshKeyPath" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Copy the ENTIRE content below (including BEGIN and END lines):" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────────────────────────────"
Get-Content $sshKeyPath
Write-Host "────────────────────────────────────────────────────────────────"
Write-Host ""
Write-Host "🔐 This will become the MASTER_SSH_PRIVATE_KEY secret in GitHub" -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# Part 2: Get Master IP
# ============================================================================

Write-Host "Step 2: Master VM IP Address" -ForegroundColor Green
Write-Host "────────────────────────────────────────────────────────────────"
Write-Host ""

$masterIp = ""

if (Test-Path "infra-outputs.json") {
    try {
        $infraOutputs = Get-Content "infra-outputs.json" | ConvertFrom-Json
        $masterIp = $infraOutputs.master_public_ip.value
        if ($masterIp) {
            Write-Host "✓ Found Master IP in infra-outputs.json: $masterIp" -ForegroundColor Green
        }
    } catch {
        Write-Host "[ℹ] Could not parse infra-outputs.json" -ForegroundColor Yellow
    }
}

if (!$masterIp -and (Test-Path "terraform\terraform.tfstate")) {
    try {
        $tfState = Get-Content "terraform\terraform.tfstate" | ConvertFrom-Json
        $masterIp = $tfState.outputs.master_public_ip.value
        if ($masterIp) {
            Write-Host "✓ Found Master IP in terraform.tfstate: $masterIp" -ForegroundColor Green
        }
    } catch {
        Write-Host "[ℹ] Could not parse terraform.tfstate" -ForegroundColor Yellow
    }
}

if (!$masterIp) {
    Write-Host "❌ Could not find Master IP automatically" -ForegroundColor Yellow
    Write-Host ""
    $masterIp = Read-Host "Enter your Master VM public IP address"
}

Write-Host ""
Write-Host "📝 MASTER_IP secret value: $masterIp" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Part 3: Instructions
# ============================================================================

Write-Host "Step 3: Configure GitHub Secrets" -ForegroundColor Green
Write-Host "────────────────────────────────────────────────────────────────"
Write-Host ""
Write-Host "1. Open your browser and go to:" -ForegroundColor Yellow
Write-Host "   https://github.com/YOUR_ORG/cis-cassandra-main/settings/secrets/actions" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Click 'New repository secret' and create BOTH of these:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   Secret 1:" -ForegroundColor Cyan
Write-Host "   ├─ Name: MASTER_IP" -ForegroundColor Gray
Write-Host "   └─ Value: $masterIp" -ForegroundColor Gray
Write-Host ""
Write-Host "   Secret 2:" -ForegroundColor Cyan
Write-Host "   ├─ Name: MASTER_SSH_PRIVATE_KEY" -ForegroundColor Gray
Write-Host "   └─ Value: [Paste the full SSH key from Step 1 above]" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Save both secrets" -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# Part 4: Optional - Azure OIDC Setup
# ============================================================================

Write-Host "Step 4: Azure OIDC Setup (Optional - for Destroy Workflow)" -ForegroundColor Green
Write-Host "────────────────────────────────────────────────────────────────"
Write-Host ""
Write-Host "To enable the infrastructure destruction workflow, you need to" -ForegroundColor Yellow
Write-Host "configure Azure OIDC (no credentials stored in GitHub)." -ForegroundColor Yellow
Write-Host ""
Write-Host "Follow these commands in PowerShell:" -ForegroundColor Cyan
Write-Host ""

Write-Host "# 1. Create Azure service principal" -ForegroundColor DarkGray
Write-Host "az ad app create --display-name 'cis-cassandra-github-actions'" -ForegroundColor White
Write-Host ""

Write-Host "# 2. Save the appId from the output (you'll need it next)" -ForegroundColor DarkGray
Write-Host ""

Write-Host "# 3. Get your Azure IDs" -ForegroundColor DarkGray
Write-Host "`$TENANT_ID = `$(az account show --query tenantId -o tsv)" -ForegroundColor White
Write-Host "`$SUBSCRIPTION_ID = `$(az account show --query id -o tsv)" -ForegroundColor White
Write-Host "`$APP_ID = '<paste-appId-from-step-1>'" -ForegroundColor White
Write-Host ""

Write-Host "# 4. Create OIDC federated credential" -ForegroundColor DarkGray
Write-Host "az ad app federated-credential create \\" -ForegroundColor White
Write-Host "  --id `$APP_ID \\" -ForegroundColor White
Write-Host "  --parameters @" -ForegroundColor White
Write-Host "@" -ForegroundColor White
Write-Host "{" -ForegroundColor White
Write-Host '    "name": "github-actions",' -ForegroundColor White
Write-Host '    "issuer": "https://token.actions.githubusercontent.com",' -ForegroundColor White
Write-Host '    "subject": "repo:YOUR_ORG/cis-cassandra-main:ref:refs/heads/main",' -ForegroundColor White
Write-Host '    "audiences": ["api://AzureADTokenExchange"]' -ForegroundColor White
Write-Host "}" -ForegroundColor White
Write-Host "@" -ForegroundColor White
Write-Host ""

Write-Host "# 5. Assign Contributor role" -ForegroundColor DarkGray
Write-Host "az role assignment create \\" -ForegroundColor White
Write-Host "  --assignee `$APP_ID \\" -ForegroundColor White
Write-Host "  --role Contributor \\" -ForegroundColor White
Write-Host "  --scope /subscriptions/`$SUBSCRIPTION_ID" -ForegroundColor White
Write-Host ""

Write-Host "# 6. Add GitHub Secrets (via browser):" -ForegroundColor DarkGray
Write-Host "#    AZURE_CLIENT_ID = `$APP_ID" -ForegroundColor Gray
Write-Host "#    AZURE_TENANT_ID = `$TENANT_ID" -ForegroundColor Gray
Write-Host "#    AZURE_SUBSCRIPTION_ID = `$SUBSCRIPTION_ID" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# Final Summary
# ============================================================================

Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "📝 Summary:" -ForegroundColor Cyan
Write-Host "   • SSH key: $(if (Test-Path $sshKeyPath) { '✓ Ready' } else { '✗ Missing' })" -ForegroundColor Gray
Write-Host "   • Master IP: $masterIp" -ForegroundColor Gray
Write-Host "   • GitHub Secrets configured: (Manual step above)" -ForegroundColor Gray
Write-Host ""
Write-Host "🚀 Next Steps:" -ForegroundColor Green
Write-Host "   1. Add secrets to GitHub (use links above)" -ForegroundColor Yellow
Write-Host "   2. Push code to main branch:" -ForegroundColor Yellow
Write-Host "      git push origin main" -ForegroundColor Cyan
Write-Host "   3. Watch deployment in Actions tab:" -ForegroundColor Yellow
Write-Host "      https://github.com/YOUR_ORG/cis-cassandra-main/actions" -ForegroundColor Cyan
Write-Host ""
Write-Host "📖 For detailed instructions, see SETUP.md section:" -ForegroundColor Cyan
Write-Host "   'GitHub Actions CI/CD Automation'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Gray
Read-Host
