#!/usr/bin/env bash
set -Eeuo pipefail

# --- config ---
USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
VPN_DIR="${VPN_DIR_OVERRIDE:-$USER_HOME/VPNs}"   # put THM/HTB .ovpn here
PIDDIR="/run"

# auto-elevate
[[ $EUID -eq 0 ]] || exec sudo -- "$0" "$@"

# globals
VPN_FILE=""; PROFILE=""; PIDFILE=""; LOGFILE=""; STATEFILE=""; PROFILE_NAME=""

die(){ echo "$*" >&2; exit 1; }

profile_name_from_path() { basename "${1%.*}"; }

# Read argv of a PID safely and extract the .ovpn passed to --config
vpn_name_from_pid() {
  local pid="$1" prev="" tok file=""
  while IFS= read -r -d '' tok; do
    if [[ "$prev" == "--config" && -n "$tok" ]]; then
      file="$tok"; break
    fi
    [[ "$tok" == *.ovpn ]] && file="$tok"
    prev="$tok"
  done <"/proc/$pid/cmdline"
  [[ -n "$file" ]] && basename "${file%.*}"
}

# Given a PID, return profile name; prefer /proc, else map PID->state file
profile_name_for_pid() {
  local pid="$1" name pf c slug state path
  name="$(vpn_name_from_pid "$pid" || true)"
  if [[ -z "$name" ]]; then
    for pf in "$PIDDIR"/openvpn-*.pid; do
      [[ -e "$pf" ]] || continue
      c="$(cat "$pf" 2>/dev/null || true)"
      [[ "$c" == "$pid" ]] || continue
      slug="$(basename "$pf" .pid | sed 's/^openvpn-//')"
      state="$PIDDIR/openvpn-${slug}.state"
      if [[ -r "$state" ]]; then
        IFS= read -r path < "$state" || path=""
        [[ -n "$path" ]] && name="$(basename "${path%.*}")"
      fi
      [[ -n "$name" ]] || name="$slug"
      break
    done
  fi
  [[ -n "$name" ]] && echo "$name"
}

_set_paths_from_profile() {
  PROFILE="$(basename "${VPN_FILE%.*}")"
  local slug="${PROFILE//[^A-Za-z0-9_-]/_}"
  PIDFILE="$PIDDIR/openvpn-${slug}.pid"
  LOGFILE="/var/log/openvpn-${slug}.log"
  STATEFILE="$PIDDIR/openvpn-${slug}.state"
  PROFILE_NAME="$PROFILE"
}

# Detect running instance using our PID/STATE files, else last openvpn pid
running_profile() {
  local pf pid slug
  for pf in "$PIDDIR"/openvpn-*.pid; do
    [[ -e "$pf" ]] || continue
    pid="$(cat "$pf" 2>/dev/null || true)"
    [[ -n "$pid" ]] && ps -p "$pid" &>/dev/null || continue

    slug="$(basename "$pf" .pid | sed 's/^openvpn-//')"
    PIDFILE="$pf"
    LOGFILE="/var/log/openvpn-${slug}.log"
    STATEFILE="$PIDDIR/openvpn-${slug}.state"

    if [[ -r "$STATEFILE" ]]; then
      IFS= read -r VPN_FILE < "$STATEFILE" || VPN_FILE=""
      if [[ -n "$VPN_FILE" && -f "$VPN_FILE" ]]; then
        PROFILE_NAME="$(profile_name_from_path "$VPN_FILE")"
        PROFILE="$PROFILE_NAME"
      else
        PROFILE="$slug"; PROFILE_NAME="$slug"
      fi
    else
      PROFILE="$slug"; PROFILE_NAME="$slug"
    fi

    echo "$pid"
    return 0
  done

  pid="$(pgrep -x openvpn -n || true)"
  [[ -n "$pid" ]] || return 1
  PROFILE="active"; PROFILE_NAME="active"
  PIDFILE=""; LOGFILE=""; STATEFILE=""; VPN_FILE=""
  echo "$pid"
  return 0
}

choose_profile() {
  local want="${1:-${VPN_PROFILE:-}}"
  mapfile -t list < <(find "$VPN_DIR" -maxdepth 2 -type f -name '*.ovpn' -print0 | xargs -0 -I{} echo "{}" | sort)
  (( ${#list[@]} )) || die "No .ovpn files in $VPN_DIR"

  if [[ -n "$want" ]]; then
    for f in "${list[@]}"; do
      bn="$(basename "${f%.*}")"
      [[ "$bn" == "$want" ]] && VPN_FILE="$f"
    done
    [[ -n "$VPN_FILE" ]] || die "Profile '$want' not found."
  else
    printf '\n'
    echo -e "Available VPN profiles:\n"
    local i=1; names=()
    for f in "${list[@]}"; do
      bn="$(basename "${f%.*}")"
      names+=("$bn"); printf "  %d) %s\n" "$i" "$bn"; ((i++))
    done
    printf '\n'
    read -r -p "> " idx; printf '\n'
    [[ "$idx" =~ ^[0-9]+$ ]] && (( idx>=1 && idx<=${#names[@]} )) || die "Invalid choice"
    VPN_FILE="${list[idx-1]}"
  fi
  _set_paths_from_profile
}

start_vpn() {
  if running_profile >/dev/null; then die "Another OpenVPN is running. Stop it first."; fi
  choose_profile "${1-}"
  [[ -r "$VPN_FILE" ]] || die "OVPN not readable: $VPN_FILE"

  mkdir -p "$PIDDIR"; touch "$LOGFILE" || true
  printf '%s' "$VPN_FILE" > "$STATEFILE"   # no trailing newline

  openvpn --writepid "$PIDFILE" --config "$VPN_FILE" --daemon --log "$LOGFILE" >/dev/null 2>&1
  sleep 1

  if [[ ! -s "$PIDFILE" ]]; then
    local p; p="$(pgrep -x openvpn -n || true)"
    [[ -n "$p" ]] && echo "$p" >"$PIDFILE"
  fi

  [[ -s "$PIDFILE" ]] && ps -p "$(cat "$PIDFILE")" &>/dev/null \
    && echo "Started. PID $(cat "$PIDFILE")" || die "Failed to start."
}

stop_vpn() {
  local p
  printf '\n'
  if p="$(running_profile)"; then
    local name; name="$(profile_name_for_pid "$p")"
    kill -INT "$p" 2>/dev/null || true
    for _ in {1..50}; do ps -p "$p" &>/dev/null || break; sleep 0.1; done
    ps -p "$p" &>/dev/null && kill -KILL "$p" 2>/dev/null || true
    [[ -n "${PIDFILE:-}" ]] && rm -f "$PIDFILE" "$STATEFILE" 2>/dev/null || true
    echo "Stopped: ${name:-unknown}"
  else
    echo "Already stopped."
  fi
}

status_vpn() {
  local p
  printf '\n'
  if p="$(running_profile)"; then
    local name; name="$(profile_name_for_pid "$p")"
    echo "Running: ${name:-unknown} (PID $p)"
  else
    echo "Not running."
  fi
}



menu() {
  echo "Choose: [1] Start  [2] Stop  [3] Status  [q] Quit"
  read -r -p "> " c;
  case "$c" in
    1) start_vpn ;;
    2) stop_vpn ;;
    3) status_vpn ;;
    q|Q) exit 0 ;;
    *) echo "Invalid choice."; exit 1 ;;
  esac
  printf '\n'
}

case "${1:-}" in
  start)   start_vpn   "${2-}" ;;
  stop)    stop_vpn ;;
  status)  status_vpn ;;
  *)       menu ;;
esac
