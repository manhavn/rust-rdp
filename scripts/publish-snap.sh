#!/usr/bin/env bash
# Build and publish Rust RDP VNC to the Snap Store.
#
# Usage:
#   ./scripts/publish-snap.sh              # build + upload to edge
#   ./scripts/publish-snap.sh edge         # same
#   ./scripts/publish-snap.sh beta
#   ./scripts/publish-snap.sh candidate
#   ./scripts/publish-snap.sh stable
#   ./scripts/publish-snap.sh --build-only # only produce the .snap
#   ./scripts/publish-snap.sh --register   # register snap name once
#
# Prerequisites:
#   sudo snap install snapcraft --classic
#   sudo snap install lxd && sudo lxd init --auto
#   snapcraft login
#   snapcraft register rust-rdp   # once (or use --register)
#
# Full guide: snap/README.md  |  snap/README.vi.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CHANNEL="edge"
BUILD_ONLY=0
DO_REGISTER=0

for arg in "$@"; do
  case "$arg" in
    --build-only) BUILD_ONLY=1 ;;
    --register) DO_REGISTER=1 ;;
    --help|-h)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    edge|beta|candidate|stable) CHANNEL="$arg" ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

if ! command -v snapcraft >/dev/null 2>&1; then
  echo "snapcraft not found. Install with:"
  echo "  sudo snap install snapcraft --classic"
  exit 1
fi

SNAP_NAME="$(grep -E '^name:' snap/snapcraft.yaml | head -1 | awk '{print $2}')"
echo "==> Snap name: ${SNAP_NAME}"
echo "==> Channel:   ${CHANNEL}"

if [[ "$DO_REGISTER" -eq 1 ]]; then
  echo "==> Registering ${SNAP_NAME} on the Snap Store (one-time)…"
  snapcraft register "${SNAP_NAME}"
fi

echo "==> Building snap (this can take a long time on first run)…"
# Prefer destructive mode only if LXD is unavailable
if command -v lxc >/dev/null 2>&1; then
  snapcraft pack --output "${ROOT}"
else
  echo "LXD not found; trying --destructive-mode (builds on host)."
  snapcraft pack --destructive-mode --output "${ROOT}"
fi

SNAP_FILE="$(ls -1t "${ROOT}/${SNAP_NAME}"_*.snap 2>/dev/null | head -1 || true)"
if [[ -z "${SNAP_FILE}" ]]; then
  # snapcraft may write into cwd with different pattern
  SNAP_FILE="$(ls -1t "${ROOT}"/*.snap 2>/dev/null | head -1 || true)"
fi
if [[ -z "${SNAP_FILE}" || ! -f "${SNAP_FILE}" ]]; then
  echo "ERROR: could not find built .snap file in ${ROOT}" >&2
  exit 1
fi

echo "==> Built: ${SNAP_FILE}"
ls -lh "${SNAP_FILE}"

if [[ "$BUILD_ONLY" -eq 1 ]]; then
  echo "Build-only mode; skip upload."
  echo "Install locally with:"
  echo "  sudo snap install --dangerous \"${SNAP_FILE}\""
  exit 0
fi

echo "==> Uploading to channel: ${CHANNEL}"
echo "    (requires: snapcraft login)"
snapcraft upload --release="${CHANNEL}" "${SNAP_FILE}"

echo
echo "Done."
echo "  Install from store:  sudo snap install ${SNAP_NAME} --${CHANNEL}"
echo "  Status:              snapcraft status ${SNAP_NAME}"
echo "  Promote later:       snapcraft release ${SNAP_NAME} <rev> stable"
