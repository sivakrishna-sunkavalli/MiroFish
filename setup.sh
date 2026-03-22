#!/bin/bash

# MiroFish - Setup Script
# Installs dependencies and configures environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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
print_step() { echo -e "\n${BLUE}===>${NC} $1"; }

echo "========================================="
echo "MiroFish - Setup"
echo "========================================="

# Check prerequisites
print_step "Checking prerequisites"

# Try to find Python 3.11 or 3.12
PYTHON_CMD=""
for py_cmd in python3.11 python3.12 python3; do
    if command -v $py_cmd &> /dev/null; then
        PY_VERSION=$($py_cmd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        PY_MAJOR=$(echo $PY_VERSION | cut -d. -f1)
        PY_MINOR=$(echo $PY_VERSION | cut -d. -f2)

        if [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -ge 11 ] && [ "$PY_MINOR" -le 12 ]; then
            PYTHON_CMD=$py_cmd
            PYTHON_VERSION=$PY_VERSION
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    print_error "Python 3.11 or 3.12 not found"
    print_error "Install with: brew install python@3.11"
    exit 1
fi

print_success "Python $PYTHON_VERSION ($PYTHON_CMD)"

if ! command -v node &> /dev/null; then
    print_error "Node.js not found. Please install Node.js 18+"
    exit 1
fi

NODE_VERSION=$(node --version | grep -oE '[0-9]+' | head -1)
if [ "$NODE_VERSION" -lt 18 ]; then
    print_error "Node.js 18+ required. Found: $(node --version)"
    exit 1
fi

print_success "Node.js $(node --version)"

# Install root dependencies (concurrently for running services)
print_step "Installing root dependencies"
npm install --silent
print_success "Root dependencies installed"

# Install frontend dependencies
print_step "Installing frontend dependencies"
cd frontend
npm install --silent
cd ..
print_success "Frontend dependencies installed"

# Install backend dependencies (Python with uv)
print_step "Installing backend dependencies"

if ! command -v uv &> /dev/null; then
    print_info "Installing uv (Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add uv to PATH
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    if [ -f "$HOME/.local/bin/env" ]; then
        source "$HOME/.local/bin/env"
    fi
fi

# Ensure uv is in PATH for this session
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

cd backend
"$HOME/.local/bin/uv" sync --quiet 2>&1 || uv sync --quiet
cd ..
print_success "Backend dependencies installed (uv virtual environment created)"

# Create .env file if not exists
print_step "Configuring environment variables"

if [ ! -f ".env" ]; then
    cp .env.example .env
    print_warning "Created .env file from .env.example"
    print_warning "IMPORTANT: Edit .env and add your API keys:"
    print_warning "  - LLM_API_KEY (or use Ollama/LM Studio for FREE)"
    print_warning "  - ZEP_API_KEY (get free key from https://app.getzep.com/)"
    echo ""
    print_info "For FREE setup, configure Ollama:"
    print_info "  1. Install Ollama: https://ollama.ai/download"
    print_info "  2. Pull model: ollama pull qwen2.5"
    print_info "  3. Set in .env:"
    print_info "     LLM_BASE_URL=http://localhost:11434/v1"
    print_info "     LLM_MODEL_NAME=qwen2.5"
    print_info "     LLM_API_KEY=ollama"
else
    print_success ".env file already exists"
fi

# Create logs directory
mkdir -p logs
print_success "Logs directory created"

print_step "Setup Complete!"
echo ""
echo "Next steps:"
echo "  1. Edit .env file and configure API keys"
echo "  2. Start backend: ./server.sh"
echo "  3. (Optional) Start frontend: npm run frontend"
echo ""
print_info "Backend will run on: http://localhost:5001"
print_info "Frontend will run on: http://localhost:3000"
