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
echo "Creating interface-specific dhcp6c wrapper symlinks from GUI mappings..."
for gui_if in wan wan2; do
    real_if=$(/usr/local/bin/php -d display_errors=0 -r 'require_once("/etc/inc/config.inc"); require_once("/etc/inc/interfaces.inc"); $if=get_real_interface($argv[1], "inet6"); if (is_string($if) && $if !== "") { echo $if; }' "${gui_if}" 2>/dev/null || true)
    case "${real_if}" in
        ''|*[!A-Za-z0-9_.:-]*)
            echo "  WARN: could not resolve valid real interface for ${gui_if}; create wrapper symlink manually if needed"
            continue
            ;;
    esac
    if [ -n "${real_if}" ]; then
        ln -sf /usr/local/bin/dhcp6c_interface_wrapper.sh "/usr/local/bin/dhcp6c_${real_if}.sh"
        echo "  ${gui_if} -> ${real_if} -> /usr/local/bin/dhcp6c_${real_if}.sh"
    else
        echo "  WARN: could not resolve real interface for ${gui_if}; create wrapper symlink manually if needed"
    fi
done

echo ""
echo "Installation complete."
echo "Configure WAN overrides in GUI:"
echo "  /usr/local/etc/dhcp6c_wan.conf.custom   = COMCAST/XFINITY role (ia-pd 0,1)"
echo "  /usr/local/etc/dhcp6c_wan2.conf.custom  = AT&T role (ia-pd 2..8)"
echo "Assign to WAN/WAN2 based on your provider mapping (swap if providers are wired opposite)."
echo "OPNsense substitutes {interface} at startup and merges per-interface configs into /var/etc/dhcp6c.conf."
echo "If wrapper auto-detect fails, manually create symlinks (example):"
echo "  ln -sf /usr/local/bin/dhcp6c_interface_wrapper.sh /usr/local/bin/dhcp6c_vtnet0.sh"
echo "  ln -sf /usr/local/bin/dhcp6c_interface_wrapper.sh /usr/local/bin/dhcp6c_vtnet1.sh"
echo "Run 'sh preflight-check.sh' to verify the full environment."
