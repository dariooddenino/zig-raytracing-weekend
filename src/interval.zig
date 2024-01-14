const std = @import("std");
const rtweekend = @import("rtweekend.zig");

pub const Interval = struct {
    min: f32 = -rtweekend.infinity,
    max: f32 = rtweekend.infinity,

    pub fn contains(self: Interval, x: f32) bool {
        return self.min <= x and x <= self.max;
    }

    pub fn surrounds(self: Interval, x: f32) bool {
        return self.min < x and x < self.max;
    }
};

pub const empty = Interval{ .min = rtweekend.infinity, .max = -rtweekend.infinity };

pub const universe = Interval{};
