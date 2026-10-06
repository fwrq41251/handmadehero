const std = @import("std");
const rl = @import("raylib");
const game = @import("game.zig");
const game_api = @import("game_api.zig");

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

    const samples = try std.heap.page_allocator.alloc(i16, buffer_size);
    defer std.heap.page_allocator.free(samples);
    var sound_buffer = game_api.SoundOutputBuffer{
        .samples = samples.ptr,
        .samples_count = buffer_size,
        .samples_per_second = sample_rate,
    };

    const perm_size = megaBytes(64);
    const trans_size = megaBytes(256);
    const perm_memory = try std.heap.page_allocator.alloc(u8, perm_size);
    defer std.heap.page_allocator.free(perm_memory);
    @memset(perm_memory, 0); // 确保开局全零
    const trans_memory = try std.heap.page_allocator.alloc(u8, trans_size);
    defer std.heap.page_allocator.free(trans_memory);

    var game_memory = game_api.Memory{
        .is_initialized = false,
        .permanent_storage_size = perm_size,
        .permanent_storage = perm_memory.ptr,
        .transient_storage_size = trans_size,
        .transient_storage = trans_memory.ptr,
    };

    game.getSoundSamples(&game_memory, &sound_buffer);
    rl.updateAudioStream(stream, sound_buffer.samples, buffer_size);
    game.getSoundSamples(&game_memory, &sound_buffer);
    rl.updateAudioStream(stream, sound_buffer.samples, buffer_size);

    // 两个子缓冲区满载，现在开始播放！
    rl.playAudioStream(stream);

    while (!rl.windowShouldClose()) {
        var new_input = game_api.Input{
            .delta_time = rl.getFrameTime(),
        };

        const keyboard = &new_input.controllers[0];
        keyboard.move_up.is_down = rl.isKeyDown(.w);
        keyboard.move_down.is_down = rl.isKeyDown(.s);
        keyboard.move_left.is_down = rl.isKeyDown(.a);
        keyboard.move_right.is_down = rl.isKeyDown(.d);

        var game_buffer = game_api.OffScreenBuffer{
            .memory = @ptrCast(pixels.ptr),
            .width = width,
            .height = height,
            .pitch = width * 4,
        };

        game.updateAndRender(&game_memory, &new_input, &game_buffer);

        rl.updateTexture(texture, pixels.ptr);

        rl.beginDrawing();
        rl.clearBackground(.black);
        rl.drawTexture(texture, 0, 0, .white);
        rl.endDrawing();

        // 持续检查并喂饱消耗掉的缓冲区
        while (rl.isAudioStreamProcessed(stream)) {
            game.getSoundSamples(&game_memory, &sound_buffer);
            rl.updateAudioStream(stream, sound_buffer.samples, buffer_size);
        }
    }
}

fn megaBytes(value: usize) usize {
    return value * 1024 * 1024;
}
