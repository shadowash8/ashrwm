# rijan

A window manager for the [river](https://codeberg.org/river/river) Wayland compositor.

Not intended to be used by anyone but me currently, but might be useful
nonetheless for the capable and adventurous.

## Features

- Dynamic tiling
- Tags
	- Each window has exactly one tag
	- An arbitrary number of tags can be displayed at once on each output
	- Each tag can be displayed on at most one output at a time
- Floating windows
- A REPL

## Building

Run `zig build`. All dependencies will be fetched by Zig and built from source,
producing a statically linked `rijan` binary.

Requires Zig 0.15, a statically linked Zig binary can be obtained from https://ziglang.org/download/.
