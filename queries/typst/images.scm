(call
  (ident) @ident
  (#eq? @ident "image")
  (group (string) @image.src)
  (#offset! @image.src 0 1 0 -1)
) @image
