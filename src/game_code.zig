const std = @import("std");

const api = @import("game_api.zig");

pub const Code = struct {
    library: std.DynLib,
    update_and_render: api.UpdateAndRenderFn,
    get_sound_samples: api.GetSoundSamplesFn,
    loaded: bool = false,

    pub fn load(path: []const u8) !Code {
        var library = try std.DynLib.open(path);
        errdefer library.close();

        const update_and_render = library.lookup(
            api.UpdateAndRenderFn,
            "updateAndRender",
        ) orelse return error.MissingUpdateAndRender;

        const get_sound_samples = library.lookup(
            api.GetSoundSamplesFn,
            "getSoundSamples",
        ) orelse return error.MissingGetSoundSamples;

        return Code{
            .library = library,
            .update_and_render = update_and_render,
            .get_sound_samples = get_sound_samples,
            .loaded = true,
        };
    }

    pub fn unload(self: *Code) void {
        if (self.loaded) {
            self.library.close();
            self.loaded = false;
        }
    }
};
