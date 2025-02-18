
(element
  (start_tag
    (tag_name) @tag (#eq? @tag "img")
    (attribute
    (attribute_name) @attr_name (#eq? @attr_name "src")
    (quoted_attribute_value (attribute_value) @image.src)
    )
  )
) @image

(self_closing_tag
  (tag_name) @tag (#eq? @tag "img")
  (attribute
    (attribute_name) @attr_name (#eq? @attr_name "src")
    (quoted_attribute_value (attribute_value) @image.src)
  )
) @image

(element
  (start_tag (tag_name) @tag (#eq? @tag "svg"))
  (#set! image.ext "svg")
) @image @image.content
