(* Yoann Padioleau
 *
 * Copyright (C) 2002-2005 Yoann Padioleau
 * Copyright (C) 2006-2007 Ecole des Mines de Nantes
 * Copyright (C) 2008-2009 University of Urbana Champaign
 * Copyright (C) 2010-2014 Facebook
 * Copyright (C) 2019-2021 r2c
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License (GPL)
 * version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * file license.txt for more details.
*)

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* An Abstract Syntax Tree for C/C++/Cpp.
 *
 * This is a big file. C++ is a big and complicated language, and dealing
 * directly with preprocessor constructs from cpp makes the language
 * even bigger.
 *
 * This file started as a simple AST for C. It was then extended
 * to deal with cpp idioms (see 'cppext:' tag) and converted to a CST.
 * Then, it was extented again to deal with gcc extensions (see gccext:),
 * and C++ constructs (see c++ext:), and a few kencc (the plan9 compiler)
 * extensions (see kenccext:). Then, it was extended to deal with
 * a few C++0x (see c++0x:) and C++11 extensions (see c++11:).
 * Finally it was converted back to an AST (actually half AST, half CST)
 * for semgrep and to be the target of tree-sitter-cpp.
 *
 * gcc introduced StatementExpr which made 'expr' and 'stmt' mutually
 * recursive. It also added NestedFunc for even more mutual recursivity.
 * With C++ templates, because template arguments can be types or expressions
 * and because templates are also qualifiers, almost all types
 * are now mutually recursive ...
 *
 * Some stuff are tagged 'semantic:' which means that they can be computed
 * only after parsing.
 *
 * See also lang_c/parsing/ast_c.ml and lang_clang/parsing/ast_clang.ml
 * (as well as mini/ast_minic.ml).
 *
 * todo:
 *  - support C++0x11, e.g. lambdas
 *  - some things are tagged tsonly, meaning they are only generated by
 *    tree-sitter-cpp, but they should also be handled by parser_cpp.mly
 *
 * related work:
 *  - https://github.com/facebook/facebook-clang-plugins
 *    or https://github.com/Antique-team/clangml
 *    but by both using clang they work after preprocessing. This is
 *    fine for bug finding, but for codemap we need to parse as is,
 *    and we need to do it fast (calling clang is super expensive because
 *    calling cpp and parsing the end result is expensive)
 *  - EDG
 *  - see the CC'09 paper
*)

(*****************************************************************************)
(* Tokens and names *)
(*****************************************************************************)
(* ------------------------------------------------------------------------- *)
(* Token/info *)
(* ------------------------------------------------------------------------- *)

(* Contains among other things the position of the token through
 * the Parse_info.token_location embedded inside it, as well as the
 * transformation field that makes possible spatch on C/C++/cpp code.
*)
type tok = Parse_info.t
[@@deriving show]

(* a shortcut to annotate some information with token/position information *)
type 'a wrap  = 'a * tok
[@@deriving show]

type 'a paren   = tok * 'a * tok
[@@deriving show]
type 'a brace   = tok * 'a * tok
[@@deriving show]
type 'a bracket = tok * 'a * tok
[@@deriving show]
type 'a angle   = tok * 'a * tok
[@@deriving show]

(* semicolon *)
type sc = tok
[@@deriving show]

type todo_category = string wrap
[@@deriving show]

(* ------------------------------------------------------------------------- *)
(* Ident, name, scope qualifier *)
(* ------------------------------------------------------------------------- *)

type ident = string wrap
[@@deriving show]

(* c++ext: in C 'name' and 'ident' are equivalent and are just strings.
 * In C++ 'name' can have a complex form like 'A::B::list<int>::size'.
 * I use Q for qualified. I also have a special type to make the difference
 * between intermediate idents (the classname or template_id) and final idents.
 * Note that sometimes final idents are also classnames and can have final
 * template_id.
 *
 * Sometimes some elements are not allowed at certain places, for instance
 * converters can not have an associated Qtop. But I prefered to simplify
 * and have a unique type for all those different kinds of names.
*)
type name = tok (*::*) option  * qualifier list * ident_or_op

and ident_or_op =
  (* function name, macro name, variable, classname, enumname, namespace *)
  | IdIdent of ident
  (* c++ext: *)
  | IdTemplateId of ident * template_arguments
  (* c++ext: for operator overloading *)
  | IdDestructor of tok(*~*) * ident
  (* TODO: tok list?? *)
  | IdOperator of (tok * (operator * tok list))
  (* ?? paren? *)
  | IdConverter of tok * type_


and template_arguments = template_argument list angle
(* C++ allows integers for template arguments! (=~ dependent types) *)
and template_argument = (type_, expr) Common.either

