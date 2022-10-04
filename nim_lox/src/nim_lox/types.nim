import std/strformat


template fmt*(s: static string): string =
  try:
    strformat.fmt s
  except ValueError:
    raiseAssert("This doesn't happen")

type
  LoxOperatorKind* = enum
    lopkADD
    lopkSUB
    lopkMUL
    lopkDIV

    lopkEQ
    lopkGT
    lopkGE
    lopkLT
    lopkLE

  LoxObjectKind* = enum
    lokError
    lokNumber
    lokBool
    lokString

  LoxObject* = object
    case kind*: LoxObjectKind
    of lokError:
      discard
    of lokNumber:
      number*: float64
    of lokBool:
      boolean*: bool
    of lokString:
      str*: string
 
  LoxInstructionKind* = enum
    likLoadConstant
    likStoreName
    likLoadName
    likBinOp
    likPrint
  LoxInstruction* = object
    case kind*: LoxInstructionKind
    of likLoadConstant, likStoreName, likLoadName:
      index*: int
    of likBinOp:
      op*: LoxOperatorKind
    of likPrint:
      discard

  LoxBytecode* = object
    constants*: seq[LoxObject]
    instructions*: seq[LoxInstruction]
    var_count*: int

  LoxFrame* = object
    code*: LoxBytecode
    counter*: int
    stack*: seq[LoxObject]
    variables*: seq[LoxObject]
  
  LoxRuntimeError* = object of ValueError

proc `==`*(a, b: LoxObject): bool =
  if a.kind != b.kind:
    return false
  case a.kind:
  of lokError:
    return false
  of lokNumber:
    return a.number == b.number
  of lokBool:
    return a.boolean == b.boolean
  of lokString:
    return a.str == b.str

const loxFalse* = LoxObject(kind: lokBool, boolean: false)
const loxTrue* = LoxObject(kind: lokBool, boolean: true)

proc `$`*(o: LoxObject): string =
  case o.kind:
  of lokError:
    return "<Unitalized Object>"
  of lokNumber:
    return $o.number
  of lokBool:
    return $o.boolean
  of lokString:
    return $o.str

type
  LoxTokenKind* = enum
    ltkError
    ltkUnexpectedChar
    ltkEOF
    ltkWhitespace
    ltkNumberLiteral
    ltkStringLiteral
    ltkKeyword
    ltkIdentifier
    ltkOperator
    ltkComment

  LoxToken* = object
    position*: int
    line*: int
    column*: int
    case kind*: LoxTokenKind
    of ltkError, ltkEOF, ltkWhitespace, ltkComment: discard
    of ltkNumberLiteral:
      value*: float64
    of ltkStringLiteral:
      str*: string
    of ltkKeyword, ltkIdentifier:
      name*: string
    of ltkOperator:
      op*: string
    of ltkUnexpectedChar:
      c*: char



proc nice*(token: LoxToken): string {.raises: [].}=
  let body = case token.kind:
    of ltkError, ltkEOF, ltkWhitespace, ltkComment:
      ""
    of ltkNumberLiteral:
      $token.value
    of ltkKeyword, ltkIdentifier:
      $token.name
    of ltkStringLiteral:
      $token.str
    of ltkOperator:
      $token.op
    of ltkUnexpectedChar:
      "'" & $token.c & "'"
  fmt"{token.kind}({body}) at ({token.line}:{token.column} [{token.position}])"

type
  LoxASTKind* = enum
    lakError
    lakLiteral
    lakPrintStmt
    lakBinOp
    lakUnaryOp
    lakAssignment
    lakVarUsage
    lakVarDef
    lakStmtList
    lakExprStmt

  LoxASTNode* = object
    case kind*: LoxASTKind
    of lakError:
      discard
    of lakLiteral:
      value*: LoxObject
    of lakBinOp:
      operator*: LoxOperatorKind
    of lakAssignment, lakVarDef, lakVarUsage:
      var_name*: string
    else:
      discard
    children*: seq[LoxASTNode]
  LoxParseError* = object of ValueError
