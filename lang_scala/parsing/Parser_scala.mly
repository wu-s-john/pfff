%{
(* Yoann Padioleau
 *
 * Copyright (C) 2021 R2C
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

(*************************************************************************)
(* Prelude *)
(*************************************************************************)
(* This file contains a grammar for Scala 2.13
 *
 * src: this was converted from scala.ebnf (itself derived from the official
 * grammar) by semgrep -ebnf_to_menhir, and adapted to conform to what
 * menhir can do (hence the use of macros like list_sep, seq2, etc.).
 *
 * reference:
 *  - https://scala-lang.org/files/archive/spec/2.13/13-syntax-summary.html
 *
 * other sources:
 *  - dotty compiler source
 *  - scala compiler source
 *  - tree-sitter-scala
 *  - scalaparse from the fastparse Scala library
 *  - ANTLR v4 grammar for Scala
 *)

(*************************************************************************)
(* Helpers *)
(*************************************************************************)

(* unused rec flag *)
[@@@warning "-39"]

%}

(*************************************************************************)
(* Tokens *)
(*************************************************************************)

(* unrecognized token, will generate parse error *)
%token <Parse_info.t> Unknown
%token <Parse_info.t> EOF

(*-----------------------------------------*)
(* The space/comment tokens *)
(*-----------------------------------------*)
(* coupling: Token_helpers.is_real_comment *)
%token <Parse_info.t> Space Comment

(* This is actually treated specially in Scala *)
%token <Parse_info.t> Nl

(*-----------------------------------------*)
(* The normal tokens *)
(*-----------------------------------------*)

(* tokens with "values" *)
%token <Parse_info.t> Id
%token <Parse_info.t> Boundvarid
%token <Parse_info.t> Varid
%token <Parse_info.t> SymbolLiteral

%token <bool * Parse_info.t> BooleanLiteral
%token <string * Parse_info.t> CharacterLiteral
%token <float option * Parse_info.t> FloatingPointLiteral
%token <int option * Parse_info.t> IntegerLiteral

%token <string * Parse_info.t> StringLiteral
%token <Parse_info.t> InterpStart
%token <Parse_info.t> InterpolatedString

(* keywords tokens *)
%token <Parse_info.t> Kabstract "abstract"
%token <Parse_info.t> Kcase "case"
%token <Parse_info.t> Kcatch "catch"
%token <Parse_info.t> Kclass "class"
%token <Parse_info.t> Kdef "def"
%token <Parse_info.t> Kdo "do"
%token <Parse_info.t> Kelse "else"
%token <Parse_info.t> Kextends "extends"
%token <Parse_info.t> Kfinal "final"
%token <Parse_info.t> Kfinally "finally"
%token <Parse_info.t> Kfor "for"
%token <Parse_info.t> KforSome "forSome"
%token <Parse_info.t> Kif "if"
%token <Parse_info.t> Kimplicit "implicit"
%token <Parse_info.t> Kimport "import"
%token <Parse_info.t> Klazy "lazy"
%token <Parse_info.t> Kmatch "match"
%token <Parse_info.t> Knew "new"
%token <Parse_info.t> Knull "null"
%token <Parse_info.t> Kobject "object"
%token <Parse_info.t> Koverride "override"
%token <Parse_info.t> Kpackage "package"
%token <Parse_info.t> Kprivate "private"
%token <Parse_info.t> Kprotected "protected"
%token <Parse_info.t> Kreturn "return"
%token <Parse_info.t> Ksealed "sealed"
%token <Parse_info.t> Ksuper "super"
%token <Parse_info.t> Kthis "this"
%token <Parse_info.t> Kthrow "throw"
%token <Parse_info.t> Ktrait "trait"
%token <Parse_info.t> Ktry "try"
%token <Parse_info.t> Ktype "type"
%token <Parse_info.t> Kval "val"
%token <Parse_info.t> Kvar "var"
%token <Parse_info.t> Kwhile "while"
%token <Parse_info.t> Kwith "with"
%token <Parse_info.t> Kyield "yield"

(* syntax *)
%token <Parse_info.t> LPAREN   "(" RPAREN ")"
%token <Parse_info.t> LBRACKET "[" RBRACKET "]"
%token <Parse_info.t> LBRACE   "{" RBRACE "}"

%token <Parse_info.t> SEMI ";"
%token <Parse_info.t> COMMA ","
%token <Parse_info.t> DOT "."
%token <Parse_info.t> COLON ":"
%token <Parse_info.t> EQ "="

(* operators *)
%token <Parse_info.t> PLUS "+"
%token <Parse_info.t> MINUS "-"
%token <Parse_info.t> STAR "*"

%token <Parse_info.t> BANG "!"
%token <Parse_info.t> SHARP "#"
%token <Parse_info.t> TILDE "~"
%token <Parse_info.t> PIPE "|"
%token <Parse_info.t> UNDERSCORE "_"

%token <Parse_info.t> LESSPERCENT "<%"
%token <Parse_info.t> LESSMINUS "<-"
%token <Parse_info.t> LESSCOLON "<:"
%token <Parse_info.t> EQMORE "=>"
%token <Parse_info.t> MORECOLON ">:"
%token <Parse_info.t> AT "@"

(*-----------------------------------------*)
(* extra tokens: *)
(*-----------------------------------------*)
(* semgrep-ext: *)
%token <Parse_info.t> Ellipsis "..."
%token <Parse_info.t> LDots "<..." RDots "...>"

(*************************************************************************)
(* Priorities *)
(*************************************************************************)

(*************************************************************************)
(* Rules type decl *)
(*************************************************************************)

%start <unit> compilationUnit
%%

compilationUnit: EOF { () }

(*
(*************************************************************************)
(* Macros *)
(*************************************************************************)
list_sep(X,Sep):
 | X                      { }
 | list_sep(X,Sep) Sep X  { }

%inline
seq2(X,Y): X Y { }

%inline
choice2(X,Y):
 | X { }
 | Y { }

(*************************************************************************)
(* Literal *)
(*************************************************************************)

literal:
 | IntegerLiteral { }
 | FloatingPointLiteral { }
 | BooleanLiteral { }
 | CharacterLiteral { }
 | StringLiteral { }
 | InterpStart InterpolatedString { }
 | SymbolLiteral { }
 | "null" { }

(*************************************************************************)
(* Names *)
(*************************************************************************)

qualId: list_sep(Id, ".") { }

ids: list_sep(Id,",") { }

path:
 | stableId { }
 | seq2(Id, ".")? "this" { }

stableId:
 | Id { }
 | path "." Id { }
 | seq2(Id, ".")? "super" classQualifier? "." Id { }

classQualifier: "[" Id "]" { }


(*************************************************************************)
(* Misc1 *)
(*************************************************************************)

valDef: "val" Id "=" literal { }

(*************************************************************************)
(* Types *)
(*************************************************************************)

type_:
 | functionArgTypes "=>" type_ { }
 | infixType existentialClause? { }

functionArgTypes: infixType { }
 | "(" paramType ("," paramType) *? ")" { }

existentialClause: "forSome" "{" existentialDcl (Semi existentialDcl)* "}" { }

existentialDcl: "type" typeDcl { }
 | "val" valDcl { }

infixType: compoundType (Id Nl? compoundType)* { }

compoundType:
 | annotType ("with" annotType)* refinement? { }
 | refinement { }

annotType: simpleType annotation* { }

simpleType:
 | simpleType typeArgs { }
 | simpleType "#" Id { }
 | stableId { }
 | path "." "type" { }
 | "(" types ")" { }

(*----------------------------*)
(* *)
(*----------------------------*)

typeArgs: "[" types "]" { }

types: type_ ("," type_)* { }

refinement: Nl? "{" refineStat?(Semi refineStat)* "}" { }

refineStat:
 | dcl { }
 | "type" typeDef { }

typePat: type { }

ascription: ":" infixType { }
 | ":" annotation annotation* { }
 | ":" "_" "*" { }

(*************************************************************************)
(* Statements *)
(*************************************************************************)

ifExpression: "if" "(" expr ")" Nl* expr (Semi? "else" expr)? { }

whileExpression: "while" "(" expr ")" Nl* expr { }

tryExpression: "try" expr ("catch" expr)?("finally" expr)? { }

doExpression: "do" expr Semi? "while" "(" expr ")" { }

throwExpression: "throw" expr { }

returnExpression: "return" expr? { }

forExpression: "for" ("(" enumerators ")" | "{" enumerators Semi? "}") Nl* "yield"? expr { }

caseExpression: postfixExpr "match" "{" caseClauses "}" { }

(*************************************************************************)
(* Expressions *)
(*************************************************************************)

expr:
 | (bindings | "implicit"? Id | "_") "=>" expr { }
 | expr1 { }

expr1:
 | ifExpression { }
 | whileExpression { }
 | tryExpression { }
 | doExpression { }
 | throwExpression { }
 | returnExpression { }
 | forExpression { }
 | postfixExpr { }
 | postfixExpr ascription { }
 | caseExpression { }

postfixExpr: infixExpr (Id Nl?)? { }

infixExpr:
 | prefixExpr { }
 | infixExpr Id Nl? infixExpr { }

prefixExpr: ("-" | "+" | "~" | "!")? simpleExpr { }

simpleExpr:
 | "new" (classTemplate | templateBody) { }
 | blockExpr { }
 | simpleExpr1 "_"? { }

simpleExpr1:
 | literal { }
 | path { }
 | "_" { }
 | "(" exprs? ")" { }
 | simpleExpr "." Id { }
 | simpleExpr typeArgs { }
 | simpleExpr1 argumentExprs { }

(*----------------------------*)
(* *)
(*----------------------------*)

exprs: expr ("," expr)* { }

argumentExprs: "(" exprs? ")" { }
 | "(" (exprs ",")? postfixExpr ":" "_" "*" ")" { }
 | Nl? blockExpr { }

(*----------------------------*)
(* *)
(*----------------------------*)

blockExpr: "{" caseClauses "}" { }
 | "{" Nl* block "}" { }

block: blockStat (Semi blockStat)* resultExpr? { }

blockStat: import { }
 | annotation* "implicit"? "lazy"? def { }
 | annotation* localModifier* tmplDef { }
 | expr1 { }
 | /*Empty*/ { }

(*----------------------------*)
(* *)
(*----------------------------*)

resultExpr:
 | expr1 { }
 | (bindings | ("implicit"? Id | "_") ":" compoundType) "=>" block { }

(*----------------------------*)
(* *)
(*----------------------------*)

enumerators: generator (Semi generator)* { }

generator: pattern1 "<-" expr (Semi? guard | Semi pattern1 "=" expr)* { }

(*----------------------------*)
(* *)
(*----------------------------*)

caseClauses: caseClause (Semi? caseClause)* { }

caseClause: "case" pattern guard? "=>" block { }

guard: "if" postfixExpr { }

(*************************************************************************)
(* Patterns *)
(*************************************************************************)

pattern: pattern1 ("|" pattern1)* { }

pattern1: Boundvarid ":" typePat { }
 | "_" ":" typePat { }
 | pattern2 { }

pattern2: Id ("@" pattern3)? { }
 | pattern3 { }

pattern3: simplePattern { }
 | simplePattern (Id Nl? simplePattern)* { }

simplePattern: "_" { }
 | Varid { }
 | literal { }
 | stableId { }
 | stableId "(" patterns? ")" { }
 | stableId "(" (patterns ",")?(Id "@")? "_" "*" ")" { }
 | "(" patterns? ")" { }

(*----------------------------*)
(* *)
(*----------------------------*)

patterns:
 | pattern ("," patterns)? { }
 | "_" "*" { }

typeParamClause: "[" variantTypeParam ("," variantTypeParam)* "]" { }

funTypeParamClause: "[" typeParam ("," typeParam)* "]" { }

variantTypeParam: annotation*("+" | "-")? typeParam { }

typeParam: (Id | "_") typeParamClause?(">:" type)?("<:" type)?("<%" type)*(":" type)* { }

paramClauses: paramClause*(Nl? "(" "implicit" params ")")? { }

paramClause: Nl? "(" params? ")" { }

params: param ("," param)* { }

(*----------------------------*)
(* *)
(*----------------------------*)

param: annotation* Id (":" paramType)?("=" expr)? { }

paramType: type { }
 | "=>" type { }
 | type "*" { }

implicitClassParams: "(" "implicit" classParams ")" { }

classParamClauses: classParamClause*(Nl? implicitClassParams?) { }

classParamClause: Nl? "(" classParams? ")" { }

classParams: classParam ("," classParam)* { }

classParam: annotation* modifier*(("val" | "var"))? Id ":" paramType ("=" expr)? { }

bindings: "(" binding ("," binding)* ")" { }

binding: (Id | "_")(":" type)? { }

(*************************************************************************)
(* Annotations and modifiers *)
(*************************************************************************)

modifier:
 | localModifier { }
 | accessModifier { }
 | "override" { }

localModifier: "abstract" { }
 | "final" { }
 | "sealed" { }
 | "implicit" { }
 | "lazy" { }

accessModifier: ("private" | "protected") accessQualifier? { }

accessQualifier: "[" (Id | "this") "]" { }

annotation: "@" simpleType argumentExprs* { }

constrAnnotation: "@" simpleType argumentExprs { }

(*************************************************************************)
(* Template *)
(*************************************************************************)

templateBody: Nl? "{" selfType? templateStat (Semi templateStat)* "}" { }

templateStat: import { }
 | (annotation Nl?)* modifier* def { }
 | (annotation Nl?)* modifier* dcl { }
 | expr { }
 | /*Empty*/ { }

selfType:
 | Id (":" type)? "=>" { }
 | "this" ":" type "=>" { }

(*************************************************************************)
(* Import *)
(*************************************************************************)

import: "import" list_sep(importExpr, ",") { }

importExpr: stableId "." importExpr_1 { }

importExpr_1:
  | Id  { }
  | "_" { }
  | importSelectors { }

importSelectors: "{" seq2(importSelector, ",")* choice2(importSelector, "_") "}" { }

importSelector:
 | Id { }
 | Id "=>" Id  { }
 | Id "=>" "_" { }

(*************************************************************************)
(* Declarations *)
(*************************************************************************)

dcl: "val" valDcl { }
 | "var" varDcl { }
 | "def" funDcl { }
 | "type" Nl* typeDcl { }

valDcl: ids ":" type { }

varDcl: ids ":" type { }

funDcl: funSig (":" type)? { }

funSig: Id funTypeParamClause? paramClauses { }

typeDcl: Id typeParamClause?(">:" type)?("<:" type)? { }

(*************************************************************************)
(* Definitions *)
(*************************************************************************)

patVarDef: "val" patDef { }
 | "var" varDef { }

def: patVarDef { }
 | "def" funDef { }
 | "type" Nl* typeDef { }
 | tmplDef { }

patDef: pattern2 (":" type)? "=" expr { }

varDef: patDef { }
 | ids ":" type "=" "_" { }

funDef: funSig (":" type)? "=" expr { }
 | funSig Nl? "{" block "}" { }
 | "this" paramClause paramClauses ("=" constrExpr | Nl? constrBlock) { }

typeDef: Id typeParamClause? "=" type { }

tmplDef:
 | "case"? "class" classDef { }
 | "case"? "object" objectDef { }
 | "trait" traitDef { }

classDef: Id typeParamClause? constrAnnotation* accessModifier? classParamClauses classTemplateOpt { }

traitDef: Id typeParamClause? traitTemplateOpt { }


objectDef: Id classTemplateOpt { }

(*----------------------------*)
(* *)
(*----------------------------*)

classTemplateOpt:
 | "extends" classTemplate { }
 | ("extends"? templateBody)? { }

traitTemplateOpt: "extends" traitTemplate { }
 | ("extends"? templateBody)? { }

classTemplate: earlyDefs? classParents templateBody? { }

traitTemplate: earlyDefs? traitParents templateBody? { }

classParents: constr ("with" annotType)* { }

traitParents: annotType ("with" annotType)* { }

constr: annotType argumentExprs* { }

earlyDefs: "{" (earlyDef (Semi earlyDef)* )? "}" "with" { }

earlyDef: (annotation Nl?)* modifier* patVarDef { }

constrExpr:
 | selfInvocation { }
 | constrBlock { }

constrBlock: "{" selfInvocation (Semi blockStat)* "}" { }

selfInvocation: "this" argumentExprs argumentExprs* { }

(*************************************************************************)
(* Toplevel *)
(*************************************************************************)

topStatSeq_ext: list_sep(topStat_ext, Semi) { }

topStat_ext:
 | (annotation Nl?)* modifier* tmplDef { }
 | import { }
 | packaging { }
 | packageObject { }
 (* _ext *)
 | compilationUnit_1 { }

packaging: "package" qualId Nl? "{" topStatSeq_ext "}" { }

packageObject: "package" "object" objectDef { }

compilationUnit: (*compilationUnit_1* *) topStatSeq_ext EOF { }
compilationUnit_1: "package" qualId Semi { }
*)