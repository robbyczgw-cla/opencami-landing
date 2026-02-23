#!/usr/bin/env bash
set -euo pipefail

VERSION="1.8.3"

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
if [ -t 0 ] || { [ -e /dev/tty ] && (echo -n "" > /dev/tty) 2>/dev/null; }; then
  printf "${BOLD}Configure OpenCami?${NC} [Y/n]: " > /dev/tty
  read -r setup < /dev/tty
else
  setup="n"
  ok "Installed! Run 'opencami' to start."
fi

if [ -z "$setup" ] || [ "$setup" = "y" ] || [ "$setup" = "Y" ]; then
  echo ""

  # --- Prompt helpers (tty) ---
  read_tty() {
    local __var="$1"; shift
    local __prompt="$1"; shift
    printf "%b" "$__prompt" > /dev/tty
    IFS= read -r "$__var" < /dev/tty || true
  }

  info "Gateway URL vs Origin quick guide:"
  echo "  - Gateway URL = OpenClaw WebSocket endpoint (ws:// or wss://)."
  echo "    Recommended when OpenCami runs on the SAME machine as OpenClaw: ws://127.0.0.1:18789"
  echo "  - Origin = the EXACT browser URL you open OpenCami on (https://<host>:<port>, no trailing /)."
  echo "    If you set an Origin, you must allowlist it in OpenClaw: gateway.controlUI.allowedOrigins"
  echo ""

  # --- Gateway URL ---
  while true; do
    read_tty gateway_url "  Gateway WebSocket URL ${CYAN}(default: ws://127.0.0.1:18789)${NC}: "
    gateway_url="${gateway_url:-ws://127.0.0.1:18789}"
    gateway_url="${gateway_url%/}"

    if [[ "$gateway_url" =~ ^https?:// ]]; then
      warn "You entered an HTTP URL ($gateway_url). The Gateway URL must be a WebSocket URL (ws:// or wss://)."
      info "Recommended (when OpenCami runs on the same host as OpenClaw): ws://127.0.0.1:18789"
      continue
    fi

    if [[ ! "$gateway_url" =~ ^wss?:// ]]; then
      warn "Invalid Gateway URL scheme. Use ws:// or wss://"
      continue
    fi

    break
  done

  printf "  Gateway Token ${CYAN}(recommended)${NC}: "
  read -r gateway_token < /dev/tty

  if [ -z "$gateway_token" ]; then
    printf "  Gateway Password ${CYAN}(optional)${NC}: "
    read -r gateway_password < /dev/tty
  else
    gateway_password=""
  fi

  # --- Origin (must match browser address bar exactly; no trailing slash) ---
  while true; do
    read_tty opencami_origin "  Origin (OpenCami public URL) ${CYAN}(optional, e.g. https://<magicdns>:3001)${NC}: "
    opencami_origin="${opencami_origin%/}"

    # allow empty
    if [ -z "$opencami_origin" ]; then
      break
    fi

    if [[ ! "$opencami_origin" =~ ^https?:// ]]; then
      warn "Origin must start with https:// (or http:// for local testing). You entered: $opencami_origin"
      continue
    fi

    ok "Using origin: $opencami_origin"
    echo "  ${YELLOW}Note:${NC} Add this to OpenClaw config (then restart gateway):"
    echo "    gateway.controlUI.allowedOrigins: [\"$opencami_origin\"]"
    break
  done

  while true; do
    read_tty port "  Port ${CYAN}(default: 3000)${NC}: "
    port="${port:-3000}"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
      warn "Invalid port: $port"
      continue
    fi
    break
  done

  echo ""
  ok "Configuration saved"
  echo ""
  printf "${BOLD}Start OpenCami now?${NC} [Y/n]: " > /dev/tty
  read -r start_now < /dev/tty

  if [ -z "$start_now" ] || [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
    echo ""
    info "Starting OpenCami on port $port..."
    echo ""

    CMD="opencami --port $port --gateway $gateway_url"
    [ -n "$gateway_token" ] && CMD="$CMD --token $gateway_token"
    [ -n "${gateway_password:-}" ] && CMD="$CMD --password $gateway_password"
    [ -n "${opencami_origin:-}" ] && CMD="$CMD --origin $opencami_origin"

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
