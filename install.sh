#!/usr/bin/env bash
set -euo pipefail

VERSION="1.6.0"

cat <<'EOF'

   ___                   ____            _
  / _ \ _ __   ___ _ __ / ___|__ _ _ __ (_)
 | | | | '_ \ / _ \ '_ \ |   / _` | '_ \| |
 | |_| | |_) |  __/ | | | |__| (_| | | | | |
  \___/| .__/ \___|_| |_|\____\__,_|_| |_|_|
       |_|                              🦎

  A feature-rich web client for OpenClaw

EOF

printf "  Version: %s\n\n" "$VERSION"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${CYAN}▸${NC} %s\n" "$1"; }
ok()    { printf "${GREEN}✔${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}!${NC} %s\n" "$1"; }
fail()  { printf "${RED}✖${NC} %s\n" "$1"; exit 1; }

# --- Check Node.js ---
info "Checking Node.js..."
if command -v node >/dev/null 2>&1; then
  NODE_VERSION=$(node -v | sed 's/v//')
  NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
  if [ "$NODE_MAJOR" -lt 20 ]; then
    fail "Node.js $NODE_VERSION found, but v20+ is required. Please upgrade: https://nodejs.org"
  fi
  ok "Node.js v$NODE_VERSION"
else
  fail "Node.js not found. Install v20+: https://nodejs.org"
fi

# --- Check npm ---
info "Checking npm..."
if command -v npm >/dev/null 2>&1; then
  ok "npm $(npm -v)"
else
  fail "npm not found"
fi

# --- Install OpenCami ---
info "Installing opencami@$VERSION globally..."
if npm install -g "opencami@$VERSION" 2>&1; then
  ok "opencami@$VERSION installed"
else
  warn "Global install failed, trying with sudo..."
  sudo npm install -g "opencami@$VERSION" 2>&1
  ok "opencami@$VERSION installed (with sudo)"
fi

# --- Check OpenClaw ---
echo ""
if command -v openclaw >/dev/null 2>&1; then
  ok "OpenClaw detected: $(openclaw --version 2>/dev/null || echo 'installed')"
else
  warn "OpenClaw not found — you'll need it for OpenCami to connect to"
  info "Install OpenClaw: https://docs.openclaw.ai/install"
fi

# --- Interactive Setup ---
echo ""
printf "${BOLD}Configure OpenCami?${NC} [Y/n]: "
if [ -r /dev/tty ] && [ -w /dev/tty ]; then
  read -r setup < /dev/tty
else
  setup="n"
  warn "No TTY — skipping interactive setup"
fi

if [ -z "$setup" ] || [ "$setup" = "y" ] || [ "$setup" = "Y" ]; then
  echo ""
  printf "  Gateway URL ${CYAN}(default: ws://127.0.0.1:18789)${NC}: "
  read -r gateway_url < /dev/tty
  gateway_url="${gateway_url:-ws://127.0.0.1:18789}"

  printf "  Gateway Token ${CYAN}(optional)${NC}: "
  read -r gateway_token < /dev/tty

  printf "  Port ${CYAN}(default: 3000)${NC}: "
  read -r port < /dev/tty
  port="${port:-3000}"

  echo ""
  ok "Configuration saved"
  echo ""
  printf "${BOLD}Start OpenCami now?${NC} [Y/n]: "
  read -r start_now < /dev/tty

  if [ -z "$start_now" ] || [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
    echo ""
    info "Starting OpenCami on port $port..."
    echo ""

    CMD="opencami --port $port --gateway $gateway_url"
    [ -n "$gateway_token" ] && CMD="$CMD --token $gateway_token"

    echo "  ${CYAN}$ $CMD${NC}"
    echo ""
    eval "$CMD"
  else
    echo ""
    ok "Setup complete! Run opencami to start:"
    echo ""
    echo "  ${CYAN}opencami --port $port --gateway $gateway_url${NC}"
    echo ""
  fi
else
  echo ""
  ok "Setup complete! Run opencami to start:"
  echo ""
  echo "  ${CYAN}opencami${NC}"
  echo ""
fi

echo "  📖 Docs:    https://github.com/robbyczgw-cla/opencami"
echo "  🌐 Website: https://opencami.xyz"
echo "  💬 Discord: https://discord.com/invite/clawd"
echo ""
