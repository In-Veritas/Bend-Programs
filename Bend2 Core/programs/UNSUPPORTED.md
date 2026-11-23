# Unsupported programs

None. Under the old `bend2-core`, `gabs1` (prints a line) and `gabs4` (reads
two files named in argv and prints a Jaccard vocabulary report) could not be
ported because Core had no effect runtime. Bend 2.0.40 has IO, so both are now
ported in this folder:

```sh
bend gabs1.bend                                          # You are not real
bend gabs4.bend fixtures/reference.txt fixtures/other.txt
# the texts are 61% alike (19 of 31 distinct words shared)
```

The Bend3 originals remain under `Bend-Programs/Bend3/programs/`.
