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

def get_last_run_time():
    if state_file.exists():
        return state_file.stat().st_mtime
    return 0

def update_last_run_time():
    state_file.touch()

def main():
    last_run = get_last_run_time()
    files_to_check = [f for f in prefix_files if f.exists()]
    if not files_to_check:
        sys.exit(0)  # Nothing to do
    # Check if any file is newer than last run
    if not any(f.stat().st_mtime > last_run for f in files_to_check):
        sys.exit(0)
    # Run /etc/dhcp6c-prefix-json
    try:
        subprocess.check_call([prefix_json_script])
    except subprocess.CalledProcessError:
        sys.exit(1)
    # Run /tmp/dhcp6c-checkset-nptv6
    try:
        subprocess.check_call([checkset_script])
    except subprocess.CalledProcessError:
        sys.exit(2)
    # Update last run time
    update_last_run_time()

if __name__ == '__main__':
    main()
