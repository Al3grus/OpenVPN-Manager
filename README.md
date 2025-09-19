<!-- README.md -->

# Simple OpenVPN Launcher

This project provides a small Bash script to manage OpenVPN connections with a simple menu or direct commands.
It supports starting, stopping, and checking the status of `.ovpn` profiles, including those stored in subfolders, and handles spaces in filenames.
The script also stores runtime state and PID files in `/run` for clean process management.

---

## Features

- Interactive menu (**start**, **stop**, **status**)
- Non-interactive CLI usage (`vpn-menu` start "Profile")
- Supports spaces in profile filenames and directories
- Tracks runtime with PID and state files under `/run`
- Auto-elevates with `sudo` if not run as root
- Designed for **one VPN connection at a time** (safe and predictable)

---

## Requirements

- Linux
- [OpenVPN](https://openvpn.net/) installed and in your PATH
- Common tools: `bash`, `find`, `xargs`, `pgrep`
- Root privileges (the script auto re-execs with `sudo`)

---

## Installation

Clone or download the script, then install it somewhere on your `PATH`:
```bash
sudo install -m 0755 VPN.sh /usr/local/bin/vpn-menu
```

Now you can run it anywhere with `vpn-menu`.

---

## Configuration

By default the script looks for `.ovpn` files in `~/VPNs/`.

Recommended folder structure:
```
~/VPNs/
├── Try Hack Me/
│   └── Try Hack Me.ovpn
└── Hack The Box/
    └── Hack The Box.ovpn
```

---

## Usage

Interactive
```bash
vpn-menu
```

Non-interactive
```bash
vpn-menu start                 # choose from list
vpn-menu start "Try Hack Me"   # start a specific profile by name (no .ovpn)
vpn-menu stop
vpn-menu status
```

---

## Behavior

- **start:** prompts unless a profile name is supplied
- **stop:** stops whichever OpenVPN is running (no prompt)
- **status:** shows the active profile and PID

---

## Runtime Files

The script writes state under `/run`:
- `/run/openvpn-<slug>.pid`
- `/run/openvpn-<slug>.state` (stores absolute path to the `.ovpn` file)
These files are cleaned automatically when you stop the VPN.

---

## Troubleshooting

- **No profiles listed:** ensure `.ovpn` files exist under `$VPN_DIR`.
- **“Another OpenVPN is running”:** stop it first with `vpn-menu stop`.
- **Permission errors:** run with sudo and check OpenVPN is installed.
- **Names show as `unknown`:** ensure `.state` files are created (they are written on `start`).

---

## Notes

- Only **one OpenVPN instance at a time** is supported.

---

## License

- This project is licensed under the MIT License.
- You are free to use, modify, and distribute this software with proper attribution.

---

## Upcoming

- Adding a help menu
- Instalation script 
