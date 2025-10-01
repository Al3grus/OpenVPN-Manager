#!/usr/bin/env bash
set -Eeuo pipefail
set -o pipefail

INSTALL_PATH="/usr/local/bin/vpn-menu"
PIDDIR="/run"
LOG_DIR="/var/log"
SCRIPT_NAME="vpn-menu-uninstall.sh"

[[ $EUID -eq 0 ]] || exec sudo -- "$0" "$@"

die() {
  printf '%s\n' "$*" >&2
  return 1
}

confirm() {
  local prompt; prompt="$1"
  local ans
  printf '%s' "$prompt"
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

remove_binary() {
  if [[ -e "$INSTALL_PATH" ]]; then
    if ! rm -f -- "$INSTALL_PATH"; then
      printf 'Failed to remove %s\n' "$INSTALL_PATH" >&2
      return 1
    fi
    printf 'Removed: %s\n' "$INSTALL_PATH"
  else
    printf 'Not found: %s\n' "$INSTALL_PATH"
  fi
  return 0
}

cleanup_runtime_files() {
  local removed=0
  local found=0

  # remove pid and state files
  if find "$PIDDIR" -maxdepth 1 -type f -name 'openvpn-*.pid' -o -name 'openvpn-*.state' | read -r; then
    found=1
    if ! find "$PIDDIR" -maxdepth 1 -type f \( -name 'openvpn-*.pid' -o -name 'openvpn-*.state' \) -exec rm -f -- {} +; then
      printf 'Failed to remove some runtime files in %s\n' "$PIDDIR" >&2
      return 1
    fi
    removed=1
    printf 'Removed runtime PID/STATE files from %s\n' "$PIDDIR"
  fi

  # remove logs
  if find "$LOG_DIR" -maxdepth 1 -type f -name 'openvpn-*.log' | read -r; then
    if ! find "$LOG_DIR" -maxdepth 1 -type f -name 'openvpn-*.log' -exec rm -f -- {} +; then
      printf 'Failed to remove some log files in %s\n' "$LOG_DIR" >&2
      return 1
    fi
    removed=1
    printf 'Removed OpenVPN logs from %s\n' "$LOG_DIR"
  fi

  if (( removed == 0 )); then
    printf 'No runtime or log files found to remove.\n'
  fi

  return 0
}

orphan_openvpn_checks() {
  local pids
  if pids="$(pgrep -x openvpn 2>/dev/null || true)"; then
    if [[ -n "${pids//[[:space:]]/}" ]]; then
      printf 'Warning: openvpn processes currently running (PIDs): %s\n' "$pids"
      printf 'They will NOT be killed by this uninstaller. Stop them manually if desired.\n'
    fi
  fi
  return 0
}

main() {
  printf '\n'
  printf 'This will uninstall vpn-menu and optionally remove runtime files.\n'
  printf 'Installed path: %s\n' "$INSTALL_PATH"
  printf '\n'
  if ! confirm 'Proceed with uninstall? (y/N): '; then
    printf 'Aborted by user.\n'
    return 0
  fi

  if ! remove_binary; then
    die 'Uninstallation failed while removing binary.'
    return 1
  fi

  if confirm 'Also remove runtime PID/state and log files? (y/N): '; then
    if ! cleanup_runtime_files; then
      die 'Failed cleaning runtime/log files.'
      return 1
    fi
  else
    printf 'Skipped removing runtime/log files.\n'
  fi

  orphan_openvpn_checks

  printf '\nUninstall complete.\n'
  return 0
}

main "$@"
exit $?
