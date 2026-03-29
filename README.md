# rijan

A window manager for the [river](https://codeberg.org/river/river) Wayland compositor.

Rijan is currently less than 600 lines of [Janet](https://janet-lang.org) but
capable enough to use as my daily driver. It's not really intended for use by
anyone else but may be an interesting starting point for others to fork off
their own window manager.

I'm not interested in feature requests for this project, but bug reports are
always welcome!

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

Install to path `zig build --prefix /usr/local`

Requires Zig 0.15, a statically linked Zig binary can be obtained from https://ziglang.org/download/.

## Usage

Run rijan inside [river](https://codeberg.org/river/river). Requires river's
main branch (version 0.4.0-dev). It may be useful to start rijan from river's
init script.

On startup rijan will evaluate `$XDG_CONFIG_HOME/rijan/init.janet` if the file
exists. If `$XDG_CONFIG_HOME` is not set, `~/.config/rijan/init.janet` will be
tried instead.

Passing a file to rijan as an argument will evaluate that file instead.

See [example/init.janet](example/init.janet).
