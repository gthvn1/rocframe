use std::process::Command;

pub struct Veth {
    name: String,
    peer: String,
}

impl Veth {
    pub fn init(name: &str) -> Self {
        let peer = format!("{}-peer", name);
        Self {
            name: name.to_string(),
            peer,
        }
    }

    pub fn create_device(&self) {
        // man 4 veth
        // We need to run: ip link add <name> type veth peer name <peer>
        // https://doc.rust-lang.org/std/process/struct.Command.html

        // ----- First check that it doesn't already exist
        let ip_args = ["link", "show", &self.name];
        match Command::new("ip").args(ip_args).output() {
            Ok(output) => {
                // We are expecting that device doesn't exist
                // Panic if it exists to avoid using the wrong one
                if output.status.success() {
                    panic!("{} already exist", &self.name);
                }
                // For debugging print output
                println!("stdout: {:?}", String::from_utf8(output.stdout).unwrap());
                println!("stderr: {:?}", String::from_utf8(output.stderr).unwrap());
            }
            Err(error) => panic!("Failed to run ip link show {}: {error:?}", &self.name),
        };

        // ----- Create the Veth pair, set IP and set them UP
        println!(
            "TODO: create veth {} and its peer {}",
            &self.name, &self.peer
        );
    }
}
