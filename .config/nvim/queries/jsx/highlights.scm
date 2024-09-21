(jsx_closing_element name: _ @tag (#match? @tag "^[A-Z]"))
(jsx_opening_element name: _ @tag (#match? @tag "^[A-Z]"))
(jsx_self_closing_element name: _ @tag (#match? @tag "^[A-Z]"))

(jsx_attribute (property_identifier) @tag.attribute)

(jsx_closing_element name: _ @tag.builtin (#match? @tag.builtin "^[a-z]"))
(jsx_opening_element name: _ @tag.builtin (#match? @tag.builtin "^[a-z]"))
(jsx_self_closing_element name: _ @tag.builtin (#match? @tag.builtin "^[a-z]"))
