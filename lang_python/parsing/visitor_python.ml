(* Yoann Padioleau
 *
 * Copyright (C) 2019 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)
open Ocaml
open Ast_python

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(* hooks *)
type visitor_in = {
  kexpr: (expr  -> unit) * visitor_out -> expr  -> unit;
  kstmt: (stmt  -> unit) * visitor_out -> stmt  -> unit;
  ktype_: (type_  -> unit) * visitor_out -> type_  -> unit;
  kdecorator: (decorator  -> unit) * visitor_out -> decorator  -> unit;
  kparameters: (parameters  -> unit) * visitor_out -> parameters  -> unit;
  kinfo: (tok -> unit)  * visitor_out -> tok  -> unit;
}
and visitor_out = any -> unit

let default_visitor =
  { kexpr   = (fun (k,_) x -> k x);
    kstmt   = (fun (k,_) x -> k x);
    ktype_   = (fun (k,_) x -> k x);
    kdecorator   = (fun (k,_) x -> k x);
    kparameters   = (fun (k,_) x -> k x);
    kinfo   = (fun (k,_) x -> k x);
  }

let (mk_visitor: visitor_in -> visitor_out) = fun vin ->

(* start of auto generation *)


(* generated by ocamltarzan with: camlp4o -o /tmp/yyy.ml -I pa/ pa_type_conv.cmo pa_visitor.cmo  pr_o.cmo /tmp/xxx.ml  *)


let rec v_info x =
  let k x = match x with { Parse_info.
     token = _v_pinfox; transfo = _v_transfo
    } ->
(*
    let arg = Parse_info.v_pinfo v_pinfox in
    let arg = v_unit v_comments in
    let arg = Parse_info.v_transformation v_transfo in
*)
    ()
  in
  vin.kinfo (k, all_functions) x

and v_tok v = v_info v

and v_wrap: 'a. ('a -> unit) -> 'a wrap -> unit = fun _of_a (v1, v2) ->
  let v1 = _of_a v1 and v2 = v_info v2 in ()

and v_name v = v_wrap v_string v

and v_resolved_name =
  function
  | LocalVar -> ()
  | Parameter -> ()
  | ImportedModule -> ()
  | ImportedGlobal -> ()
  | NotResolved -> ()

and v_expr (x: expr) =
  (* tweak *)
  let k x =  match x with
  | Num v1 -> let v1 = v_number v1 in ()
  | Str ((v1, v2)) -> let v1 = v_string v1 and v2 = v_list v_tok v2 in ()
  | Name ((v1, v2, v3, v4)) ->
      let v1 = v_name v1
      and v2 = v_expr_context v2
      and v3 = v_option v_type_ v3
      and v4 = v_ref v_resolved_name v4
      in ()
  | Tuple ((v1, v2)) ->
      let v1 = v_list v_expr v1 and v2 = v_expr_context v2 in ()
  | List ((v1, v2)) ->
      let v1 = v_list v_expr v1 and v2 = v_expr_context v2 in ()
  | Dict ((v1, v2)) ->
      let v1 = v_list v_expr v1 and v2 = v_list v_expr v2 in ()
  | ListComp ((v1, v2)) ->
      let v1 = v_expr v1 and v2 = v_list v_comprehension v2 in ()
  | BoolOp ((v1, v2)) -> let v1 = v_boolop v1 and v2 = v_list v_expr v2 in ()
  | BinOp ((v1, v2, v3)) ->
      let v1 = v_expr v1 and v2 = v_operator v2 and v3 = v_expr v3 in ()
  | UnaryOp ((v1, v2)) -> let v1 = v_unaryop v1 and v2 = v_expr v2 in ()
  | Compare ((v1, v2, v3)) ->
      let v1 = v_expr v1
      and v2 = v_list v_cmpop v2
      and v3 = v_list v_expr v3
      in ()
  | Call ((v1, v2, v3, v4, v5)) ->
      let v1 = v_expr v1
      and v2 = v_list v_expr v2
      and v3 = v_list v_keyword v3
      and v4 = v_option v_expr v4
      and v5 = v_option v_expr v5
      in ()
  | Subscript ((v1, v2, v3)) ->
      let v1 = v_expr v1 and v2 = v_slice v2 and v3 = v_expr_context v3 in ()
  | Lambda ((v1, v2)) -> let v1 = v_parameters v1 and v2 = v_expr v2 in ()
  | IfExp ((v1, v2, v3)) ->
      let v1 = v_expr v1 and v2 = v_expr v2 and v3 = v_expr v3 in ()
  | GeneratorExp ((v1, v2)) ->
      let v1 = v_expr v1 and v2 = v_list v_comprehension v2 in ()
  | Yield v1 -> let v1 = v_option v_expr v1 in ()
  | Repr v1 -> let v1 = v_expr v1 in ()
  | Attribute ((v1, v2, v3)) ->
      let v1 = v_expr v1 and v2 = v_name v2 and v3 = v_expr_context v3 in ()
  in
  vin.kexpr (k, all_functions) x
  
