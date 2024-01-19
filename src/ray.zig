const std = @import("std");
const vec3 = @import("vec3.zig");

pub const Ray = struct {
    origin: vec3.Vec3 = vec3.zero(),
    direction: vec3.Vec3 = vec3.zero(),

    pub inline fn at(self: Ray, t: f32) vec3.Vec3 {
        return self.origin + vec3.splat3(t) * self.direction;
    }
};
