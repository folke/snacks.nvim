(infirm_tag
  (tag_name) @tag (#eq? @tag "image")
  (tag_parameters (tag_param) @image.src)
) @image

(inline_math
  (#set! image.lang "latex")
  (#set! image.ext "math.tex")
) @image.content @image
