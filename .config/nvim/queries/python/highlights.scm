[(false) (true)] @boolean

(comment) @comment @spell

(none) @constant.builtin

((identifier) @constant.macro
  (#any-of? @constant.macro
    "__file__"
    "__name__"
  ))

(function_definition (identifier) @function)

(call function: [
  (attribute attribute: (identifier) @function.call)
  (identifier) @function.call
])
(decorator (call function: _ @function.call))
(decorator [(attribute) (identifier)] @function.call)

(decorator "@" @keyword)
(ellipsis) @keyword
[
  "as"
  "assert"
  "break"
  "continue"
  "del"
  "global"
  "nonlocal"
  "pass"
  "with"
] @keyword

["elif" "else" "if"] @keyword.conditional

(conditional_expression
  ["else" "if"] @keyword.conditional.ternary
  (#set! "priority" 101))

["async" "await"] @keyword.coroutine

"raise" @keyword.exception
(raise_statement "from" @keyword.exception)
["except" "finally" "try"] @keyword.exception

"def" @keyword.function
"lambda" @keyword.function

"import" @keyword.import
(future_import_statement "from" @keyword.import)
(import_from_statement "from" @keyword.import)

["and" "in" "is not" "is" "not in" "not" "or"] @keyword.operator

(while_statement "while" @keyword.repeat)
["for" "in"] @keyword.repeat

(yield "from" @keyword.return)
["return" "yield"] @keyword.return

"class" @keyword.type

(integer) @number

(float) @number.float

(assignment "=" @operator)
(augmented_assignment [
  "%="
  "&="
  "**="
  "*="
  "+="
  "-="
  "//="
  "/="
  "<<="
  ">>="
  "@="
  "^="
  "|="
] @operator)
(binary_operator [
  "%"
  "&"
  "*"
  "**"
  "+"
  "-"
  "/"
  "//"
  "<<"
  ">>"
  "@"
  "^"
  "|"
] @operator)
(comparison_operator ["!=" "<" "<=" "==" ">" ">="] @operator)
(named_expression ":=" @operator)
(unary_operator ["+" "-"] @operator)

(interpolation ["{" "}"] @punctuation.special)

[(string_content) (string_end) (string_start)] @string @spell

(class_definition body: (block
  .
  (expression_statement (string) @string.documentation (#set! "priority" 101))))
(function_definition body: (block
  .
  (expression_statement (string) @string.documentation (#set! "priority" 101))))
(module
  .
  (expression_statement (string) @string.documentation (#set! "priority" 101)))
((expression_statement (assignment))
  .
  (expression_statement (string) @string.documentation (#set! "priority" 101)))

(type (attribute attribute: (identifier) @type))
(type (generic_type (identifier) @type))
(type (identifier) @type)

(class_definition (identifier) @type.definition)

((identifier) @variable.builtin
  (#any-of? @variable.builtin
    "cls"
    "self"
  ))
