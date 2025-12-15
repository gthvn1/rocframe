# Rocframe

**R**ust handles low-level packet I/O, **OC**aml decodes **frame** and responds...

This project contains three components:

- **network script** - Shell script to create Veth pair and setup IP (Posix Shell)
- **frameforge** - OCaml server to decode frame and protocol logic (built with Dune)
- **ethproxy** - Rust or Zig proxy to forward data to server

We used Rust and Zig to compare how it feels to program in these two languages. We initially
planned to use C for packet handling, but we wanted to try some newer languages.

## Requirements

- Rust + Cargo and/or Zig 0.15
- OCaml + Dune
- [Just](https://github.com/casey/just)
- ip command (from iproute2)
- Linux environment with support for network namespaces (unshare)

Install them via your system package manager or preferred toolchain.

## Building

From the repository root, using Just:
- Build everything: `just build`
- Build only the Rust client (ethproxy): `just build-rust-proxy`
- Build only the Zig client (ethproxy): `just build-zig-proxy`
- Build only the OCaml server (frameforge): `just build-server`

The Justfile uses directory switching internally to build in the correct directories.

## Cleaning

From the repository root: `just clean`

## Setting up the network

The project uses a veth pair inside a network namespace for testing.
Use the **netns-shell** recipe to create the namespace and start an interactive shell inside it: `just netns-shell`

- This will create a veth pair:
  - net interface (default: veth0)
  - peer interface (default: veth0-peer)
- Assigns a CIDR address to the interface (default: 192.168.35.2/24)
- Cleans up automatically when the shell exits
- Use a terminal multiplexer (tmux, screen, etc.) for running multiple commands inside the namespace

All commands run inside this shell inherit the network namespace.

## Running

After `just netns-shell`, you can start the server and proxy in separate terminal panes or shells.

- Start the server: `just server`
  - The OCaml server listens on a Unix socket (default: /tmp/frameforge.sock)
  - Receives Ethernet frames and responds
  - Press Ctrl-C to stop it cleanly

- Start the proxy: `just rust-proxy` or `just zig-proxy`, both are working.
  - The client connects to the veth interface and sends Ethernet frames to the server
  - Also listens for user input
  - Press Ctrl-C to stop it cleanly

Ensure the proxy and server are run inside the namespace shell created by `netns-shell`.

You can also, it you have **tmux** run everything with one command: `just netns-tmux`

## Justfile Recipes Summary

```sh
❯ just
Available recipes:
    build            # Build the proxy and the server
    build-rust-proxy # Build the rust proxy
    build-server     # Build the server
    build-zig-proxy  # Build Zig version of proxy
    clean            # Clean the build of proxy and server
    default          # List recipes
    netns-shell      # Set up Veth pair and start a shell.
    netns-tmux       # Run the whole workflow in tmux
    rust-proxy       # Start the proxy. Must be run in a shell started with setup-net
    server           # Start server. Must be run in a shell started using setup-net
    zig-proxy        # Start Zig proxy
```

The server and client run separately.

## Notes

- All network testing happens inside the namespace; no root privileges are required outside the namespace creation.
- You can change the interface names, CIDR, or socket by editing the Justfile variables:

```
net_iface := "veth0"
peer_iface := net_iface + "-peer"
cidr := "192.168.35.2/24"
socket := "/tmp/frameforge.sock"
```

- Use a terminal multiplexer to run server and proxy simultaneously for testing.

## Debug tips

- We can inspect exchange between the client and the serve using sockat:
  - Start the server
  - Modified the client to connect to /tmp/frameforge-proxy.socket
  - Create a proxy with socat
```sh
socat -v UNIX-LISTEN:/tmp/frameforge-proxy.sock,fork \
         UNIX-CONNECT:/tmp/frameforge.sock \
  | tee /tmp/frameforge.log
```
  - We are able to see messages that are exchanged
  - We will able to see the issue where data size is too big on the ethproxy
    side.

## Screenshot

<img src="https://github.com/gthvn1/rocframe/blob/master/screenshot.png">
