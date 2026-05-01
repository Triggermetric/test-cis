#!/bin/bash
# Quick start orchestration — backend + frontend in separate tmux windows

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$REPO_ROOT/backend"
FRONTEND_DIR="$REPO_ROOT/frontend"

echo "CIS Cassandra Quick Start Orchestration"
echo "=========================================="
echo "Repository: $REPO_ROOT"
echo ""

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "WARNING: tmux not found. Starting backend and frontend sequentially instead."
    echo "   (Install tmux for parallel execution: apt-get install tmux)"
    echo ""
    echo "Starting backend..."
    bash "$BACKEND_DIR/start-backend.sh" &
    BACKEND_PID=$!
    sleep 2
    
    echo ""
    echo "Starting frontend..."
    bash "$FRONTEND_DIR/start-frontend.sh" &
    FRONTEND_PID=$!
    
    echo ""
    echo "[OK] Both services started in background"
    echo "  Backend PID: $BACKEND_PID"
    echo "  Frontend PID: $FRONTEND_PID"
    echo ""
    echo "To stop:"
    echo "  kill $BACKEND_PID $FRONTEND_PID"
    
    wait
else
    echo "[OK] tmux found, starting services in separate windows..."
    
    # Create new tmux session
    SESSION="cis-cassandra"
    
    # Kill existing session if present
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    
    # Create new session with backend window
    tmux new-session -d -s "$SESSION" -n "backend"
    tmux send-keys -t "$SESSION:backend" "bash '$BACKEND_DIR/start-backend.sh'" Enter
    
    # Create frontend window
    tmux new-window -t "$SESSION" -n "frontend"
    tmux send-keys -t "$SESSION:frontend" "bash '$FRONTEND_DIR/start-frontend.sh'" Enter
    
    echo "[OK] Services started in tmux session: $SESSION"
    echo ""
    echo "Commands:"
    echo "  tmux attach -t $SESSION          # Attach to session"
    echo "  tmux select-window -t $SESSION:0 # Switch to backend"
    echo "  tmux select-window -t $SESSION:1 # Switch to frontend"
    echo "  tmux kill-session -t $SESSION    # Kill all"
    echo ""
    echo "Frontend: http://localhost:5173"
    echo "Backend docs: http://localhost:8000/docs"
    echo ""
    
    # Optionally attach
    read -p "Attach to session now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux attach -t "$SESSION"
    fi
fi
