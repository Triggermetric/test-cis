#!/bin/bash
# Destroy everything and cleanup
# WARNING: This will delete all VMs, VNets, and storage

set -e

echo "DESTROY CONFIRMATION"
echo "======================="
echo "This will DELETE:"
echo "  - All VMs (master, db1, db2, db3)"
echo "  - VNets and subnets"
echo "  - NSGs and storage accounts"
echo "  - Key Vault and all secrets"
echo ""
echo "Data loss is PERMANENT. This cannot be undone."
echo ""

read -p "Type 'destroy' to confirm: " confirmation

if [ "$confirmation" != "destroy" ]; then
    echo "ERROR: Cancelled."
    exit 1
fi

cd terraform

echo ""
echo "Running terraform destroy..."
terraform destroy -auto-approve

echo ""
echo "[SUCCESS] Destroy complete. All resources have been deleted."
