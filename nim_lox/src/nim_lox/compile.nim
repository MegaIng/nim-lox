import fusion/matching

import types

type CompileContext = object
  bytecode: LoxBytecode
  names: seq[string]

using cc: var CompileContext

proc constant(cc; value: LoxObject): int =
  if value not_in cc.bytecode.constants:
    cc.bytecode.constants.add(value)
    return cc.bytecode.constants.len - 1
  else:
    return cc.bytecode.constants.find(value)

proc def_var_name(cc; var_name: string): int =
  if var_name in cc.names:
    raise newException(LoxParseError, "Variable already define: {var_name}")
  cc.names.add var_name

proc get_var_name(cc; var_name: string): int =
  if var_name not_in cc.names:
    raise newException(LoxParseError, "Variable not define: {var_name}")
  cc.names.add var_name

proc emit(cc; inst: LoxInstruction) =
  cc.bytecode.instructions.add inst

proc emit(cc; node: LoxASTNode) =
  case node:
    of StmtList():
      for child in node.children:
        cc.emit(child)
    of Literal(value: @value):
      cc.emit(LoxInstruction(kind: likLoadConstant, index: cc.constant(value)))
    of PrintStmt(children: [_]):
      cc.emit(node.children[0])
      cc.emit(LoxInstruction(kind: likPrint))
    of BinOp(children: @args is [_, _], operator: @op):
      for arg in args:
        cc.emit(arg)
      cc.emit(LoxInstruction(kind: likBinOp, op: op))
    of VarDef(var_name: @name, children: [_]):
      cc.emit(node.children[0])
      let i = cc.def_var_name(name)
      cc.emit LoxInstruction(kind: likStoreName, index: i)
    of Assignment(var_name: @name, children: [_]):
      cc.emit(node.children[0])
      let i = cc.get_var_name(name)
      cc.emit LoxInstruction(kind: likStoreName, index: i)
    of VarUsage(var_name: @name, children: []):
      let i = cc.get_var_name(name)
      cc.emit LoxInstruction(kind: likLoadName, index: i)
    else:
      raiseAssert fmt"Unknown ast node: {node.repr}"
    


proc compile*(ast: LoxASTNode): LoxBytecode =
  var cc: CompileContext
  cc.emit(ast)
  return cc.bytecode
