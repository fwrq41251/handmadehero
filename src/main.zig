const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    const width = 800;
    const height = 450;

    rl.initWindow(width, height, "Handmade Hero - Animated Backbuffer");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // CPU 上的 backbuffer，每个像素包含 RGBA 四个字节。
    const pixels = try std.heap.page_allocator.alloc(rl.Color, width * height);
    defer std.heap.page_allocator.free(pixels);

    // 创建一张 RGBA 纹理，只创建一次，之后每帧更新内容。
    const texture = blk: {
        const image = rl.genImageColor(width, height, .black);
        defer rl.unloadImage(image);

        break :blk try rl.loadTextureFromImage(image);
    };
    defer rl.unloadTexture(texture);

    var offset_x: u8 = 0;
    var offset_y: u8 = 0;

    while (!rl.windowShouldClose()) {
        // 1. 在 CPU 上逐像素生成蓝绿渐变。
        for (0..height) |y| {
            for (0..width) |x| {
                const blue: u8 = @truncate(x);
                const green: u8 = @truncate(y);

                pixels[y * width + x] = .{
                    .r = 0,
                    .g = green +% offset_y,
                    .b = blue +% offset_x,
                    .a = 255,
                };
            }
        }

        // 2. 将整块像素数据上传到已有的 GPU 纹理。
        rl.updateTexture(texture, pixels.ptr);

        // 3. 将纹理绘制到窗口。
        rl.beginDrawing();
        rl.clearBackground(.black);
        rl.drawTexture(texture, 0, 0, .white);
        rl.endDrawing();

        // +% 是回绕加法：255 + 1 变成 0。
        offset_x +%= 1;
        offset_y +%= 1;
    }
}
