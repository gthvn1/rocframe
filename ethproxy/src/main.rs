use std::io::{self, Write};
use std::os::fd::AsFd;
use std::sync::{Arc, atomic};

use nix::poll::{PollFd, PollFlags, PollTimeout, poll};
//use ethproxy::setup;

//static VETHNAME: &str = "veth0";
//static VETHIP: &str = "192.168.35.1/24";

fn main() {
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

    // We declare the fd here to live during the whole loop
    let binding = io::stdin();
    let stdin_fd = binding.as_fd();

    println!("Ctrl-C to quit");

    print!("> ");
    io::stdout().flush().unwrap();

    'outer: while keep_looping.load(atomic::Ordering::SeqCst) {
        // Currently we just have stdin but we will add the Veth socket
        let mut pollfds = [PollFd::new(stdin_fd, PollFlags::POLLIN)];

        // Retry poll if interruped by signal EINTR. Without this we have:
        //  | thread 'main' (60079) panicked at src/main.rs:41:68:
        //  | called `Result::unwrap()` on an `Err` value: EINTR
        //  | note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
        loop {
            match poll(&mut pollfds, PollTimeout::from(100u16)) {
                Ok(0) => continue 'outer, // We could also break because we test what happens later
                Ok(_) => break,
                Err(nix::errno::Errno::EINTR) => {
                    // poll() returns EINTR for any signal, not just SIGINT so we need to check
                    if !keep_looping.load(atomic::Ordering::SeqCst) {
                        break 'outer;
                    }
                    continue 'outer;
                }
                // and we will quit
                Err(e) => panic!("poll failed: {}", e),
            }
        }

        if pollfds[0]
            .revents()
            .is_some_and(|f| f.contains(PollFlags::POLLIN))
        {
            let mut input = String::new();
            io::stdin()
                .read_line(&mut input)
                .expect("Failed to read line");

            print!("your input is {input}");
            print!("> ");
            io::stdout().flush().unwrap();
        }
    }

    println!("Bye!!!");
}
