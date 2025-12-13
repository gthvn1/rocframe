#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: $0 NET_IFACE PEER_IFACE CIDR" >&2
  exit 1
fi

. ./netns_common.sh

netns_run "$1" "$2" "$3" sh
