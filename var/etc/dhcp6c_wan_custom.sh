#!/bin/sh

if [ -z "$INTERFACE" ]; then
    /usr/bin/logger -t dhcp6c "dhcp6c_script: INTERFACE is null: EXIT"
    exit 1
fi

case $REASON in
SOLICIT|INFOREQ|REBIND|RENEW|REQUEST)
    /usr/bin/logger -t dhcp6c "dhcp6c_script: $REASON on ${INTERFACE} executing"

    ARGS=
    for NAMESERVER in ${new_domain_name_servers}; do
        ARGS="${ARGS} -a ${NAMESERVER}"
    done
    /usr/local/sbin/ifctl -i ${INTERFACE} -6nd ${ARGS}

    ARGS=
    for DOMAIN in ${new_domain_name}; do
        ARGS="${ARGS} -a ${DOMAIN}"
    done
    /usr/local/sbin/ifctl -i ${INTERFACE} -6sd ${ARGS}

    ARGS=
    for PD in ${PDINFO}; do
        ARGS="${ARGS} -a ${PD}"
    done
    if [ ${REASON} != "RENEW" -a ${REASON} != "REBIND" ]; then
        # cannot update since PDINFO may be incomplete in these cases
        # as each PD is being handled separately via the client side
        /usr/local/sbin/ifctl -i ${INTERFACE} -6pd ${ARGS}
    fi

    FORCE=
    if [ ${REASON} = "REQUEST" ]; then
        /usr/bin/logger -t dhcp6c "dhcp6c_script: $REASON on ${INTERFACE} renewal"
        FORCE=force
    fi

    /usr/local/sbin/configctl -d interface newipv6 ${INTERFACE} ${FORCE}
    ;;
EXIT|RELEASE)
    /usr/bin/logger -t dhcp6c "dhcp6c_script: $REASON on ${INTERFACE} executing"

    /usr/local/sbin/ifctl -i ${INTERFACE} -6nd
    /usr/local/sbin/ifctl -i ${INTERFACE} -6sd
    /usr/local/sbin/ifctl -i ${INTERFACE} -6pd

    /usr/local/sbin/configctl -d interface newipv6 ${INTERFACE}
    ;;
*)
    /usr/bin/logger -t dhcp6c "dhcp6c_script: $REASON on ${INTERFACE} ignored"
    ;;
esac
