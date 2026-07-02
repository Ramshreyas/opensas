#!/usr/bin/env bash
# install-k3s-server.sh — Install k3s server (control-plane) for OpenSAS dev
#
# Run with: sudo ./scripts/install-k3s-server.sh
# After installation, the k3s node token is printed so worker nodes can join.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Use: sudo $0"
  exit 1
fi

echo "==> Writing k3s server config..."
mkdir -p /etc/rancher/k3s
cat <<'EOF' > /etc/rancher/k3s/config.yaml
# k3s server config — OpenSAS development
write-kubeconfig-mode: "0644"
disable:
  - traefik
  - servicelb
cluster-cidr: 10.44.0.0/16
service-cidr: 10.45.0.0/16
EOF

echo "==> Installing k3s server..."
curl -sfL https://get.k3s.io | sh -

echo "==> Waiting for node to be ready..."
sleep 5
k3s kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "==> Setting up kubectl alias..."
ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl 2>/dev/null || true

echo ""
echo "=============================================="
echo "  k3s server installed!"
echo "=============================================="
echo ""
k3s kubectl get nodes -o wide
echo ""

# Print join command for worker nodes
NODE_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "──────────────────────────────────────────────────"
echo "  Worker node join command:"
echo "──────────────────────────────────────────────────"
echo ""
echo "  curl -sfL https://get.k3s.io | K3S_URL=https://${SERVER_IP}:6443 \\"
echo "    K3S_TOKEN=${NODE_TOKEN} sh -"
echo ""
echo "──────────────────────────────────────────────────"
