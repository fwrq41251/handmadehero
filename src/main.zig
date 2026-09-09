const rl = @import("raylib");

pub fn main() void {
    rl.initWindow(800, 450, "Handmade Hero");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);
        rl.drawText("Hello, raylib-zig!", 250, 200, 24, .dark_gray);
    }
}
