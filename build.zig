const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const janet = b.dependency("janet", .{ .linkage = .dynamic });
    const janet_static = b.dependency("janet", .{
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });

    const spork = b.dependency("spork", .{});
    const rawterm = b.addLibrary(.{
        .name = "rawterm",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .link_libc = true,
        }),
        .linkage = .dynamic,
    });
    rawterm.addCSourceFile(.{ .file = spork.path("src/rawterm.c") });
    rawterm.root_module.linkLibrary(janet.artifact("janet"));

    const rawterm_static = b.addLibrary(.{
        .name = "rawterm",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });
    rawterm_static.addCSourceFile(.{
        .file = spork.path("src/rawterm.c"),
        .flags = &.{"-DJANET_ENTRY_NAME=janet_module_entry_rawterm"},
    });
    rawterm_static.root_module.linkLibrary(janet_static.artifact("janet"));

    const lemongrass = b.dependency("lemongrass", .{});
    const janet_wayland = b.dependency("janet_wayland", .{});
    const wayland = b.dependency("wayland", .{ .linkage = .dynamic });
    const wayland_native = b.addLibrary(.{
        .name = "wayland-native",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .link_libc = true,
        }),
        .linkage = .dynamic,
    });
    wayland_native.addCSourceFile(.{ .file = janet_wayland.path("src/wayland-native.c") });
    wayland_native.root_module.linkLibrary(janet.artifact("janet"));
    wayland_native.root_module.linkLibrary(wayland.artifact("wayland-client"));

    const wayland_static = b.dependency("wayland", .{
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });
    const wayland_native_static = b.addLibrary(.{
        .name = "wayland-native",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });
    wayland_native_static.addCSourceFile(.{
        .file = janet_wayland.path("src/wayland-native.c"),
        .flags = &.{"-DJANET_ENTRY_NAME=janet_module_entry_wayland_native"},
    });
    wayland_native_static.root_module.linkLibrary(janet_static.artifact("janet"));
    wayland_native_static.root_module.linkLibrary(wayland_static.artifact("wayland-client"));

    const janet_xkbcommon = b.dependency("janet_xkbcommon", .{});
    const xkbcommon = b.dependency("libxkbcommon", .{ .linkage = .dynamic });
    const xkbcommon_native = b.addLibrary(.{
        .name = "xkbcommon-native",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .link_libc = true,
        }),
        .linkage = .dynamic,
    });
    xkbcommon_native.addCSourceFile(.{ .file = janet_xkbcommon.path("src/xkbcommon-native.c") });
    xkbcommon_native.root_module.linkLibrary(janet.artifact("janet"));
    xkbcommon_native.root_module.linkLibrary(xkbcommon.artifact("xkbcommon"));

    const xkbcommon_static = b.dependency("libxkbcommon", .{
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });
    const xkbcommon_native_static = b.addLibrary(.{
        .name = "xkbcommon-native",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });
    xkbcommon_native_static.addCSourceFile(.{
        .file = janet_xkbcommon.path("src/xkbcommon-native.c"),
        .flags = &.{"-DJANET_ENTRY_NAME=janet_module_entry_xkbcommon_native"},
    });
    xkbcommon_native_static.root_module.linkLibrary(janet_static.artifact("janet"));
    xkbcommon_native_static.root_module.linkLibrary(xkbcommon_static.artifact("xkbcommon"));

    const gen_protocols = b.addRunArtifact(janet.artifact("janet-bin"));
    gen_protocols.addFileArg(b.path("build/gen-protocols.janet"));
    const protocols_image = gen_protocols.addOutputFileArg("protocols.jimage");
    gen_protocols.addFileArg(wayland.namedLazyPath("wayland-xml"));
    const wayland_protocols = b.dependency("wayland_protocols", .{});
    gen_protocols.addDirectoryArg(wayland_protocols.path("."));
    const river = b.dependency("river", .{});
    gen_protocols.addDirectoryArg(river.path("protocol"));

    const gen_c = b.addRunArtifact(janet.artifact("janet-bin"));
    // This is necessary to re-run every build to ensure changes to
    // janet files in src other than main.janet are picked up.
    // TODO better integrate into the zig build cache.
    gen_c.has_side_effects = true;
    gen_c.addFileArg(b.path("build/gen-c-source.janet"));
    gen_c.addFileArg(b.path("src/main.janet"));
    _ = gen_c.addOutputFileArg("image.jimage");
    const generated = gen_c.addOutputFileArg("main.c");

    gen_c.addArgs(&.{ "--image", "protocols" });
    gen_c.addFileArg(protocols_image);

    gen_c.addArgs(&.{ "--source", "wayland" });
    gen_c.addFileArg(janet_wayland.path("src/wayland.janet"));

    gen_c.addArgs(&.{ "--native", "wayland-native", "janet_module_entry_wayland_native" });
    gen_c.addArtifactArg(wayland_native);

    gen_c.addArgs(&.{ "--source", "lemongrass" });
    gen_c.addFileArg(lemongrass.path("init.janet"));

    gen_c.addArgs(&.{ "--source", "spork/sh" });
    gen_c.addFileArg(spork.path("spork/sh.janet"));

    gen_c.addArgs(&.{ "--source", "spork/netrepl" });
    gen_c.addFileArg(spork.path("spork/netrepl.janet"));

    gen_c.addArgs(&.{ "--native", "spork/rawterm", "janet_module_entry_rawterm" });
    gen_c.addArtifactArg(rawterm);

    gen_c.addArgs(&.{ "--source", "xkbcommon" });
    gen_c.addFileArg(janet_xkbcommon.path("src/xkbcommon.janet"));

    gen_c.addArgs(&.{ "--native", "xkbcommon-native", "janet_module_entry_xkbcommon_native" });
    gen_c.addArtifactArg(xkbcommon_native);

    b.getInstallStep().dependOn(&gen_c.step);

    const rijan = b.addExecutable(.{
        .name = "rijan",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    rijan.addCSourceFile(.{ .file = generated });
    rijan.linkLibrary(janet_static.artifact("janet"));
    rijan.linkLibrary(wayland_native_static);
    rijan.linkLibrary(rawterm_static);
    rijan.linkLibrary(xkbcommon_native_static);

    b.installArtifact(rijan);
}
