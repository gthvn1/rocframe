(* https://en.wikipedia.org/wiki/Ethernet_frame *)

type ethernet_header = {
  dst_mac : bytes;
  src_mac : bytes;
  ethertype : Ethertype.t;
}

type 'a parser = bytes -> int -> ('a * int, string) result
(** It represents the parser. It takes a full input buffer [bytes], the current
    offset [int] in the buffer and returns a tuple with the value read and the
    new offset, or an error string in case of failure .*)

(** [comp p f] returns a function that call the parser [p] and if the result is
    ok it applies [f]. Otherwise it returns the error. *)
let comp (p : 'a parser) (f : 'a -> 'b parser) : 'b parser =
 fun buf pos ->
  match p buf pos with Error e -> Error e | Ok (v, pos') -> f v buf pos'

(** Use to chain comp operation *)
let ( >=> ) = comp

let mac_parser : bytes parser =
 fun buf pos ->
  if pos + 6 > Bytes.length buf then Error "unexpected end of input"
  else
    let m = Bytes.sub buf pos 6 in
    Ok (m, pos + 6)

let u16_be_parser : int parser =
 fun buf pos ->
  if pos + 2 > Bytes.length buf then Error "unexpected end of input"
  else
    let v = (Bytes.get_uint8 buf pos lsl 8) lor Bytes.get_uint8 buf (pos + 1) in
    Ok (v, pos + 2)

let ethertype_parser : Ethertype.t parser =
  u16_be_parser >=> fun etype ->
  match etype with
  | 0x0800 -> fun _buf pos -> Ok (Ethertype.Ether_ipv4, pos)
  | 0x0806 -> fun _buf pos -> Ok (Ethertype.Ether_arp, pos)
  | 0x86DD -> fun _buf pos -> Ok (Ethertype.Ether_ipv6, pos)
  | x -> fun _buf pos -> Ok (Ethertype.Ether_unknown x, pos)

(** [frame_parser buf pos] parse the destination mac, the src mac and the
    ethertype. We are using the comp function we can create a parser for
    ethernet.

    NOTE:
    {|
      -> mac_parser parses 6 bytes and returns (mac, new_pos)
      -> ethertype_parser parses 2 bytes and returns (ethertype, new_pos)
      1. Call to `frame_parser payload 0` is expanded as:
           comp mac_parser (fun dst ->
               comp mac_parser (fun src ->
                   comp ethertype_parser (fun etype ->
                       fun _buf pos ->
                        Ok ({ dst_mac = dst; src_mac = src; ethertype = etype }, pos)))) payload 0

      2. Evaluate the outer comp:
           match mac_parser payload 0 with
           | Error e -> Error e
           | Ok(dst, pos1) -> (fun dst ->
               comp mac_parser (fun src ->
                 comp ethertype_parser (fun etype ->
                   fun _buf pos ->
                     Ok ({ dst_mac = dst; src_mac = src; ethertype = etype }, pos)))) dst payload pos1

      3. Evaluate the next outer comp:
           match comp mac_parser payload pos1 with
           | Error e -> Error e
           | Ok(src, pos2) -> (fun src ->
               comp ethertype_parser (fun etype ->
                 fun _buf pos ->
                   Ok ({ dst_mac = dst; src_mac = src; ethertype = etype }, pos)))) src payload pos2

      4. If no Error continue
          match comp ethertype_parser payload pos2 with
          | Error e -> Error e
          | Ok(etype, pos3) -> (fun etype ->
                 fun _buf pos ->
                   Ok ({ dst_mac = dst; src_mac = src; ethertype = etype }, pos)))) etype payload pos3
      
      5. Last comp:
          fun _buf pos ->
            Ok ({ dst_mac = dst; src_mac = src; ethertype = etype }, pos)))) payload pos3

      6. That returns 
            Ok ({ dst_mac = dst; src_mac = src; ethertype = etype }, pos3))))
    |}
    *)
let frame_parser : ethernet_header parser =
  mac_parser >=> fun dst ->
  mac_parser >=> fun src ->
  ethertype_parser >=> fun etype ->
  fun _buf pos -> Ok ({ dst_mac = dst; src_mac = src; ethertype = etype }, pos)

(** [handle payload] is the entry point of the Ethernet handler. It takes the
    [payload] and parse it to produce a result. Currently it is a work in
    progress and it returns a todo message as bytes. *)
let handle (payload : bytes) : bytes =
  (* ----- Display payload as hexadecimal *)
  let sl = Utils.hex_of_bytes payload in
  (* Start by printing the bytes we received. Insert a new line each 12 bytes and
     add extra space at 6. It is because the Ethernet II frame is like that:
         +----------------+----------------+-----------+------------------+
         | Dest MAC (6)   | Src MAC (6)    | EtherType | Payload ...      |
         +----------------+----------------+-----------+------------------+
                                              2 bytes                           *)
  List.mapi
    (fun i s ->
      if i > 0 && i mod 12 = 0 then "\n" ^ s
      else if i > 0 && i mod 6 = 0 then "  " ^ s
      else s)
    sl
  |> String.concat " " |> print_endline;

  (* ----- Parsing *)
  match frame_parser payload 0 with
  | Error _e ->
      Printf.printf "Failed to parse frame header\n";
      Bytes.of_string "ERROR: failed to parse ethernet header\n"
  | Ok (h, offset) -> (
      let open Utils in
      let dst_str = hex_of_bytes h.dst_mac |> String.concat ":" in
      let src_str = hex_of_bytes h.src_mac |> String.concat ":" in
      Printf.printf "Destination MAC: %s\n" dst_str;
      Printf.printf "Source MAC     : %s\n" src_str;
      Printf.printf "Ethernet type  : %s\n" (Ethertype.to_string h.ethertype);
      Printf.printf "-------------------------------------\n";
      match h.ethertype with
      | Ether_ipv4 -> Bytes.of_string "TODO: parse IPv4"
      | Ether_ipv6 -> Bytes.of_string "TODO: parse IPv6"
      | Ether_arp -> Arp_handler.handle payload offset
      | Ether_unknown x ->
          Bytes.of_string @@ Printf.sprintf "TODO: parse unknown (0x%2X)" x)
