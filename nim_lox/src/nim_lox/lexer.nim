import std/strutils
import std/setutils

import fusion/matching

import types


type Lexer* = object
  text*: string
  position: int
  line: int
  column: int
  queue: seq[LoxToken]
  include_ws*: bool
  include_comments*: bool

using lex: var Lexer

proc eof(lex; offset: int = 0): bool =
  return lex.position + offset >= lex.text.len

proc get(lex; offset: int = 0): char =
  return lex.text[lex.position + offset]

const OPERATOR_SYMBOLS = "!$%&/=*'+#;:,.-<>".toSet
const LONEOPERATOR_SYMBOLS = "()[]{}".toSet
const ID_START = {'a'..'z', 'A'..'Z', '_'}
const ID_CONTINUE = ID_START + {'0'..'9'}
const LOX_KEYWORDS = ["print", "false", "true", "var"]

proc advance*(lex) =
  if lex.get() == '\n':
    lex.line += 1
    lex.column = 1
  else:
    lex.column += 1
  lex.position += 1

proc read_token(lex): LoxToken {.raises: [LoxParseError].} =
  if lex.eof():
    return LoxToken(kind: ltkEOF)
  let start_position = lex.position
  let start_line = lex.line
  let start_column = lex.column
  defer:
    result.position = start_position
    result.line = start_line
    result.column = start_column
  case lex.get():
    of {' ', '\t', '\f', '\n', '\r'}:
      while not lex.eof() and lex.get() in {' ', '\t', '\f', '\n', '\r'}:
        lex.advance()
      LoxToken(kind: ltkWhitespace)
    of '/':
      if not lex.eof(1) and lex.get(1)=='/':
        while not lex.eof() and lex.get() not_in {'\n', '\r'}:
          lex.advance()
        LoxToken(kind: ltkComment)
      else:
        var value = ""
        while not lex.eof() and lex.get() in OPERATOR_SYMBOLS:
          value.add lex.get()
          lex.advance()
        LoxToken(kind: ltkOperator, op: value)
    of OPERATOR_SYMBOLS - {'/'}:
      var value = ""
      while not lex.eof() and lex.get() in OPERATOR_SYMBOLS:
        value.add lex.get()
        lex.advance()
      LoxToken(kind: ltkOperator, op: value)
    of LONEOPERATOR_SYMBOLS:
      lex.advance()
      LoxToken(kind: ltkOperator, op: $lex.get(-1))
    of ID_START:
      var value = ""
      while not lex.eof() and lex.get() in ID_CONTINUE:
        value.add lex.get()
        lex.advance()
      if value in LOX_KEYWORDS:
        LoxToken(kind: ltkKeyword, name: value)
      else:
        LoxToken(kind: ltkIdentifier, name: value)
    of '0'..'9':
      var value = ""
      while not lex.eof() and lex.get() in {'0'..'9', '.', 'e', 'E'}:
        value.add lex.get()
        lex.advance()
      try:
        LoxToken(kind: ltkNumberLiteral, value: parse_float(value))
      except ValueError:
        raise newException(LoxParseError, "Invalid Number literal " & value)
    of '"':
      var value = ""
      lex.advance()
      while not lex.eof() and lex.get() != '"':
        if lex.get() == '\\':
          lex.advance()
        value.add lex.get()
        lex.advance()
      if lex.eof():
        raise newException(LoxParseError, "Unexpected EOF file parsing String literal")
      else:
        lex.advance()
      LoxToken(kind: ltkStringLiteral, str: value)
    else:
      lex.advance()
      LoxToken(kind: ltkUnexpectedChar, c: lex.get(-1))

proc read_next_token(lex) {.raises:[LoxParseError].} =
  var ignore: set[LoxTokenKind]
  if not lex.include_ws:
    ignore.incl ltkWhitespace
  if not lex.include_comments:
    ignore.incl ltkComment
  var new_tok = lex.read_token()
  while new_tok.kind in ignore:
    new_tok = lex.read_token()
  lex.queue.add(new_tok)


proc peek_token*(lex): LoxToken {.raises:[LoxParseError].} =
  if lex.queue.len == 0:
    lex.read_next_token()
  return lex.queue[0]
proc consume*(lex) {.raises:[LoxParseError].} =
  if lex.queue.len == 0:
    lex.read_next_token()
  lex.queue.delete 0

template consume*(lex, pattern) {.dirty.} =
  if not matches(lex.peek_token(), pattern):
    raise newException(LoxParseError, fmt"Expected " & astToStr(pattern) & fmt", got {lex.peek_token().nice()}")
  else:
    lex.consume()
