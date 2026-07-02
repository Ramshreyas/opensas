#!/usr/bin/env bash
# bootstrap.sh — Install toolchain dependencies for OpenSAS development
#
# Prerequisites: a package manager (apt, dnf, or brew) and sudo access.
# kubectl is assumed to already be installed.

set -euo pipefail

OS="$(uname -s)"
ARCH="$(uname -m)"

# Color helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Detect package manager ──────────────────────────────────────────────
detect_pkg_mgr() {
  if command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v brew &>/dev/null; then
    echo "brew"
  elif command -v apk &>/dev/null; then
    echo "apk"
  else
    echo "unknown"
  fi
}

# ── YAMLLint ────────────────────────────────────────────────────────────
install_yamllint() {
  if command -v yamllint &>/dev/null; then
    log "yamllint already installed: $(yamllint --version 2>&1)"
    return
  fi
  log "Installing yamllint via pip..."
  pip3 install --user yamllint
  # Ensure ~/.local/bin is on PATH for this session
  export PATH="$HOME/.local/bin:$PATH"
  log "yamllint installed: $(yamllint --version 2>&1)"
}

# ── Helm ────────────────────────────────────────────────────────────────
install_helm() {
  if command -v helm &>/dev/null; then
    log "helm already installed: $(helm version --short 2>&1)"
    return
  fi
  log "Installing Helm..."
  PKG_MGR="$(detect_pkg_mgr)"
  case "$PKG_MGR" in
    apt)
      curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
      sudo apt-get install apt-transport-https --yes
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
      sudo apt-get update
      sudo apt-get install helm --yes
      ;;
    dnf)
      sudo dnf install helm --yes
      ;;
    brew)
      brew install helm
      ;;
    *)
      # Fallback: install from release binary
      HELM_VERSION="v3.17.1"
      log "No supported package manager found. Installing Helm ${HELM_VERSION} from release binary..."
      curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-${OS,,}-${ARCH}.tar.gz" | tar -xz
      sudo mv "${OS,,}-${ARCH}/helm" /usr/local/bin/helm
      rm -rf "${OS,,}-${ARCH}"
      ;;
  esac
  log "helm installed: $(helm version --short 2>&1)"
}

# ── k3s ──────────────────────────────────────────────────────────────────
# Installs k3s server (control-plane) on this machine. Worker nodes
# join via the k3s token. See docs/development.md for multi-node setup.
install_k3s() {
  if command -v k3s &>/dev/null; then
    log "k3s already installed: $(k3s --version 2>&1 | head -1)"
    return
  fi
  log "Installing k3s server..."
  # Write k3s config to disable traefik and use a known CIDR
  sudo mkdir -p /etc/rancher/k3s
  cat <<EOF | sudo tee /etc/rancher/k3s/config.yaml > /dev/null
# k3s server config — OpenSAS development
write-kubeconfig-mode: "0644"
disable:
  - traefik
  - servicelb
cluster-cidr: 10.44.0.0/16
service-cidr: 10.45.0.0/16
EOF
  curl -sfL https://get.k3s.io | sh -
  # Wait for k3s to be ready
  log "Waiting for k3s to be ready..."
  sleep 5
  sudo k3s kubectl wait --for=condition=Ready nodes --all --timeout=120s
  # Set up kubectl symlink for convenience
  if ! command -v kubectl &>/dev/null; then
    log "Setting up kubectl symlink..."
    sudo ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
  fi
  log "k3s installed. Cluster nodes:"
  sudo k3s kubectl get nodes -o wide

  # Print join token for worker nodes
  echo ""
  echo "──────────────────────────────────────────────────"
  echo "  To join a worker node, run on the remote machine:"
  echo "──────────────────────────────────────────────────"
  echo ""
  NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
  SERVER_IP=$(hostname -I | awk '{print $1}')
  echo "  curl -sfL https://get.k3s.io | K3S_URL=https://${SERVER_IP}:6443 \\"
  echo "    K3S_TOKEN=${NODE_TOKEN} sh -"
  echo ""
  echo "──────────────────────────────────────────────────"
}

# ── Ansible ─────────────────────────────────────────────────────────────
install_ansible() {
  if command -v ansible &>/dev/null; then
    log "ansible already installed: $(ansible --version | head -1)"
    return
  fi
  log "Installing Ansible..."
  PKG_MGR="$(detect_pkg_mgr)"
  case "$PKG_MGR" in
    apt)
      sudo apt-get update
      sudo apt-get install ansible --yes
      ;;
    dnf)
      sudo dnf install ansible --yes
      ;;
    brew)
      brew install ansible
      ;;
    *)
      pip3 install --user ansible
      export PATH="$HOME/.local/bin:$PATH"
      ;;
  esac
  log "ansible installed: $(ansible --version | head -1)"
}

# ── Ansible community.general collection (for additional modules) ───────
install_ansible_collections() {
  log "Installing Ansible community.general collection..."
  ansible-galaxy collection install community.general
}

# ── Main ────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo "=============================================="
  echo "  OpenSAS Developer Bootstrap"
  echo "=============================================="
  echo ""

  install_yamllint
  install_helm
  install_k3s
  install_ansible
  install_ansible_collections

  echo ""
  echo "=============================================="
  echo "  Bootstrap complete!"
  echo "=============================================="
  echo ""
  echo "Installed versions:"
  echo "  yamllint : $(yamllint --version 2>&1)"
  echo "  helm     : $(helm version --short 2>&1)"
  echo "  k3s      : $(k3s --version 2>&1 | head -1)"
  echo "  ansible  : $(ansible --version | head -1)"
  echo ""
  echo "Next steps:"
  echo "  1. Configure config/opensas.dev.yaml for your hardware"
  echo "  2. Run: ./scripts/validate.sh"
  echo ""
}

main
