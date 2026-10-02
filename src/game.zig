pub const GameOffScreenBuffer = struct {
    memory: [*]u8,
    width: u32,
    height: u32,
    pitch: usize,
    bytes_per_pixel: u32 = 4,

    pub fn getPixelAddress(self: *GameOffScreenBuffer, x: u32, y: u32) [*]u8 {
        return self.memory + (y * self.pitch) + (x * self.bytes_per_pixel);
    }

    pub fn setPixel(self: *GameOffScreenBuffer, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        const pixel_address = self.getPixelAddress(x, y);
        pixel_address[0] = r; // R
        pixel_address[1] = g; // G
        pixel_address[2] = b; // B
        pixel_address[3] = a; // A
    }
};

pub const GameButtonState = struct {
    is_down: bool = false,
    half_transition_count: u32 = 0,

    pub fn isDown(self: GameButtonState) bool {
        return self.is_down;
    }

    pub fn isReleased(self: GameButtonState) bool {
        return !self.is_down and self.half_transition_count == 1;
    }

    pub fn isPressed(self: GameButtonState) bool {
        return self.is_down and self.half_transition_count == 1;
    }
};

pub const GameControllerInput = struct {
    is_annalog: bool = false,

    // 摇杆的平均值(范围 -1.0 ~ 1.0)
    stick_average_x: f32 = 0.0,
    stick_average_y: f32 = 0.0,

    // 逻辑移动键
    move_up: GameButtonState = .{},
    move_down: GameButtonState = .{},
    move_left: GameButtonState = .{},
    move_right: GameButtonState = .{},

    // 动作键 (对应手柄的 A/B/X/Y)
    action_up: GameButtonState = .{},
    action_down: GameButtonState = .{},
    action_left: GameButtonState = .{},
    action_right: GameButtonState = .{},

    // 肩键
    left_shoulder: GameButtonState = .{},
    right_shoulder: GameButtonState = .{},

    // 功能键
    back: GameButtonState = .{},
    start: GameButtonState = .{},

    pub fn beginNewFrame(self: *GameControllerInput) void {
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
    controllers: [5]GameControllerInput = .{GameControllerInput{}} ** 5,
    delta_time: f32 = 0.0,
};

var offset_x: u8 = 0;
var offset_y: u8 = 0;

pub fn gameUpdateAndRender(input: *GameInput, buffer: *GameOffScreenBuffer) void {
    const controller = input.controllers[0];
    if (controller.move_up.isDown()) {
        offset_y -%= 2;
    }
    if (controller.move_down.isDown()) {
        offset_y +%= 2;
    }
    if (controller.move_left.isDown()) {
        offset_x -%= 2;
    }
    if (controller.move_right.isDown()) {
        offset_x +%= 2;
    }

    // 默认自增滚动
    offset_x +%= 1;
    offset_y +%= 1;

    for (0..buffer.height) |y| {
        for (0..buffer.width) |x| {
            const blue: u8 = @truncate(x);
            const green: u8 = @truncate(y);
            const red: u8 = 0;
            buffer.setPixel(@intCast(x), @intCast(y), red, green +% offset_y, blue +% offset_x, 255);
        }
    }
}
