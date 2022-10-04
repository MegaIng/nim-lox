import std/strutils
import std/setutils

import fusion/matching

import types
import lexer


using lex: var Lexer

proc parse_expr(lex; right_binding_power: int = 0): LoxASTNode {.raises:[LoxParseError].}


proc parse_atom(lex): LoxASTNode {.raises:[LoxParseError].} =
  case lex.peek_token():
    of NumberLiteral(value: @value):
      lex.consume()
      result = LoxASTNode(kind: lakLiteral, value: LoxObject(kind: lokNumber, number: value))
    of StringLiteral(str: @value):
      lex.consume()
      result = LoxASTNode(kind: lakLiteral, value: LoxObject(kind: lokString, str: value))
    of Keyword(name: "false"):
      lex.consume()
      result = LoxASTNode(kind: lakLiteral, value: loxFalse)
    of Keyword(name: "true"):
      lex.consume()
      result = LoxASTNode(kind: lakLiteral, value: loxTrue)
    of Identifier(name: @name):
      lex.consume()
      result = LoxASTNode(kind: lakVarUsage, var_name: name)
    of Operator(op: "("):
      lex.consume()
      result = lex.parse_expr()
      lex.consume(Operator(op: ")"))
    else:
      raise newException(LoxParseError, "Unknown Expression Start " & lex.peek_token().nice())


proc parse_precedence(lex; lhs: LoxASTNode, right_binding_power: int): LoxASTNode {.raises:[LoxParseError].} =
  result = lhs
  while true:
    case lex.peek_token():
      of Operator(op: "+"):
        if right_binding_power >= 50: return
        lex.consume()
        let right = lex.parse_expr(50)
        result = LoxASTNode(kind: lakBinOp, children: @[result, right], operator: lopkADD)
      of Operator(op: "-"):
        if right_binding_power >= 50: return
        lex.consume()
        let right = lex.parse_expr(50)
        result = LoxASTNode(kind: lakBinOp, children: @[result, right], operator: lopkSUB)
      of Operator(op: "*"):
        if right_binding_power >= 60: return
        lex.consume()
        let right = lex.parse_expr(60)
        result = LoxASTNode(kind: lakBinOp, children: @[result, right], operator: lopkMUL)
      of Operator(op: "/"):
        if right_binding_power >= 60: return
        lex.consume()
        let right = lex.parse_expr(60)
        result = LoxASTNode(kind: lakBinOp, children: @[result, right], operator: lopkDIV)
      of Operator(op: "=="):
        if right_binding_power >= 30: return
        lex.consume()
        let right = lex.parse_expr(30)
        result = LoxASTNode(kind: lakBinOp, children: @[result, right], operator: lopkEQ)
      of Operator(op: ">="):
        if right_binding_power >= 40: return
        lex.consume()
        let right = lex.parse_expr(40)
        result = LoxASTNode(kind: lakBinOp, children: @[result, right], operator: lopkGE)
      of Operator(op: "<="):
        if right_binding_power >= 40: return
        lex.consume()
        let right = lex.parse_expr(40)
        result = LoxASTNode(kind: lakBinOp, children: @[result, right], operator: lopkLE)
      of Operator(op: ">"):
        if right_binding_power >= 40: return
        lex.consume()
        let right = lex.parse_expr(40)
        result = LoxASTNode(kind: lakBinOp, children: @[result, right], operator: lopkGT)
      of Operator(op: "<"):
        if right_binding_power >= 40: return
        lex.consume()
        let right = lex.parse_expr(40)
        result = LoxASTNode(kind: lakBinOp, children: @[result, right], operator: lopkLT)
      of Operator(op: "="):
        if right_binding_power >= 10: return
        if result.kind != lakVarUsage:
          raise newException(LoxParseError, fmt"Invalid assignment target {result.kind}")
        lex.consume()
        let right = lex.parse_expr(10 - 1)
        result = LoxASTNode(kind: lakAssignment, var_name: result.var_name, children: @[right])
      else:
        return result


proc parse_expr(lex; right_binding_power: int = 0): LoxASTNode {.raises:[LoxParseError].} =
  result = lex.parse_atom()
  result = lex.parse_precedence(result, right_binding_power)


proc parse_stmt(lex): LoxASTNode {.raises:[LoxParseError].} =
  case lex.peek_token():
    of Keyword(name: "print"):
      lex.consume()
      result = LoxASTNode(kind: lakPrintStmt)
      result.children.add lex.parse_expr()
    of Keyword(name: "var"):
      lex.consume()
      let name = lex.peek_token()
      lex.consume(Identifier())
      lex.consume(Operator(op: "="))
      let init = lex.parse_expr()
      result = LoxASTNode(kind: lakVarDef, var_name: name.name, children: @[init])
    of Identifier(): # Assignments and calls
      let e = lex.parse_expr()
      result = LoxASTNode(kind: lakExprStmt, children: @[e])
    else:
      raise newException(LoxParseError, "Unknown Statement Start: " & lex.peek_token().nice())
  if not matches(lex.peek_token(), Operator(op: ";")):
    raise newException(LoxParseError, "Expected a Semicolon at the end of a statement, got " & lex.peek_token().nice())
  lex.consume()

proc parse_code*(code: string): LoxASTNode =
  var lex = Lexer(text: code)
  result = LoxASTNode(kind: lakStmtList)
  while lex.peek_token().kind != ltkEOF:
    result.children.add parse_stmt(lex)
