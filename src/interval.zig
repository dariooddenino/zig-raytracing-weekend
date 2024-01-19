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

    pub fn clamp(self: Interval, x: f32) f32 {
        if (x < self.min) return self.min;
        if (x > self.max) return self.max;
        return x;
    }

    pub fn size(self: Interval) f32 {
        return self.max - self.min;
    }

    pub fn expand(self: Interval, delta: f32) Interval {
        const padding = delta / 2.0;
        return Interval{ .min = self.min - padding, .max = self.max + padding };
    }
};

pub const empty = Interval{ .min = rtweekend.infinity, .max = -rtweekend.infinity };

pub const universe = Interval{};
