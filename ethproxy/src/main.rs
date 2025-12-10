use ethproxy::setup;

static VETHNAME: &str = "veth0";

fn main() {
    let _veth = setup::Veth::init(VETHNAME);
}
