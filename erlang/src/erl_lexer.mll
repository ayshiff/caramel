(**
	* The lexer definition. This is largely inspired by the Js_of_ocaml Lexer.
	*)

{
open Erl_parser

exception Error of (Parse_info.t * string)

let error lexbuf e =
	let info = Parse_info.t_of_lexbuf lexbuf in
  raise (Error (info, e))

(* The table of keywords *)
let keyword_table =
  let h = Hashtbl.create 6 in
  List.iter (fun (s,f) -> Hashtbl.add h s f ) [
    "after", (fun i -> AFTER i);
    "and", (fun i -> AND i);
    "andalso", (fun i -> ANDALSO i);
    "band", (fun i -> BAND i);
    "begin", (fun i -> BEGIN i);
    "bnot", (fun i -> BNOT i);
    "bor", (fun i -> BOR i);
    "bsl", (fun i -> BSL i);
    "bsr", (fun i -> BSR i);
    "bxor", (fun i -> BXOR i);
    "case", (fun i -> CASE i);
    "catch", (fun i -> CATCH i);
    "div", (fun i -> DIV i);
    "end", (fun i -> END i);
    "fun", (fun i -> FUN i);
    "if", (fun i -> IF i);
    "not", (fun i -> NOT i);
    "of", (fun i -> OF i);
    "or", (fun i -> OR i);
    "orelse", (fun i -> ORELSE i);
    "receive", (fun i -> RECEIVE i);
    "rem", (fun i -> REM i);
    "throw", (fun i -> THROW i);
    "try", (fun i -> TRY i);
    "when", (fun i -> WHEN i);
    "xor", (fun i -> XOR i);
  ];
  h

let update_loc lexbuf ?file ~line ~absolute chars =
  let pos = lexbuf.Lexing.lex_curr_p in
  let new_file = match file with
                 | None -> pos.pos_fname
                 | Some s -> s
  in
  lexbuf.Lexing.lex_curr_p <-
  { pos with
    pos_fname = new_file;
    pos_lnum = if absolute then line else pos.pos_lnum + line;
    pos_bol = pos.pos_cnum - chars;
  }

let tokinfo lexbuf = Parse_info.t_of_lexbuf lexbuf

let or_else a b = match b with | Some c -> c | None -> a
}

let newline = ('\013' * '\010' | "\r" | "\n" | "\r\n")
let blank = [' ' '\009' '\012']
let lowercase = ['a'-'z']
let uppercase = ['A'-'Z']

let digit = [ '0'-'9' ]
let number = digit digit*

let float = number '.' number

let atom = lowercase ['A'-'Z' 'a'-'z' '_' '0'-'9' '@']*

let variable = ['_' 'A'-'Z'] ['A'-'Z' 'a'-'z' '_' '0'-'9' ]*

let macro = ['?'] ['A'-'Z' 'a'-'z' '_' '0'-'9' ]*

let comment = '%'

rule token = parse
  | comment { read_comment (Buffer.create 256) lexbuf }
  | newline { update_loc lexbuf ~line:1 ~absolute:false 0; token lexbuf }
  | blank + { token lexbuf }
  | float as float { FLOAT (float, tokinfo lexbuf) }
  | number as number { INTEGER (number, tokinfo lexbuf) }
  | "!" { BANG (tokinfo lexbuf) }
  | "#" { HASH (tokinfo lexbuf) }
  | "." { DOT (tokinfo lexbuf) }
  | "," { COMMA (tokinfo lexbuf) }
  | ":" { COLON (tokinfo lexbuf) }
  | "=" { EQUAL (tokinfo lexbuf) }
  | "::" { COLON_COLON (tokinfo lexbuf) }
  | ";" { SEMICOLON (tokinfo lexbuf) }
  | "-" { DASH (tokinfo lexbuf) }
  | "--" { MINUS_MINUS (tokinfo lexbuf) }
  | "|" { PIPE (tokinfo lexbuf) }
  | "|>" { FUN_PIPE (tokinfo lexbuf) }
  | "/" { SLASH (tokinfo lexbuf) }
  | "(" { LEFT_PARENS (tokinfo lexbuf) }
  | ")" { RIGHT_PARENS (tokinfo lexbuf) }
  | "<" { LT (tokinfo lexbuf) }
  | ">" { GT (tokinfo lexbuf) }
  | "=<" { LTE (tokinfo lexbuf) }
  | ">=" { GTE (tokinfo lexbuf) }
  | "[" { LEFT_BRACKET (tokinfo lexbuf) }
  | "]" { RIGHT_BRACKET (tokinfo lexbuf) }
  | "{" { LEFT_BRACE (tokinfo lexbuf) }
  | "}" { RIGHT_BRACE (tokinfo lexbuf) }
  | "->" { ARROW (tokinfo lexbuf) }
  | "=>" { FAT_ARROW (tokinfo lexbuf) }
  | "<<" { BINARY_OPEN (tokinfo lexbuf) }
  | ">>" { BINARY_CLOSE (tokinfo lexbuf) }
  | "++" { PLUS_PLUS (tokinfo lexbuf) }
  | "+" { PLUS (tokinfo lexbuf) }
  | "*" { STAR (tokinfo lexbuf) }
  | "==" { EQUAL_EQUAL (tokinfo lexbuf) }
  | "/=" { SLASH_EQUAL (tokinfo lexbuf) }
  | "=:=" { EQUAL_COLON_EQUAL (tokinfo lexbuf) }
  | "=/=" { EQUAL_SLASH_EQUAL (tokinfo lexbuf) }
  | ":=" { COLON_EQUAL (tokinfo lexbuf) }
  | "\'" { read_atom (Buffer.create 1024) lexbuf }
  | "\"" { read_string (Buffer.create 1024) lexbuf }
  | atom as atom {
			let a = (Hashtbl.find_opt keyword_table atom)
							|> or_else (fun i -> ATOM (atom, i))
			in a (tokinfo lexbuf)
	}
  | macro as macro { MACRO (macro, tokinfo lexbuf) }
  | variable as variable { VARIABLE (variable, tokinfo lexbuf) }
  | eof { EOF (tokinfo lexbuf) }

