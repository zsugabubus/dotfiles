; inherits: javascript

(mapped_type_clause "in" @keyword)
(unary_expression "void" @keyword)
[
  "declare"
  "implements"
  "infer"
  "interface"
  "is"
  "keyof"
  "module"
  "namespace"
  "readonly"
  "satisfies"
  "type"
] @keyword

(conditional_type [":" "?"] @keyword.conditional.ternary)

(accessibility_modifier) @keyword.modifier

(conditional_type "extends" @keyword.operator)

"abstract" @keyword.type

(intersection_type "&" @operator)
(non_null_expression "!" @operator)
(union_type "|" @operator)

(literal_type [(null) (undefined)]) @type
(predefined_type) @type

((type_identifier) @type.builtin
  (#any-of? @type.builtin
    "Awaited"
    "Capitalize"
    "ConstructorParameters"
    "Exclude"
    "Extract"
    "InstanceType"
    "Lowercase"
    "NoInfer"
    "NonNullable"
    "Omit"
    "OmitThisParameter"
    "Parameters"
    "Partial"
    "Pick"
    "Readonly"
    "Record"
    "Required"
    "ReturnType"
    "ThisParameterType"
    "ThisType"
    "Uncapitalize"
    "Uppercase"
  ))
