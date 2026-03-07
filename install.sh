#!/bin/sh
##
## install.sh — install opnsense-ipv6 scripts to persistent OPNsense paths
##
## Run as root on the OPNsense node after cloning this repository.
## Idempotent: re-running overwrites with the current version.
##
## Usage:
##   cd /path/to/opnsense-ipv6
##   sh install.sh
##
## IMPORTANT: edit /usr/local/etc/checkset-nptv6.yml after install to add
## your site-specific API credentials and interface mappings before the
## NPTv6 reconciliation script will function.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

err() { echo "ERROR: $*" >&2; exit 1; }

## ── Preflight ──────────────────────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || err "Must run as root"
[ -d "${REPO_DIR}/usr/local/bin" ] || err "Run from the repository root"

echo "Installing from: ${REPO_DIR}"

## ── Config files ─────────────────────────────────────────────────────────────
install -d -m 755 /usr/local/etc

# dhcp6c per-interface override configs — always install (no secrets)
for cfg in dhcp6c_wan.conf.custom dhcp6c_wan2.conf.custom; do
    install -m 644 "${REPO_DIR}/usr/local/etc/${cfg}" "/usr/local/etc/${cfg}"
done

# checkset config — install the example if the live file doesn't exist yet;
# never overwrite a customized file
if [ ! -f /usr/local/etc/checkset-nptv6.yml ]; then
    install -m 640 "${REPO_DIR}/usr/local/etc/checkset-nptv6.yml.example" \
                   /usr/local/etc/checkset-nptv6.yml
    echo ""
    echo "===================================================================="
    echo "  ACTION REQUIRED: edit /usr/local/etc/checkset-nptv6.yml"
    echo "  Fill in api-base, api-key, api-secret, ipv6-ula, and lan-interfaces"
    echo "  before running dhcp6c-checkset-nptv6."
    echo "===================================================================="
    echo ""
else
    echo "INFO: /usr/local/etc/checkset-nptv6.yml already exists — not overwritten"
    install -m 640 "${REPO_DIR}/usr/local/etc/checkset-nptv6.yml.example" \
                   /usr/local/etc/checkset-nptv6.yml.example
fi

## ── Executable scripts ───────────────────────────────────────────────────────
install -d -m 755 /usr/local/bin

for script in dhcp6c_wan_custom.sh \
              dhcp6c_interface_wrapper.sh \
              dhcp6c-prefix-json \
              dhcp6c-checkset-nptv6 \
              dhcp6c-ula-mapping.py; do
    install -m 755 "${REPO_DIR}/usr/local/bin/${script}" "/usr/local/bin/${script}"
    echo "  installed /usr/local/bin/${script}"
done

## ── Verify python dependencies ───────────────────────────────────────────────
echo ""
echo "Verifying Python dependencies..."
MISS=0
for pkg in yaml requests; do
    if ! /usr/local/bin/python3 -c "import ${pkg}" 2>/dev/null; then
        echo "  MISSING: python3 package '${pkg}'"
        MISS=$((MISS+1))
    fi
done

if [ "${MISS}" -gt 0 ]; then
    echo ""
    echo "Install missing packages, for example:"
    echo "  pkg install py311-pyyaml py311-requests"
    echo "(adjust the py3XX version prefix to match your Python version)"
fi

echo ""
echo "Creating interface-specific dhcp6c hook scripts from GUI mappings..."
for gui_if in wan wan2; do
    real_if=$(/usr/local/bin/php -d display_errors=0 -r 'require_once("/usr/local/etc/inc/config.inc"); $all=config_read_array("interfaces"); $if=""; $target=$argv[1]; if (is_array($all)) { if ($target === "wan" && isset($all["wan"]["if"]) && $all["wan"]["if"] !== "") { $if=$all["wan"]["if"]; } if ($target === "wan2") { if (isset($all["wan2"]["if"]) && $all["wan2"]["if"] !== "") { $if=$all["wan2"]["if"]; } if ($if === "") { foreach ($all as $entry) { if (is_array($entry) && isset($entry["descr"]) && isset($entry["if"]) && $entry["if"] !== "" && strtoupper($entry["descr"]) === "WAN2") { $if=$entry["if"]; break; } } } } } if (is_string($if) && $if !== "") { echo $if; }' "${gui_if}" 2>/dev/null || true)
    case "${real_if}" in
        ''|*[!A-Za-z0-9_.:-]*)
            echo "  WARN: could not resolve valid real interface for ${gui_if}; create hook script manually if needed"
            continue
            ;;
    esac
    if [ -n "${real_if}" ]; then
        hook_path="/usr/local/bin/dhcp6c_${real_if}.sh"
        if [ -L "${hook_path}" ]; then
            rm -f "${hook_path}"
        fi
        cat > "${hook_path}" <<EOF
#!/bin/sh
export INTERFACE="${real_if}"
exec /usr/local/bin/dhcp6c_wan_custom.sh "\$@"
EOF
        chmod 755 "${hook_path}"
        echo "  ${gui_if} -> ${real_if} -> /usr/local/bin/dhcp6c_${real_if}.sh"
    else
        echo "  WARN: could not resolve real interface for ${gui_if}; create hook script manually if needed"
    fi
done

echo ""
echo "Installation complete."
echo ""
echo "===================================================================="
echo "POST-INSTALL SETUP REQUIRED (DO THIS BEFORE TESTING)"
echo "===================================================================="
echo "1) Edit runtime config file:"
echo "   /usr/local/etc/checkset-nptv6.yml"
echo "   - Set api-base, api-key, api-secret, ipv6-ula, lan-interfaces"
echo ""
echo "2) Configure DHCPv6 override files in OPNsense GUI:"
echo "   WAN  -> /usr/local/etc/dhcp6c_wan.conf.custom   (COMCAST/XFINITY role, ia-pd 0,1)"
echo "   WAN2 -> /usr/local/etc/dhcp6c_wan2.conf.custom  (AT&T role, ia-pd 2..8)"
echo "   - Swap assignments if your provider wiring is reversed"
echo ""
echo "3) (Optional troubleshooting) If prefix files are missing under /tmp,"
echo "   set Interfaces > Settings > IPv6 DHCP > Log level = Info"
echo ""
echo "4) If wrapper auto-detect failed above, create manual hook scripts (example):"
echo "   cat > /usr/local/bin/dhcp6c_vtnet0.sh <<'EOF'"
echo "   #!/bin/sh"
echo "   export INTERFACE=\"vtnet0\""
echo "   exec /usr/local/bin/dhcp6c_wan_custom.sh \"\$@\""
echo "   EOF"
echo "   chmod 755 /usr/local/bin/dhcp6c_vtnet0.sh"
echo "   cat > /usr/local/bin/dhcp6c_vtnet1.sh <<'EOF'"
echo "   #!/bin/sh"
echo "   export INTERFACE=\"vtnet1\""
echo "   exec /usr/local/bin/dhcp6c_wan_custom.sh \"\$@\""
echo "   EOF"
echo "   chmod 755 /usr/local/bin/dhcp6c_vtnet1.sh"
echo ""
echo "5) Verify setup:"
echo "   sh preflight-check.sh"
echo "===================================================================="
