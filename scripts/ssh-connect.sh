#!/bin/bash
# SSH setup helper — adds your key to agent and opens connection to master

set -e

# Check if running from a Git Bash, WSL, or native bash
if ! command -v ssh &> /dev/null; then
    echo "ERROR: SSH not found. Please use Git Bash, WSL, or native bash on Windows."
    exit 1
fi

# Default key and master IP
SSH_KEY="${1:-$HOME/.ssh/id_rsa}"
MASTER_IP="${2:-localhost}"
SSH_USER="cassandra"

echo "SSH Setup Helper"
echo "===================="
echo "Key: $SSH_KEY"
echo "Master IP: $MASTER_IP"
echo "User: $SSH_USER"
echo ""

# Check if key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "ERROR: SSH key not found at $SSH_KEY"
    echo "   Create one with: ssh-keygen -t rsa -b 4096 -f '$SSH_KEY'"
    exit 1
fi

echo "[OK] SSH key found"

# Add key to ssh-agent (only on Linux/macOS; Windows uses ssh-agent service)
if [ -z "$SSH_AUTH_SOCK" ]; then
    # Start agent
    echo "Starting ssh-agent..."
    eval "$(ssh-agent -s)"
fi

# Add key
echo "Adding key to agent..."
ssh-add "$SSH_KEY"

echo "[OK] Key added to agent"
echo ""
echo "Connecting to master..."
echo "   Command: ssh -A $SSH_USER@$MASTER_IP"
echo ""

# Connect with agent forwarding
ssh -A "$SSH_USER@$MASTER_IP"
