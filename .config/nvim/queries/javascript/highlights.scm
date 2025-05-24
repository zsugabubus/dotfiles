[(false) (true)] @boolean

(comment) @comment @spell

[(null) (undefined)] @constant.builtin

(new_expression constructor: (identifier) @constructor)

(variable_declarator name: (identifier) @function value: (arrow_function))

(call_expression function: [
  (identifier) @function.call
  (member_expression property: (property_identifier) @function.call)
])

(method_definition name: (property_identifier) @function.method)

(class_body (method_definition name: ((property_identifier) @keyword
  (#eq? @keyword "constructor"))))
(export_specifier name: (identifier) @keyword (#eq? @keyword "default"))
(import_specifier name: (identifier) @keyword (#eq? @keyword "default"))
[
  "as"
  "break"
  "catch"
  "const"
  "continue"
  "export"
  "extends"
  "finally"
  "function"
  "let"
  "new"
  "try"
  "var"
  (super)
] @keyword

["case" "default" "else" "if" "switch"] @keyword.conditional

(ternary_expression [":" "?"] @keyword.conditional.ternary)

["async" "await"] @keyword.coroutine

"debugger" @keyword.debug

"throw" @keyword.exception

["from" "import"] @keyword.import

(binary_expression "in" @keyword.operator)
["instanceof" "typeof"] @keyword.operator

(for_in_statement "in" @keyword.repeat)
["do" "for" "of" "while"] @keyword.repeat

["return" "yield"] @keyword.return

"class" @keyword.type

(number) @number

(arrow_function "=>" @operator)
(binary_expression [
  "!="
  "!=="
  "&"
  "&&"
  "+"
  "-"
  "<"
  "<="
  "=="
  "==="
  ">"
  ">="
  "??"
  "|"
  "||"
] @operator)
(unary_expression ["!" "+" "-"] @operator)

(regex) @string
[(string) (template_string)] @string @spell

(class_declaration name: (type_identifier) @type.definition)

(this) @variable.builtin
((identifier) @variable.builtin
  (#any-of? @variable.builtin
    "arguments"
    "console"
    "document"
    "module"
    "window"
  ))

(function_declaration
  ["async" "function"] @keyword.function
  name: (identifier) @function)

(generator_function_declaration
  ["async" "function"] @keyword.function
  name: (identifier) @function)
