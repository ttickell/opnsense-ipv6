#!/bin/sh
##
## preflight-check.sh — pre-install dependency and environment check
##
## Run this on the OPNsense node before installing to verify that all required
## software and configuration prerequisites are met.
##
## Usage: sh preflight-check.sh
##

PASS=0
FAIL=0
WARN=0

ok()   { echo "[  OK  ] $*"; PASS=$((PASS+1)); }
fail() { echo "[ FAIL ] $*"; FAIL=$((FAIL+1)); }
warn() { echo "[ WARN ] $*"; WARN=$((WARN+1)); }

## ── Python 3 ─────────────────────────────────────────────────────────────────
if /usr/local/bin/python3 -c "import sys; sys.exit(0)" 2>/dev/null; then
    PY_VER=$(/usr/local/bin/python3 -c "import sys; print('%d.%d' % sys.version_info[:2])")
    ok "python3 present (${PY_VER})"
else
    fail "python3 not found at /usr/local/bin/python3 — install from Firmware → Packages"
fi

## ── Python packages ──────────────────────────────────────────────────────────
for pkg in yaml requests; do
    if /usr/local/bin/python3 -c "import ${pkg}" 2>/dev/null; then
        ok "python3 package '${pkg}' importable"
    else
        case "${pkg}" in
            yaml)     hint="pkg install py311-pyyaml" ;;
            requests) hint="pkg install py311-requests" ;;
            *)        hint="pkg install py311-${pkg}" ;;
        esac
        fail "python3 package '${pkg}' missing — install: ${hint}"
    fi
done

## ── OPNsense tools ───────────────────────────────────────────────────────────
for tool in /usr/local/sbin/configctl /usr/local/sbin/ifctl; do
    if [ -x "${tool}" ]; then
        ok "${tool} present"
    else
        fail "${tool} not found — is this OPNsense?"
    fi
done

## ── Runtime directories and paths ────────────────────────────────────────────
for dir in /usr/local/bin /usr/local/etc /var/db; do
    if [ -d "${dir}" ]; then
        ok "directory ${dir} exists"
    else
        fail "directory ${dir} missing"
    fi
done

## ── Configuration file ───────────────────────────────────────────────────────
if [ -f /usr/local/etc/checkset-nptv6.yml ]; then
    # Quick placeholder check
    if grep -q "YOUR-OPNSENSE-HOST\|YOUR-API-KEY\|fdXX" /usr/local/etc/checkset-nptv6.yml 2>/dev/null; then
        fail "/usr/local/etc/checkset-nptv6.yml still contains placeholder values — edit it"
    else
        ok "/usr/local/etc/checkset-nptv6.yml present and appears customized"
    fi
else
    warn "/usr/local/etc/checkset-nptv6.yml not found — copy from .example and fill in values"
fi

## ── dhcp6c per-interface config overrides ────────────────────────────────────
for cfg in /usr/local/etc/dhcp6c_wan.conf.custom /usr/local/etc/dhcp6c_wan2.conf.custom; do
    if [ -f "${cfg}" ]; then
        ok "${cfg} present"
    else
        warn "${cfg} not found — copy from this repo's usr/local/etc/"
    fi
done

## ── Script executability ─────────────────────────────────────────────────────
for script in dhcp6c_wan_custom.sh dhcp6c_interface_wrapper.sh \
              dhcp6c-prefix-json dhcp6c-checkset-nptv6 dhcp6c-ula-mapping.py; do
    if [ -x "/usr/local/bin/${script}" ]; then
        ok "/usr/local/bin/${script} executable"
    else
        warn "/usr/local/bin/${script} not found or not executable — install from this repo's usr/local/bin/"
    fi
done

## ── dhcp6c real-interface wrapper links ─────────────────────────────────────
for gui_if in wan wan2; do
    real_if=$(/usr/local/bin/php -d display_errors=0 -r 'require_once("/etc/inc/config.inc"); require_once("/etc/inc/interfaces.inc"); $if=get_real_interface($argv[1], "inet6"); if (is_string($if) && $if !== "") { echo $if; }' "${gui_if}" 2>/dev/null || true)
    case "${real_if}" in
        ''|*[!A-Za-z0-9_.:-]*)
            warn "Could not resolve valid real interface for ${gui_if}"
            continue
            ;;
    esac
    if [ -n "${real_if}" ]; then
        link_path="/usr/local/bin/dhcp6c_${real_if}.sh"
        if [ -L "${link_path}" ] || [ -x "${link_path}" ]; then
            ok "${gui_if} wrapper present (${link_path})"
        else
            warn "${gui_if} wrapper missing (${link_path}) — rerun install.sh"
        fi
    else
        warn "Could not resolve real interface for ${gui_if}"
    fi
done

## ── OPNsense: dhcp6c -d flag ─────────────────────────────────────────────────
warn "MANUAL CHECK REQUIRED: Verify 'Interfaces → Settings → IPv6 DHCP → Log level' is set to 'Info'"
warn "  (This enables the -d flag so dhcp6c writes per-interface prefix files.)"
warn "MANUAL CHECK REQUIRED: Set WAN override -> /usr/local/etc/dhcp6c_wan.conf.custom"
warn "MANUAL CHECK REQUIRED: Set WAN2 override -> /usr/local/etc/dhcp6c_wan2.conf.custom"

## ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "Preflight: ${PASS} passed, ${WARN} warnings, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
    echo "Fix FAIL items before proceeding."
    exit 1
elif [ "${WARN}" -gt 0 ]; then
    echo "Review WARN items before proceeding."
    exit 0
else
    echo "All checks passed."
    exit 0
fi
