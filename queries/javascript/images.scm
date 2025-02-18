
(jsx_element
  (jsx_opening_element
    (identifier) @tag (#any-of? @tag "img" "Image")
    (jsx_attribute
      (property_identifier) @attr_name (#eq? @attr_name "src")
      (string (string_fragment) @image.src)
    )
  )
) @image

(jsx_self_closing_element
  (identifier) @tag (#any-of? @tag "img" "Image")
  (jsx_attribute
    (property_identifier) @attr_name (#eq? @attr_name "src")
    (string (string_fragment) @image.src)
  )
) @image
