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
}