and qualifier =
  | QClassname of ident (* a_class_name or a_namespace_name *)
  | QTemplateId of ident * template_arguments

(* special cases *)
and a_class_name     = name (* only IdIdent or IdTemplateId *)
and a_namespace_name = name (* only IdIdent *)

and _a_typedef_name   = name (* only IdIdent *)
and _a_enum_name      = name (* only IdIdent *)

and a_ident_name = name (* only IdIdent *)

(* less: do like in parsing_c/
 * and ident_string =
 *  | RegularName of string wrap
 *
 *  (* cppext: *)
 *  | CppConcatenatedName of (string wrap) wrap (* the ## separators *) list
 *  (* normally only used inside list of things, as in parameters or arguments
 *   * in which case, cf cpp-manual, it has a special meaning *)
 *  | CppVariadicName of string wrap (* ## s *)
 *  | CppIdentBuilder of string wrap (* s ( ) *) *
 *                      ((string wrap) wrap list) (* arguments *)
*)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)
(* We could have a more precise type in type_, in expression, etc, but
 * it would require too much things at parsing time such as checking whether
 * there is no conflicts structname, computing value, etc. It's better to
 * separate concerns, so I put '=>' to mean what we would really like. In fact
 * what we really like is defining another type_, expression, etc
 * from scratch, because many stuff are just sugar.
 *
 * invariant: Array and FunctionType have also typeQualifier but they
 * dont have sense. I put this to factorise some code. If you look in
 * grammar, you see that we can never specify const for the array
 * himself (but we can do it for pointer).
*)
and type_ = type_qualifiers * typeC
and typeC =
  | TBase        of baseType

  | TPointer         of tok (*'*'*) * type_ * pointer_modifier list
  (* c++ext: *)
  | TReference       of tok (*'&'*) * type_
  (* c++0x: *)
  | TRefRef       of tok (*'&&'*) * type_

  | TArray           of a_const_expr (* or star? *) option bracket * type_
  | TFunction        of functionType

  | EnumName  of tok (* 'enum' *) * ident (* a_enum_name *)
  (* less: ms declspec option after struct/union *)
  | ClassName of class_key wrap * ident (* a_ident_name *)
  (* c++ext: TypeName can now correspond also to a classname or enumname
   * and it is a name so it can have some IdTemplateId in it.
  *)
  | TypeName of name (* a_typedef_name*)
  (* only to disambiguate I think *)
  | TypenameKwd of tok (* 'typename' *) * type_ (* usually a TypeName *)

  (* should be really just at toplevel *)
  | EnumDef of enum_definition (* => string * int list *)
  (* c++ext: bigger type now *)
  | ClassDef of class_definition

  (* gccext: TypeOfType may seems useless, why declare a __typeof__(int)
   * x; ? But when used with macro, it allows to fix a problem of C which
   * is that type declaration can be spread around the ident. Indeed it
   * may be difficult to have a macro such as '#define macro(type,
   * ident) type ident;' because when you want to do a macro(char[256],
   * x), then it will generate invalid code, but with a '#define
   * macro(type, ident) __typeof(type) ident;' it will work. *)
  | TypeOf of tok * (type_, expr) Common.either paren

  (* c++0x: *)
  | TAuto of tok

  (* forunparser: *)
  | ParenType of type_ paren (* less: delete *)

  (* TODO: TypeDots, DeclType *)
  | TypeTodo of todo_category * type_ list

(* TODO: simplify, it is now possible to do 'signed foo' so make
 * sign and base possible qualifier?
*)
and  baseType =
  | Void of tok
  | IntType   of intType   * tok (* TOFIX there should be * tok list *)
  | FloatType of floatType * tok (* TOFIX there should be * tok list *)

(* stdC: type section. 'char' and 'signed char' are different *)
and intType   =
  | CChar (* obsolete? | CWchar  *)
  | Si of signed
  (* c++ext: maybe could be put in baseType instead ? *)
  | CBool | WChar_t

and signed = sign * base
and base =
  | CChar2 | CShort | CInt | CLong
  (* gccext: *)
  | CLongLong
and sign = Signed | UnSigned

and floatType = CFloat | CDouble | CLongDouble

and type_qualifiers = type_qualifier wrap list

