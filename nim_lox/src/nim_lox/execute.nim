import std/options

import fusion/matching

import types

using frame: var LoxFrame

proc to_lox(b: bool): LoxObject =
  [false:loxFalse, true:loxTrue][b]
proc to_lox(n: float64): LoxObject =
  LoxObject(kind: lokNumber, number: n)
proc to_lox(s: string): LoxObject =
  LoxObject(kind: lokString, str: s)

proc binop(op: LoxOperatorKind; a, b: LoxObject): LoxObject {.raises: [LoxRuntimeError].} =
  if a.kind != b.kind:
    raise newException(LoxRuntimeError, fmt"Objects need to be of the same type, got {a.kind} and {b.kind}")
  case a.kind:
  of lokError:
    raise newException(LoxRuntimeError, "Trying to operator on error object")
  of lokBool:
    case op:
    of lopkEQ: to_lox(a.boolean == b.boolean)
    else:
      raise newException(LoxRuntimeError, fmt"Unsupported Operator for boolean values {op}")
  of lokNumber:
    case op:
    of lopkEQ: to_lox(a.number == b.number)
    of lopkGE: to_lox(a.number >= b.number)
    of lopkGT: to_lox(a.number > b.number)
    of lopkLE: to_lox(a.number <= b.number)
    of lopkLT: to_lox(a.number < b.number)
    of lopkADD: to_lox(a.number + b.number)
    of lopkSUB: to_lox(a.number - b.number)
    of lopkMUL: to_lox(a.number * b.number)
    of lopkDIV: to_lox(a.number / b.number)
    else:
      raise newException(LoxRuntimeError, fmt"Unsupported Operator for numbers {op}")
  of lokString:
    case op:
    of lopkEQ: to_lox(a.str == b.str)
    of lopkADD: to_lox(a.str & b.str)
    else:
      raise newException(LoxRuntimeError, fmt"Unsupported Operator for strings {op}")



proc step(frame) =
  frame.counter += 1
  case frame.code.instructions[frame.counter - 1]:
    of LoadConstant(index: @index):
      frame.stack.add frame.code.constants[index]
    of Print():
      echo frame.stack.pop()
    of BinOp(op: @op):
      let r = frame.stack.pop()
      let l = frame.stack.pop()
      frame.stack.add binop(op, l, r)
    else:
      raiseAssert "Unhandled Instruction " & frame.code.instructions[frame.counter - 1].repr

proc execute*(code: LoxBytecode): Option[LoxObject] =
  var frame: LoxFrame
  frame.code = code
  frame.counter = 0
  while frame.counter < frame.code.instructions.len:
    frame.step()  