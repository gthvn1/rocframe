use std::io::{self, Write};
use std::sync::{Arc, atomic};

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

    let mut input = String::new();

    println!("Ctrl-C to quit");
    while keep_looping.load(atomic::Ordering::SeqCst) {
        print!("> ");
        io::stdout().flush().unwrap();
        io::stdin()
            .read_line(&mut input)
            .expect("Failed to read line");

        print!("your input is {input}");
    }

    println!("Bye!!!");
}
