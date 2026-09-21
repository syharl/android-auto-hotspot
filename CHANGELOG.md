# Changelog

## Unreleased
### Added
- **Control panel**, `menu.sh` — single-keypress interactive menu (no Enter needed to navigate). Main options: Toggle Autostart Hotspot, Pengaturan, **Reset Jaringan (sekarang)**, **Reboot x3nfc**, and Uninstall (full reset). Replaces the earlier flat settings menu.
- **Remote reset listener** — trigger the full "Reset Jaringan" sequence from another phone (e.g. F6) connected to x3nfc's hotspot, via a simple token-protected URL, without unlocking or touching x3nfc at all. Runs as a normal Termux process via Termux:Boot (no root needed except the final trigger). Toggle via `menu.sh` → Pengaturan → option 7. (`scripts/reset-listener.sh`, `scripts/reset-handler.sh`, requires `pkg install nmap`)
- **Auto-reset on internet loss** — pings `8.8.8.8` every 20s; after 3 consecutive failures (~1 min), automatically runs the full network reset with no interaction needed at all. Handles the case where the hotspot itself stays connected but mobile data silently stops passing traffic. Toggle via `menu.sh` → Pengaturan → option 8. (`scripts/connectivity-watchdog.sh`)

### Changed
- `install.sh` now detects an existing `hotspot-config.sh` and reuses it automatically — SSID/password are only asked on a true first install. Re-running it also restores the watchdog/schedule/auto-reset if they were previously enabled.
- Turning autostart **off** via the menu keeps SSID/password/watchdog/schedule/auto-reset preferences saved, so turning it back **on** doesn't require re-entering anything.
- Notification button changed from a simple hotspot restart to a full **"Reset Jaringan"**: stop hotspot → disable data → airplane mode on → airplane mode off → re-enable data → restart hotspot. Every wait step polls actual system state instead of a fixed `sleep`. (`scripts/network-reset.sh`, replaces `scripts/restart-hotspot.sh`)
- `network-reset.sh` rewritten to a **fixed 10-second schedule** instead of adaptive polling — disable data (t=1s) → stop hotspot (t=2s) → airplane mode on (t=3s) → airplane mode off (t=6s) → re-enable data (t=8s) → restart hotspot (t=10s). Much faster and predictable than the previous polling approach, at the cost of not confirming each step actually completed before moving on.

### Fixed
- Reboot instructions in README/install.sh corrected to `su -c /system/bin/reboot` — plain `su -c reboot` fails since Termux's `$PATH` doesn't include Android's `reboot` binary.

### Planned next
- Multi-SSID / dual-band (2.4GHz + 5GHz) softAp support
- Telegram/webhook notifications for hotspot state changes
- Per-client data cap (cut off one connected device after N data used, others unaffected)
- Per-client speed limit (experimental — device/kernel dependent)

## v0.3
### Added
- Status notification with an interactive **"Restart Hotspot"** button (via Termux:API), sent after boot and whenever the watchdog auto-restarts the hotspot. Silently disabled if Termux:API isn't installed. (`scripts/notify-status.sh`, `scripts/restart-hotspot.sh`)
- **Scheduled off/on** — optionally turn the hotspot off at one hour and back on at another, every day. Configured during `install.sh`. (`scripts/hotspot-scheduler.sh`)
### Fixed
- `notify-status.sh` now explicitly exports `HOME`/`PREFIX`/`TMPDIR`/`LD_LIBRARY_PATH` before calling `termux-notification`. Without these, the call reached Termux:API but failed with `Error in ResultReturner`, since the script runs from a root/Magisk context with none of Termux's own environment inherited.

## v0.2
### Added
- Interactive `install.sh` — prompts for SSID/password/security instead of manual `nano` editing. Re-runnable any time to change settings.
- Credentials moved out of the script into a separate `hotspot-config.sh`, written with `chmod 700` (root-only).
- `uninstall.sh` — removes all installed files, offers to delete logs.
- Optional **idle-timeout watchdog** (`scripts/hotspot-watchdog.sh`) — detects when the hotspot turns itself off due to Android's idle auto-shutoff (heuristic via `logcat`) and restarts it, without interfering when the hotspot is turned off manually.
### Changed
- `scripts/autostart-network.sh` main service loop refactored into a `wait_for_service()` function; timeouts now log a clear `WARNING` line instead of failing silently.

## v0.1
### Added
- Initial release: `scripts/autostart-network.sh` polls the `phone` and `wifi` system services after boot (instead of a blind `sleep`), then enables mobile data and starts the Wi-Fi hotspot with credentials hardcoded at the top of the script.
- `install.sh` copies the script into `/data/adb/service.d/` via Magisk.
