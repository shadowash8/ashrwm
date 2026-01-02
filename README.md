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

Run `zig build`. All dependencies will be fetched by Zig and built from source.

Requires Zig 0.15, a statically linked Zig binary can be obtained from https://ziglang.org/download/.

## Usage

On startup rijan will evaluate `$XDG_CONFIG_HOME/rijan/init.janet` if the file
exists. If `$XDG_CONFIG_HOME` is not set, `~/.config/rijan/init.janet` will be
tried instead.

Passing a file to rijan as an argument will evaluate that file instead.

See [example/init.janet](example/init.janet).
