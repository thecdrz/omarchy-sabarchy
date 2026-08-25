# Changelog

All notable changes to SABarchy are documented here.

## [0.7.0] — 2026-08-24

### Added

- Bar failure indicator when unresolved failed history items need attention.
- Stage-aware job colors so download, verify, unpack, and failure states read clearly on a single active row.
- Richer expanded history rows with retry count, failure message, and storage path.
- Notification click opens the SABarchy panel (`notify-send --wait --action=default:Open`).

### Changed

- Bar tooltip summarizes verify/unpack activity and failure counts.
- Active jobs stay in one list; the status pill tracks SABnzbd stage changes instead of splitting into parallel sections.
- Failed history rows stay compact when expanded (retry count folded into the meta line).
- Processing demo fixture shows a verifying job in that single-row flow.

### Fixed

- Pause/resume no longer leaves a sticky **ACCEPTED** label in the panel footer after queue actions succeed.

## [0.6.0] — 2026-08-24

### Fixed

- Treat SABnzbd's quoted-empty INI values (e.g. `url_base = ""`) as absent so default configs connect instead of hitting `/""/api` and showing offline.

### Added

- Desktop notifications when downloads complete or fail while the panel is closed, with optional freedesktop sound via PipeWire.
- Configurable **Low disk warning (GB)** setting (default 20; set 0 to disable).
- **Open folder** for completed history items (`f` key and history action), using validated absolute paths from SABnzbd.
- `storage` path field in helper snapshots with bounds and validation.
- `_demoNotify` development key for notification screenshot previews.

### Changed

- Disk low warning threshold is now driven by widget settings instead of a hard-coded 20 GB in the helper.

## [0.5.5] — 2026-08-22

### Added

- API response and output bounds, redirect blocking, and stricter JSON parsing in the helper.
- Rich-text-safe plain rendering for SABnzbd metadata fields.

## [0.5.4] — 2026-08-22

### Fixed

- Harden disconnect, stale, and configuration-error states for marketplace release.

## [0.5.0] — 2026-08-21

### Added

- Initial SABarchy release: bar widget, keyboard-first panel, queue/history dashboard, retry and clear-history flows.
