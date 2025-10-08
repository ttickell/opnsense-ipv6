# OPNsense DHCPv6 Configuration Migration to Standards

## Overview

This document outlines the migration from improper use of `/var/etc/` (generated configuration directory) to proper persistent configuration locations in OPNsense. The current configuration works but is vulnerable to being overwritten during updates.

## Problem Analysis

### What Was Wrong

1. **Wrong Configuration Location**
   - **Problem:** Configuration placed in `/var/etc/dhcp6c.conf.custom`
   - **Issue:** `/var/etc/` is OPNsense's generated configuration directory - files get overwritten
   - **Evidence:** Configuration gets lost during template regeneration

2. **Scripts in Volatile Directory**
   - **Problem:** Scripts placed in `/var/etc/`:
     - `dhcp6c_wan_custom.sh`
     - `dhcp6c-prefix-json`
     - `dhcp6c-checkset-nptv6`
   - **Issue:** These get overwritten during OPNsense updates

3. **Configuration Complexity Fighting GUI**
   - **Problem:** Complex multi-PD configuration conflicts with OPNsense expectations
   - **Issue:** Template system doesn't expect custom DHCPv6 client configurations

## Solution: Proper OPNsense Integration

### File Location Changes

| Current (Wrong) | Correct (Persistent) | Purpose |
|-----------------|---------------------|---------|
| `/var/etc/dhcp6c.conf.custom` | `/usr/local/etc/dhcp6c.conf.custom` | Main configuration |
| `/var/etc/dhcp6c_wan_custom.sh` | `/usr/local/bin/dhcp6c_wan_custom.sh` | Hook script |
| `/var/etc/dhcp6c-prefix-json` | `/usr/local/bin/dhcp6c-prefix-json` | Prefix tracking |
| `/var/etc/dhcp6c-checkset-nptv6` | `/usr/local/bin/dhcp6c-checkset-nptv6` | NPTv6 management |
| N/A | `/usr/local/bin/igc0_dhcp6c.sh` | Interface-specific hook |
| N/A | `/usr/local/bin/igc1_dhcp6c.sh` | Interface-specific hook |

## Configuration File Changes

### Diff Analysis

```diff
--- /var/etc/dhcp6c.conf.custom
+++ /usr/local/etc/dhcp6c.conf.custom
@@ -6,7 +6,7 @@
   send ia-pd 0;
   send ia-pd 1;
   
-  script "/var/etc/igc1_dhcp6c.sh";
+  script "/usr/local/bin/igc1_dhcp6c.sh";
   request domain-name-servers;
   request domain-name;
 };
@@ -32,7 +32,7 @@
   send ia-pd 8; # request prefix delegation
   request domain-name-servers;
   request domain-name;
-  script "/var/etc/igc0_dhcp6c.sh";
+  script "/usr/local/bin/igc0_dhcp6c.sh";
 };
 id-assoc na 1 { };
 
@@ -51,7 +51,7 @@
   };
 };
 
-## Switch to ULA BLock 
+## Switch to ULA Block 
 id-assoc pd 4 { };
 id-assoc pd 5 { };
 id-assoc pd 6 { };
```

### Explanation of Changes

1. **File Location Change**
   - **Why:** `/usr/local/etc/` is persistent configuration directory
   - **Benefit:** Survives OPNsense updates and template regeneration

2. **Script Path Corrections**
   - **Why:** `/usr/local/bin/` is standard location for user scripts
   - **Benefit:** Scripts are in PATH and persistent across updates

3. **Minor Typo Fix**
   - **Why:** Improved readability and consistency

## Migration Steps

### Phase 1: Backup Current Configuration

```bash
# Create backup directory
mkdir -p /tmp/dhcp6c-migration-backup

# Backup current configuration
cp /var/etc/dhcp6c.conf.custom /tmp/dhcp6c-migration-backup/
cp /var/etc/dhcp6c_wan_custom.sh /tmp/dhcp6c-migration-backup/
cp /var/etc/dhcp6c-prefix-json /tmp/dhcp6c-migration-backup/
cp /var/etc/dhcp6c-checkset-nptv6 /tmp/dhcp6c-migration-backup/
cp /var/etc/checkset-nptv6.yml /tmp/dhcp6c-migration-backup/ 2>/dev/null || true

# Backup any existing JSON state
cp /var/db/dhcp6c-pds.json /tmp/dhcp6c-migration-backup/ 2>/dev/null || true

echo "Backup completed in /tmp/dhcp6c-migration-backup/"
```

