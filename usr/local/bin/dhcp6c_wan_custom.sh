#!/bin/sh
##
## dhcp6c_wan_custom.sh — dhcp6c exit hook
##
## Called by interface-specific wrapper scripts (dhcp6c_<if>.sh symlinks)
## which set INTERFACE before calling this script.  A fallback case block is
## retained in case the script is invoked directly (e.g., for testing).
##
## Install to: /usr/local/bin/dhcp6c_wan_custom.sh
## Permissions: chmod 755

TAG="dhcp6c-wan-hook"
PREFIX_JSON_SCRIPT="/usr/local/bin/dhcp6c-prefix-json"
CHECKSET_NPTV6_SCRIPT="/usr/local/bin/dhcp6c-checkset-nptv6"

log_info() {
    /usr/bin/logger -t "${TAG}" -- "$*"
}
log_err() {
    /usr/bin/logger -p daemon.err -t "${TAG}" -- "$*"
}

## Determine interface from wrapper-set env var, or fall back to $0
if [ -z "$INTERFACE" ]; then
    case $0 in
        /usr/local/bin/dhcp6c_*.sh)
            script_name="$(basename "$0")"
            export INTERFACE="${script_name#dhcp6c_}"
            export INTERFACE="${INTERFACE%.sh}"
            ;;
    esac
fi

if [ -z "$INTERFACE" ]; then
    log_err "INTERFACE is unset and could not be inferred from \$0=$0 — aborting"
    exit 1
fi

log_info "INTERFACE=${INTERFACE} REASON=${REASON}"

run_prefix_nptv6_sync() {
    if [ -x "${PREFIX_JSON_SCRIPT}" ]; then
        if ! "${PREFIX_JSON_SCRIPT}" >/dev/null 2>&1; then
            log_err "prefix-json update failed"
            return 1
        fi
    else
        log_err "Missing script: ${PREFIX_JSON_SCRIPT}"
        return 1
    fi

    if [ -x "${CHECKSET_NPTV6_SCRIPT}" ]; then
        if ! "${CHECKSET_NPTV6_SCRIPT}" >/dev/null 2>&1; then
            log_err "checkset-nptv6 failed"
            return 1
        fi
    else
        log_info "checkset script not present: ${CHECKSET_NPTV6_SCRIPT}"
    fi

    return 0
}

case $REASON in
SOLICIT|INFOREQ|REBIND|RENEW|REQUEST)
    log_info "${REASON} on ${INTERFACE}: updating resolvers and triggering newipv6"

    ARGS=
    for NAMESERVER in ${new_domain_name_servers}; do
        ARGS="${ARGS} -a ${NAMESERVER}"
    done
    /usr/local/sbin/ifctl -i "${INTERFACE}" -6nd ${ARGS}

    ARGS=
    for DOMAIN in ${new_domain_name}; do
        ARGS="${ARGS} -a ${DOMAIN}"
    done
    /usr/local/sbin/ifctl -i "${INTERFACE}" -6sd ${ARGS}

    ARGS=
    for PD in ${PDINFO}; do
        ARGS="${ARGS} -a ${PD}"
    done
    if [ "${REASON}" != "RENEW" ] && [ "${REASON}" != "REBIND" ]; then
        ## Skip PDINFO update on RENEW/REBIND — dhcp6c delivers PDs one at a
        ## time in those cases and the list may be incomplete.
        /usr/local/sbin/ifctl -i "${INTERFACE}" -6pd ${ARGS}
    fi

    FORCE=
    if [ "${REASON}" = "REQUEST" ]; then
        log_info "${REASON} on ${INTERFACE}: forcing renewal"
        FORCE=force
    fi

    /usr/local/sbin/configctl -d interface newipv6 "${INTERFACE}" ${FORCE}

    run_prefix_nptv6_sync || true
    ;;
EXIT|RELEASE)
    log_info "${REASON} on ${INTERFACE}: clearing resolvers and triggering newipv6"

    /usr/local/sbin/ifctl -i "${INTERFACE}" -6nd
    /usr/local/sbin/ifctl -i "${INTERFACE}" -6sd
    /usr/local/sbin/ifctl -i "${INTERFACE}" -6pd

    /usr/local/sbin/configctl -d interface newipv6 "${INTERFACE}"

    if [ -x "${PREFIX_JSON_SCRIPT}" ]; then
        "${PREFIX_JSON_SCRIPT}" >/dev/null 2>&1 || \
            log_err "prefix-json update failed after ${REASON}"
    fi
    ;;
*)
    log_info "${REASON} on ${INTERFACE}: no action taken (ignored reason)"
    ;;
esac
