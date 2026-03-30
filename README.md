# ashrwm

A window manager for the [river](https://codeberg.org/river/river) Wayland compositor.

ashrwm is currently around 700 lines of [Janet](https://janet-lang.org) but
capable enough to use as my daily driver. 

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

Run ashrwm inside [river](https://codeberg.org/river/river). Requires river's
main branch (version 0.4.0-dev). It may be useful to start ashrwm from river's
init script.

On startup ashrwm will evaluate `$XDG_CONFIG_HOME/ashrwm/config.janet` if the file
exists. If `$XDG_CONFIG_HOME` is not set, `~/.config/ashrwm/config.janet` will be
tried instead.

Passing a file to ashrwm as an argument will evaluate that file instead.

See [example/config.janet](example/config.janet).

## credits
ashrwm is a fork of [rijan](https://codeberg.org/ifreund/rijan)
