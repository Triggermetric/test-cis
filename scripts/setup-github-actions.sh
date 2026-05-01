#!/bin/bash
# ============================================================================
# GitHub Actions CI/CD Setup Script (Cross-Platform)
# ============================================================================
# This script helps you configure GitHub Secrets for CI/CD workflows
# Run this from your machine (not on the Master VM)
# 
# Usage: 
#   Bash/Linux/macOS:  bash scripts/setup-github-actions.sh
#   Windows (Git Bash): bash scripts/setup-github-actions.sh
#   Windows (PowerShell): powershell -ExecutionPolicy Bypass -File scripts/setup-github-actions.ps1

# Detect OS for proper command usage
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    IS_WINDOWS=true
    CAT_CMD="Get-Content"
else
    IS_WINDOWS=false
    CAT_CMD="cat"
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  GitHub Actions CI/CD Setup for CIS Cassandra                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# Part 1: Prepare SSH Key Secret
# ============================================================================

echo "Step 1: SSH Key Configuration"
echo "────────────────────────────────────────────────────────────────"
echo ""

if [ ! -f "ssh/id_rsa" ]; then
    echo "❌ ERROR: ssh/id_rsa not found!"
    echo ""
    echo "Please generate SSH keys first:"
    if [ "$IS_WINDOWS" = true ]; then
        echo "  mkdir ssh"
        echo "  ssh-keygen -t rsa -b 4096 -f ssh/id_rsa -N ''''"
    else
        echo "  mkdir -p ssh"
        echo "  ssh-keygen -t rsa -b 4096 -f ssh/id_rsa -N ''"
    fi
    exit 1
fi

echo "✓ SSH private key found at: ssh/id_rsa"
echo ""
echo "📋 Copy the ENTIRE content below (including BEGIN and END lines):"
echo "────────────────────────────────────────────────────────────────"

if [ "$IS_WINDOWS" = true ]; then
    # Windows PowerShell Get-Content
    powershell -Command "Get-Content 'ssh/id_rsa'" 2>/dev/null || cat ssh/id_rsa
else
    cat ssh/id_rsa
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "🔐 This will become the MASTER_SSH_PRIVATE_KEY secret in GitHub"
echo ""

# ============================================================================
# Part 2: Get Master IP
# ============================================================================

echo "Step 2: Master VM IP Address"
echo "────────────────────────────────────────────────────────────────"
echo ""

if [ -f "infra-outputs.json" ]; then
    MASTER_IP=$(jq -r '.master_public_ip.value' infra-outputs.json 2>/dev/null || echo "")
    if [ -n "$MASTER_IP" ]; then
        echo "✓ Found Master IP in infra-outputs.json: $MASTER_IP"
    fi
fi

if [ -z "$MASTER_IP" ]; then
    if [ -d "terraform" ] && [ -f "terraform/terraform.tfstate" ]; then
        MASTER_IP=$(jq -r '.outputs.master_public_ip.value' terraform/terraform.tfstate 2>/dev/null || echo "")
        if [ -n "$MASTER_IP" ]; then
            echo "✓ Found Master IP in terraform.tfstate: $MASTER_IP"
        fi
    fi
fi

if [ -z "$MASTER_IP" ]; then
    echo "❌ Could not find Master IP automatically"
    echo ""
    read -p "Enter your Master VM public IP address: " MASTER_IP
fi

echo ""
echo "📝 MASTER_IP secret value: $MASTER_IP"
echo ""

# ============================================================================
# Part 3: Instructions
# ============================================================================

echo "Step 3: Configure GitHub Secrets"
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "1. Open: https://github.com/YOUR_ORG/cis-cassandra-main/settings/secrets/actions"
echo ""
echo "2. Click 'New repository secret' and create BOTH of these:"
echo ""
echo "   Secret 1:"
echo "   ├─ Name: MASTER_IP"
echo "   └─ Value: $MASTER_IP"
echo ""
echo "   Secret 2:"
echo "   ├─ Name: MASTER_SSH_PRIVATE_KEY"
echo "   └─ Value: [Paste the full SSH key from Step 1 above]"
echo ""
echo "3. Save both secrets"
echo ""

# ============================================================================
# Part 4: Optional - Azure OIDC Setup
# ============================================================================

echo "Step 4: Azure OIDC Setup (Optional - for Destroy Workflow)"
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "To enable the infrastructure destruction workflow, you need to"
echo "configure Azure OIDC (no credentials stored in GitHub)."
echo ""
echo "Follow these commands:"
echo ""

echo "# 1. Create Azure service principal"
echo "az ad app create --display-name 'cis-cassandra-github-actions'"
echo ""

echo "# 2. Note the following from the output:"
echo "#    - appId (Application ID)"
echo "#    - id (Object ID)"
echo ""

echo "# 3. Get your Azure IDs"
echo "TENANT_ID=\$(az account show --query tenantId -o tsv)"
echo "SUBSCRIPTION_ID=\$(az account show --query id -o tsv)"
echo "echo \"Tenant ID: \$TENANT_ID\""
echo "echo \"Subscription ID: \$SUBSCRIPTION_ID\""
echo ""

echo "# 4. Create OIDC federated credential"
echo "az ad app federated-credential create \\"
echo "  --id <APP_ID> \\"
echo "  --parameters '{"
echo "    \"name\": \"github-actions\","
echo "    \"issuer\": \"https://token.actions.githubusercontent.com\","
echo "    \"subject\": \"repo:YOUR_ORG/cis-cassandra-main:ref:refs/heads/main\","
echo "    \"audiences\": [\"api://AzureADTokenExchange\"]"
echo "  }'"
echo ""

echo "# 5. Assign Contributor role"
echo "az role assignment create \\"
echo "  --assignee <APP_ID> \\"
echo "  --role Contributor \\"
echo "  --scope /subscriptions/\$SUBSCRIPTION_ID"
echo ""

echo "# 6. Add GitHub Secrets:"
echo "#    AZURE_CLIENT_ID = <APP_ID>"
echo "#    AZURE_TENANT_ID = \$TENANT_ID"
echo "#    AZURE_SUBSCRIPTION_ID = \$SUBSCRIPTION_ID"
echo ""

# ============================================================================
# Final Summary
# ============================================================================

echo "✅ Setup Complete!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📝 Summary:"
echo "   • SSH key: $( [ -f "ssh/id_rsa" ] && echo "✓ Ready" || echo "✗ Missing" )"
echo "   • Master IP: $MASTER_IP"
echo "   • GitHub Secrets configured: (Manual step above)"
echo ""
echo "🚀 Next Steps:"
echo "   1. Add secrets to GitHub (use links above)"
echo "   2. Push code to main branch:"
echo "      git push origin main"
echo "   3. Watch deployment in Actions tab:"
echo "      https://github.com/YOUR_ORG/cis-cassandra-main/actions"
echo ""
echo "📖 For detailed instructions, see SETUP.md section:"
echo "   'GitHub Actions CI/CD Automation'"
echo ""
