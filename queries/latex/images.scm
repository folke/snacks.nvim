(inline_formula
  (#set! image.ext "math.tex"))
  @image.content @image

(displayed_equation
  (#set! image.ext "math.tex"))
  @image.content @image

((math_environment
  (#set! image.ext "math.tex"))
  @image.content @image
  (#not-has-ancestor? @image "displayed_equation" "math_environment"))

(graphics_include
  (_ (path) @image.src)
) @image

