#!/bin/bash
# Deploy both frontend and backend to master VM
# Usage: bash deploy-to-master.sh <MASTER_IP> <SSH_KEY_PATH>

set -e

MASTER_IP="${1:-localhost}"
SSH_KEY_PATH="${2:-$HOME/.ssh/id_rsa}"
SSH_USER="cassandra"
#REPO_URL="https://github.com/your-org/cis-cassandra-main.git"  # Update this
REPO_URL="https://github.com/Triggermetric/test-cis"  # Update this

echo "Deploying CIS Cassandra to Master VM"
echo "========================================"
echo "Master IP: $MASTER_IP"
echo "SSH Key: $SSH_KEY_PATH"
echo "User: $SSH_USER"
echo ""

# Verify SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "ERROR: SSH key not found: $SSH_KEY_PATH"
    exit 1
fi

# Test SSH connection
echo "Testing SSH connection..."
if ! ssh -i "$SSH_KEY_PATH" "$SSH_USER@$MASTER_IP" "echo 'SSH OK'" &>/dev/null; then
    echo "ERROR: Cannot connect to master. Check IP and SSH key."
    exit 1
fi
echo "[OK] SSH connection OK"

# Deploy
echo ""
echo "Deploying application..."
ssh -i "$SSH_KEY_PATH" "$SSH_USER@$MASTER_IP" bash <<'DEPLOY_SCRIPT'
#!/bin/bash
set -e

echo "On master VM — starting deployment..."

# Create app directory
mkdir -p ~/app
cd ~/app

# Clone or pull repo (assumes git is installed)
if [ -d "cis-cassandra-main" ]; then
    echo "Updating repo..."
    cd cis-cassandra-main
    git pull origin main
    cd ..
else
    echo "Cloning repo..."
    git clone "$REPO_URL" cis-cassandra-main
fi

cd cis-cassandra-main

# Backend setup
echo ""
echo "Setting up backend..."
cd backend

# Create .env if not exists
if [ ! -f ".env" ]; then
    echo "Creating .env file..."
    cat > .env <<'ENV_FILE'
NODE_IPS=10.0.1.11,10.0.1.12,10.0.1.13
CASSANDRA_CONTACT_POINT=localhost
CIS_SSH_KEY=~/.ssh/id_rsa
CIS_SSH_USER=cassandra
ENV_FILE
    echo "[OK] Created .env"
else
    echo "[OK] .env already exists"
fi

# Install Python deps
pip install -r "$BACKEND_DIR/requirements.txt"

# Create systemd service for backend
echo "Installing backend systemd service..."
sudo tee /etc/systemd/system/cis-backend.service > /dev/null <<'SERVICE'
[Unit]
Description=CIS Cassandra Backend API
After=network.target

[Service]
Type=simple
User=cassandra
WorkingDirectory=/home/cassandra/app/cis-cassandra-main/backend
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Backend frontend setup
echo ""
echo "Setting up frontend..."
cd ../frontend

# Install Node deps
npm install

# Build frontend
npm run build

# Create nginx config for frontend + API proxy
echo "Configuring nginx..."
sudo tee /etc/nginx/sites-available/cis-cassandra > /dev/null <<'NGINX_CONF'
upstream backend {
    server 127.0.0.1:8000;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /home/cassandra/app/cis-cassandra-main/frontend/dist;
    index index.html;

    # Frontend static files
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy to backend
    location /api/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_request_buffering off;
    }

    # Disable caching for index.html
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
}
NGINX_CONF

# Enable nginx site
sudo ln -sf /etc/nginx/sites-available/cis-cassandra /etc/nginx/sites-enabled/cis-cassandra
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "[OK] Backend service created"
echo "[OK] Frontend built and nginx configured"
echo ""
echo "Starting/restarting services..."
sudo systemctl daemon-reload
sudo systemctl enable cis-backend
sudo systemctl restart cis-backend

echo "[OK] Backend service running"
echo "[OK] Nginx running"
echo ""
echo "[SUCCESS] Deployment complete!"
echo ""
echo "Access application at:"
echo "  🌐 http://$HOSTNAME/"
echo "  📖 Backend docs: http://$HOSTNAME/api/docs"
DEPLOY_SCRIPT

echo ""
echo "[SUCCESS] Deployment successful!"
echo ""
echo "Master services:"
echo "  - Frontend (nginx): http://$MASTER_IP/"
echo "  - Backend (systemd): http://$MASTER_IP/api/docs"
echo "  - Cassandra: 127.0.0.1:9042"
echo ""
echo "Next steps:"
echo "  1. Set up DNS or use the public IP to access the frontend"
echo "  2. Configure HTTPS/SSL certificate via Let's Encrypt (optional)"
echo "  3. Monitor logs: ssh ... tail -f /var/log/nginx/error.log"
