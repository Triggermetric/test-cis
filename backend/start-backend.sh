#!/bin/bash
# Backend startup script — initializes .env and starts FastAPI server

set -e

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$BACKEND_DIR/.env"

echo "Starting CIS Cassandra Backend..."
echo "Backend directory: $BACKEND_DIR"

# Check if .env exists; if not, create with defaults
if [ ! -f "$ENV_FILE" ]; then
    echo "Creating .env file with defaults..."
    cat > "$ENV_FILE" <<'EOF'
# Node IPs (update with your actual cluster node IPs)
NODE_IPS=10.0.1.11,10.0.1.12,10.0.1.13

# Cassandra contact point (master node or any seed node)
# If running locally with SSH: use 10.0.1.11 (requires network access)
# If running on master VM: use localhost
CASSANDRA_CONTACT_POINT=localhost

# SSH configuration (for audit/harden endpoints)
CIS_SSH_KEY=~/.ssh/id_rsa
CIS_SSH_USER=cassandra
EOF
    echo "[OK] .env created at $ENV_FILE"
    echo "  (Update NODE_IPS and CASSANDRA_CONTACT_POINT as needed)"
else
    echo "[OK] .env already exists"
fi

# Check if requirements installed
echo "Checking Python dependencies..."
if ! python3 -c "import fastapi" 2>/dev/null; then
    echo "Installing requirements..."
    pip install -r "$BACKEND_DIR/requirements.txt"
else
    echo "[OK] Dependencies already installed"
fi

# Start backend
echo "Starting uvicorn server on 0.0.0.0:8000..."
echo "API docs: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop."
echo ""

cd "$BACKEND_DIR"
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
