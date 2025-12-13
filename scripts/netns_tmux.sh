#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
  echo "usage: $0 NET_IFACE PEER_IFACE CIDR SOCKET" >&2
  exit 1
fi

. ./netns_common.sh

NET_IFACE="$1"
PEER_IFACE="$2"
CIDR="$3"
SOCKET="$4"

netns_run "$NET_IFACE" "$PEER_IFACE" "$CIDR" sh -eu -c '
  tmux new-session -d -s rocframe-session

  tmux send-keys "just server" C-m
  tmux split-window -h
  tmux send-keys "while [ ! -S '"$SOCKET"' ]; do sleep 0.1; done; just proxy" C-m

  tmux attach -t rocframe-session
'
