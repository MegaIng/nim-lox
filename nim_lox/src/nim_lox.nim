import os
import nim_lox/parse
import nim_lox/compile
import nim_lox/execute

proc execute_string*(code: string) =
  let ast = parse_code(code)
  let bytecode = compile(ast)
  discard execute(bytecode)

proc execute_file*(file_path: string) =
  let contents = read_file(file_path)
  execute_string(contents)

when isMainModule:
  let file_path = paramStr(1)
  execute_file(file_path)
