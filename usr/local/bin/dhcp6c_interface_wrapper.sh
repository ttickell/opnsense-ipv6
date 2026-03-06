#!/bin/sh
##
## dhcp6c_interface_wrapper.sh — runtime wrapper for dhcp6c hooks
##
## Installed as a symlink per real interface name, for example:
##   /usr/local/bin/dhcp6c_vtnet0.sh -> /usr/local/bin/dhcp6c_interface_wrapper.sh
##   /usr/local/bin/dhcp6c_vtnet1.sh -> /usr/local/bin/dhcp6c_interface_wrapper.sh
##
## The interface is derived from the symlink basename and exported as INTERFACE
## for dhcp6c_wan_custom.sh.

script_name="$(basename "$0")"
iface="${script_name#dhcp6c_}"
iface="${iface%.sh}"

if [ -z "$iface" ] || [ "$iface" = "$script_name" ]; then
    /usr/bin/logger -p daemon.err -t dhcp6c-if-wrapper -- \
        "Could not infer interface from script name: $script_name"
    exit 1
fi

export INTERFACE="$iface"
exec /usr/local/bin/dhcp6c_wan_custom.sh "$@"
