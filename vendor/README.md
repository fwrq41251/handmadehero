# Vendored Raylib dependencies

The project pins Zig 0.16.0 and ZLS 0.16.0 in `mise.toml`.
`build/raylib.zig` compiles these pinned sources directly.
No package cache edits or dependency downloads are required to build.

- `raylib/src`: Raylib 6.0, https://github.com/raysan5/raylib/tree/6.0/src
  (original package hash: `raylib-6.0.0-whq8uCSwLgWWeF3ec3dbG6Rr36SLFL-s2WJ1Q_2E22Bb`).
- `raylib-zig/lib`: https://github.com/raylib-zig/raylib-zig/tree/8758f4cd3a5ae0df6941c4715257223d34c5ad3e/lib
  (original package hash: `raylib_zig-6.0.0-KE8RECZ8BQDm-txuospkpZHbJ6DNpacUF7D88RWQ_qAe`).

Licenses are included alongside each dependency; embedded dependencies retain
their upstream license notices. The desktop build uses GLFW and OpenGL 3.3,
with macOS frameworks, Linux X11 libraries, or Windows system libraries.
Web, Android, Wayland, and cross-compilation SDK provisioning are not configured.

To update, replace the vendored sources and bindings together, retain licenses,
record their versions here, and validate `zig build` and `zig build test`.
