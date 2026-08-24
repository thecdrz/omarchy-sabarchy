# Changelog

All notable changes to SABarchy are documented here.

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
