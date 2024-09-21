; inherits: javascript

(mapped_type_clause "in" @keyword)
[
  "declare"
  "implements"
  "infer"
  "interface"
  "keyof"
  "module"
  "readonly"
  "satisfies"
  "type"
] @keyword

(conditional_type [":" "?"] @keyword.conditional.ternary)

(conditional_type "extends" @keyword.operator)

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