### Phase 2: Create Persistent Configuration

```bash
# Create the corrected main configuration
cat > /usr/local/etc/dhcp6c.conf.custom << 'EOF'
## Comcast
interface igc1 {
  send rapid-commit;
  send ia-na 0;

  send ia-pd 0;
  send ia-pd 1;
  
  script "/usr/local/bin/igc1_dhcp6c.sh";
  request domain-name-servers;
  request domain-name;
};

id-assoc na 0 { };

id-assoc pd 0 { 
  prefix ::/60 21600 86400;
};

id-assoc pd 1 { 
  prefix ::/60 21600 86400;
};

## AT&T
interface igc0 {
  send rapid-commit;
  send ia-na 1; # request stateful address

  send ia-pd 2; # request prefix delegation
  send ia-pd 3; # request prefix delegation
  send ia-pd 4; # request prefix delegation
  send ia-pd 5; # request prefix delegation
  send ia-pd 6; # request prefix delegation
  send ia-pd 7; # request prefix delegation
  send ia-pd 8; # request prefix delegation
  request domain-name-servers;
  request domain-name;
  script "/usr/local/bin/igc0_dhcp6c.sh";
};
id-assoc na 1 { };

## LAN Interface
id-assoc pd 2 {
  prefix-interface igc2 {
    sla-id 0;
    sla-len 0;
  };
};

id-assoc pd 3 { 
  prefix-interface igc3 {
    sla-id 0;
    sla-len 0;
  };
};

## Switch to ULA Block 
id-assoc pd 4 { };
id-assoc pd 5 { };
id-assoc pd 6 { };
id-assoc pd 7 { };
id-assoc pd 8 { };
EOF

echo "Created /usr/local/etc/dhcp6c.conf.custom"
```

### Phase 3: Move Scripts to Persistent Locations

```bash
# Move main script to persistent location
cp /var/etc/dhcp6c_wan_custom.sh /usr/local/bin/
chmod +x /usr/local/bin/dhcp6c_wan_custom.sh

# Move supporting scripts
cp /var/etc/dhcp6c-prefix-json /usr/local/bin/
cp /var/etc/dhcp6c-checkset-nptv6 /usr/local/bin/
chmod +x /usr/local/bin/dhcp6c-prefix-json
chmod +x /usr/local/bin/dhcp6c-checkset-nptv6

# Move configuration files
cp /var/etc/checkset-nptv6.yml /usr/local/etc/ 2>/dev/null || true

echo "Moved scripts to /usr/local/bin/"
```

### Phase 4: Create Interface-Specific Hook Scripts

```bash
# Create igc0 hook script
cat > /usr/local/bin/igc0_dhcp6c.sh << 'EOF'
#!/bin/sh
export INTERFACE=igc0
exec /usr/local/bin/dhcp6c_wan_custom.sh "$@"
EOF
chmod +x /usr/local/bin/igc0_dhcp6c.sh

# Create igc1 hook script
cat > /usr/local/bin/igc1_dhcp6c.sh << 'EOF'
#!/bin/sh
export INTERFACE=igc1
exec /usr/local/bin/dhcp6c_wan_custom.sh "$@"
EOF
chmod +x /usr/local/bin/igc1_dhcp6c.sh

echo "Created interface-specific hook scripts"
```

### Phase 5: Update Script Paths

```bash
# Update any hardcoded paths in the main script
sed -i '' 's|/var/etc/|/usr/local/bin/|g' /usr/local/bin/dhcp6c_wan_custom.sh
sed -i '' 's|/var/etc/checkset-nptv6.yml|/usr/local/etc/checkset-nptv6.yml|g' /usr/local/bin/dhcp6c-checkset-nptv6

echo "Updated script paths"
```

### Phase 6: Configure OPNsense GUI

