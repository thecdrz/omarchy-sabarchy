# SABarchy roadmap

Living plan for feature and visual work. Update this as items ship or priorities shift.

## Current baseline

| Track | Version | Where |
|-------|---------|-------|
| **Published (marketplace)** | 0.5.5 | Only public release today |
| **In development (`main`)** | 0.7.0 | Next marketplace release |

### On `main` for 0.7.0

- 0.6.0 milestone: notifications, open-folder, disk threshold, `url_base` fix
- Bar failure indicator and processing-aware tooltips
- Split verify/unpack processing sections
- Stage color system and expanded history details
- Notification click opens panel

**Release strategy:** No hotfix rush. Only 0.5.5 is public; ship one substantial 0.7.0 marketplace update.

---

## Release plan

### 0.7.0 — Next marketplace release

**Status:** Code complete on `main`; fresh screenshots remain before marketplace submit.

| Item | Status |
|------|--------|
| Bar failure indicator | Done |
| Dedicated Processing section (verify vs unpack) | Done |
| Expanded history details | Done |
| Notification click opens panel | Done |
| Stage color system | Done |
| Compact verify/unpack processing rows | Done |
| Fresh marketplace screenshots | Pending |
| Push + marketplace submit | Pending |

### 0.6.0 — Development milestone (done)

Merged WIP + connection fix to `main`. Not submitted to marketplace.

---

## Phase 1 — Bar & at-a-glance polish

Small, high-visibility improvements while the panel is closed.

| Item | Type | Priority | Notes |
|------|------|----------|-------|
| Failure indicator on bar | Visual | High | Urgent color / badge when recent history has unresolved failures |
| Processing vs downloading hint | Visual | Medium | Differentiate verify/unpack active jobs in tooltip or micro-label |
| Mini progress on bar | Visual | Medium | Optional: thin progress or % for single active download |
| Idle vs clear-queue copy | Visual | Low | Tooltip already says Idle; align with panel “queue clear” language |
| Vertical bar layout pass | Visual | Low | Confirm icon + speed read well in vertical bar sections |

---

## Phase 2 — Panel UX & recovery

Deeper dashboard workflows without leaving the keyboard.

| Item | Type | Priority | Notes |
|------|------|----------|-------|
| Dedicated **Processing** section | Visual + UX | High | Unpack jobs exist in API but merge into one active list; split verify vs unpack headers |
| Expanded history details | UX | High | Show failure message, retry count, storage path, completed time in expand row |
| Delete / abort queue job | Feature | Medium | SABnzbd `mode=queue&name=delete` — confirm before destructive action |
| Priority bump / lower | Feature | Medium | Queue job priority from panel (`switch` API) |
| Category filter on active queue | Feature | Medium | Filter chips like history (all / by category) |
| Search or filter long queues | Feature | Medium | Especially for `--demo large` / 100+ job installs |
| Schedule pause integration | Feature | Low | Only if SABnzbd API exposes it cleanly |
| Copy job name / path | UX | Low | Clipboard via `wl-copy` for failed or completed items |

---

## Phase 3 — Notifications & system integration

Build on 0.6.0 notification work.

| Item | Type | Priority | Notes |
|------|------|----------|-------|
| Notification click opens panel | UX | High | `notify-send` hints or Omarchy notification bridge if available |
| Per-category notification rules | Feature | Medium | e.g. only notify for `movies`, silence `tv` |
| Quota / disk notifications | Feature | Medium | Separate from low-disk banner; tie to SAB quota fields if present |
| Omarchy notification center plugin | Integration | Low | Evaluate vs raw `notify-send` long-term |

---

## Phase 4 — Visual identity & marketplace

Theme-aware polish and release presentation.

| Item | Type | Priority | Notes |
|------|------|----------|-------|
| Screenshot set per theme | Visual | High | Gruvbox, Tokyo Night, Ristretto (failure/disk), light theme |
| Stage color system | Visual | Medium | Consistent colors: download / verify / unpack / failed / completed |
| Category pill styling | Visual | Medium | Subtle tinted pills instead of plain uppercase text |
| Progress bar micro-animation | Visual | Low | Already animated; tune for large queue scroll performance |
| Empty-state illustrations | Visual | Low | Optional iconography for setup / clear queue / offline |
| SabarchyIcon variants | Visual | Low | Paused / error / active states on the bar glyph |

---

## Phase 5 — Power user & API surface

Optional; ship when there is clear demand.

| Item | Type | Priority | Notes |
|------|------|----------|-------|
| Speed limit toggle | Feature | Low | Pause vs throttle — expose SAB speed limit if useful |
| Queue URL / add NZB | Feature | Low | Paste URL flow; security review required |
| Multi-disk breakdown | Feature | Low | Show disk 1 vs disk 2 free space separately |
| Helper IPC auth subcommand polish | Feature | Low | `auth` mode exists; use for setup wizard |
| Remote SABnzbd (non-loopback) | Feature | **Defer** | Conflicts with local-only security model unless opt-in + explicit host allowlist |

---

## Explicit non-goals (for now)

- Editing SABnzbd server settings from the panel (keep read + queue actions only)
- Remote / LAN SABnzbd without a deliberate security design
- Bundling SABnzbd or managing its systemd unit
- Replacing the SABnzbd web UI for config

---

## How to use this doc

1. Pick the next release (usually top of **Release plan**).
2. Move shipped items to `CHANGELOG.md` and bump `manifest.json`.
3. Capture new ideas under the relevant phase; bump priority rather than adding duplicate rows.
4. For visual work, add or update demo keys (`_demoState`, `_demoNotify`, etc.) before taking marketplace screenshots.

## Related files

- `README.md` — user-facing feature list
- `docs/screenshots/` — current marketplace captures
- `bin/sabnzbd-pipeline-api` — API bridge; demo fixtures live here
- `tests/test_api.py` — helper regression tests