(* NOTE: this is naively copied from read_string and should be restricted to
 * valid atom characters *)
and read_atom buf = parse
  | '''       { ATOM (Buffer.contents buf, tokinfo lexbuf) }
  | '\\' '/'  { Buffer.add_char buf '/'; read_atom buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_atom buf lexbuf }
  | '\\' 'b'  { Buffer.add_char buf '\b'; read_atom buf lexbuf }
  | '\\' 'f'  { Buffer.add_char buf '\012'; read_atom buf lexbuf }
  | '\\' 'n'  { Buffer.add_char buf '\n'; read_atom buf lexbuf }
  | '\\' 'r'  { Buffer.add_char buf '\r'; read_atom buf lexbuf }
  | '\\' 't'  { Buffer.add_char buf '\t'; read_atom buf lexbuf }
  | [^ ''' '\\']+ {
    Buffer.add_string buf (Lexing.lexeme lexbuf); read_atom buf lexbuf }
  | _ { error lexbuf ("Illegal atom character: " ^ Lexing.lexeme lexbuf) }
  | eof { error lexbuf "Unterminated_string" }

and read_comment buf = parse
  | newline   { COMMENT (Buffer.contents buf, tokinfo lexbuf) }
  | '\\' '/'  { Buffer.add_char buf '/'; read_comment buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_comment buf lexbuf }
  | '\\' 'b'  { Buffer.add_char buf '\b'; read_comment buf lexbuf }
  | '\\' 'f'  { Buffer.add_char buf '\012'; read_comment buf lexbuf }
  | '\\' 'n'  { Buffer.add_char buf '\n'; read_comment buf lexbuf }
  | '\\' 'r'  { Buffer.add_char buf '\r'; read_comment buf lexbuf }
  | '\\' 't'  { Buffer.add_char buf '\t'; read_comment buf lexbuf }
  | _ {
      Buffer.add_string buf (Lexing.lexeme lexbuf);
      read_comment buf lexbuf
  }
  | eof { COMMENT (Buffer.contents buf, tokinfo lexbuf) }

and read_string buf = parse
  | '"'       { STRING (Buffer.contents buf, tokinfo lexbuf) }
  | '\\' '/'  { Buffer.add_char buf '/'; read_string buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_string buf lexbuf }
  | '\\' 'b'  { Buffer.add_char buf '\b'; read_string buf lexbuf }
  | '\\' 'f'  { Buffer.add_char buf '\012'; read_string buf lexbuf }
  | '\\' 'n'  { Buffer.add_char buf '\n'; read_string buf lexbuf }
  | '\\' 'r'  { Buffer.add_char buf '\r'; read_string buf lexbuf }
  | '\\' 't'  { Buffer.add_char buf '\t'; read_string buf lexbuf }
  | [^ '"' '\\']+ {
    Buffer.add_string buf (Lexing.lexeme lexbuf); read_string buf lexbuf }
  | _ { error lexbuf ("Illegal string character: " ^ Lexing.lexeme lexbuf) }
  | eof { error lexbuf "Unterminated_string" }
