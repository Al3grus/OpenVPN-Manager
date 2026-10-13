<!-- README.md -->

# Simple OpenVPN Launcher (vpn-menu)

This project provides a small Bash script to manage OpenVPN connections with a simple menu or direct commands.  
It supports starting, stopping, and checking the status of `.ovpn` profiles, including those stored in subfolders, and handles spaces in filenames.  
The script stores runtime state and PID files in `/run` for clean process management.

---

## 🚀 Features

- Interactive menu (**start**, **stop**, **status**)
- Non-interactive CLI usage (`vpn-menu start "Profile"`)
- Supports spaces in profile filenames and directories
- Tracks runtime with PID and state files under `/run`
- Auto-elevates with `sudo` if not run as root
- Designed for **one VPN connection at a time** (safe and predictable)
- Clean installer and uninstaller scripts

---

## ✅ Requirements

- Linux
- [OpenVPN](https://openvpn.net/) installed and in your `PATH`
- Common tools: `bash`, `find`, `xargs`, `pgrep`, `sudo`
- Root privileges (script re-execs with `sudo` automatically)

---

## 🛠️ Installation

Clone or download the repo and run:

```bash
./install-vpn-menu.sh
```

This will install `vpn-menu` into `/usr/local/bin`.

---

## 🧼 Uninstallation

To remove everything:

```bash
./uninstall-vpn-menu.sh
```

You will be asked whether to delete PID/state and log files.

---

## 📁 Configuration

By default, the script looks for `.ovpn` files in:

```bash
~/VPNs/
```

### Recommended structure:
```
~/VPNs/
├── Try Hack Me/
│   └── Try Hack Me.ovpn
└── Hack The Box/
    └── Hack The Box.ovpn
```

---

## ⚙️ Usage

### Interactive
```bash
vpn-menu
```

### Non-interactive
```bash
vpn-menu start                 # choose from list
vpn-menu start "Try Hack Me"   # start specific profile (omit .ovpn)
vpn-menu stop
vpn-menu status
vpn-menu -h / --help
```

---

## 📌 Behavior

- `start`: prompts for a profile unless one is supplied
- `stop`: stops the currently running OpenVPN instance
- `status`: shows the active profile and PID

---

## 🗂️ Runtime Files

The script writes temporary state to `/run`:
- `/run/openvpn-<slug>.pid` — PID of the OpenVPN process
- `/run/openvpn-<slug>.state` — full path to the profile used

These are automatically removed when the VPN is stopped.

---

## 🧯 Troubleshooting

- **No profiles listed**: ensure `.ovpn` files exist under `$VPN_DIR`
- **"Another OpenVPN is running"**: use `vpn-menu stop` first
- **Permission errors**: run with `sudo`, or ensure you installed correctly
- **`unknown` profile shown**: ensure `.state` file was created correctly

---

## 📄 License

This project is licensed under the **MIT License**.  
You are free to use, modify, and distribute this software with proper attribution.




