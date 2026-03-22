#!/bin/bash

# MiroFish - Server Management Script
# Start/stop/restart/status for MiroFish backend

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SERVICE_NAME="MiroFish"
PORT=5001
PID_FILE="/tmp/mirofish.pid"
LOG_FILE="logs/server.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }

# Check if server is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Start server
start_server() {
    if is_running; then
        print_warning "$SERVICE_NAME is already running (PID: $(cat $PID_FILE))"
        return
    fi

    print_info "Starting $SERVICE_NAME..."

    # Check if .env exists
    if [ ! -f ".env" ]; then
        print_error ".env file not found. Run ./setup.sh first"
        exit 1
    fi

    # Check if backend venv exists
    if [ ! -d "backend/.venv" ]; then
        print_error "Backend virtual environment not found. Run ./setup.sh first"
        exit 1
    fi

    # Create logs directory
    mkdir -p logs

    # Ensure uv is in PATH
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    # Start backend using run.py (Flask app)
    cd backend
    nohup uv run python run.py > "../$LOG_FILE" 2>&1 &
    PID=$!
    cd ..
    echo $PID > "$PID_FILE"

    # Wait a moment and check if it started
    sleep 2
    if is_running; then
        print_success "$SERVICE_NAME started (PID: $PID)"
        print_info "Backend running on: http://localhost:$PORT"
        print_info "API docs: http://localhost:$PORT/docs"
        print_info "Logs: tail -f $LOG_FILE"
    else
        print_error "Failed to start $SERVICE_NAME"
        print_error "Check logs: cat $LOG_FILE"
        exit 1
    fi
}

# Stop server
stop_server() {
    if ! is_running; then
        print_warning "$SERVICE_NAME is not running"
        return
    fi

    PID=$(cat "$PID_FILE")
    print_info "Stopping $SERVICE_NAME (PID: $PID)..."

    kill "$PID" 2>/dev/null || true

    # Wait for graceful shutdown
    for i in {1..10}; do
        if ! ps -p "$PID" > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    # Force kill if still running
    if ps -p "$PID" > /dev/null 2>&1; then
        print_warning "Forcefully killing $SERVICE_NAME..."
        kill -9 "$PID" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    print_success "$SERVICE_NAME stopped"
}

# Restart server
restart_server() {
    print_info "Restarting $SERVICE_NAME..."
    stop_server
    sleep 1
    start_server
}

# Show status
show_status() {
    echo "========================================="
    echo "$SERVICE_NAME - Status"
    echo "========================================="

    if is_running; then
        PID=$(cat "$PID_FILE")
        print_success "Status: RUNNING"
        echo "PID: $PID"
        echo "Port: $PORT"
        echo "Logs: $LOG_FILE"
        echo ""

        # Try to check health endpoint
        if command -v curl &> /dev/null; then
            print_info "Health check:"
            curl -s http://localhost:$PORT/health 2>/dev/null | head -20 || print_warning "Health endpoint not responding"
        fi
    else
        print_error "Status: STOPPED"
        if [ -f "$LOG_FILE" ]; then
            echo ""
            print_info "Last 10 log lines:"
            tail -10 "$LOG_FILE"
        fi
    fi
    echo ""
}

# Main command handler
case "${1:-start}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        show_status
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            print_error "Log file not found: $LOG_FILE"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start   - Start MiroFish backend server"
        echo "  stop    - Stop MiroFish backend server"
        echo "  restart - Restart MiroFish backend server"
        echo "  status  - Show server status and health"
        echo "  logs    - Tail server logs (live)"
        exit 1
        ;;
esac
