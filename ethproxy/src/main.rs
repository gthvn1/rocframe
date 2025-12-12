use std::error::Error;
use std::io::{self, Read, Write};
use std::os::fd::AsFd;
use std::os::unix::net::UnixStream;
use std::sync::{Arc, atomic};

use nix::poll::{PollFd, PollFlags, PollTimeout, poll};

//use ethproxy::setup;

//static VETHNAME: &str = "veth0";
//static VETHIP: &str = "192.168.35.1/24";
const SERVER_PATH: &str = "/tmp/frameforge.sock";

enum PollAction {
    TimedOut,
    StdinReady,
    Interrupted,
    Ignore,
}

fn main() -> Result<(), Box<dyn Error>> {
    // Check https://doc.rust-lang.org/stable/std/os/unix/net/struct.UnixStream.html#method.pair
    //
    //let veth = setup::Veth::init(VETHNAME, VETHIP);
    //veth.create_device();
    //veth.destroy_device();
    let keep_looping = Arc::new(atomic::AtomicBool::new(true));

    // Set handler to set keep looping to false. We need to clone
    // it otherwise it is borrowed in the while loop. Shadow it in
    // its own context and pass ownership in the closure.
    {
        let keep_looping = keep_looping.clone();
        ctrlc::set_handler(move || {
            // Here ownership of keep_looping is taken
            keep_looping.store(false, atomic::Ordering::SeqCst);
        })
        .expect("Error setting Ctrl-C handler");
    }

    // We declare the fd here to live during the whole loop. It is a little
    // bit strange but I need to first declare the binding (io::stding() returns
    // a temporary), and then borrow it to stdin_fd. Then binding is dropped but
    // it is ok now to use stdin_fd. If we don't do that when using stdin_fd we
    // have an issue "temporary value dropped while borrowed".
    let binding = io::stdin();
    let stdin_fd = binding.as_fd();

    // Connect to server so we will be able to send data
    let mut frameforge_sock = UnixStream::connect(SERVER_PATH)?;

    println!("Ctrl-C to quit");

    print!("> ");
    io::stdout().flush()?;

    while keep_looping.load(atomic::Ordering::SeqCst) {
        // Currently we just have stdin but we will add the Veth socket
        // In the implementation of poll_once we are expecting stdin in
        // first place (and next Veth that is not yet available).
        let mut pollfds = [PollFd::new(stdin_fd, PollFlags::POLLIN)];

        match poll_once(&mut pollfds) {
            PollAction::Ignore | PollAction::TimedOut => continue,
            PollAction::StdinReady => {
                let mut input = String::new();
                io::stdin().read_line(&mut input)?;

                print!("Sending {input}");

                let response = send_message(&mut frameforge_sock, &input)?;
                print!("Received: {response}");

                print!("> ");
                io::stdout().flush()?;
            }
            PollAction::Interrupted => {
                // poll() returns EINTR for any signal, not just SIGINT so we need to check
                if keep_looping.load(atomic::Ordering::SeqCst) {
                    // It wasn't SIGINT (otherwise keep_looping is false) so keep looping
                    continue;
                }
                break;
            }
        }
    }

    println!("Bye!!!");
    Ok(())
}

fn poll_once(fds: &mut [PollFd]) -> PollAction {
    // Retry poll if interruped by signal EINTR. Without this we have:
    //  | thread 'main' (60079) panicked at src/main.rs:41:68:
    //  | called `Result::unwrap()` on an `Err` value: EINTR
    //  | note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
    match poll(fds, PollTimeout::from(100u16)) {
        Ok(0) => PollAction::TimedOut,
        Ok(_) => {
            if fds[0]
                .revents()
                .is_some_and(|f| f.contains(PollFlags::POLLIN))
            {
                PollAction::StdinReady
            } else {
                PollAction::Ignore
            }
        } // nothing to do, fds are checked right after the match
        Err(nix::errno::Errno::EINTR) => PollAction::Interrupted,
        Err(e) => panic!("poll failed: {}", e),
    }
}

fn send_message(sock: &mut UnixStream, msg: &str) -> io::Result<String> {
    // Sending to server. The protocol is to send the data size then the data
    let data = msg.as_bytes();
    let data_len = data.len() as u32;

    sock.write_all(&data_len.to_le_bytes())?;
    sock.write_all(data)?;
    sock.flush()?;

    // Read the 4 bytes lenght header
    let mut len_buf = [0u8; 4];
    sock.read_exact(&mut len_buf)?;
    let len = u32::from_le_bytes(len_buf) as usize;

    // Read the message
    let mut buf = vec![0u8; len];
    sock.read_exact(&mut buf)?;
    String::from_utf8(buf).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))
}
