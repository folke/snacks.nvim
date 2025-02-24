(declaration
  (call_expression
    (function_name) @fn (#eq? @fn "url")
    (arguments  [
      (plain_value) @image.src
      (string_value) @image.src
      ; Remove quotes from the image URL
      (#gsub! @image.src "^['\"]" "")
      (#gsub! @image.src "['\"]$" "")
    ]))
) @image
