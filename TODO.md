# TODO — OPNsense Standards & Best-Practice Compliance

This checklist captures the work needed to move this project from experimental scripts to a
standards-aligned OPNsense deployment model.  Phases 1-3 are complete.  Phase 4 requires
field validation.

## Compliance Change Table

| Priority | Area | What Changed | Validation Gate | Status |
|---|---|---|---|---|
| High | Persistent paths | All scripts and configs moved to `usr/local/etc/` and `usr/local/bin/` in the repo; legacy `var/etc/` content removed from branch to avoid accidental path fallback during testing | Reboot: files persist, services execute | ✅ Done |
| High | DHCPv6 config hook paths | Per-interface override files (`usr/local/etc/dhcp6c_wan.conf.custom`, `usr/local/etc/dhcp6c_wan2.conf.custom`) use `script "/usr/local/bin/dhcp6c_{interface}.sh"` | `dhcp6c -n -c /usr/local/etc/dhcp6c_wan.conf.custom -D` and `...wan2...` pass | ✅ Done |
| High | Interface wrappers | Runtime wrapper model installed: `dhcp6c_interface_wrapper.sh` + per-interface symlinks (`dhcp6c_<real_if>.sh`) generated from GUI WAN/WAN2 mapping | Hook execution logs show correct runtime `INTERFACE` on `vtnet*/igc*` | ✅ Done |
| High | Secrets/config hygiene | `checkset-nptv6.yml` replaced with `checkset-nptv6.yml.example`; `install.sh` deploys template if no live file exists | No secrets in repo; config linter passes | ✅ Done |
| High | Dependency preflight | `preflight-check.sh` checks all deps; `dhcp6c-checkset-nptv6` checks at startup and exits with clear error | Fresh-node preflight passes before enable | ✅ Done |
| High | Idempotent NPTv6 updates | Mark/sweep reconciliation: mark existing rules wanted/unwanted, add missing, delete stale; zero mutations on no-change run | Re-run produces zero API changes | ✅ Done |
| Medium | Logging standardization | All scripts use `syslog` with tag-based, severity-level logging; `DEBUG` flag gates LOG_DEBUG entries | Operational actions visible in system log by tag | ✅ Done |
| Medium | Temp-file resilience | Orchestrator state moved to `/var/db/` (persistent); missing `/tmp/` prefix files handled gracefully | Restart + failover converge without manual fix | ✅ Done |
| Medium | Packaging/integration | `install.sh` provides idempotent file install + dep warning; `preflight-check.sh` validates environment | New-node install from one runbook without ad hoc edits | ✅ Done |
| Medium | API access robustness | `_api_get`/`_api_post` helpers: 15 s timeout, 3 retries, explicit error logging | Simulated API failure produces safe, diagnosable behavior | ✅ Done |
| High | Source-of-truth alignment | `Migration_to_Standards.md` updated to reflect completed migration and removal of legacy files from active test branch | Runtime paths match migration doc; survive firmware updates | ✅ Done |

## Implementation Phases

### Phase 1 — Path & Hook Compliance ✅
- [x] Move all runtime scripts/config from `/var/etc` to persistent OPNsense paths
- [x] Add interface wrapper scripts in `usr/local/bin`
- [x] Update per-interface custom dhcp6c files to wrapper script paths
- [x] `dhcp6c -n -c /usr/local/etc/dhcp6c_wan.conf.custom` and `...wan2...` pass syntax check

### Phase 2 — Installability & Safety ✅
- [x] `preflight-check.sh` verifies `python3`, `pyyaml`, `requests`, tools, and config
- [x] `install.sh` copies files, sets permissions, warns on missing deps
- [x] Config template (`checkset-nptv6.yml.example`) with no secrets; placeholder validation in script
- [x] `install.sh` sets explicit permissions for all installed files

### Phase 3 — Runtime Correctness ✅
- [x] NPTv6 reconciliation is strict desired-state mark/sweep
- [x] API helpers add timeout, retry, and rollback-safe error flow
- [x] Orchestrator skips gracefully when `/tmp/` prefix files are absent
- [x] All scripts log to syslog with consistent tags and severity levels

### Phase 4 — Operational Validation (field test pending)
- [ ] Validate across reboot, WAN flap, and CARP transition scenarios
- [ ] Confirm persistence across OPNsense firmware update / template regeneration
- [ ] Run post-install verification commands and confirm expected syslog output
- [ ] Finalize install/upgrade/rollback runbook in `readme.md`

## Exit Criteria

- [x] Runtime no longer depends on `/var/etc` for user-managed scripts/config.
- [x] Fresh install works from documented steps with no ad hoc edits.
- [ ] Reboot/failover/update cycles preserve behavior and configuration. *(field test pending)*
- [x] Repeated runs are idempotent and produce no config/API drift.
