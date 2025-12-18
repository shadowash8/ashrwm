const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const janet = b.dependency("janet", .{ .linkage = .dynamic });
    const janet_static = b.dependency("janet", .{ .linkage = .static });

    const spork = b.dependency("spork", .{});
    const rawterm = b.addLibrary(.{
        .name = "rawterm",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
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

    const janet_wayland = b.dependency("janet_wayland", .{});
    const wayland = b.dependency("wayland", .{ .linkage = .dynamic });
    const wayland_native = b.addLibrary(.{
        .name = "wayland-native",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .dynamic,
    });
    wayland_native.addCSourceFile(.{ .file = janet_wayland.path("src/wayland-native.c") });
    wayland_native.root_module.linkLibrary(janet.artifact("janet"));
    wayland_native.root_module.linkLibrary(wayland.artifact("wayland-client"));

    const wayland_static = b.dependency("wayland", .{ .linkage = .static });
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
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .dynamic,
    });
    xkbcommon_native.addCSourceFile(.{ .file = janet_xkbcommon.path("src/xkbcommon-native.c") });
    xkbcommon_native.root_module.linkLibrary(janet.artifact("janet"));
    xkbcommon_native.root_module.linkLibrary(xkbcommon.artifact("xkbcommon"));

    const xkbcommon_static = b.dependency("libxkbcommon", .{ .linkage = .static });
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

    const lemongrass = b.dependency("lemongrass", .{});

    const run = b.addRunArtifact(janet.artifact("janet-bin"));
    run.addFileArg(b.path("build-helper.janet"));
    run.addFileArg(b.path("src/main.janet"));
    const generated = run.addOutputFileArg("main.c");

    run.addArgs(&.{ "--mod", "wayland" });
    run.addFileArg(janet_wayland.path("src/wayland.janet"));

    run.addArgs(&.{ "--native", "wayland-native", "janet_module_entry_wayland_native" });
    run.addArtifactArg(wayland_native);

    run.addArgs(&.{ "--mod", "lemongrass" });
    run.addFileArg(lemongrass.path("init.janet"));

    run.addArgs(&.{ "--mod", "spork/sh" });
    run.addFileArg(spork.path("spork/sh.janet"));

    run.addArgs(&.{ "--mod", "spork/netrepl" });
    run.addFileArg(spork.path("spork/netrepl.janet"));

    run.addArgs(&.{ "--native", "spork/rawterm", "janet_module_entry_rawterm" });
    run.addArtifactArg(rawterm);

    run.addArgs(&.{ "--mod", "xkbcommon" });
    run.addFileArg(janet_xkbcommon.path("src/xkbcommon.janet"));

    run.addArgs(&.{ "--native", "xkbcommon-native", "janet_module_entry_xkbcommon_native" });
    run.addArtifactArg(xkbcommon_native);

    b.getInstallStep().dependOn(&run.step);

    const rijan = b.addExecutable(.{
        .name = "rijan",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });
    rijan.addCSourceFile(.{ .file = generated });
    rijan.linkLibrary(janet_static.artifact("janet"));
    rijan.linkLibrary(wayland_native_static);
    rijan.linkLibrary(rawterm_static);
    rijan.linkLibrary(xkbcommon_native_static);

    b.installArtifact(rijan);
}
