# dhcp6c-prefix-json: Recording IPv6 Prefix Delegations with Historical Data

This script provides a robust, context-free record of what IPv6 prefix delegations (PDs) `dhcp6c` received and how they were assigned to interfaces. It merges data from the `dhcp6c` configuration and the current prefix assignment files into a single JSON output, showing the prefix delegation IDs, interface assignments, and prefix sizes. **The script now preserves historical prefix data to prevent loss when `/tmp/` prefix files are removed.**

## How It Works
- **No log parsing required:** The script does not rely on log files or log parsing.
- **No iscpy dependency:** The script does not use the `iscpy` module or any external parser. All configuration parsing is done with a custom, robust regex-based parser.
- **Historical data preservation:** The script loads existing JSON data from previous runs and merges it with new data, ensuring prefix history is never lost even if `/tmp/` files disappear.
- **Direct config and prefix file parsing:**
  - The script reads the `dhcp6c.conf` configuration file directly, extracting all `send ia-pd` lines from all interface blocks, handling multiple/duplicate blocks and comments.
  - For each interface, it reads the corresponding prefix assignment file (e.g., `/tmp/<interface>_prefixv6`) to determine the actual delegated prefix.
  - If prefix files are missing, existing data is preserved and marked with a status indicator.
- **Output:**
  - The script generates a file `/var/db/dhcp6c-pd.json` containing all discovered PDs, their assignments, prefix sizes, status information, and historical data in JSON format.

## Usage
1. **Adjust paths** in the script as needed to point to your `dhcp6c.conf`, the prefix assignment files, and the output location for the JSON file.
2. **No special logging or Python modules are required.** The script is self-contained and does not require `iscpy` or log file access.
3. **Run the script** as needed (for example, from a hook called by `dhcp6c` on changes).

## Example Output
The output JSON will look like:

```json
{
  "summary": {
    "total_pds": 2,
    "active_pds": 1,
    "missing_prefix_files": 1,
    "last_run": "2025-08-29T10:30:00.123456"
  },
  "prefix_delegations": {
    "pd_id": {
      "prefix": "<current_prefix>",
      "interface": "<interface>",
      "allocations": false,
      "interfaces": {},
      "status": "active",
      "created": "2025-08-29T09:00:00.000000",
      "last_updated": "2025-08-29T10:30:00.123456",
      "prefix_history": [
        {
          "prefix": "<previous_prefix>",
          "timestamp": "2025-08-29T09:00:00.000000"
        }
      ]
    },
    "another_pd_id": {
      "prefix": "<delegated_prefix>",
      "interface": "<interface>",
      "allocations": false,
      "interfaces": {},
      "status": "prefix_file_missing",
      "created": "2025-08-28T15:00:00.000000",
      "last_seen": "2025-08-29T10:30:00.123456"
    }
  }
}
```

## Key Features
- **Status tracking:** Each PD entry includes a status field indicating whether it's "active" or "prefix_file_missing"
- **Timestamp tracking:** Creation time, last update time, and last seen time are recorded
- **Prefix history:** When a prefix changes, the previous prefix is stored in a history array
- **Summary information:** The output includes a summary with counts of total, active, and missing PDs
- **Data persistence:** Existing data is always preserved, even when source files are unavailable

## Notes
- The script is robust to config structure, comments, and multiple interface blocks.
- Historical data is preserved across runs, ensuring no prefix information is lost.
- The script handles both the old JSON format (direct PD data) and the new format (with summary) for backwards compatibility.
- When prefix files are missing, existing entries are marked as "prefix_file_missing" but retained.
- Any further subdivision or persistent record of prefix usage is out of scope for this script.

---

*This documentation reflects the current implementation with historical data preservation as of August 2025.*
