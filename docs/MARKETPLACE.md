# Omarchy marketplace listing — 0.7.0

Use this when submitting or updating SABarchy on the Omarchy plugin marketplace.

## Listing copy (source of truth)

| Field | Source |
|---|---|
| Name | `manifest.json` → `SABarchy` |
| Version | `manifest.json` → `0.7.0` |
| ID | `io.github.thecdrz.sabarchy` |
| Short description | `manifest.json` → `description` |
| Long description | `README.md` → **Features** + **Usage** (trim if the form has a limit) |
| Install | `omarchy plugin add https://github.com/thecdrz/omarchy-sabarchy.git --enable` |
| Changelog | `CHANGELOG.md` → `[0.7.0]` section |

## Screenshots to capture

Existing shots live under `docs/screenshots/`. Overwrite in place when new captures are ready.

| File | Show | Notes |
|---|---|---|
| `00-gruvbox-clean-download.png` | Active download + clear history | Primary hero; Gruvbox or current default theme |
| `03-ristretto-failure-retry.png` | Failed job + retry + low-disk banner | Confirms failure recovery UX |
| `07-tokyo-night-active-history.png` | Active queue + history on alternate theme | Proves theme adaptability |

**Recommended for 0.7.0** (optional fourth/fifth marketplace images or README):

- Verifying / unpacking status on a single active job card (`--demo processing`)
- Expanded failed history row with retry count and failure message (`--demo failed` + expand history)
- Bar failure indicator dot with issues filter selected
- Notification preview (`"_demoNotify": "both"`)

### Capture tips

- **Use the helper script** (recommended): `bin/capture-screenshot processing docs/screenshots/04-everforest-processing.png`
- The script sets demo state, restarts the shell, opens the panel, then launches Omarchy’s region picker. Drag a ~960px-wide box over the bar + panel.
- Move or minimize windows behind the panel before capturing; automated `grim` crops are unreliable on ultrawide layouts.
- Use a real Omarchy theme; dark themes read best for the panel chrome.
- Left-click the bar widget to reopen the panel if needed; use `--demo failed` for disk warning shots.
- For notifications, set `"_demoState": "failed"` and `"_demoNotify": "both"` on the widget entry in `~/.config/omarchy/shell.json`, then reload the shell.
- Clear demo keys when finished: `omarchy bar set io.github.thecdrz.sabarchy _demoState '""' --json && omarchy-restart-shell`
- After capture, run `python -m unittest discover -s tests -v`.

## Pre-submit checklist

- [x] `manifest.json` version is `0.7.0`
- [x] `CHANGELOG.md` has a `[0.7.0]` section
- [x] Helper tests pass on a clean checkout
- [x] Fresh screenshots for processing / failure UX (overwrite `docs/screenshots/` as needed)
- [x] Fresh `omarchy plugin add … --enable` connects to a default `~/.sabnzbd/sabnzbd.ini` install
- [x] GitHub release notes pasted from `CHANGELOG.md`
- [x] Marketplace verify/update submitted ([#2290](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/2290))

## After publish

- Update **Current baseline** in `docs/ROADMAP.md`
- Run `omarchy plugin update io.github.thecdrz.sabarchy` on dev machines to confirm the upgrade path
