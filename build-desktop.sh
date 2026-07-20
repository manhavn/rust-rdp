#!/bin/bash
# Exit on error
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${CYAN}${BOLD}==================================================${NC}"
echo -e "${CYAN}${BOLD}     ANTIGRAVITY RDP CLIENT - DESKTOP LINUX       ${NC}"
echo -e "${CYAN}${BOLD}==================================================${NC}"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

MODE="${1:-release}"

if [ "$MODE" = "dev" ] || [ "$MODE" = "debug" ]; then
    echo -e "${YELLOW}Building desktop client (debug)...${NC}"
    cargo build -p rust-rdp-vnc-desktop
    BIN="$DIR/target/debug/rust-rdp-vnc"
else
    echo -e "${YELLOW}Building desktop client (release)...${NC}"
    cargo build -p rust-rdp-vnc-desktop --release
    BIN="$DIR/target/release/rust-rdp-vnc"
fi

if [ -f "$BIN" ]; then
    echo -e "\n${GREEN}${BOLD}✔ Desktop build completed successfully!${NC}"
    echo -e "${GREEN}Binary:${NC} ${BOLD}$BIN${NC}"
    ls -lh "$BIN"
    echo -e "\n${CYAN}Run with:${NC} $BIN"
    echo -e "${CYAN}Or:${NC}       ./build-desktop.sh && $BIN"
else
    echo -e "\n${RED}✘ Error: binary not found at $BIN${NC}"
    exit 1
fi
