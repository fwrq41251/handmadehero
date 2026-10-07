const std = @import("std");

// Compile the vendored desktop sources without evaluating upstream build scripts.
pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const native = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    native.addIncludePath(b.path("vendor/raylib/src"));
    native.addIncludePath(b.path("vendor/raylib/src/platforms"));
    native.addIncludePath(b.path("vendor/raylib/src/external/glfw/include"));
    native.addCMacro("PLATFORM_DESKTOP_GLFW", "");
    native.addCMacro("GRAPHICS_API_OPENGL_33", "");
    native.addCMacro("_GNU_SOURCE", "");
    native.addCMacro("GL_SILENCE_DEPRECATION", "199309L");
    native.addCSourceFiles(.{
        .root = b.path("vendor/raylib/src"),
        .files = &.{ "rcore.c", "rshapes.c", "rtextures.c", "rtext.c", "rmodels.c", "raudio.c" },
        .flags = &.{"-std=c99"},
    });

    const bindings = b.createModule(.{
        .root_source_file = b.path("vendor/raylib-zig/lib/raylib.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    switch (target.result.os.tag) {
        .macos => {
            native.addCSourceFile(.{
                .file = b.path("vendor/raylib/src/rglfw.c"),
                .flags = &.{ "-std=c99", "-ObjC" },
            });
            for ([_][]const u8{ "Foundation", "CoreServices", "CoreGraphics", "AppKit", "IOKit" }) |framework| {
                bindings.linkFramework(framework, .{});
            }
        },
        .linux => {
            native.addCMacro("_GLFW_X11", "");
            native.addCSourceFile(.{ .file = b.path("vendor/raylib/src/rglfw.c"), .flags = &.{"-std=c99"} });
            for ([_][]const u8{ "GL", "X11", "Xrandr", "Xinerama", "Xi", "Xcursor", "m", "dl", "pthread" }) |library| {
                bindings.linkSystemLibrary(library, .{});
            }
        },
        .windows => {
            native.addCSourceFile(.{ .file = b.path("vendor/raylib/src/rglfw.c"), .flags = &.{"-std=c99"} });
            for ([_][]const u8{ "opengl32", "winmm", "gdi32" }) |library| {
                bindings.linkSystemLibrary(library, .{});
            }
        },
        else => @panic("The Raylib build supports macOS, Linux (X11), and Windows desktop targets"),
    }

    const library = b.addLibrary(.{ .name = "raylib", .linkage = .static, .root_module = native });
    bindings.linkLibrary(library);
    return bindings;
}