(*****************************************************************************)
(* Expressions *)
(*****************************************************************************)
(* Because of StatementExpr, we can have more 'new scope', but it's
 * rare I think. For instance with 'array of constExpression' we could
 * have an StatementExpr and a new (local) struct defined. Same for
 * Constructor.
*)
and expr =
  (* Id can be an enumeration constant, variable, function name.
   * cppext: Id can also be the name of a macro. sparse says
   *  "an identifier with a meaning is a symbol".
   * c++ext: Id is now a 'name' instead of a 'string' and can be
   *  also an operator name.
   * todo: split in Id vs IdQualified like in ast_generic.ml?
   * TODO: Id -> Name
  *)
  | Id of name * ident_info (* semantic: see check_variables_cpp.ml *)
  | C of constant
  | IdSpecial of special wrap

  (* I used to have FunCallSimple but not that useful, and we want scope info
   * for FunCallSimple too because can have fn(...) where fn is actually
   * a local *)
  | Call of expr * argument list paren

  (* gccext: x ? /* empty */ : y <=> x ? x : y; *)
  | CondExpr       of expr * tok * expr option * tok * expr

  (* should be considered as statements, bad C langage *)
  | Sequence       of expr * tok (* , *) * expr
  | Assign         of a_lhs * assignOp * expr

  | Prefix         of fixOp wrap * expr
  | Postfix        of expr * fixOp wrap
  (* contains GetRef and Deref!! less: lift up? *)
  | Unary          of unaryOp wrap * expr
  | Binary         of expr * binaryOp wrap * expr

  | ArrayAccess    of expr * expr bracket

  (* The Pt is redundant normally, could be replace by DeRef RecordAccess.
   * name is usually just an ident_or_op. In rare cases it can be
   * a template_method name.
  *)
  | RecordAccess   of expr * tok (* . *)  * name
  | RecordPtAccess of expr * tok (* -> *) * name

  (* pfffonly, TODO still valid?
   * c++ext: note that second paramater is an expr, not a name *)
  | RecordStarAccess   of expr * tok (* .* *) * expr
  | RecordPtStarAccess of expr * tok (* ->* *) * expr

  | SizeOfExpr     of tok * expr
  | SizeOfType     of tok * type_ paren
  (* TODO: SizeOfDots of tok * tok * ident paren ??? *)

  | Cast          of type_ paren * expr

  (* gccext: *)
  | StatementExpr of compound paren (* ( {  } ) new scope*)
  (* gccext: kenccext: *)
  | GccConstructor  of type_ paren * initialiser list brace

  (* c++ext: *)
  | ConstructedObject of type_ * argument list paren
  (* ?? *)
  | TypeId     of tok * (type_, expr) Common.either paren
  | CplusplusCast of cast_operator wrap * type_ angle * expr paren
  | New of tok (*::*) option * tok (* 'new' *) *
           argument list paren option (* placement *) *
           type_ *
           (* TODO: c++11? rectype option *)
           argument list paren option (* initializer *)

  | Delete      of tok (*::*) option * tok * expr
  | DeleteArray of tok (*::*) option * tok * unit bracket * expr
  (* TODO: tsonly it's a stmt *)
  | Throw of tok * expr option

  (* forunparser: *)
  | ParenExpr of expr paren

  (* sgrep-ext: *)
  | Ellipses of tok
  | DeepEllipsis of expr bracket

  | TypedMetavar of ident * type_

  | ExprTodo of todo_category * expr list

(* see check_variables_cpp.ml *)
and ident_info = {
  mutable i_scope: Scope_code.t
                   [@printer fun _fmt _ -> "??"];
}

and special =
  (* c++ext: *)
  | This
  (* cppext: tsonly *)
  | Defined

(* cppext: normally should just have type argument = expr *)
and argument =
  | Arg of expr
  (* cppext: *)
  | ArgType of type_
  (* cppext: for really unparsable stuff ... we just bailout *)
  | ArgAction of action_macro
and action_macro =
  | ActMisc of tok list

(* Constants.
 * note: '-2' is not a constant; it is the unary operator '-'
 * applied to the constant '2'. So the string must represent a positive
 * integer only.
*)
and constant =
  | Int    of (int option wrap  (* * intType*))
  | Float  of (float option wrap * floatType)
  | Char   of (string wrap * isWchar) (* normally it is equivalent to Int *)
  | String of (string wrap * isWchar)

  | MultiString of string wrap list  (* can contain MacroString *)
  (* c++ext: *)
  | Bool of bool wrap
  | Nullptr of tok

(* TODO? remove? *)
and isWchar = IsWchar | IsChar

and unaryOp  =
  | UnPlus |  UnMinus | Tilde | Not
  (* less: could be lift up, those are really important operators *)
  | GetRef | DeRef
  (* gccext: via &&label notation *)
  | GetRefLabel
and assignOp = SimpleAssign of tok | OpAssign of arithOp wrap

(* TODO: migrate to AST_generic_.incr_decr? *)
and fixOp    = Dec | Inc

(* TODO: migrate to AST_generic_.op? *)
and binaryOp = Arith of arithOp | Logical of logicalOp
and arithOp   =
  | Plus | Minus | Mul | Div | Mod
  | DecLeft | DecRight
  | And | Or | Xor
and logicalOp =
  | Inf | Sup | InfEq | SupEq
  | Eq | NotEq
  | AndLog | OrLog

(* c++ext: used elsewhere but prefer to define it close to other operators *)
and ptrOp = PtrStarOp | PtrOp
and allocOp = NewOp | DeleteOp | NewArrayOp | DeleteArrayOp
and accessop = ParenOp | ArrayOp
and operator =
  | BinaryOp of binaryOp
  | AssignOp of assignOp
  | FixOp of fixOp
  | PtrOpOp of ptrOp
  | AccessOp of accessop
  | AllocOp of allocOp
  | UnaryTildeOp | UnaryNotOp | CommaOp

(* c++ext: *)
and cast_operator =
  | Static_cast | Dynamic_cast | Const_cast | Reinterpret_cast

and a_const_expr = expr (* => int *)

(* expr subset: Id, XxxAccess, Deref, ParenExpr, ...*)
and a_lhs = expr

(*****************************************************************************)
(* Statements *)
(*****************************************************************************)
(* note: assignement is not a statement, it's an expr :(
 * (wonderful C language).
 * note: I use 'and' for type definition because gccext allows statements as
 * expressions, so we need mutual recursive type definition now.
*)
and stmt =
  | Compound      of compound   (* new scope *)
  | ExprStmt of expr_stmt

  (* selection *)
  | If of tok * tok (* 'constexpr' *) option * condition_clause paren *
          stmt * (tok * stmt) option
  (* need to check that all elements in the compound start
   * with a case:, otherwise it's unreachable code.
  *)
  | Switch of tok * condition_clause paren * stmt (* always a compound? *)

  (* iteration *)
  | While   of tok * condition_clause paren * stmt
  | DoWhile of tok * stmt * tok * expr paren * sc
  | For of tok * for_header paren * stmt
  (* cppext: *)
  | MacroIteration of ident * argument list paren * stmt

  | Jump          of jump * sc

  (* labeled *)
  | Label   of a_label * tok (* : *) * stmt
  (* TODO: only inside Switch in theory *)
  | Case      of tok * expr * tok (* : *) * stmt (* TODO list *)
  (* gccext: *)
  | CaseRange of tok * expr * tok (* ... *) * expr * tok (* : *) * stmt
  | Default of tok * tok (* : *) * stmt (* TODO list *)

  (* c++ext: in C this constructor could be outside the statement type, in a
   * decl type, because declarations are only at the beginning of a compound
   * normally. But in C++ we can freely mix declarations and statements.
   * TODO: if mix stmt and tolevel, can factorize with a general
   * DeclStmt encompassing lots of stuff?
  *)
  | DeclStmt  of block_declaration
  (* c++ext: *)
  | Try of tok * compound * handler list
  (* gccext: TODO if mix stmt and toplevel, no need NestedFunc *)
  | NestedFunc of func_definition
  (* cppext: *)
  | MacroStmt of tok

  | StmtTodo of todo_category * stmt list

(* cppext: c++ext:
 * old: compound = (declaration list * stmt list)
 * old: (declaration, stmt) either list
*)
and compound = stmt sequencable list brace

and expr_stmt = expr option * sc

and condition_clause =
  | CondClassic of expr

(* TODO *)
and for_header =
  | ForClassic of a_expr_or_vars * expr option * expr option
  | ForRange of (entity * var_decl) * tok (*':'*) * initialiser
and a_expr_or_vars = (expr_stmt, vars_decl) Common.either

and a_label = string wrap

and jump  =
  | Goto of tok * a_label
  | Continue of tok | Break of tok
  | Return of tok * expr(*TODO _or_inits*) option
  (* gccext: goto *exp *)
  | GotoComputed of tok * tok * expr

(* c++ext: *)

and handler =
  tok (* 'catch' *) * exception_declaration list paren (* list??? *) * compound
and exception_declaration =
  | ExnDecl of parameter
  (* sgrep-ext? *)
  | ExnDeclEllipsis of tok

(*****************************************************************************)
(* Definitions/Declarations *)
(*****************************************************************************)

(* see also ClassDef in type_ which can also define entities *)

and entity = {
  (* Usually a simple ident.
   * Can be an ident_or_op for functions
  *)
  name: name;
  specs: specifier list;
  (* TODO? put type_ also? *)
}

(* ------------------------------------------------------------------------- *)
(* Simple var *)
(* ------------------------------------------------------------------------- *)
and var_decl = {
  v__type: type_;
}

(* ------------------------------------------------------------------------- *)
(* Block Declaration *)
(* ------------------------------------------------------------------------- *)
(* a.k.a declaration_stmt *)
and block_declaration =
  (* TODO: Have an EmptyDecl of type_ * sc ? *)

  (* Before I had a Typedef constructor, but why make this special case and not
   * have also StructDef, EnumDef, so that 'struct t {...} v' which would
   * then generate two declarations.
   * If you want a cleaner C AST use ast_c.ml.
   * note: before the need for unparser, I didn't have a DeclList but just
   * a Decl.
  *)
  | DeclList of vars_decl

  (* cppext: todo? now factorize with MacroTop ?  *)
  | MacroDecl of tok list * ident * argument list paren * tok

  (* c++ext: using namespace *)
  | UsingDecl of using
  (* type_ is usually just a name TODO tsonly is using, but pfff is namespace? *)
  | NameSpaceAlias of tok (*'namespace'*) * ident * tok (*=*) * type_ * sc
  (* gccext: *)
  | Asm of tok * tok option (*volatile*) * asmbody paren * sc

and vars_decl = onedecl list * sc

(* gccext: *)
and asmbody = string wrap list * colon list
and colon = Colon of tok (* : *) * colon_option list
and colon_option =
  | ColonExpr of tok list * expr paren
  | ColonMisc of tok list

(* ------------------------------------------------------------------------- *)
(* Variable definition (and also field definition) *)
(* ------------------------------------------------------------------------- *)

(* note: onedecl includes prototype declarations and class_declarations!
 * c++ext: onedecl now covers also field definitions as fields can have
 * storage in C++.
 * TODO: split in EmptyDecl vs OneDecl with a name and use entity!
*)
and onedecl = {
  (* option cos can have empty declaration or struct tag declaration.
   * kenccext: name can also be empty because of anonymous fields.
  *)
  v_namei: (name * init option) option;
  v_type: type_;
  v_storage: storage_opt; (* TODO: use for c++0x 'auto' inferred locals *)
  (* v_attr: attribute list; *) (* gccext: *)
}
(* TODO: migrate with annotation? S of storage? and move
 * in entity?
*)
and storage_opt = NoSto | StoTypedef of tok | Sto of storage wrap

and init =
  | EqInit of tok (*=*) * initialiser
  (* c++ext: constructed object *)
  | ObjInit of obj_init

(* TODO: ObjArgs or ObjInits *)
and obj_init = argument list paren

and initialiser =
  (* in lhs and rhs *)
  | InitExpr of expr
  | InitList of initialiser list brace
  (* gccext: and only in lhs *)
  | InitDesignators of designator list * tok (*=*) * initialiser
  | InitFieldOld  of ident * tok (*:*) * initialiser
  | InitIndexOld  of expr bracket * initialiser

(* ex: [2].y = x,  or .y[2]  or .y.x. They can be nested *)
and designator =
  | DesignatorField of tok (* . *) * ident
  | DesignatorIndex of expr bracket
  | DesignatorRange of (expr * tok (*...*) * expr) bracket

(* ------------------------------------------------------------------------- *)
(* Function definition *)
(* ------------------------------------------------------------------------- *)
(* Normally we should define another type functionType2 because there
 * are more restrictions on what can define a function than a pointer
 * function. For instance a function declaration can omit the name of the
 * parameter whereas a function definition can not. But, in some cases such
 * as 'f(void) {', there is no name too, so I simplified and reused the
 * same functionType type for both declarations and function definitions.
 *
 * TODO: split in entity * func_definition, to factorize things with lambdas?
 * can maybe factorize annotations in this entity type (e.g., storage).
 * Also will remove the need for func_or_else
*)
and func_definition = entity * function_definition
and function_definition = {
  f_type: functionType;
  f_storage: storage_opt;
  (* todo: gccext: inline or not:, f_inline: tok option *)
  f_body: function_body;
  (*f_attr: attribute list;*) (* gccext: *)
}
and functionType = {
  ft_ret: type_; (* fake return type for ctor/dtor *)
  ft_params: parameter list paren;
  ft_dots: (tok(*,*) (* TODO DELETE, via ParamDots *) * tok(*...*)) option;
  (* c++ext: *)
  (* TODO: via attribute *)
  ft_const: tok option; (* only for methods, TODO put in attribute? *)
  ft_throw: exn_spec option;
}
(* TODO: | ParamDots of tok, sgrep-ext or not *)
and parameter =
  | P of parameter_classic
and parameter_classic = {
  p_name: ident option;
  p_type: type_;
  p_register: tok option; (* TODO put in attribute? *)
  p_specs: specifier list;
  (* c++ext: *)
  p_val: (tok (*=*) * expr) option;
}
and exn_spec =
  (* c++ext: *)
  | ThrowSpec of tok (*'throw'*) * type_ (* usually just a name *) list paren
  (* c++11: *)
  | Noexcept of tok * a_const_expr option paren option

(* TODO: = default, = delete? *)
and function_body =
  compound

(* less: simplify? need differentiate at this level? could have
 * is_ctor, is_dtor helper instead.
 * TODO do via attributes?
*)
and func_or_else =
  | FunctionOrMethod of func_definition
  (* c++ext: special member function *)
  | Constructor of func_definition (* TODO explicit/inline, chain_call *)
  | Destructor of func_definition

and method_decl =
  | MethodDecl of onedecl * (tok * tok) option (* '=' '0' *) * sc
  | ConstructorDecl of
      ident * parameter list paren * sc
  | DestructorDecl of
      tok(*~*) * ident * tok option paren * exn_spec option * sc

(* ------------------------------------------------------------------------- *)
(* enum definition *)
(* ------------------------------------------------------------------------- *)
(* less: use a record *)
and enum_definition =
  tok (*enum*) * ident option * enum_elem list brace

and enum_elem = {
  e_name: ident;
  e_val: (tok (*=*) * a_const_expr) option;
}

(* ------------------------------------------------------------------------- *)
(* Class definition *)
(* ------------------------------------------------------------------------- *)
(* the ident can be a template_id when do template specialization. *)
and class_definition =
  a_ident_name (* a_class_name?? *) option * class_definition_bis

and class_definition_bis = {
  c_kind: class_key wrap;
  (* c++ext: *)
  c_inherit: base_clause list;
  c_members: class_member sequencable list brace (* new scope *);
}
and class_key =
  (* classic C *)
  | Struct | Union
  (* c++ext: *)
  | Class

and base_clause = {
  i_name: a_class_name;
  (* TODO: i_specs? i_dots ? *)
  i_virtual: tok option; (* ?? still c++ valid? pfff-only *)
  i_access: access_spec wrap option;
}

(* was called 'field wrap' before *)
and class_member =
  (* could put outside and take class_member list *)
  | Access of access_spec wrap * tok (*:*)

  (* before unparser, I didn't have a FieldDeclList but just a Field. *)
  | MemberField of fieldkind list * sc
  | MemberFunc of func_or_else
  | MemberDecl of method_decl

  | QualifiedIdInClass of name (* ?? *) * sc

  | TemplateDeclInClass of (tok * template_parameters * declaration)
  | UsingDeclInClass of using

  (* gccext: and maybe c++ext: *)
  | EmptyField  of sc

(* At first I thought that a bitfield could be only Signed/Unsigned.
 * But it seems that gcc allows char i:4. C rule must say that you
 * can cast into int so enum too, ...
 * c++ext: FieldDecl was before Simple of string option * type_
 * but in c++ fields can also have storage (e.g. static) so now reuse
 * ondecl.
*)
and fieldkind =
  | FieldDecl of onedecl
  | BitField of ident option * tok(*:*) * type_ * a_const_expr
  (* type_ => BitFieldInt | BitFieldUnsigned *)

(*****************************************************************************)
(* Attributes, modifiers *)
(*****************************************************************************)
(* not a great name, but the C++ grammar often uses that term *)
and specifier =
  | A of attribute
  | M of modifier
  | Q of type_qualifier wrap
  | S of storage wrap

and attribute =
  (* __attribute__((...)), double paren *)
  | UnderscoresAttr of tok (* __attribute__ *) * argument list paren paren
  (* [[ ... ]], double bracket *)
  | BracketsAttr of expr list bracket (* actually double [[ ]] *)
  (* msext: __declspec(id) *)
  | DeclSpec of tok * ident paren

and modifier =
  (* what is a prototype inline?? gccaccepts it. *)
  | Inline of tok
  (* virtual specifier *)
  | Virtual of tok
  | Final of tok | Override of tok
  (* just for functions *)
  | MsCall of string wrap (* msext: e.g., __cdecl, __stdcall *)
  (* just for constructor *)
  | Explicit of tok * expr paren option

(* used in inheritance spec (base_clause) and class_member *)
and access_spec = Public | Private | Protected

and type_qualifier =
  (* classic C type qualifiers *)
  | Const | Volatile
  (* cext? *)
  | Restrict
  | Atomic
  (* c++ext? *)
  | Mutable
  | Constexpr

and storage  =
  (* only in C, in C++ auto is for TAuto *)
  | Auto
  | Static
  | Register
  | Extern
  (* c++0x? *)
  | StoInline
  (* Friend ???? Mutable? *)

(* only in declarator (not in abstract declarator) *)
and pointer_modifier =
  (* msext: tsonly: *)
  | Based of tok (* '__based' *) * argument list paren
  | PtrRestrict of tok (* '__restrict' *)
  | Uptr of tok (* '__uptr' *)
  | Sptr of tok (* '__sptr' *)
  | Unaligned of tok

(* TODO: like in parsing_c/
 * (* gccext: cppext: *)
 * and attribute = attributebis wrap
 *  and attributebis =
 *   | Attribute of string
*)

(*****************************************************************************)
(* Namespace (using) *)
(*****************************************************************************)
and using = tok (*'using'*) * using_kind * sc
and using_kind =
  | UsingName of name
  | UsingNamespace of tok (*'namespace'*) * a_namespace_name
  (* tsonly, type_ is usually just a name *)
  | UsingAlias of ident * tok (*'='*) * type_

(*****************************************************************************)
(* Cpp *)
(*****************************************************************************)
(* ------------------------------------------------------------------------- *)
(* cppext: #define and #include body *)
(* ------------------------------------------------------------------------- *)

(* all except ifdefs which are treated separately *)
and cpp_directive =
  | Define of tok (* #define*) * ident * define_kind * define_val
  (* tsonly: in pfff the first tok contains everything actually *)
  | Include of tok (* #include *) * include_kind
  (* other stuff *)
  | Undef of ident (* #undef xxx *)
  (* e.g., #line *)
  | PragmaAndCo of tok

and define_kind =
  | DefineVar
  (* tsonly: string can be special "..." *)
  | DefineMacro   of ident list paren
and define_val =
  (* pfffonly *)
  | DefineExpr of expr
  | DefineStmt of stmt
  | DefineType of type_
  | DefineFunction of func_definition
  | DefineInit of initialiser (* in practice only { } with possible ',' *)

  (* do ... while(0) *)
  | DefineDoWhileZero of tok * stmt * tok * tok paren
  | DefinePrintWrapper of tok (* if *) * expr paren * name

  | DefineEmpty
  (* ?? dead? DefineText of string wrap *)

  | DefineTodo of todo_category

and include_kind =
  (* tsonly: in pfff the string does not contain the enclosing chars *)
  | IncLocal (* "" *) of string wrap
  | IncSystem (* <> *) of string wrap
  | IncOther of a_cppExpr (* ex: SYSTEM_H, foo("x") *)

(* this is restricted to simple expressions like a && b *)
and a_cppExpr = expr

(* ------------------------------------------------------------------------- *)
(* cppext: #ifdefs *)
(* ------------------------------------------------------------------------- *)

and 'a sequencable =
  | X of 'a
  (* cppext: *)
  | CppDirective of cpp_directive
  | CppIfdef of ifdef_directive (* * 'a list *)
  (* todo: right now just at the toplevel, but could have elsewhere *)
  | MacroTop of ident * argument list paren * tok option
  | MacroVarTop of ident * sc

(* less: 'a ifdefed = 'a list wrap (* ifdef elsif else endif *) *)
and ifdef_directive =
  | Ifdef of tok (* todo? of string? *)
  (* TODO: IfIf of formula_cpp ? *)
  (* TODO: Ifndef *)
  | IfdefElse of tok
  | IfdefElseif of tok
  | IfdefEndif of tok
  (* less:
   * set in Parsing_hacks.set_ifdef_parenthize_info. It internally use
   * a global so it means if you parse the same file twice you may get
   * different id. I try now to avoid this pb by resetting it each
   * time I parse a file.
   *
   *   and matching_tag =
   *     IfdefTag of (int (* tag *) * int (* total with this tag *))
  *)

(*****************************************************************************)
(* Toplevel *)
(*****************************************************************************)

(* it's not really 'toplevel' because the elements below can be nested
 * inside namespaces or some extern. It's not really 'declaration'
 * either because it can defines stuff. But I keep the C++ standard
 * terminology.
 *
 * note that we use 'block_declaration' below, not 'statement'.
 *
 * TODO: merge with stmt?
*)
and declaration =
  | BlockDecl of block_declaration (* include struct/globals/... definitions *)
  | Func of func_or_else

  (* c++ext: *)
  | TemplateDecl of tok * template_parameters * declaration
  | TemplateSpecialization of tok * unit angle * declaration
  (* the list can be empty *)
  | ExternC     of tok * tok * declaration
  | ExternCList of tok * tok * declaration sequencable list brace
  (* the list can be empty *)
  | NameSpace of tok * ident * declaration sequencable list brace
  (* after have some semantic info *)
  | NameSpaceExtend of string * declaration sequencable list
  | NameSpaceAnon   of tok * declaration sequencable list brace

  (* gccext: allow redundant ';' *)
  | EmptyDef of sc

  | NotParsedCorrectly of tok list

  | DeclTodo of todo_category

(* c++ext: *)
and template_parameter = parameter (* todo? more? *)
and template_parameters = template_parameter list angle
[@@deriving show { with_path = false }]


type toplevel = declaration sequencable
[@@deriving show]

(* finally *)
type program = toplevel list
[@@deriving show]

(*****************************************************************************)
(* Any *)
(*****************************************************************************)
type any =
  (* for semgrep *)
  | Expr of expr
  | Stmt of stmt
  | Stmts of stmt list
  | Toplevel of toplevel
  | Toplevels of toplevel list

  | Program of program
  | Cpp of cpp_directive
  | Type of type_
  | Name of name
  | OneDecl of onedecl
  | Init of initialiser
  | BlockDecl2 of block_declaration
  | ClassMember of class_member

  | Constant of constant

  | Argument of argument
  | Parameter of parameter

  | Body of compound

  | Info of tok
  | InfoList of tok list

[@@deriving show { with_path = false }] (* with tarzan *)

(*****************************************************************************)
(* Extra types, used just during parsing *)
(*****************************************************************************)
(* Take the left part of the type and build around it with the right part
 * to return a final type. For example in int[2], the
 * left part will be int and the right part [2] and the final
 * type will be int[2].
*)
type abstract_declarator = type_ -> type_

(* A couple with a name and an abstract_declarator.
 * Note that with 'int* f(int)' we must return Func(Pointer int,int) and not
 * Pointer (Func(int,int)).
*)
type declarator = { dn: name; dt: abstract_declarator }

(*****************************************************************************)
(* Some constructors *)
(*****************************************************************************)
let nQ = []
let noIdInfo () = { i_scope = Scope_code.NoScope; }
let noQscope = []

(*****************************************************************************)
(* Wrappers *)
(*****************************************************************************)
let unwrap x = fst x
let unparen (_, x, _) = x
let unbrace (_, x, _) = x

let unwrap_typeC (_qu, typeC) = typeC

let name_of_id (id: ident) : name =
  None, [], IdIdent id
let expr_of_id id =
  Id (name_of_id id, noIdInfo())
let expr_to_arg e =
  Arg e

(* When want add some info in AST that does not correspond to
 * an existing C element.
 * old: when don't want 'synchronize' on it in unparse_c.ml
 * (now have other mark for tha matter).
 * used by parsing hacks
*)
let make_expanded ii =
  let noVirtPos = ({Parse_info.str="";charpos=0;line=0;column=0;file=""},-1) in
  let (a, b) = noVirtPos in
  { ii with Parse_info.token = Parse_info.ExpandedTok
                (Parse_info.get_original_token_location ii.Parse_info.token, a, b) }

let basic_param id t specs =
  { p_name = Some id; p_type = t; p_specs = specs; p_register = None;
    p_val = None }

(* used by parsing hacks *)
let rewrap_pinfo pi ii =
  {ii with Parse_info.token = pi}


(* used while migrating the use of 'string' to 'name' in check_variables *)
let (string_of_name_tmp: name -> string) = fun name ->
  let (_opt, _qu, id) = name in
  match id with
  | IdIdent (s,_) -> s
  | _ -> failwith "TODO:string_of_name_tmp"

let (ii_of_id_name: name -> tok list) = fun name ->
  let (_opt, _qu, id) = name in
  match id with
  | IdIdent (_s,ii) -> [ii]
  | IdOperator (_, (_op, ii)) -> ii
  | IdConverter (_tok, _ft) -> failwith "ii_of_id_name: IdConverter"
  | IdDestructor (tok, (_s, ii)) -> [tok;ii]
  | IdTemplateId ((_s, ii), _args) -> [ii]

let (ii_of_name: name -> tok) = fun name ->
  let (_opt, _qu, id) = name in
  match id with
  | IdIdent (_s,ii) -> ii
  | IdOperator (_, (_op, ii)) -> List.hd ii
  | IdConverter (tok, _ft) -> tok
  | IdDestructor (tok, (_s, _ii)) -> tok
  | IdTemplateId ((_s, ii), _args) -> ii
