# dhcp6c-prefix-json: Recording IPv6 Prefix Delegations

This script provides a robust, context-free record of what IPv6 prefix delegations (PDs) `dhcp6c` received and how they were assigned to interfaces. It merges data from the `dhcp6c` configuration and the current prefix assignment files into a single JSON output, showing the prefix delegation IDs, interface assignments, and prefix sizes.

## How It Works
- **No log parsing required:** The script does not rely on log files or log parsing.
- **No iscpy dependency:** The script does not use the `iscpy` module or any external parser. All configuration parsing is done with a custom, robust regex-based parser.
- **Direct config and prefix file parsing:**
  - The script reads the `dhcp6c.conf` configuration file directly, extracting all `send ia-pd` lines from all interface blocks, handling multiple/duplicate blocks and comments.
  - For each interface, it reads the corresponding prefix assignment file (e.g., `/tmp/<interface>_prefixv6`) to determine the actual delegated prefix.
- **Output:**
  - The script generates a file `/var/db/dhcp6c-pd.json` containing all discovered PDs, their assignments, and prefix sizes in JSON format.

## Usage
1. **Adjust paths** in the script as needed to point to your `dhcp6c.conf`, the prefix assignment files, and the output location for the JSON file.
2. **No special logging or Python modules are required.** The script is self-contained and does not require `iscpy` or log file access.
3. **Run the script** as needed (for example, from a hook called by `dhcp6c` on changes).

## Example Output
The output JSON will look like:

```json
{
  "pd_id": {
    "interface": "<interface>",
    "prefix": "<delegated_prefix>",
    "prefix_length": <length>
  },
  ...
}
```

## Notes
- The script is robust to config structure, comments, and multiple interface blocks.
- Any further subdivision or persistent record of prefix usage is out of scope for this script.

---

*This documentation reflects the current, log-free, iscpy-free, direct parsing approach as of July 2025.*
