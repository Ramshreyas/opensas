#!/usr/bin/env bash
# setup-gpu-k3s.sh — Configure k3s for GPU workloads
#
# Run with: sudo ./scripts/setup-gpu-k3s.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Use: sudo $0"
  exit 1
fi

echo "==> Checking prerequisites..."
if ! command -v nvidia-container-toolkit &>/dev/null; then
  echo "Error: nvidia-container-toolkit not found. Install it first."
  exit 1
fi
echo "  nvidia-container-toolkit: $(nvidia-container-toolkit --version | head -1)"

# ── Step 1: Configure containerd to use nvidia runtime ─────────────────
echo ""
echo "==> Configuring containerd for NVIDIA runtime..."

CONTAINERD_CONFIG="/var/lib/rancher/k3s/agent/etc/containerd/config.toml"
CONTAINERD_CONFIG_TMPL="/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl"

# Determine which config file k3s uses
CONFIG_FILE=""
if [ -f "$CONTAINERD_CONFIG_TMPL" ]; then
  CONFIG_FILE="$CONTAINERD_CONFIG_TMPL"
elif [ -f "$CONTAINERD_CONFIG" ]; then
  CONFIG_FILE="$CONTAINERD_CONFIG"
else
  echo "Error: No containerd config found at expected paths."
  exit 1
fi

echo "  Using config: $CONFIG_FILE"

# Backup original
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Check if nvidia runtime is already configured
if grep -q "nvidia" "$CONFIG_FILE" 2>/dev/null; then
  echo "  NVIDIA runtime already configured in containerd. Skipping."
else
  # Generate the nvidia container toolkit config for containerd
  nvidia-ctk runtime configure --runtime=containerd --config="$CONFIG_FILE"

  echo "  NVIDIA runtime added to containerd config."
fi

# ── Step 2: Restart k3s ────────────────────────────────────────────────
echo ""
echo "==> Restarting k3s to pick up containerd changes..."
systemctl restart k3s

echo "  Waiting for k3s to be ready..."
sleep 5
k3s kubectl wait --for=condition=Ready nodes --all --timeout=60s
echo "  k3s is ready."

# ── Step 3: Deploy NVIDIA device plugin ─────────────────────────────────
echo ""
echo "==> Deploying NVIDIA device plugin (DaemonSet)..."

k3s kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  template:
    metadata:
      labels:
        name: nvidia-device-plugin-ds
    spec:
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      priorityClassName: system-node-critical
      runtimeClassName: nvidia
      containers:
        - name: nvidia-device-plugin-ctr
          image: nvcr.io/nvidia/k8s-device-plugin:v0.17.1
          env:
            - name: FAIL_ON_INIT_ERROR
              value: "false"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: device-plugin
              mountPath: /var/lib/kubelet/device-plugins
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
EOF

echo "  Waiting for device plugin to be ready..."
k3s kubectl wait --for=condition=Ready pods -l name=nvidia-device-plugin-ds \
  -n kube-system --timeout=120s 2>/dev/null || true

sleep 10

# ── Step 4: Verify ──────────────────────────────────────────────────────
echo ""
echo "==> Verification..."
echo ""
echo "  Node labels:"
k3s kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.capacity.'nvidia\.com/gpu'
echo ""
echo "  GPU allocatable:"
k3s kubectl describe node yoneda 2>/dev/null | grep -A2 "nvidia.com/gpu" || \
  k3s kubectl describe node "$(hostname)" | grep -A2 "nvidia.com/gpu"

echo ""
echo "=============================================="
echo "  GPU setup complete!"
echo "=============================================="
