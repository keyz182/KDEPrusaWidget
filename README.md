# Prusa Status

A KDE Plasma 6 panel widget that shows the status of a Prusa 3D printer via
its [PrusaLink](https://help.prusa3d.com/article/prusa-link-and-prusa-connect_399412)
local API: print progress, temperatures, and a thumbnail of the current job.
Left-click opens a popup with details and print controls; middle-click (or
the popup's button) opens the printer's web UI in the default browser.

The widget talks to the printer directly on your network. It does not use
the Prusa Connect cloud service.

## Features

- Poll interval adapts to state: faster while printing, slower while idle,
  with backoff (5s → 60s) when the printer can't be reached.
- Shows separate states for: not configured, printer unreachable, login
  rejected, and connected. No stale data is shown once a printer goes
  offline.
- Panel shows the job's thumbnail, progress percentage, and time remaining.
- When the printer needs a human (for example, filament runout) or reports
  an error, the widget asks for attention: the panel icon changes and the
  popup shows the printer's message.
- Popup shows filename, progress, elapsed and remaining time, nozzle and bed
  temperatures, and Pause / Resume / Stop buttons. Stop needs a second
  click within 5 seconds, because a stopped job cannot be resumed.
- Controls are disabled until the next poll confirms the printer's state. A
  rejected request is reported in the popup.
- One printer per widget instance; add the widget again for a second
  printer.

## Requirements

- KDE Plasma 6.
- A Prusa printer with PrusaLink enabled (for example MK4, MK3.9, Core One,
  XL, MINI, or MK3 with a PrusaLink Raspberry Pi), reachable over HTTP(S)
  from the desktop running Plasma.

## Installation

```sh
kpackagetool6 --type Plasma/Applet --install package
```

To update an existing install:

```sh
kpackagetool6 --type Plasma/Applet --upgrade package
```

Then add "Prusa Status" from the panel's Add Widgets dialog, or restart
Plasma (`systemctl --user restart plasma-plasmashell`) if it does not show
up.

## Configuration

Right-click the widget → Configure:

| Setting | Description |
|---|---|
| Printer URL | Base URL of the printer, e.g. `http://192.168.1.60`. Required. Do not put the username or password in it. |
| Username / Password | PrusaLink login (HTTP Digest). The printer shows them under Settings → Network → PrusaLink. The default username is `maker`. |
| API key | Optional. When set, it is sent as `X-Api-Key` and replaces the username and password. Print thumbnails are not shown in this mode. |
| Web UI URL | Overrides the URL opened on click. Leave blank to use the printer URL. |
| Poll interval while printing / idle | Seconds between status checks in each state. |
| Show print thumbnail | Toggles the panel thumbnail. |

Credentials are stored in plain text in
`~/.config/plasma-org.kde.plasma.desktop-appletsrc`.

## Known limitations

- Qt caches HTTP Digest logins per host. After you change the password in
  the settings, the old login can stay in use until Plasma restarts. Two
  widgets that point at the same printer with different logins can
  interfere with each other.
- PrusaLink has no emergency stop endpoint, so the widget has none.

## Scope

This widget is a status display and basic remote control, not a full front
end. It does not do camera streaming, file browsing or upload, or print
queuing. Use the PrusaLink web UI or Prusa Connect for that.

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).
