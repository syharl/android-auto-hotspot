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
No editing required — the installer asks you for everything interactively:
- **SSID** and **Password** (the same hotspot you already set up once in Android's Settings).
- **Security** type: `wpa2`, `wpa3`, or `open` (defaults to `wpa2` if you just press Enter).
- Whether to enable the **watchdog** (auto-restart the hotspot if it turns itself off from idle — see [Optional: auto-restart watchdog](#optional-auto-restart-watchdog) below).

It then asks you to confirm before touching anything (type `y` and Enter), and uses `su` to:
- Write your answers to `/data/adb/service.d/hotspot-config.sh` (kept separate from the scripts, `chmod 700` so only root can read it).
- Copy `scripts/autostart-network.sh` (and `scripts/hotspot-watchdog.sh`, if enabled) into `/data/adb/service.d/` — the folder Magisk automatically runs scripts from after boot.
- Make everything executable.

You'll likely get a root permission popup here too if it's the installer's first time asking — grant it.

**Want to change your SSID/password later, or toggle the watchdog on/off?** Just run `bash install.sh` again — it overwrites the config, no need to re-clone or edit files by hand.

### 3. Reboot to test

```bash
su -c reboot
```
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

## Optional: auto-restart watchdog

Many Android versions auto-disable the hotspot after a few minutes with no connected client (a battery-saving feature). If you enabled the watchdog during install (or run `bash install.sh` again to turn it on), `scripts/hotspot-watchdog.sh` gets installed alongside the main script and runs continuously in the background:

- It checks the hotspot's on/off state every 15 seconds.
- If it just turned **off**, the watchdog scans recent `logcat` output for the system's own idle-timeout message. If it looks like an idle auto-shutoff, it restarts the hotspot automatically.
- If you turned it off **yourself** (Settings or the quick-settings tile), no matching idle-timeout message is found, so the watchdog leaves it off.

This detection is a best-effort heuristic — the exact log wording can differ by ROM/Android version. If it restarts the hotspot when you turned it off on purpose (or vice versa), check `su -c 'cat /data/local/tmp/hotspot-watchdog.log'`, then run `logcat -d | grep -i softap` right after an idle auto-shutoff to find the real message on your device, and adjust the `grep` pattern near the bottom of `scripts/hotspot-watchdog.sh`.

## Uninstalling

```bash
bash uninstall.sh
```
Asks for confirmation, then removes `autostart-network.sh`, `hotspot-watchdog.sh`, and `hotspot-config.sh` from `/data/adb/service.d/` (whichever exist). It also offers to delete the log files, since they can contain your SSID. Any hotspot currently running stays on until you turn it off yourself — this only stops it from auto-starting/auto-restarting on future boots.

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
