#!/bin/bash
# Frontend startup script — initializes npm and starts Vite dev server

set -e

FRONTEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting CIS Cassandra Frontend..."
echo "Frontend directory: $FRONTEND_DIR"

# Default API URL
API_URL="${VITE_API_URL:-http://localhost:8000}"

echo "Backend API URL: $API_URL"
echo "   (override with: VITE_API_URL=http://your-backend:8000 $0)"

# Check if node_modules exists
if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
    echo "Installing npm dependencies..."
    cd "$FRONTEND_DIR"
    npm install
else
    echo "[OK] npm dependencies already installed"
fi

# Start frontend
echo "Starting Vite dev server..."
echo "Frontend: http://localhost:5173"
echo ""
echo "Press Ctrl+C to stop."
echo ""

cd "$FRONTEND_DIR"
VITE_API_URL="$API_URL" npm run dev
