let ip_json_str =
  {|
[{"ifindex":1,"ifname":"lo","flags":["LOOPBACK"],"mtu":65536,"qdisc":"noop","operstate":"DOWN","group":"default","txqlen":1000,"link_type":"loopback","address":"00:00:00:00:00:00","broadcast":"00:00:00:00:00:00","addr_info":[]},{"ifindex":2,"link":"veth0","ifname":"veth0-peer","flags":["BROADCAST","MULTICAST","UP","LOWER_UP"],"mtu":1500,"qdisc":"noqueue","operstate":"UP","group":"default","txqlen":1000,"link_type":"ether","address":"3a:b4:51:1e:6b:79","broadcast":"ff:ff:ff:ff:ff:ff","addr_info":[{"family":"inet6","local":"fe80::38b4:51ff:fe1e:6b79","prefixlen":64,"scope":"link","protocol":"kernel_ll","valid_life_time":4294967295,"preferred_life_time":4294967295}]},{"ifindex":3,"link":"veth0-peer","ifname":"veth0","flags":["BROADCAST","MULTICAST","UP","LOWER_UP"],"mtu":1500,"qdisc":"noqueue","operstate":"UP","group":"default","txqlen":1000,"link_type":"ether","address":"5e:4d:17:24:1b:b5","broadcast":"ff:ff:ff:ff:ff:ff","addr_info":[{"family":"inet","local":"192.168.35.2","prefixlen":24,"scope":"global","label":"veth0","valid_life_time":4294967295,"preferred_life_time":4294967295},{"family":"inet6","local":"fe80::5c4d:17ff:fe24:1bb5","prefixlen":64,"scope":"link","protocol":"kernel_ll","valid_life_time":4294967295,"preferred_life_time":4294967295}]}]
|}

let () =
  let json = Yojson.Safe.from_string ip_json_str in
  Format.printf "Parsed to %a" Yojson.Safe.pp json
