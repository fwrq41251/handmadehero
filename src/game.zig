const std = @import("std");

pub const OffScreenBuffer = struct {
    memory: [*]u8,
    width: u32,
    height: u32,
    pitch: usize,
    bytes_per_pixel: u32 = 4,

    pub fn getPixelAddress(self: *OffScreenBuffer, x: u32, y: u32) [*]u8 {
        return self.memory + (y * self.pitch) + (x * self.bytes_per_pixel);
    }

    pub fn setPixel(self: *OffScreenBuffer, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        const pixel_address = self.getPixelAddress(x, y);
        pixel_address[0] = r; // R
        pixel_address[1] = g; // G
        pixel_address[2] = b; // B
        pixel_address[3] = a; // A
    }
};

pub const ButtonState = struct {
    is_down: bool = false,
    half_transition_count: u32 = 0,

    pub fn isDown(self: ButtonState) bool {
        return self.is_down;
    }

    pub fn isReleased(self: ButtonState) bool {
        return !self.is_down and self.half_transition_count == 1;
    }

    pub fn isPressed(self: ButtonState) bool {
        return self.is_down and self.half_transition_count == 1;
    }
};

pub const ControllerInput = struct {
    is_annalog: bool = false,

    // 摇杆的平均值(范围 -1.0 ~ 1.0)
    stick_average_x: f32 = 0.0,
    stick_average_y: f32 = 0.0,

    // 逻辑移动键
    move_up: ButtonState = .{},
    move_down: ButtonState = .{},
    move_left: ButtonState = .{},
    move_right: ButtonState = .{},

    // 动作键 (对应手柄的 A/B/X/Y)
    action_up: ButtonState = .{},
    action_down: ButtonState = .{},
    action_left: ButtonState = .{},
    action_right: ButtonState = .{},

    // 肩键
    left_shoulder: ButtonState = .{},
    right_shoulder: ButtonState = .{},

    // 功能键
    back: ButtonState = .{},
    start: ButtonState = .{},

    pub fn beginNewFrame(self: *ControllerInput) void {
        self.move_up.half_transition_count = 0;
        self.move_down.half_transition_count = 0;
        self.move_left.half_transition_count = 0;
        self.move_right.half_transition_count = 0;

        self.action_up.half_transition_count = 0;
        self.action_down.half_transition_count = 0;
        self.action_left.half_transition_count = 0;
        self.action_right.half_transition_count = 0;

        self.left_shoulder.half_transition_count = 0;
        self.right_shoulder.half_transition_count = 0;

        self.back.half_transition_count = 0;
        self.start.half_transition_count = 0;
    }
};

pub const GameInput = struct {
    controllers: [5]ControllerInput = .{ControllerInput{}} ** 5,
    delta_time: f32 = 0.0,
};

pub const SoundOutputBuffer = struct {
    samples: []i16,
    samples_per_second: u32,
};

pub const GameMemory = struct {
    is_initialized: bool = false,
    permanent_storage_size: usize = 0,
    permanent_storage: [*]u8,

    transient_storage_size: usize = 0,
    transient_storage: [*]u8,
};

pub const GameState = struct {
    tone_hz: f32 = 256.0,
    green_offset: u8 = 0,
    blue_offset: u8 = 0,
};

pub fn updateAndRender(memory: *GameMemory, input: *GameInput, buffer: *OffScreenBuffer) void {
    const state: *GameState = @ptrCast(@alignCast(memory.permanent_storage));

    if (!memory.is_initialized) {
        memory.is_initialized = true;
        state.tone_hz = 256.0;
        state.green_offset = 0;
        state.blue_offset = 0;
    }

    const controller = input.controllers[0];
    if (controller.move_up.isDown()) {
        state.green_offset -%= 2;
    }
    if (controller.move_down.isDown()) {
        state.green_offset +%= 2;
    }
    if (controller.move_left.isDown()) {
        state.blue_offset -%= 2;
    }
    if (controller.move_right.isDown()) {
        state.blue_offset +%= 2;
    }

    // 默认自增滚动
    state.green_offset +%= 1;
    state.blue_offset +%= 1;

    for (0..buffer.height) |y| {
        for (0..buffer.width) |x| {
            const blue: u8 = @truncate(x);
            const green: u8 = @truncate(y);
            const red: u8 = 0;
            buffer.setPixel(@intCast(x), @intCast(y), red, green +% state.green_offset, blue +% state.blue_offset, 255);
        }
    }
}

var running_sample_index: u32 = 0;

pub fn getSoundSamples(buffer: *SoundOutputBuffer) void {
    const tone_hz: f32 = 256.0;
    const volume: i16 = 2500;
    const sample_rate: f32 = @floatFromInt(buffer.samples_per_second);
    const phase_step: f32 = 2.0 * std.math.pi * tone_hz / sample_rate;

    for (0..buffer.samples.len) |i| {
        const index: f32 = @floatFromInt(running_sample_index);
        buffer.samples[i] = @intFromFloat(@sin(index * phase_step) * volume);
        running_sample_index +%= 1;
    }
}
