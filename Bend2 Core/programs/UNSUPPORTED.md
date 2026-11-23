# Unsupported programs

None. Under the old `bend2-core`, `gabs1` (prints a line) and `gabs4` (reads
two files named in argv and prints a Jaccard vocabulary report) were blocked.
The owner's later Core revision unblocked `gabs1` (Core gained `IO.write`), but
still lists `gabs4` as unsupported: Core has file effects and a String/Char
surface, but no argument-vector effect, and replacing argv with hard-coded
paths or environment variables would change the authored command-line
interface.

The latest Bend (bendlang/bend, `bend 2.0.40`) has `IO.args`, so both are
ported in this folder with their authored interfaces:

```sh
bend gabs1.bend                                          # You are not real
bend gabs4.bend fixtures/reference.txt fixtures/other.txt
# the texts are 61% alike (19 of 31 distinct words shared)
```

The Bend3 originals and fixtures remain under `Bend-Programs/Bend3/programs/`.
