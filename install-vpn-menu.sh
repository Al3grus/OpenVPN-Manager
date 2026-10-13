#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_PATH="/usr/local/bin/vpn-menu"
SCRIPT_NAME="vpn-menu"
VPN_DIR="$HOME/VPNs"
REQUIRED_CMDS=(openvpn sudo bash find xargs pgrep)

check_dependencies() {
  local cmd missing=0
  for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf 'Missing required command: %s\n' "$cmd" >&2
      missing=1
    fi
  done
  (( missing == 0 )) || return 1
}

create_directories() {
  mkdir -p "$VPN_DIR"
  printf 'Created VPN directory at %s\n' "$VPN_DIR"
}

install_script() {
  if [[ ! -f "$SCRIPT_NAME" ]]; then
    printf 'Script %s not found in current directory.\n' "$SCRIPT_NAME" >&2
    return 1
  fi

  sudo install -m 0755 "$SCRIPT_NAME" "$INSTALL_PATH" || {
    printf 'Failed to install script to %s\n' "$INSTALL_PATH" >&2
    return 1
  }

  printf 'Installed as %s\n' "$INSTALL_PATH"
}

print_post_install_notes() {
  cat <<EOF

Installation complete.

Usage:
  vpn-menu                        # Launch interactive menu
  vpn-menu start                  # Start VPN with prompt
  vpn-menu start "OVPN_FILENAME"  # Start specific VPN profile
  vpn-menu stop
  vpn-menu status
  vpn-menu -h | --help            # Show help

VPN profiles should be placed in:
  $VPN_DIR

Example:
  ~/VPNs/Try Hack Me/Try Hack Me.ovpn

EOF
}

main() {
  check_dependencies || exit 1
  create_directories
  install_script || exit 1
  print_post_install_notes
}

main "$@"
