# Programs blocked by missing IO

- `gabs1.bend` only prints `You are not real`. Core has the `IO.OP` datatype
  shape but no print effect or scheduler, so there is no runnable semantic port.
- `gabs4.bend` reads two paths from argv, reads both files, and prints a Jaccard
  vocabulary report. Core has neither argv/filesystem effects nor the Bend3
  String/Char utility surface. Its pure tokenizer could be rewritten, but the
  authored program as a whole cannot run and would no longer test its intended
  IO path.

The verified Bend3 versions and `gabs4` fixtures remain under
`Bend-Programs/Bend3/programs/`.
