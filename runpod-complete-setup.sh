#!/bin/bash

# Complete RunPod Setup Script for Legal RAG System
# Installs Git, Claude Code, pulls repo, and sets up dependencies
# Run this script on your fresh RunPod instance

set -e

echo "🏛️  Legal RAG Complete RunPod Setup"
echo "=================================================="
echo "This script will install:"
echo "  ✅ Git"
echo "  ✅ Node.js (required for Claude Code)"
echo "  ✅ GitHub CLI (for easy authentication)"
echo "  ✅ Claude Code CLI"
echo "  ✅ Legal RAG repository"
echo "  ✅ Python dependencies"
echo "  ✅ Ollama with Mistral model"
echo ""

# Update system packages
echo "📦 Updating system packages..."
apt-get update && apt-get upgrade -y

# Install essential packages including Node.js
echo "🔧 Installing essential packages..."
apt-get install -y curl wget git python3 python3-pip build-essential

# Install Node.js (required for Claude Code)
echo "📦 Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
    NODE_VERSION=$(node --version)
    echo "✅ Node.js $NODE_VERSION installed successfully"
else
    NODE_VERSION=$(node --version)
    echo "✅ Node.js already installed: $NODE_VERSION"
fi

# Install GitHub CLI
echo "📦 Installing GitHub CLI..."
if ! command -v gh &> /dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt-get update
    apt-get install -y gh
    echo "✅ GitHub CLI installed successfully"
else
    echo "✅ GitHub CLI already installed"
fi

# Install Claude Code CLI
echo "🤖 Installing Claude Code CLI..."
if ! command -v claude &> /dev/null; then
    # Install via npm (requires Node.js)
    npm install -g @anthropic-ai/claude-code
    
    # Create symlink if needed
    if [ ! -f "/usr/local/bin/claude" ] && [ -f "/usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude" ]; then
        ln -s /usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude /usr/local/bin/claude
    fi
    
    # Verify installation
    if command -v claude &> /dev/null; then
        echo "✅ Claude Code installed successfully"
    else
        echo "⚠️  Claude Code installation may have failed"
        echo "   You can try installing manually with: npm install -g @anthropic-ai/claude-code"
    fi
else
    echo "✅ Claude Code already installed"
fi

# Create workspace directory
echo "📁 Setting up workspace..."
mkdir -p /workspace
cd /workspace

# GitHub Authentication and Repository Clone
echo "🔐 Setting up GitHub authentication..."
echo "You need to authenticate with GitHub to clone the repository."
echo "This will open a browser for authentication."
echo ""

# Authenticate with GitHub
if ! gh auth status &> /dev/null; then
    echo "Please authenticate with GitHub:"
    echo "1. This will open a web browser"
    echo "2. Login to GitHub and authorize the CLI"
    echo "3. Return here when done"
    echo ""
    read -p "Press Enter to start authentication..."
    
    if ! gh auth login; then
        echo ""
        echo "❌ GitHub authentication failed."
        echo "You can try again later with: gh auth login"
        echo "Or use the public setup script instead: runpod-public-setup.sh"
        exit 1
    fi
else
    echo "✅ Already authenticated with GitHub"
fi

# Clone the Legal RAG repository
echo "📥 Cloning Legal RAG repository..."
if [ -d "localRAG" ]; then
    echo "Repository already exists, pulling latest changes..."
    cd localRAG
    git pull
else
    gh repo clone RickFBAG/localRAG
    cd localRAG
fi

echo "📍 Current location: $(pwd)"

# Install Python dependencies
echo "📚 Installing Python dependencies..."
pip3 install -r requirements.txt --break-system-packages

# Install and setup Ollama
echo "🦙 Installing Ollama..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh
    echo "✅ Ollama installed successfully"
else
    echo "✅ Ollama already installed"
fi

# Start Ollama service in background
echo "🚀 Starting Ollama service..."
ollama serve &
sleep 10

# Pull Mistral model
echo "📥 Pulling Mistral 7B model (this may take a few minutes)..."
ollama pull mistral

# Create necessary directories
echo "📁 Creating project directories..."
mkdir -p data chroma_db config

# Create convenience scripts
echo "📝 Creating launch scripts..."

# Main launch script
cat > /usr/local/bin/legal-rag << 'EOF'
#!/bin/bash
cd /workspace/localRAG

# Ensure Ollama is running
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "🦙 Starting Ollama..."
    ollama serve &
    sleep 5
fi

# Check if mistral model is available
if ! ollama list | grep -q mistral; then
    echo "📥 Pulling Mistral model..."
    ollama pull mistral
fi

echo "🏛️  Starting Legal RAG System..."
python3 app/main.py
EOF

# Claude Code launch script
cat > /usr/local/bin/claude-rag << 'EOF'
#!/bin/bash
cd /workspace/localRAG
echo "🤖 Launching Claude Code in Legal RAG directory..."

# Check if Claude Code is installed
if ! command -v claude &> /dev/null; then
    echo "❌ Claude Code not found. Installing now..."
    npm install -g @anthropic-ai/claude-code
    
    # Create symlink if needed
    if [ ! -f "/usr/local/bin/claude" ] && [ -f "/usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude" ]; then
        sudo ln -s /usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude /usr/local/bin/claude
    fi
    
    if ! command -v claude &> /dev/null; then
        echo "❌ Failed to install Claude Code"
        echo "Try manually: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
fi

claude
EOF

# Docker setup script (alternative)
cat > /usr/local/bin/legal-rag-docker << 'EOF'
#!/bin/bash
cd /workspace/localRAG
echo "🐳 Starting Legal RAG with Docker..."
docker-compose up --build
EOF

# Make scripts executable
chmod +x /usr/local/bin/legal-rag
chmod +x /usr/local/bin/claude-rag
chmod +x /usr/local/bin/legal-rag-docker

# Create startup script that runs on boot
cat > /etc/rc.local << 'EOF'
#!/bin/bash
# Start Ollama on boot
sudo -u root ollama serve &
exit 0
EOF
chmod +x /etc/rc.local

# Git is already configured through GitHub CLI authentication
echo "✅ Git authentication configured via GitHub CLI"

# Create environment setup file
cat > /workspace/localRAG/.env << EOF
# Legal RAG Environment Configuration
OLLAMA_HOST=http://localhost:11434
PYTHONPATH=/workspace/localRAG/app
EOF

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "📋 Available commands:"
echo "  legal-rag                    # Launch Legal RAG system"
echo "  claude-rag                   # Launch Claude Code in project directory"
echo "  legal-rag-docker             # Launch with Docker (if Docker installed)"
echo ""
echo "📁 Project structure:"
echo "  /workspace/localRAG/         # Main project directory"
echo "  /workspace/localRAG/data/    # Add your legal documents here"
echo "  /workspace/localRAG/chroma_db/ # Vector database storage"
echo ""
echo "🚀 Quick start:"
echo "  1. Add documents to: /workspace/localRAG/data/"
echo "  2. Run: legal-rag"
echo "  3. Ask questions about your documents!"
echo ""
echo "🤖 Claude Code integration:"
echo "  - Run 'claude-rag' to use Claude Code in the project"
echo "  - Edit code, run tests, and manage the project with AI assistance"
echo ""
echo "🔒 Privacy: All processing happens locally on your RunPod!"
echo "    No documents or data are sent to external services."
echo ""
echo "📖 For more info, check the CLAUDE.md file in the project directory"