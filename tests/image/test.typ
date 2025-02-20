
#figure(
  image("test.png", width: 80%),
  caption: [
    A step in the molecular testing
    pipeline of our lab.
  ],
)

#set page(width: auto, height: auto, margin: (x: 2pt, y: 2pt))
#set text(size: 12pt, fill: rgb("#FF0000"))
$ 5 + 5 = 10 $

$ E = g c^2 $

$ A = pi r^2 $

$ "area" = pi dot "radius"^2 $

$ cal(A) :=

    { x in RR | x "is natural" } $
#let x = 5

$ x < 17 $

$ (3x + y) / 7 &= 9 && "given" \
  3x + y &= 63 & "multiply by 7" \
  3x &= 63 - y && "subtract y" \
  x &= 21 - y/3 & "divide by 3" $
// snacks: header start
#let x = 5
// snacks: header end
$ #x <= 17 $
