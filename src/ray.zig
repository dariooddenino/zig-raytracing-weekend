const std = @import("std");
const vec3 = @import("vec3.zig");

pub const Ray = struct {
    origin: vec3.Vec3 = vec3.Vec3{},
    direction: vec3.Vec3 = vec3.Vec3{},

    pub inline fn at(self: Ray, t: f32) vec3.Vec3 {
        return vec3.add(self.origin, vec3.mul(t, self.direction));
    }
};
