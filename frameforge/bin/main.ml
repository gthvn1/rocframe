let () =
  let arg = Args.parse () in
  Frameforge.Server.run ~socket_path:arg.socket_path ~veth_name:arg.veth_name
    ~veth_mac:arg.veth_mac
