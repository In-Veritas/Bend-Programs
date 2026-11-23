# A plain 2D `App.run` program runs ~3x slower on a CUDA machine than with `+RTS --gpu off`

## Description

`App.run` (Base) frees every shown frame with `Image.drop!(image)`, and on
Linux with CUDA the window effect also fills the frame through its device
kernel while the GPU is on. So any app, even one with no `!` of its own,
builds a `.gpu` file and moves every frame's quadtree across PCIe (managed
memory, page faults both ways). On this machine a trivial 1024 x 1024
checkerboard app shows about a third of the frames it shows with the GPU off.

Expected: a 2D app with no parallel call of its own runs at least as fast by
default as with `+RTS --gpu off` (or the GPU path is opt-in for App.run).
Actual: 93 frames in 5 s by default vs 284 frames with `--gpu off`.

`bend guide shaders` does warn that CUDA pages fault across PCIe, but here it is
the Base library, not the program, that puts the frame on the device.

## Reproduce

```sh
bend mre.bend -o /tmp/mre
timeout 5 /tmp/mre > on.txt                      # one "frame" line per frame
timeout 5 /tmp/mre +RTS --gpu off -RTS > off.txt
wc -l on.txt off.txt
```

(needs an X11 display; the window shows a checkerboard)

## Output

```
  93 on.txt
 284 off.txt
```

The real app (Bend2/water_movement, 1024 x 848, ~17k image nodes) shows the
same ratio: 54 vs 186 frames in 5 s.

## Environment

- bend 2.0.40
- Linux x86_64, NVIDIA Quadro RTX 3000 (driver 595.99.02), CUDA 13 at /usr/local/cuda
- Ubuntu clang version 21.1.8

## Workaround used in the port

None in code; Bend2/water_movement/GUIDE.md recommends running the native
binary with `+RTS --gpu off -RTS` on CUDA machines.

## Hit by

`Bend2/water_movement/main.bend` (native build of the App).

Also hit by `Bend3/demos/elements/elements.bend` and
`Bend3/demos/bar_bench/window_bar.bend` (640 x 400 App.run windows, 3k-12k
image nodes per frame, no `!` of their own), rebuilt with the latest
bendlang/bend source (6b806192): with the default GPU a frame takes 100-225 ms
(`elements --demo`, 300 frames, did not finish in 60 s; `window_bar --demo`
did not finish in 60 s), with `+RTS --gpu off -RTS` 17-60 ms (the paced 30 fps
demos finish in 11 s and 27 s). Deleting the `.gpu` file does not help: the
binary recompiles it on start. Same workaround documented in their READMEs.
