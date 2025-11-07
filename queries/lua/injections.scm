; extends

((comment
  content: (comment_content) @injection.language)
  (#lua-match? @injection.language "inject%s*:%s*%S+")
  (#gsub! @injection.language "^%s*inject%s*:%s*(%S+).*" "%1")
  .
  (_
    (string
      content: (string_content) @injection.content)))
