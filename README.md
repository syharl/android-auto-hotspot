# android-auto-hotspot

Auto-enable mobile data and Wi-Fi hotspot right after your Android phone boots — no manual toggling needed.

Built for the classic "phone as a portable hotspot" setup: you reboot the device, and by the time it's usable, mobile data and the hotspot are already on, with no need to open Settings.

## The problem this solves

Android has no built-in setting for "turn hotspot on automatically at every boot." Most guides online suggest a boot script with a blind `sleep 20` before enabling things, but the actual system services involved (telephony, wifi) don't come up at a fixed, predictable time after boot — it varies by device, ROM, and even by boot (sometimes 20 seconds, sometimes over a minute).

A fixed sleep either:
- fails intermittently (script runs before the service exists, silently does nothing), or
- wastes time (sleeping way longer than actually necessary "just to be safe").

This script instead **polls the actual system services** (`phone` and `wifi`) until they report as registered, then enables data and starts the hotspot. No guessing, no race conditions, no wasted time.

## Requirements

- **Root access** via Magisk (tested) or KernelSU (should also work — both support `/data/adb/service.d`).
- **Termux** installed on the phone that will act as the hotspot (used to install the script; not needed afterwards).
- A hotspot **already configured at least once manually** in Android's own Settings (SSID + password saved) — the script reuses those exact credentials, so they must match.

### Checking you actually have root

Before doing anything else, open Termux and run:
```bash
su
```
- If a popup appears asking to grant root access (from Magisk or your KernelSU manager app), tap **Grant**, then continue.
- If you instead see `su: command not found` or nothing happens, root isn't set up — install Magisk (or confirm KernelSU is active) before proceeding.

If it worked, your prompt changes from `$` to `#`. Type `exit` to leave the root shell for now — we'll come back to it.

## Step-by-step installation

### 1. Get the files onto your phone

**Option A — using `git` (recommended):**
```bash
pkg install git
git clone https://github.com/syharl/android-auto-hotspot.git
cd android-auto-hotspot
```

**Option B — download the ZIP manually:**
1. On the GitHub repo page, tap **Code → Download ZIP**.
2. Move the downloaded ZIP into Termux's accessible storage (usually lands in your phone's `Downloads` folder).
3. In Termux:
   ```bash
   termux-setup-storage   # only needed once, grants storage access
   cd ~/storage/downloads
   unzip android-auto-hotspot-main.zip
   cd android-auto-hotspot-main
   ```

### 2. Run the installer

