use std::process::Command;

pub struct Veth {
    name: String,
    peer: String,
    cidr: String,
}

/// Runs a command with the given arguments and checks its exit code.
///
/// # Parameters
/// - `cmd`: The command to run (e.g., `"ip"`).
/// - `args`: A slice of string slices representing the arguments (e.g., `["link", "show", "eth0"]`).
/// - `expected`: The expected exit code. If the actual exit code does not match,
///   the function will print `stdout` and `stderr` for debugging.
///
/// # Returns
/// - `Ok(())` if the command's exit code matches `expected`.
/// - `Err(String)` if:
///     - the command could not be executed,
///     - it returned a different exit code than expected,
///     - or there was no exit code (e.g., terminated by a signal).
///
/// # Panics
/// - This function itself does not panic. Panics occur only if the caller calls
///   `.unwrap()` or `.expect()` on the returned `Result`.
///
fn run_cmd(cmd: &str, args: &[&str], expected: i32) -> Result<(), String> {
    match Command::new(cmd).args(args).output() {
        Ok(output) => match output.status.code() {
            None => Err("Not having return code is not expected".to_string()),
            Some(exit_code) => {
                if exit_code != expected {
                    println!("Command `{cmd} {}` failed.", args.join(" "));
                    println!("stdout: {}", String::from_utf8_lossy(&output.stdout));
                    println!("stderr: {}", String::from_utf8_lossy(&output.stderr));
                    Err(format!("Expected {} got {}", expected, exit_code))
                } else {
                    Ok(())
                }
            }
        },
        Err(error) => Err(format!("Failed to run {cmd}: {error:?}")),
    }
}

impl Veth {
    pub fn init(name: &str, cidr: &str) -> Self {
        let peer = format!("{}-peer", name);
        Self {
            name: name.to_string(),
            peer,
            cidr: cidr.to_string(),
        }
    }

    pub fn create_device(&self) {
        // man 4 veth
        // We need to run: ip link add <name> type veth peer name <peer>
        // https://doc.rust-lang.org/std/process/struct.Command.html

        // list of commands: (expected exit code, description, args)
        #[rustfmt::skip]
        let commands = [
            (
                1, "Check if interface exists",
                vec!["link", "show", &self.name]),
            (
                0, "Create veth pair",
                vec!["link", "add", &self.name, "type", "veth", "peer", "name", &self.peer,]),
            (
                0, "Set IPv4 address",
                vec!["addr", "add", &self.cidr, "dev", &self.name]),
            (
                0, "Bring main link up",
                vec!["link", "set", &self.name, "up"]),
            (
                0, "Bring peer link up",
                vec!["link", "set", &self.peer, "up"]),
        ];

        for (expected, description, args) in commands {
            run_cmd("ip", &args, expected).unwrap_or_else(|e| panic!("{description}: {e}"))
        }
    }

    pub fn destroy_device(&self) {
        let _ = run_cmd("ip", &["link", "del", &self.name], 0);
    }
}
