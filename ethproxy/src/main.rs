use ethproxy::setup;

static VETHNAME: &str = "veth0";
static VETHIP: &str = "192.168.35.1/24";

fn main() {
    let veth = setup::Veth::init(VETHNAME, VETHIP);

    veth.create_device();

    veth.destroy_device();
}
