const std = @import("std");
const rl = @import("raylib");
const game = @import("game.zig");

const width = 800;
const height = 450;

pub fn main() !void {
    rl.initWindow(width, height, "Handmade Hero - Animated Backbuffer");
    defer rl.closeWindow();

    // 初始化音频设备
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

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

    const sample_rate: u32 = 44100; // 采样率 44.1 kHz
    const buffer_size: u32 = 4096; // 4096 已经足够稳定（约 92 毫秒）

    // 【修改 1】：必须在 loadAudioStream 之前告诉 Raylib 缓冲区的大小！
    rl.setAudioStreamBufferSizeDefault(buffer_size);

    // 创建裸音频流
    const stream = try rl.loadAudioStream(sample_rate, 16, 1);
    defer rl.unloadAudioStream(stream);

    var pcm_buffer: [buffer_size]i16 = undefined;
    var tone_hz: u32 = 256;
    const volume: i16 = 2500;
    var running_sample_index: u32 = 0;

    // 辅助函数：把正弦波填充逻辑封装一下，方便预填和每帧调用
    const generateSineWave = struct {
        fn fill(buf: []i16, hz: u32, vol: i16, s_rate: u32, run_idx: *u32) void {
            const pi = std.math.pi;
            for (buf) |*sample| {
                const t = @as(f32, @floatFromInt(run_idx.*)) / @as(f32, @floatFromInt(s_rate));
                const sine_ratio = @sin(2.0 * pi * @as(f32, @floatFromInt(hz)) * t);
                sample.* = @intFromFloat(sine_ratio * @as(f32, @floatFromInt(vol)));
                run_idx.* +%= 1;
            }
        }
    }.fill;

    // 【修改 2】：核心关键！在 Play 之前，连续 update 两次，填满两个子缓冲区（预热起跑）
    generateSineWave(&pcm_buffer, tone_hz, volume, sample_rate, &running_sample_index);
    rl.updateAudioStream(stream, &pcm_buffer, buffer_size);

    generateSineWave(&pcm_buffer, tone_hz, volume, sample_rate, &running_sample_index);
    rl.updateAudioStream(stream, &pcm_buffer, buffer_size);

    // 两个子缓冲区满载，现在开始播放！
    rl.playAudioStream(stream);

    while (!rl.windowShouldClose()) {
        var new_input = game.GameInput{
            .delta_time = rl.getFrameTime(),
        };

        const keyboard = &new_input.controllers[0];
        keyboard.move_up.is_down = rl.isKeyDown(.w);
        keyboard.move_down.is_down = rl.isKeyDown(.s);
        keyboard.move_left.is_down = rl.isKeyDown(.a);
        keyboard.move_right.is_down = rl.isKeyDown(.d);

        var game_buffer = game.GameOffScreenBuffer{
            .memory = @ptrCast(pixels.ptr),
            .width = width,
            .height = height,
            .pitch = width * 4,
        };

        game.gameUpdateAndRender(&new_input, &game_buffer);

        rl.updateTexture(texture, pixels.ptr);

        rl.beginDrawing();
        rl.clearBackground(.black);
        rl.drawTexture(texture, 0, 0, .white);
        rl.endDrawing();

        if (rl.isKeyDown(.up)) tone_hz +%= 1;
        if (rl.isKeyDown(.down) and tone_hz > 60) tone_hz -%= 1;

        // 持续检查并喂饱消耗掉的缓冲区
        while (rl.isAudioStreamProcessed(stream)) {
            generateSineWave(&pcm_buffer, tone_hz, volume, sample_rate, &running_sample_index);
            rl.updateAudioStream(stream, &pcm_buffer, buffer_size);
        }
    }
}
