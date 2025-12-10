# Rocframe

**R**ust handles low-level packet I/O, **OC**aml decodes **frame** and responds...

## FrameForge + EthProxy

This repository contains two components:

- **frameforge** — OCaml server (built with Dune)
- **ethproxy** — Rust client (built with Cargo)

Both are independent programs but live in the same project directory.

## Requirements

- Rust + Cargo
- OCaml + Dune

Install them through your system package manager or toolchain.

## Building

From the repository root:

- Build everything: `make`
- Build only the Rust client: `make ethproxy`
- Build only the OCaml server: `make frameforge`

## Running

The server and client run separately.

### Run the server
```sh
make run-server
```
- The server listens on: `/tmp/frameforge.sock`
- Press Ctrl-C to stop it cleanly.

### Run the client
```sh
make run-proxy
```
- This starts the Rust client that will setup the network and sends ethernet frame
  to server.
- Press Ctrl-C to stop it cleanly.

## Cleaning

### Clean both builds

```sh
make clean
```
