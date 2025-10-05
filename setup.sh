#!/usr/bin/env bash
set -euo pipefail

echo "[1/8] Updating system packages..."
sudo apt-get update -y
sudo apt-get install -y make curl ca-certificates gnupg lsb-release jq arping

echo "[2/8] Installing Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[3/8] Enabling Docker for current user..."
sudo usermod -aG docker "$USER" || true

echo "[4/8] Installing Kind..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  curl -Lo kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
elif [ "$ARCH" = "aarch64" ]; then
  curl -Lo kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-arm64
else
  echo "Unsupported architecture: $ARCH"; exit 1
fi
chmod +x kind
sudo mv kind /usr/local/bin/kind

echo "[5/8] Installing kubectl..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
elif [ "$ARCH" = "aarch64" ]; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
else
  echo "Unsupported architecture: $ARCH"; exit 1
fi

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo "[7/8] Verifying installations..."
for cmd in docker kind kubectl make jq arping; do
  command -v $cmd >/dev/null || { echo "❌ $cmd not found after install"; exit 1; }
done

echo "[8/8] Done. Log out and back in (or run 'newgrp docker') to use Docker without sudo."
echo "You can now run: make bootstrap"
