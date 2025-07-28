#!/usr/bin/env python3
import os
import sys
import subprocess
from pathlib import Path

# Files to check
prefix_files = [Path('/igc0_prefixv6'), Path('/igc1_prefixv6')]
# State file to track last run time
state_file = Path('/tmp/dhcp6c-prefix-checker.last')
# Scripts to execute
prefix_json_script = '/etc/dhcp6c-prefix-json'
checkset_script = '/tmp/dhcp6c-checkset-nptv6'
# Debug flag (set to True to enable debug output)
DEBUG = False

def get_last_run_time():
    if state_file.exists():
        return state_file.stat().st_mtime
    return 0

def update_last_run_time():
    state_file.touch()

def debug(msg):
    if DEBUG:
        print(f"[DEBUG] {msg}")

def main():
    last_run = get_last_run_time()
    debug(f"Last run time: {last_run}")
    files_to_check = [f for f in prefix_files if f.exists()]
    debug(f"Files to check (exist): {[str(f) for f in files_to_check]}")
    if not files_to_check:
        debug("No prefix files exist. Exiting.")
        sys.exit(0)  # Nothing to do
    # Check if any file is newer than last run
    newer = [f for f in files_to_check if f.stat().st_mtime > last_run]
    debug(f"Files newer than last run: {[str(f) for f in newer]}")
    if not newer:
        debug("No prefix files are newer than last run. Exiting.")
        sys.exit(0)
    # Run /etc/dhcp6c-prefix-json
    try:
        debug(f"Running: {prefix_json_script}")
        subprocess.check_call([prefix_json_script])
    except subprocess.CalledProcessError as e:
        debug(f"{prefix_json_script} failed: {e}")
        sys.exit(1)
    # Run /tmp/dhcp6c-checkset-nptv6
    try:
        debug(f"Running: {checkset_script}")
        subprocess.check_call([checkset_script])
    except subprocess.CalledProcessError as e:
        debug(f"{checkset_script} failed: {e}")
        sys.exit(2)
    # Update last run time
    update_last_run_time()
    debug("Updated last run time.")

if __name__ == '__main__':
    main()
