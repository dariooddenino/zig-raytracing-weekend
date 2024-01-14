const std = @import("std");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");

pub const HitRecord = struct {
    p: vec3.Vec3,
    normal: vec3.Vec3,
    t: f32,
    front_face: bool,

    pub fn setFaceNormal(self: HitRecord, r: ray.Ray, outward_normal: vec3.Vec3) void {
        // Sets the hit record normal vector.
        // NOTE: the parametr 'outward_normal' is assumed to have unit length.

        self.front_face = vec3.dot(r.direction, outward_normal) < 0;
        self.normal = if (self.front_face) {
            return outward_normal;
        } else {
            return -outward_normal;
        };
    }
};
