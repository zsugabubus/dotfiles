#!/bin/sh

timespan=5

[[ -z "$1" ]] && {
    printf '%s\n' 'Error: no device specified'
    exit 1
}
[[ ! -d "/sys/class/net/$1" ]] && {
    printf '%s\n' "No such device: $1"
    exit 1
}

br1=$(</sys/class/net/"$1"/statistics/rx_bytes)
bt1=$(</sys/class/net/"$1"/statistics/tx_bytes)

sleep $timespan

br2=$(</sys/class/net/"$1"/statistics/rx_bytes)
bt2=$(</sys/class/net/"$1"/statistics/tx_bytes)

u_speed=$(( ( ( bt2 - bt1 ) / timespan ) / 1000 ))
d_speed=$(( ( ( br2 - br1 ) / timespan ) / 1000 ))

echo -n " ${d_speed}KB/s  ${u_speed}KB/s"
