# Program still blocked by the application boundary

`gabs1.bend` is no longer blocked: the current Core runtime implements
`IO.write`, and its port now runs through generated JavaScript and native C.

- `gabs4.bend` reads two paths from argv, reads both files, and prints a Jaccard
  vocabulary report. Core now has file effects and a structural String/Char
  surface, but it still exposes no argument-vector effect. Replacing argv with
  hard-coded paths or host-selected environment variables would change the
  authored command-line interface, so the whole application remains explicitly
  unsupported. Its pure tokenizer can be ported separately if that becomes a
  useful kernel.

The verified Bend3 versions and `gabs4` fixtures remain under
`Bend-Programs/Bend3/programs/`.
