(** [hex_of_bytes b] takes a bytes [b] and and return each bit as a list of
    string with exaclty two hexadecimal digits. *)
let hex_of_bytes (b : bytes) : string list =
  Bytes.fold_left (fun acc c -> Printf.sprintf "%02X" (Char.code c) :: acc) [] b
  |> List.rev