```bash
echo "=== MANUAL STEPS REQUIRED ==="
echo "1. Go to OPNsense Web GUI"
echo "2. Navigate to Interfaces → [WAN Interface 1] → DHCPv6 Client"
echo "3. Check 'Override the configuration for this interface'"
echo "4. Set 'Configuration File' to: /usr/local/etc/dhcp6c.conf.custom"
echo "5. Repeat for WAN Interface 2"
echo "6. Apply changes"
echo ""
echo "GUI configuration must be done manually - cannot be automated via CLI"
```

### Phase 7: Test and Validate

```bash
# Test configuration syntax
echo "Testing DHCPv6 configuration syntax..."
if dhcp6c -n -c /usr/local/etc/dhcp6c.conf.custom -D; then
    echo "✓ Configuration syntax is valid"
else
    echo "✗ Configuration syntax error - check /usr/local/etc/dhcp6c.conf.custom"
fi

# Verify script permissions
echo "Verifying script permissions..."
for script in igc0_dhcp6c.sh igc1_dhcp6c.sh dhcp6c_wan_custom.sh dhcp6c-prefix-json dhcp6c-checkset-nptv6; do
    if [ -x "/usr/local/bin/$script" ]; then
        echo "✓ $script is executable"
    else
        echo "✗ $script is not executable"
    fi
done

# Verify configuration file exists
if [ -f "/usr/local/etc/dhcp6c.conf.custom" ]; then
    echo "✓ Configuration file exists"
else
    echo "✗ Configuration file missing"
fi

echo ""
echo "Validation complete. Check for any ✗ errors above."
```

### Phase 8: Restart Services

```bash
echo "=== SERVICE RESTART REQUIRED ==="
echo "After completing GUI configuration, restart DHCPv6 client:"
echo ""
echo "Via GUI:"
echo "  Interfaces → Diagnostics → Restart → DHCPv6 Client"
echo ""
echo "Via CLI (if preferred):"
echo "  /usr/local/etc/rc.restart_interface_wan"
echo "  /usr/local/etc/rc.restart_interface_wan2"
```

## Benefits of Migration

### ✅ Persistence
- Configuration survives OPNsense updates
- Scripts won't be deleted during system maintenance
- No more fighting the template system

### ✅ Standards Compliance
- Follows FreeBSD filesystem hierarchy
- Uses standard locations for user customizations
- Integrates properly with OPNsense architecture

### ✅ Maintainability
- Clear separation between system and user configurations
- Easier to backup and version control
- Reduces risk of accidental overwrites

### ✅ OPNsense Integration
- Works with GUI override feature
- Respects OPNsense's configuration management
- Maintains web interface functionality

## Troubleshooting

### Common Issues

1. **Scripts not executing**
   - Check permissions: `ls -la /usr/local/bin/dhcp6c*`
   - Verify shebang lines in scripts
   - Check syslog for error messages

2. **Configuration not taking effect**
   - Verify GUI override is enabled
   - Check configuration file path in GUI
   - Restart DHCPv6 client service

3. **Missing interface-specific hooks**
   - Ensure igc0_dhcp6c.sh and igc1_dhcp6c.sh exist
   - Verify they're executable
   - Check they reference correct main script

### Rollback Procedure

If migration causes issues:

```bash
# Restore from backup
cp /tmp/dhcp6c-migration-backup/dhcp6c.conf.custom /var/etc/
cp /tmp/dhcp6c-migration-backup/dhcp6c_wan_custom.sh /var/etc/
# ... restore other files as needed

# Disable GUI override in web interface
# Restart DHCPv6 client
```

## Post-Migration Validation

After migration, verify:

1. **IPv6 addresses assigned to interfaces**
   ```bash
   ifconfig | grep inet6
   ```

2. **Prefix delegations active**
   ```bash
   cat /var/db/dhcp6c-pds.json | jq .
   ```

3. **NPTv6 rules updated**
   ```bash
   pfctl -s nat | grep inet6
   ```

4. **DHCPv6 client logs**
   ```bash
   tail -f /var/log/system.log | grep dhcp6c
   ```

## Maintenance Notes

- Configuration files in `/usr/local/etc/` should be backed up regularly
- Scripts in `/usr/local/bin/` should be included in configuration backups
- JSON state files in `/var/db/` contain runtime state and prefix history
- GUI override settings are stored in OPNsense configuration and included in config backups

---

*This migration preserves all functionality while moving to OPNsense-standard file locations for long-term maintainability.*