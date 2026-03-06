#!/usr/local/bin/python3
#
# dhcp6c-ula-mapping.py — change-triggered orchestrator for prefix-to-NPTv6 pipeline
#
# Called from dhcp6c_wan_custom.sh (or via cron) after a DHCP6 event.  Checks
# whether any per-interface prefix files have changed since the last run.  If
# they have, it runs:
#
#   1. dhcp6c-prefix-json   — update /var/db/dhcp6c-pds.json
#   2. dhcp6c-checkset-nptv6 — converge OPNsense NPTv6 rules
#
# State is tracked in /var/db/dhcp6c-prefix-checker.last (persistent across
# reboots) so a reboot does not always force a full reconciliation cycle.
#
# INSTALL
# -------
# /usr/local/bin/dhcp6c-ula-mapping.py   (chmod 755)
#
# SYSLOG TAG:  dhcp6c-ula-map

import os
import sys
import subprocess
import syslog
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Prefix files written by dhcp6c (one per WAN interface configured via split dhcp6c_igc*.conf.custom overrides)
PREFIX_FILES = [
    Path("/tmp/igc0_prefixv6"),
    Path("/tmp/igc1_prefixv6"),
]

# Persistent last-run marker — survives reboots; /var/db is persistent on OPNsense
STATE_FILE = Path("/var/db/dhcp6c-prefix-checker.last")

# Pipeline scripts
PREFIX_JSON_SCRIPT  = "/usr/local/bin/dhcp6c-prefix-json"
CHECKSET_SCRIPT     = "/usr/local/bin/dhcp6c-checkset-nptv6"

# Set to True for extra syslog output during troubleshooting.
DEBUG = False

SYSLOG_TAG = "dhcp6c-ula-map"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

syslog.openlog(SYSLOG_TAG, syslog.LOG_PID, syslog.LOG_DAEMON)


def log_info(msg: str) -> None:
    syslog.syslog(syslog.LOG_INFO, msg)


def log_warn(msg: str) -> None:
    syslog.syslog(syslog.LOG_WARNING, msg)


def log_err(msg: str) -> None:
    syslog.syslog(syslog.LOG_ERR, msg)


def log_debug(msg: str) -> None:
    if DEBUG:
        syslog.syslog(syslog.LOG_DEBUG, msg)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_last_run_time() -> float:
    if STATE_FILE.exists():
        return STATE_FILE.stat().st_mtime
    return 0.0


def update_last_run_time() -> None:
    try:
        STATE_FILE.touch()
    except OSError as exc:
        log_warn(f"Could not update state file {STATE_FILE}: {exc}")


def run_script(script: str) -> bool:
    """Run a script, log outcome, return True on success."""
    if not os.path.isfile(script):
        log_err(f"Script not found: {script}")
        return False
    if not os.access(script, os.X_OK):
        log_err(f"Script not executable: {script}")
        return False
    log_info(f"Running: {script}")
    try:
        subprocess.check_call([script], timeout=120)
        log_debug(f"{script} completed successfully")
        return True
    except subprocess.CalledProcessError as exc:
        log_err(f"{script} exited with code {exc.returncode}")
        return False
    except subprocess.TimeoutExpired:
        log_err(f"{script} timed out")
        return False


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    last_run = get_last_run_time()
    log_debug(f"Last run: {last_run}")

    # Only consider prefix files that actually exist right now
    existing = [f for f in PREFIX_FILES if f.exists()]
    if not existing:
        log_debug("No prefix files present — nothing to do")
        sys.exit(0)

    # Check whether any prefix file is newer than our last run
    newer = [f for f in existing if f.stat().st_mtime > last_run]
    if not newer:
        log_debug("No prefix files changed since last run — skipping reconciliation")
        sys.exit(0)

    log_info(f"Changed prefix file(s): {[str(f) for f in newer]} — starting reconciliation")

    # Step 1: update PD state JSON
    if not run_script(PREFIX_JSON_SCRIPT):
        log_err("dhcp6c-prefix-json failed — aborting reconciliation")
        sys.exit(1)

    # Step 2: converge NPTv6 rules
    if not run_script(CHECKSET_SCRIPT):
        log_err("dhcp6c-checkset-nptv6 failed — NPTv6 state may be inconsistent")
        sys.exit(2)

    # Only advance the state marker when both scripts succeeded
    update_last_run_time()
    log_info("Reconciliation pipeline completed successfully")


if __name__ == "__main__":
    main()
