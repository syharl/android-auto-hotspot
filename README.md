# android-auto-hotspot

Auto-enable mobile data and Wi-Fi hotspot right after your Android phone boots — no manual toggling needed.

Built for the classic "phone as a portable hotspot" setup: you reboot the device, and by the time it's usable, data and hotspot are already on.

## Why

Android has no built-in setting for "turn hotspot on automatically at every boot." Most guides suggest a blind `sleep 20` in a boot script, but the actual system services (telephony, wifi) don't always come up at a fixed time after boot — it varies by device and can take anywhere from ~20 seconds to over a minute. A fixed sleep either fails intermittently or wastes time.

This script instead **polls the actual system services** (`phone` and `wifi`) until they're registered, then enables data and starts the hotspot. No guessing, no race conditions.

## Requirements

- **Root** (tested with Magisk; should also work with KernelSU since both support `/data/adb/service.d`)
- A hotspot already configured at least once manually (SSID/password saved in Android's Wi-Fi settings) — this script reuses those settings unless you hardcode different ones

## Install

1. Clone or download this repo onto your device (e.g. into Termux's home folder).
2. Edit `scripts/autostart-network.sh` — set `SSID`, `PASSWORD`, and `SECURITY` at the top to match your hotspot.
3. Run the installer from Termux:
   ```bash
   bash install.sh
   ```
4. Reboot your device to test.

## Checking if it worked

The script logs each step to `/data/local/tmp/autostart-network.log`. After a reboot:
```bash
su -c 'cat /data/local/tmp/autostart-network.log'
```
You should see 6 numbered steps with timestamps, ending with the hotspot command being sent.

## How it works

Placed in `/data/adb/service.d/`, the script is run by Magisk at the `late_start service` boot stage. Instead of assuming a fixed delay, it:

1. Waits for `sys.boot_completed` to be `1`.
2. Polls `service check phone` until the telephony service is registered.
3. Runs `svc data enable`.
4. Polls `service check wifi` until the wifi service is registered.
5. Runs `cmd wifi start-softap "$SSID" "$SECURITY" "$PASSWORD"`.

All commands use full paths (`/system/bin/svc`, `/system/bin/cmd`) — on a rooted device with Magisk/BusyBox installed, a bare `svc` can resolve to BusyBox's own unrelated `svc` (a runit service tool), silently doing the wrong thing.

## Known limitations

- Some Android versions auto-shut-off the hotspot after N minutes of no connected clients (`softap.idle_timeout`-style setting under Settings → Hotspot). If nothing connects in time, the hotspot may turn itself off before you get to it.
- `cmd wifi start-softap` syntax can vary slightly by Android/ROM version. If it fails, run `cmd wifi start-softap -h` on your device for the exact expected arguments and adjust the script.
- This does **not** set up SSH or any remote-access tooling — it only handles data + hotspot. Pair it with your own remote-access setup if needed.

## License

MIT — see [LICENSE](LICENSE).
