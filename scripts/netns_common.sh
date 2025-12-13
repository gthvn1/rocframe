#!/bin/sh
set -eu

#!/bin/sh
set -eu

netns_run() {
  NET_IFACE="$1"
  PEER_IFACE="$2"
  CIDR="$3"
  shift 3

  unshare -Urn sh -eu -c '
    NET_IFACE="$1"
    PEER_IFACE="$2"
    CIDR="$3"
    shift 3

    ip link add "$NET_IFACE" type veth peer name "$PEER_IFACE" 2>/dev/null || true
    ip link set "$NET_IFACE" up
    ip link set "$PEER_IFACE" up
    ip addr add "$CIDR" dev "$NET_IFACE" 2>/dev/null || true

    exec "$@"
  ' sh "$NET_IFACE" "$PEER_IFACE" "$CIDR" "$@"
}
