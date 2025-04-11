; extends

(fenced_code_block
  (info_string (language) @lang)
  (#eq? @lang "math")
  (code_fence_content) @image.content
  (#set! injection.language "latex")
  (#set! image.ext "math.tex")
) @image

(fenced_code_block
  (info_string (language) @lang)
  (#eq? @lang "mermaid")
  (code_fence_content) @image.content
  (#set! injection.language "mermaid")
  (#set! image.ext "chart.mmd")
) @image
