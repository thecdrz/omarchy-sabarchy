# Omarchy marketplace listing — 0.6.0

Use this when submitting or updating SABarchy on the Omarchy plugin marketplace.

## Listing copy (source of truth)

| Field | Source |
|---|---|
| Name | `manifest.json` → `SABarchy` |
| Version | `manifest.json` → `0.6.0` |
| ID | `io.github.thecdrz.sabarchy` |
| Short description | `manifest.json` → `description` |
| Long description | `README.md` → **Features** + **Usage** (trim if the form has a limit) |
| Install | `omarchy plugin add https://github.com/thecdrz/omarchy-sabarchy.git --enable` |
| Changelog | `CHANGELOG.md` → `[0.6.0]` section |

## Screenshots to capture

Existing shots live under `docs/screenshots/`. Overwrite in place when new captures are ready.

| File | Show | Notes |
|---|---|---|
| `00-gruvbox-clean-download.png` | Active download + clear history | Primary hero; Gruvbox or current default theme |
| `03-ristretto-failure-retry.png` | Failed job + retry + low-disk banner | Confirms failure recovery UX |
| `07-tokyo-night-active-history.png` | Active queue + history on alternate theme | Proves theme adaptability |

**Recommended for 0.6.0** (optional fourth/fifth marketplace images or README):

- Notification preview (`"_demoNotify": "both"` in shell.json demo settings)
- Completed history row with **OPEN** folder action visible
- First-run / offline setup state (`--demo not-configured` or `--demo offline`)

### Capture tips

- Use a real Omarchy theme; dark themes read best for the panel chrome.
- Crop to the bar band + panel; avoid full-desktop clutter.
- Left-click the bar widget to open the panel; use `--demo failed` for disk warning shots.
- For notifications, set `"_demoState": "failed"` and `"_demoNotify": "both"` on the widget entry in `~/.config/omarchy/shell.json`, then reload the shell.
- After capture, run `python -m unittest discover -s tests -v`.

## Pre-submit checklist

- [ ] `manifest.json` version is `0.6.0`
- [ ] `CHANGELOG.md` has a `[0.6.0]` section
- [ ] Helper tests pass on a clean checkout
- [ ] Fresh `omarchy plugin add … --enable` connects to a default `~/.sabnzbd/sabnzbd.ini` install
- [ ] GitHub release notes pasted from `CHANGELOG.md`

## After publish

- Update **Current baseline** in `docs/ROADMAP.md`
- Run `omarchy plugin update io.github.thecdrz.sabarchy` on dev machines to confirm the upgrade path
