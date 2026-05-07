#!/bin/bash

# ============================================================
# Smart Contract Security — Kali Linux Setup Script
# Joseph Kamanja
# Run this once on your Kali machine to set up the full
# smart contract auditing environment
# ============================================================

echo "======================================"
echo " Smart Contract Security Setup"
echo " Joseph Kamanja — josmiles.github.io"
echo "======================================"
echo ""

# ── 1. System Update ─────────────────────────────────────────
echo "[1/7] Updating system..."
sudo apt update && sudo apt upgrade -y

# ── 2. Node.js (needed for some tooling) ─────────────────────
echo "[2/7] Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs
echo "Node version: $(node -v)"
echo "NPM version: $(npm -v)"

# ── 3. Python tools ───────────────────────────────────────────
echo "[3/7] Installing Python tools..."
sudo apt install -y python3 python3-pip

# Slither — static analyser
pip3 install slither-analyzer --break-system-packages
echo "Slither version: $(slither --version)"

# ── 4. Foundry ────────────────────────────────────────────────
echo "[4/7] Installing Foundry (forge, cast, anvil, chisel)..."
curl -L https://foundry.paradigm.xyz | bash

# Source the updated path
export PATH="$HOME/.foundry/bin:$PATH"
echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> ~/.bashrc

foundryup

echo "Forge version: $(forge --version)"
echo "Cast version: $(cast --version)"
echo "Anvil version: $(anvil --version)"

# ── 5. Git config reminder ────────────────────────────────────
echo "[5/7] Checking Git..."
git --version
echo ""
echo "Make sure your git is configured:"
echo "  git config --global user.name 'Joseph Kamanja'"
echo "  git config --global user.email 'josephkamanja433@gmail.com'"

# ── 6. VS Code extensions reminder ───────────────────────────
echo "[6/7] Recommended VS Code extensions:"
echo "  - Juan Blanco's Solidity (juanblanco.solidity)"
echo "  - Hardhat for VS Code"
echo "  - GitLens"
echo ""
echo "Install via: code --install-extension juanblanco.solidity"

# ── 7. Create .env template ──────────────────────────────────
echo "[7/7] Creating .env template..."
cat > ~/smart-contract-security/.env.example << 'EOF'
# RPC URLs — get free from alchemy.com
ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
ARB_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

# Testnet private key — NEVER use a wallet with real funds here
PRIVATE_KEY=0xYOUR_TESTNET_PRIVATE_KEY

# Etherscan API key — for contract verification
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_KEY
EOF

echo ""
echo "======================================"
echo " Setup complete!"
echo ""
echo " Next steps:"
echo " 1. Run: source ~/.bashrc"
echo " 2. Run: forge --version  (confirm Foundry works)"
echo " 3. Go to ethernaut.openzeppelin.com"
echo " 4. Start Level 01 — Fallback"
echo ""
echo " Your professor is waiting. Let's go."
echo "======================================"
