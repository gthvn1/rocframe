net_iface := "veth0"
peer_iface := net_iface + "-peer"
cidr := "192.168.35.2/24"
socket := "/tmp/frameforge.sock"

# List recipes
default:
    just --list

# Build the proxy
[working-directory: 'ethproxy']
build-proxy:
    @echo 'Building proxy...'
    cargo build

# Build the server
[working-directory: 'frameforge']
build-server:
    @echo 'Building server...'
    dune build

# Build the proxy and the server
build: build-proxy build-server

# Clean the build of proxy and server
clean:
    @echo 'Cleaning proxy'
    cd ethproxy && cargo clean
    @echo 'Cleaning server'
    cd frameforge && dune clean

# Set up Veth pair and start a shell.
setup-network:
    @echo 'Setting network using {{net_iface}} {{peer_iface}} {{cidr}}'
    @echo 'Use a terminal mux to run proxy and server in this env'
    ./scripts/netns.sh {{net_iface}} {{peer_iface}} {{cidr}}
    @echo 'Cleanup env'

# Start the proxy. Must be run in a shell started with setup-net
proxy:
    # Because we quit using ctrl-c, we prefix the rule with "-"
    # to ignore exit codes. Otherwise, Just reports an error when
    # ctrl-c is received.
    -sh -c 'exec ./ethproxy/target/debug/ethproxy {{peer_iface}} {{socket}}'

# Start server. Must be run in a shell started using setup-net
server:
    -sh -c 'exec ./frameforge/_build/default/bin/main.exe `ip -j a` {{socket}}'
