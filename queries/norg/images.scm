(infirm_tag
  (tag_name) @tag (#eq? @tag "image")
  (tag_parameters (tag_param) @image.src)
) @image

(
  (inline_math
    (#set! image.lang "latex")
    (#set! image.ext "math.tex")
  ) @image.content @image
  (#lua-match? @image.content "^$|.*|$$") ; remove `|` characters used in rigid math syntax
  (#gsub! @image.content "^$|" "$")
  (#gsub! @image.content "|$$" "$")
)

(
  (inline_math
    (#set! image.lang "latex")
    (#set! image.ext "math.tex")
  ) @image.content @image
  ; remove `\` prefix from escape sequences in normal math syntax
  (#lua-match? @image.content "^$[^|].*$$")
  (#gsub! @image.content "\\(.)" "%1")
)

(ranged_verbatim_tag
  (tag_name) @tagname
  (#eq? @tagname "math")
  (tag_parameters)?
  (ranged_verbatim_tag_content) @image.content
  (#set! injection.language "latex")
  (#set! image.ext "math.tex")
) @image
