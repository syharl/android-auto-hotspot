# Changelog

## Unreleased
### Added
- Status notification with an interactive **"Restart Hotspot"** button (via Termux:API), sent after boot and whenever the watchdog auto-restarts the hotspot. Silently disabled if Termux:API isn't installed. (`scripts/notify-status.sh`, `scripts/restart-hotspot.sh`)
- **Scheduled off/on** — optionally turn the hotspot off at one hour and back on at another, every day. Configured during `install.sh`. (`scripts/hotspot-scheduler.sh`)

### Planned next
- Multi-SSID / dual-band (2.4GHz + 5GHz) softAp support
- Telegram/webhook notifications for hotspot state changes
- Per-client data cap (cut off one connected device after N data used, others unaffected)
- Per-client speed limit (experimental — device/kernel dependent)

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
