const std = @import("std");
const vec3 = @import("vec3.zig");
const hittable = @import("hittable.zig");
const rays = @import("ray.zig");
const interval = @import("interval.zig");
const sphere = @import("sphere.zig");
const aabb = @import("aabb.zig");
const bvh = @import("bvh.zig");

const Aabb = aabb.Aabb;
const BVHTree = bvh.BVHTree;
const Interval = interval.Interval;
const Ray = rays.Ray;
const Sphere = sphere.Sphere;
const HitRecord = hittable.HitRecord;

pub const Hittable = union(enum) {
    sphere: Sphere,
    tree: BVHTree,

    pub fn hit(self: Hittable, r: rays.Ray, ray_t: Interval) ?HitRecord {
        switch (self) {
            inline else => |object| return object.hit(r, ray_t),
        }
    }

    pub fn boundingBox(self: Hittable) Aabb {
        switch (self) {
            inline else => |object| return object.boundingBox(),
        }
    }
};
