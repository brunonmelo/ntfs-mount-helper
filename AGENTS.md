# AGENTS.md — NTFS Mount Helper

## Project overview
A single bash script (`src/ntfs-mount-helper.sh`) paired with a systemd service unit (`systemd/ntfs-mount-helper.service`) that detects failed NTFS mounts after boot, runs `ntfsfix -d`, and retries mounting. One install script (`install-ntfs-helper.sh`) copies both files to their system paths and enables the service. No build system, no tests, no CI.

## Key facts an agent would miss

- **No package manager, no build step, no tests, no linter, no CI in this repo.** There is nothing to `npm install`, `cargo build`, `pip install`, or `make`. The repo is just static files deployed directly.

- **Arch-only.** The install script uses `pacman`, the systemd unit assumes Arch conventions, and the README calls out Arch explicitly. Do not add cross-distro abstractions without discussion.

- **Must run as root.** Both the install script and the service execute as root (systemd `User=root`). The install script calls `systemctl daemon-reload / enable / start` and copies files under `/usr/local/bin/` and `/etc/systemd/system/`.

## Commands

```bash
# Install locally (must be root)
sudo ./install-ntfs-helper.sh

# Run the helper manually (must be root)
sudo /usr/local/bin/ntfs-mount-helper.sh

# Service status
systemctl status ntfs-mount-helper

# Logs (journal)
journalctl -u ntfs-mount-helper -f

# Detailed log
tail -f /var/log/ntfs-mount-helper.log

# Remove everything
systemctl stop ntfs-mount-helper && systemctl disable ntfs-mount-helper
rm -f /usr/local/bin/ntfs-mount-helper.sh /etc/systemd/system/ntfs-mount-helper.service /var/log/ntfs-mount-helper.log
systemctl daemon-reload
```

## File layout (actual, not README)

| Path | Role |
|---|---|
| `src/ntfs-mount-helper.sh` | Main script |
| `systemd/ntfs-mount-helper.service` | systemd unit |
| `install-ntfs-helper.sh` | One-shot install script |

**Note:** README.MD references a stale layout (`bin/`, `services/`, `install.sh`). Trust the real directory structure above, not the README.

## Script behavior details

- Service unit depends on `systemd-udev-settle.service` to ensure block devices are discovered before the script runs.
- Waits 5s at start (`sleep 5`) to let systemd mount attempts settle.
- Parses `/etc/fstab` for `ntfs` entries, resolves `UUID=` / `LABEL=` via `blkid`.
- If a block device is not found, waits up to 30s (2s polls) re-resolving UUID/LABEL before giving up.
- Unmounts before running `ntfsfix -d` (uses lazy umount as fallback).
- After fixing, mounts by point (`mount $mount_point`) so mount options from fstab are reused. Falls back to `mount -t $fstype $device $mount_point`.
- Ends with `mount -a` as a final catch-all.
- Writes timestamp to `/var/run/ntfs-mount-helper.lastrun`.
- Log is duplicated to both stdout/journal and `/var/log/ntfs-mount-helper.log` via `tee`.
