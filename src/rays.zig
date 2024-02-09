const std = @import("std");
const vec = @import("vec.zig");

const Position = vec.Position;

pub const Ray = struct {
    origin: Position = vec.zero(),
    direction: Position = vec.zero(),
    time: f32 = 0.0,

    pub inline fn at(self: Ray, t: f32) Position {
        return self.origin + vec.splat3(t) * self.direction;
    }
};
