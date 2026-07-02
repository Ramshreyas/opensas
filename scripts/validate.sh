#!/usr/bin/env bash
# validate.sh — Run all linting and validation checks for the OpenSAS repo.
#
# Usage:
#   ./scripts/validate.sh           # Run all checks
#   ./scripts/validate.sh --yaml    # YAML lint only
#   ./scripts/validate.sh --helm    # Helm lint only

set -euo pipefail

# Color helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

pass_check() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail_check() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }

# ── YAML Lint ───────────────────────────────────────────────────────────
run_yamllint() {
  echo ""
  echo "── YAML Lint ──────────────────────────────────────────────"
  if ! command -v yamllint &>/dev/null; then
    fail_check "yamllint not found. Run ./scripts/bootstrap.sh first."
    return
  fi

  # Collect all YAML files, excluding .git and common generated dirs
  YAML_FILES=$(find . \
    -not -path './.git/*' \
    -not -path './.pi/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/vendor/*' \
    -type f \( -name '*.yaml' -o -name '*.yml' \) \
    2>/dev/null || true)

  if [ -z "$YAML_FILES" ]; then
    pass_check "yamllint: no YAML files found (clean slate)"
    return
  fi

  if echo "$YAML_FILES" | xargs yamllint -c .yamllint 2>&1; then
    pass_check "yamllint: all YAML files pass"
  else
    fail_check "yamllint: errors found (see above)"
  fi
}

# ── Helm Lint ───────────────────────────────────────────────────────────
run_helm_lint() {
  echo ""
  echo "── Helm Lint ──────────────────────────────────────────────"
  if ! command -v helm &>/dev/null; then
    fail_check "helm not found. Run ./scripts/bootstrap.sh first."
    return
  fi

  CHART_COUNT=0
  for chart_dir in charts/*/; do
    if [ ! -d "$chart_dir" ]; then
      continue
    fi
    # Skip non-chart directories (e.g., empty dirs with only templates/)
    if [ ! -f "${chart_dir}Chart.yaml" ]; then
      continue
    fi
    CHART_COUNT=$((CHART_COUNT + 1))
    echo "  Linting ${chart_dir}..."
    if helm lint "$chart_dir" 2>&1; then
      pass_check "helm lint: ${chart_dir%/}"
    else
      fail_check "helm lint: ${chart_dir%/}"
    fi
  done

  if [ "$CHART_COUNT" -eq 0 ]; then
    pass_check "helm lint: no charts found (clean slate — nothing to lint)"
  fi
}

# ── Main ────────────────────────────────────────────────────────────────
main() {
  RUN_YAML=true
  RUN_HELM=true

  for arg in "$@"; do
    case "$arg" in
      --yaml) RUN_HELM=false ;;
      --helm) RUN_YAML=false ;;
    esac
  done

  echo ""
  echo "=============================================="
  echo "  OpenSAS Validation Suite"
  echo "=============================================="

  if $RUN_YAML; then
    run_yamllint
  fi
  if $RUN_HELM; then
    run_helm_lint
  fi

  echo ""
  echo "──────────────────────────────────────────────"
  echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
  echo "──────────────────────────────────────────────"

  if [ "$FAIL" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
