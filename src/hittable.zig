const std = @import("std");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const material = @import("material.zig");

pub const HitRecord = struct {
    p: vec3.Vec3 = vec3.zero(),
    normal: vec3.Vec3 = vec3.zero(),
    mat: material.Material = undefined, // NOTE was a pointer
    t: f32 = 0,
    front_face: bool = false,

    pub fn setFaceNormal(self: *HitRecord, r: ray.Ray, outward_normal: vec3.Vec3) void {
        // Sets the hit record normal vector.
        // NOTE: the parameter 'outward_normal' is assumed to have unit length.

        self.front_face = vec3.dot(r.direction, outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else -outward_normal;
    }
};
