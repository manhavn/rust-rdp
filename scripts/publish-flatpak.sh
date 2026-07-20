#!/usr/bin/env bash
# Build / install Rust RDP VNC as Flatpak, generate Flathub cargo sources, or print
# Flathub PR instructions.
#
# Usage:
#   ./scripts/publish-flatpak.sh                 # build + install (user)
#   ./scripts/publish-flatpak.sh --build-only    # build .flatpak bundle
#   ./scripts/publish-flatpak.sh --generate-sources
#   ./scripts/publish-flatpak.sh --bundle        # export .flatpak file
#   ./scripts/publish-flatpak.sh --flathub-help   # how to open a Flathub PR
#   ./scripts/publish-flatpak.sh --uninstall
#
# Prerequisites:
#   sudo apt install flatpak flatpak-builder
#   flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
#   flatpak install --user -y flathub \
#     org.gnome.Platform//47 org.gnome.Sdk//47 \
#     org.freedesktop.Sdk.Extension.rust-stable//24.08 \
#     org.freedesktop.Sdk.Extension.llvm18//24.08
#
# Flathub (first publish) is NOT a binary upload — you open a GitHub PR.
# See --flathub-help and flatpak/README.md / flatpak/README.vi.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_ID="io.github.manhavn.rust-rdp"
MANIFEST="flatpak/${APP_ID}.yml"
BUILD_DIR="${ROOT}/.flatpak-build"
REPO_DIR="${ROOT}/.flatpak-repo"
STATE_DIR="${ROOT}/.flatpak-builder"
BUNDLE_PATH="${ROOT}/${APP_ID}.flatpak"

MODE="install" # install | build-only | generate-sources | bundle | flathub-help | uninstall

for arg in "$@"; do
  case "$arg" in
    --build-only) MODE="build-only" ;;
    --generate-sources) MODE="generate-sources" ;;
    --bundle) MODE="bundle" ;;
    --flathub-help) MODE="flathub-help" ;;
    --uninstall) MODE="uninstall" ;;
    --help|-h)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

print_flathub_help() {
  cat <<'EOF'
========== Publish to Flathub (first time) ==========

Flathub does not accept a raw binary upload. Flow:

1) Prepare a release on GitHub
   - Tag the repo, e.g. v0.1.0
   - git tag v0.1.0 && git push origin v0.1.0

2) Generate offline Cargo sources (required by Flathub)
   ./scripts/publish-flatpak.sh --generate-sources
   Commit flatpak/generated-sources.json if you host it in-tree,
   or keep it only in the Flathub app repository.

3) Create a Flathub account / join
   https://docs.flathub.org/docs/for-app-authors/submission

4) Fork https://github.com/flathub/flathub
   Create a branch: new-pr

5) Add your app (example layout under the flathub fork):
   io.github.manhavn.rust-rdp/
     io.github.manhavn.rust-rdp.yml      # git source + generated-sources.json
     io.github.manhavn.rust-rdp.metainfo.xml
     io.github.manhavn.rust-rdp.desktop
     generated-sources.json
     icons/...

   In the Flathub manifest, replace the local "type: dir" source with:

     - type: git
       url: https://github.com/manhavn/rust-rdp.git
       tag: v0.1.0
       commit: <full commit sha of the tag>

     - generated-sources.json

6) Open a PR against flathub/flathub (base branch: new-pr)
   Bot builds your app; maintainers review metainfo, permissions, etc.

7) After merge, updates are new PRs / tags on your Flathub app repo
   (flathub/io.github.manhavn.rust-rdp) following Flathub’s update process.

Useful links:
  https://docs.flathub.org/docs/for-app-authors/submission
  https://docs.flathub.org/docs/for-app-authors/requirements
  https://github.com/flatpak/flatpak-builder-tools (cargo generator)

Local test before submitting:
  ./scripts/publish-flatpak.sh
  flatpak run io.github.manhavn.rust-rdp
=====================================================
EOF
}

ensure_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "flatpak not found. Install: sudo apt install flatpak flatpak-builder" >&2
    exit 1
  fi
  if ! command -v flatpak-builder >/dev/null 2>&1; then
    echo "flatpak-builder not found. Install: sudo apt install flatpak-builder" >&2
    exit 1
  fi
}

install_runtimes() {
  echo "==> Ensuring Flathub remote + SDK runtimes…"
  flatpak remote-add --if-not-exists --user flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo || true

  # Runtime versions must match the manifest
  flatpak install --user -y flathub org.gnome.Platform//47 org.gnome.Sdk//47 || true
  # Extension branch tracks freedesktop runtime used by GNOME 47 (24.08)
  flatpak install --user -y flathub \
    org.freedesktop.Sdk.Extension.rust-stable//24.08 \
    org.freedesktop.Sdk.Extension.llvm18//24.08 || true
}

generate_cargo_sources() {
  echo "==> Generating flatpak/generated-sources.json from Cargo.lock…"
  local gen_dir="${ROOT}/.flatpak-cargo-gen"
  local script="${gen_dir}/cargo/flatpak-cargo-generator.py"

  if [[ ! -f "$script" ]]; then
    echo "    Cloning flatpak-builder-tools (one-time)…"
    rm -rf "$gen_dir"
    git clone --depth 1 https://github.com/flatpak/flatpak-builder-tools.git "$gen_dir"
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 required" >&2
    exit 1
  fi

  # tomli may be required depending on generator version
  python3 -m pip install --user -q toml aiohttp 2>/dev/null || true

  python3 "$script" "${ROOT}/Cargo.lock" -o "${ROOT}/flatpak/generated-sources.json"
  echo "    Wrote flatpak/generated-sources.json"
  echo "    For Flathub, add it under the rust-rdp module sources list."
  echo "    Tip: commit this file only if you want offline builds in-tree (large)."
}

build_flatpak() {
  ensure_flatpak
  install_runtimes

  if [[ ! -f "$MANIFEST" ]]; then
    echo "Missing manifest: $MANIFEST" >&2
    exit 1
  fi

  echo "==> flatpak-builder (user install=${1})…"
  # shellcheck disable=SC2086
  flatpak-builder \
    --user \
    --force-clean \
    --state-dir="${STATE_DIR}" \
    --repo="${REPO_DIR}" \
    ${1:+--install} \
    "${BUILD_DIR}" \
    "${MANIFEST}"
}

case "$MODE" in
  flathub-help)
    print_flathub_help
    ;;
  generate-sources)
    generate_cargo_sources
    ;;
  uninstall)
    ensure_flatpak
    flatpak uninstall --user -y "${APP_ID}" || true
    echo "Uninstalled ${APP_ID} (user)."
    ;;
  build-only)
    build_flatpak 0
    echo "Build finished (not installed). Repo: ${REPO_DIR}"
    ;;
  bundle)
    build_flatpak 0
    echo "==> Exporting bundle ${BUNDLE_PATH}"
    flatpak build-bundle "${REPO_DIR}" "${BUNDLE_PATH}" "${APP_ID}"
    ls -lh "${BUNDLE_PATH}"
    echo "Install with: flatpak install --user ${BUNDLE_PATH}"
    ;;
  install)
    build_flatpak 1
    echo
    echo "Installed. Run with:"
    echo "  flatpak run ${APP_ID}"
    echo
    echo "For Flathub submission steps:"
    echo "  ./scripts/publish-flatpak.sh --flathub-help"
    ;;
esac
