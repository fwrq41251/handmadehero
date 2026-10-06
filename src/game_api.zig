pub const OffScreenBuffer = extern struct {
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

pub const ButtonState = extern struct {
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

pub const ControllerInput = extern struct {
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

pub const Input = extern struct {
    controllers: [5]ControllerInput = .{ .{}, .{}, .{}, .{}, .{} },
    delta_time: f32 = 0.0,
};

pub const SoundOutputBuffer = extern struct {
    samples: [*]i16,
    samples_count: usize = 0,
    samples_per_second: u32,
};

pub const Memory = extern struct {
    is_initialized: bool = false,
    permanent_storage_size: usize = 0,
    permanent_storage: [*]u8,

    transient_storage_size: usize = 0,
    transient_storage: [*]u8,
};

pub const UpdateAndRenderFn = *const fn (
    memory: *Memory,
    input: *const Input,
    buffer: *OffScreenBuffer,
) callconv(.c) void;

pub const GetSoundSamplesFn = *const fn (
    memory: *Memory,
    buffer: *SoundOutputBuffer,
) callconv(.c) void;