and v_number =
  function
  | Int v1 -> let v1 = v_wrap v_int v1 in ()
  | LongInt v1 -> let v1 = v_wrap v_int v1 in ()
  | Float v1 -> let v1 = v_wrap v_float v1 in ()
  | Imag v1 -> let v1 = v_wrap v_string v1 in ()
and v_boolop = function | And -> () | Or -> ()
and v_operator =
  function
  | Add -> ()
  | Sub -> ()
  | Mult -> ()
  | Div -> ()
  | Mod -> ()
  | Pow -> ()
  | FloorDiv -> ()
  | LShift -> ()
  | RShift -> ()
  | BitOr -> ()
  | BitXor -> ()
  | BitAnd -> ()
and v_unaryop = function | Invert -> () | Not -> () | UAdd -> () | USub -> ()
and v_cmpop =
  function
  | Eq -> ()
  | NotEq -> ()
  | Lt -> ()
  | LtE -> ()
  | Gt -> ()
  | GtE -> ()
  | Is -> ()
  | IsNot -> ()
  | In -> ()
  | NotIn -> ()
and v_comprehension (v1, v2, v3) =
  let v1 = v_expr v1 and v2 = v_expr v2 and v3 = v_list v_expr v3 in ()
and v_expr_context =
  function
  | Load -> ()
  | Store -> ()
  | Del -> ()
  | AugLoad -> ()
  | AugStore -> ()
  | Param -> ()
and v_keyword (v1, v2) = let v1 = v_name v1 and v2 = v_expr v2 in ()
and v_slice =
  function
  | Ellipsis -> ()
  | Slice ((v1, v2, v3)) ->
      let v1 = v_option v_expr v1
      and v2 = v_option v_expr v2
      and v3 = v_option v_expr v3
      in ()
  | ExtSlice v1 -> let v1 = v_list v_slice v1 in ()
  | Index v1 -> let v1 = v_expr v1 in ()
and v_parameters x =
  let k (v1, v2, v3, v4) =
  let v1 = v_list v_expr v1
  and v2 = v_option v_name v2
  and v3 = v_option v_name v3
  and v4 = v_list v_expr v4
  in ()
  in
  vin.kparameters (k, all_functions) x

and v_type_ v = 
  let k x =
    v_expr x
  in
  vin.ktype_ (k, all_functions) v

