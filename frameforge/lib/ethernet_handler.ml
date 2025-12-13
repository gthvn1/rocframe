type ethernet_header = { dst_mac : bytes; src_mac : bytes; ethertype : bytes }

type 'a parser = bytes -> int -> ('a * int, string) result
(** It represents the parser. It takes a full input buffer [bytes], the current
    offset [int] in the buffer and returns a tuple with the value read and the
    new offset, or an error string in case of failure .*)

let mac_parser : bytes parser =
 fun buf pos ->
  if pos + 6 > Bytes.length buf then Error "unexpected end of input"
  else
    let m = Bytes.sub buf pos 6 in
    Ok (m, pos + 6)

let ethertype_parser : bytes parser =
 fun buf pos ->
  if pos + 2 > Bytes.length buf then Error "unexpected end of input"
  else
    let m = Bytes.sub buf pos 2 in
    Ok (m, pos + 2)

(** [comp p f] returns a function that call the parser [p] and if the result is
    ok it applies [f]. Otherwise it returns the error. *)
let comp (p : 'a parser) (f : 'a -> 'b parser) : 'b parser =
 fun buf pos ->
  match p buf pos with Error e -> Error e | Ok (v, pos') -> f v buf pos'

(** [parse_frame buf pos] parse the destination mac, the src mac and the
    ethertype. We are using the comp function we can create a parser for
    ethernet.

    NOTE:
    {|
      -> mac_parser parses 6 bytes and returns (mac, new_pos)
      -> ethertype_parser parses 2 bytes and returns (ethertype, new_pos)
      1. Call to `parse_frame payload 0` is expanded as:
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
let parse_frame : ethernet_header parser =
  comp mac_parser (fun dst ->
      comp mac_parser (fun src ->
          comp ethertype_parser (fun etype ->
              fun _buf pos ->
               Ok ({ dst_mac = dst; src_mac = src; ethertype = etype }, pos))))

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
  let () =
    match parse_frame payload 0 with
    | Error _e -> Printf.printf "Failed to parse frame header"
    | Ok (h, _) ->
        let open Utils in
        let open String in
        let dst_str = hex_of_bytes h.dst_mac |> concat " " in
        let src_str = hex_of_bytes h.src_mac |> concat " " in
        let etype_str = hex_of_bytes h.ethertype |> concat " " in
        Printf.printf "Destination MAC: %s\n" dst_str;
        Printf.printf "Source MAC     : %s\n" src_str;
        Printf.printf "Ethernet type  : %s\n" etype_str
  in
  (* ----- Return a dummy message *)
  Bytes.of_string "TODO: parse ethernet frame\n"
