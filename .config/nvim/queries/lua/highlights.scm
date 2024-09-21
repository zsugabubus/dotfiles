[(false) (true)] @boolean

(comment) @comment @spell

(nil) @constant.builtin

(function_declaration
  name: (dot_index_expression field: (identifier) @function))
(function_declaration name: (identifier) @function)

((identifier) @function.builtin
  (#any-of? @function.builtin
    "assert"
    "error"
  ))

(function_call name: (dot_index_expression field: (identifier) @function.call))
(function_call name: (identifier) @function.call)

((identifier) @function.meta
  (#any-of? @function.meta
    "__add"
    "__band"
    "__bnot"
    "__bor"
    "__bxor"
    "__call"
    "__close"
    "__concat"
    "__div"
    "__eq"
    "__gc"
    "__idiv"
    "__index"
    "__le"
    "__len"
    "__lt"
    "__mod"
    "__mode"
    "__mul"
    "__name"
    "__newindex"
    "__pow"
    "__shl"
    "__shr"
    "__sub"
    "__unm"
  ))

(function_declaration name: (method_index_expression
  method: (identifier) @function.method))

(function_call name: (method_index_expression
  method: (identifier) @function.method.call))

"local" @keyword
(break_statement) @keyword
(do_statement ["do" "end"] @keyword)

(if_statement "end" @keyword.conditional)
["else" "elseif" "if" "then"] @keyword.conditional

(hash_bang_line) @keyword.directive

"function" @keyword.function
(function_declaration "end" @keyword.function)
(function_definition "end" @keyword.function)

["and" "not" "or"] @keyword.operator

(for_numeric_clause "=" @keyword.repeat)
(for_statement ["do" "end"] @keyword.repeat)
(while_statement ["do" "end"] @keyword.repeat)
["for" "in" "repeat" "until" "while"] @keyword.repeat

"return" @keyword.return

(label_statement) @label

(function_call name: (dot_index_expression
  table: (identifier) @module.builtin
  (#any-of? @module.builtin
    "coroutine"
    "debug"
    "io"
    "math"
    "os"
    "package"
    "string"
    "table"
    "utf8"
  )))

(number) @number

(assignment_statement "=" @operator)
(binary_expression [
  "%"
  "&"
  "*"
  "+"
  "-"
  ".."
  "/"
  "//"
  "<"
  "<<"
  "<="
  "=="
  ">"
  ">="
  ">>"
  "^"
  "|"
  "~"
  "~="
] @operator)
(unary_expression ["#" "-" "~"] @operator)

(string) @string @spell

(escape_sequence) @string.escape

((identifier) @variable.builtin
  (#any-of? @variable.builtin
    "_G"
    "_VERSION"
    "cls"
    "self"
  ))

(goto_statement "goto" @keyword (identifier) @label)

((dot_index_expression table: (identifier) @_table field: (identifier) @_field)
  (#eq? @_table "math")
  (#any-of? @_field
    "huge"
    "maxinteger"
    "mininteger"
    "pi"
  )) @constant.builtin