and v_stmt x =
  let k x = match x with
  | FunctionDef ((v1, v2, v3, v4, v5)) ->
      let v1 = v_name v1
      and v2 = v_parameters v2
      and v3 = v_option v_type_ v3
      and v4 = v_list v_stmt v4
      and v5 = v_list v_decorator v5
      in ()
  | ClassDef ((v1, v2, v3, v4)) ->
      let v1 = v_name v1
      and v2 = v_list v_expr v2
      and v3 = v_list v_stmt v3
      and v4 = v_list v_decorator v4
      in ()
  | Assign ((v1, v2)) -> let v1 = v_list v_expr v1 and v2 = v_expr v2 in ()
  | AugAssign ((v1, v2, v3)) ->
      let v1 = v_expr v1 and v2 = v_operator v2 and v3 = v_expr v3 in ()
  | Return v1 -> let v1 = v_option v_expr v1 in ()
  | Delete v1 -> let v1 = v_list v_expr v1 in ()
  | Print ((v1, v2, v3)) ->
      let v1 = v_option v_expr v1
      and v2 = v_list v_expr v2
      and v3 = v_bool v3
      in ()
  | For ((v1, v2, v3, v4)) ->
      let v1 = v_expr v1
      and v2 = v_expr v2
      and v3 = v_list v_stmt v3
      and v4 = v_list v_stmt v4
      in ()
  | While ((v1, v2, v3)) ->
      let v1 = v_expr v1
      and v2 = v_list v_stmt v2
      and v3 = v_list v_stmt v3
      in ()
  | If ((v1, v2, v3)) ->
      let v1 = v_expr v1
      and v2 = v_list v_stmt v2
      and v3 = v_list v_stmt v3
      in ()
  | With ((v1, v2, v3)) ->
      let v1 = v_expr v1
      and v2 = v_option v_expr v2
      and v3 = v_list v_stmt v3
      in ()
  | Raise ((v1, v2, v3)) ->
      let v1 = v_option v_expr v1
      and v2 = v_option v_expr v2
      and v3 = v_option v_expr v3
      in ()
  | TryExcept ((v1, v2, v3)) ->
      let v1 = v_list v_stmt v1
      and v2 = v_list v_excepthandler v2
      and v3 = v_list v_stmt v3
      in ()
  | TryFinally ((v1, v2)) ->
      let v1 = v_list v_stmt v1 and v2 = v_list v_stmt v2 in ()
  | Assert ((v1, v2)) -> let v1 = v_expr v1 and v2 = v_option v_expr v2 in ()
  | Import v1 -> let v1 = v_list v_alias v1 in ()
  | ImportFrom ((v1, v2, v3)) ->
      let v1 = v_name v1
      and v2 = v_list v_alias v2
      and v3 = v_option v_int v3
      in ()
  | Exec ((v1, v2, v3)) ->
      let v1 = v_expr v1
      and v2 = v_option v_expr v2
      and v3 = v_option v_expr v3
      in ()
  | Global v1 -> let v1 = v_list v_name v1 in ()
  | ExprStmt v1 -> let v1 = v_expr v1 in ()
  | Pass -> ()
  | Break -> ()
  | Continue -> ()
  in
  vin.kstmt (k, all_functions) x


and v_excepthandler =
  function
  | ExceptHandler ((v1, v2, v3)) ->
      let v1 = v_option v_type_ v1
      and v2 = v_option v_expr v2
      and v3 = v_list v_stmt v3
      in ()
and v_decorator v = 
  let k x =
    v_expr x
  in
  vin.kdecorator (k, all_functions) v

and v_alias (v1, v2) = let v1 = v_name v1 and v2 = v_option v_name v2 in ()
and v_modl =
  function
  | Module v1 -> let v1 = v_list v_stmt v1 in ()
  | Interactive v1 -> let v1 = v_list v_stmt v1 in ()
  | Expression v1 -> let v1 = v_expr v1 in ()
  | Suite v1 -> let v1 = v_list v_stmt v1 in ()
  
and v_program v = v_modl v

and v_any =
  function
  | Expr v1 -> let v1 = v_expr v1 in ()
  | Stmt v1 -> let v1 = v_stmt v1 in ()
  | Modl v1 -> let v1 = v_modl v1 in ()
  | Program v1 -> let v1 = v_program v1 in ()
  
and all_functions x = v_any x
in
all_functions

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)