```bash
bash install.sh
```
No editing required. **First install:** the installer asks for two things:
- **SSID** and **Password** (the same hotspot you already set up once in Android's Settings).

Security defaults to `wpa2`. **Re-running it later** (e.g. after `git pull`, or if you uninstalled and reinstalled without wiping config) skips the SSID/password prompt entirely — it detects your existing `hotspot-config.sh` and reuses it automatically, along with whatever watchdog/schedule settings you had.

Changing SSID/password/security afterward, or toggling the watchdog and schedule, is done through the control panel: `bash menu.sh` (see [Control panel](#control-panel) below).

It then asks you to confirm before touching anything (type `y` and Enter), and uses `su` to:
- Write your answers to `/data/adb/service.d/hotspot-config.sh` (kept separate from the scripts, `chmod 700` so only root can read it).
- Copy `scripts/autostart-network.sh` (and `scripts/hotspot-watchdog.sh`/`scripts/hotspot-scheduler.sh`, if they were previously enabled) into `/data/adb/service.d/` — the folder Magisk automatically runs scripts from after boot.
- Make everything executable.

You'll likely get a root permission popup here too if it's the installer's first time asking — grant it.

**Want to change your SSID/password later, toggle the watchdog/schedule, or uninstall?** Run `bash menu.sh` — a control panel, no need to re-run the installer or edit files by hand.

### 3. Reboot to test

```bash
su -c /system/bin/reboot
```
(Using the full path avoids `su -c reboot` failing with "No command reboot found" — Termux's own `$PATH` doesn't include Android's `reboot` binary.)
(a plain `reboot` won't work — rebooting needs root privilege)

Wait about **2–3 minutes** after the phone finishes booting — don't touch data/hotspot settings manually during this time, so you get a clean test.

### 4. Check whether it worked

Open Termux again and run:
```bash
su -c 'cat /data/local/tmp/autostart-network.log'
```
You should see 6 numbered lines with timestamps, e.g.:
```
1. start: ...
2. boot_completed: ...
3. phone service: Service phone: found - ...
4. mobile data enabled: ...
5. wifi service: Service wifi: found - ...
6. hotspot command sent: ...
```
Then check your phone's notification shade or Settings → Hotspot to confirm it's actually on.

## Control panel

```bash
bash menu.sh
```
A single interactive control panel — press a number key, no Enter needed. Five main options:

- **[1] Toggle Autostart Hotspot** — turns the whole autostart setup on or off. Turning it **off** removes the installed scripts but keeps your SSID/password/settings saved, so turning it back **on** doesn't ask for anything again. If you haven't installed at all yet, turning it on for the first time will ask for SSID/password itself (same as `install.sh`).
- **[2] Pengaturan** — a submenu to change SSID, password, security, toggle the watchdog, set/clear the daily schedule, and toggle the [remote reset listener](#optional-remote-reset-without-touching-x3nfc). Every change is applied immediately — no separate save step.
- **[3] Reset Jaringan (sekarang)** — runs the full network reset right now, directly from the menu (stop hotspot → data off → airplane mode on/off → data on → hotspot on). Takes about a minute; same sequence as the notification button or the remote listener.
- **[4] Reboot x3nfc** — reboots the phone, with a confirmation prompt first.
- **[5] Uninstall** — removes everything, including your saved SSID/password, back to a clean state as if never installed. Optionally also deletes the log files.

You can run `menu.sh` any time — it always reflects and edits whatever is actually on the device.

## Optional: auto-restart watchdog

Many Android versions auto-disable the hotspot after a few minutes with no connected client (a battery-saving feature). Enable it via `bash menu.sh` → **[2] Pengaturan** → **[4] Toggle Watchdog**. Once installed, `scripts/hotspot-watchdog.sh` runs continuously in the background:

- It checks the hotspot's on/off state every 15 seconds.
- If it just turned **off**, the watchdog scans recent `logcat` output for the system's own idle-timeout message. If it looks like an idle auto-shutoff, it restarts the hotspot automatically.
- If you turned it off **yourself** (Settings or the quick-settings tile), no matching idle-timeout message is found, so the watchdog leaves it off.

This detection is a best-effort heuristic — the exact log wording can differ by ROM/Android version. If it restarts the hotspot when you turned it off on purpose (or vice versa), check `su -c 'cat /data/local/tmp/hotspot-watchdog.log'`, then run `logcat -d | grep -i softap` right after an idle auto-shutoff to find the real message on your device, and adjust the `grep` pattern near the bottom of `scripts/hotspot-watchdog.sh`.

## Optional: status notification with a Restart button

If you have the **Termux:API** app installed (separate from Termux — install it from F-Droid or Play Store) and have run `pkg install termux-api` once inside Termux, this repo will send you a notification:
- Right after boot, once the hotspot is up ("Hotspot Aktif").
- Whenever the watchdog auto-restarts the hotspot from an idle timeout.
- Whenever the scheduler turns it off/on.

Each notification includes a **Reset Jaringan** button that does a full network reset, similar to what happens on a normal reboot's radio init — not just restarting the hotspot:
1. Stop the hotspot
2. Disable mobile data
3. Turn airplane mode **on**
4. Turn airplane mode **off**
5. Re-enable mobile data
6. Restart the hotspot

Every wait in between polls the actual system state (airplane mode setting, SIM/radio readiness, wifi service) instead of a fixed delay — same approach as the boot script. Useful when the hotspot or data connection is stuck in a weird state and a plain restart isn't enough. Logs go to `su -c 'cat /data/local/tmp/network-reset.log'`.

If Termux:API isn't installed, `scripts/notify-status.sh` detects that and exits quietly — nothing breaks, you just won't get notifications.

## Optional: scheduled off/on

If you set a schedule via `bash menu.sh` → **[2] Pengaturan** → **[5] Atur Jadwal Off/On**, `scripts/hotspot-scheduler.sh` runs in the background and:
- Turns the hotspot **off** at your chosen hour (24h format) every day.
- Turns it back **on** at your chosen hour.

Useful if this phone runs as a home server 24/7 but you don't need the hotspot overnight. Run `bash menu.sh` any time to change the hours or clear the schedule. Logs go to `su -c 'cat /data/local/tmp/hotspot-scheduler.log'`.

## Optional: remote reset without touching x3nfc

Trigger the same **"Reset Jaringan"** sequence from another phone (e.g. F6) connected to x3nfc's hotspot — no need to unlock or open anything on x3nfc.

**Requirements (on x3nfc, one time):**
```bash
pkg install nmap termux-boot
```
(`termux-boot` here is the Termux *package*, not the separate Termux:Boot app — you already have the app installed, this just documents the dependency.)

**Enable it:** `bash menu.sh` → **[2] Pengaturan** → **[7] Toggle Remote Reset Listener**. It generates a random token, starts listening immediately, and installs itself into `~/.termux/boot/` so it also starts automatically on every future boot — without ever opening Termux.

You'll get a URL like:
```
http://192.168.43.1:8091/reset?key=AB12CD34
```
Save that as a bookmark on F6 (while connected to x3nfc's hotspot). Opening it in F6's browser triggers the full network reset on x3nfc immediately — nothing needs to be unlocked or tapped on x3nfc itself. Double-check the IP by looking at F6's WiFi connection details (Gateway address) since it isn't always `192.168.43.1` on every device.

This only works while F6 is actually associated with x3nfc's hotspot Wi-Fi (which usually stays up even when mobile data itself is misbehaving — that's exactly the situation this is meant to fix). If the hotspot radio is fully off, there's no local link to reach it over, and a physical restart is the only option. Logs: `cat ~/reset-listener.log` (in Termux, no `su` needed).

**Security note:** the token is a shared secret in the URL — anyone connected to your hotspot who guesses/sees it could trigger a reset too. Since the hotspot itself already needs a password to join, this is a reasonable second layer, not a strong one — don't share the URL outside people you trust with hotspot access.

## Uninstalling

Easiest: `bash menu.sh` → **[5] Uninstall**.

Or directly from the command line:
```bash
bash uninstall.sh
```
Asks for confirmation, then removes every installed script and `hotspot-config.sh` (whichever exist) from `/data/adb/service.d/`. It also offers to delete the log files, since they can contain your SSID. Any hotspot currently running stays on until you turn it off yourself — this only stops it from auto-starting/auto-restarting on future boots.

## Troubleshooting

These are real issues encountered while building this — check here first before opening an issue.

**Log shows nothing after step 1 (just the "start" timestamp):**
The script got killed partway through, usually because it took longer than expected. Try increasing the `sleep` values inside the script, or check if your device is unusually slow to bring up telephony after boot.

**Log shows `cmd: Can't find service: phone`:**
This means `svc data enable` ran before the telephony service existed. If you still see this despite the polling loop, your device may register the service under this exact same name but at a much later boot stage — try increasing the retry limit (the `[ "$i" -ge 30 ]` lines; each unit is a 2-second wait, so `30` = 60 seconds max wait).

**Hotspot never turns on, but no error either:**
Run `cmd wifi start-softap -h` directly (as root) on your device — some Android/ROM versions expect slightly different argument order or an extra flag. Adjust the corresponding line in `scripts/autostart-network.sh` to match.

**Commands silently do the wrong thing / behave unexpectedly:**
If you have BusyBox installed (Magisk usually ships one), a bare `svc` or `cmd` in your `PATH` might resolve to BusyBox's own unrelated tool of the same name instead of Android's real one. This script avoids that by always calling full paths (`/system/bin/svc`, `/system/bin/cmd`) — if you modify the script, keep using full paths.

**Hotspot turns on but shuts itself off a few minutes later:**
Many Android versions auto-disable the hotspot after a few minutes with no connected client (a battery-saving feature). Either disable it in Settings → Hotspot & tethering → "Turn off hotspot automatically", or enable the [watchdog](#optional-auto-restart-watchdog) to have it restart automatically instead.

## How it works internally

Placed in `/data/adb/service.d/`, `autostart-network.sh` is executed by Magisk at the `late_start service` boot stage — one of the later points in the boot sequence, but still before every system service is guaranteed to be up. Instead of assuming a fixed delay, the script:

1. Reads SSID/password/security from `hotspot-config.sh` (written by `install.sh`, sitting next to it in `/data/adb/service.d/`).
2. Waits for the `sys.boot_completed` system property to become `1`.
3. Polls `service check phone` every 2 seconds (up to 60 seconds) until Android's telephony service is registered.
4. Runs `/system/bin/svc data enable`.
5. Polls `service check wifi` the same way, until the wifi service is registered.
6. Runs `/system/bin/cmd wifi start-softap "$SSID" "$SECURITY" "$PASSWORD"`.

Every step is logged with a timestamp to `/data/local/tmp/autostart-network.log`, so any failure is visible after the fact instead of failing silently. If the watchdog is enabled, `hotspot-watchdog.sh` runs in parallel afterward, polling hotspot state and logging to `/data/local/tmp/hotspot-watchdog.log`.

## License

This project is released under the **MIT License** — one of the most common and permissive open-source licenses. In plain terms:

- ✅ You can use, copy, modify, and share this code — for personal or commercial projects, doesn't matter.
- ✅ You can even sell software that includes it.
- ⚠️ The only real requirement: keep the original copyright notice and license text somewhere in your copy (that's what the `LICENSE` file is for).
- 🚫 No warranty — if something breaks your phone or doesn't work as expected, the author isn't liable. Use at your own risk (this modifies boot-time network behavior on a rooted phone, so a basic understanding of what you're doing is expected).

See the full legal text in [LICENSE](LICENSE).
