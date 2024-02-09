const std = @import("std");
const aabbs = @import("aabbs.zig");
const bvhs = @import("bvhs.zig");
const intervals = @import("intervals.zig");
const objects = @import("objects.zig");
const materials = @import("materials.zig");
const rays = @import("rays.zig");
const vec = @import("vec.zig");

const Aabb = aabbs.Aabb;
const BVHTree = bvhs.BVHTree;
const Interval = intervals.Interval;
const Material = materials.Material;
const Object = objects.Object;
const Position = vec.Position;
const Ray = rays.Ray;

pub const HitRecord = struct {
    p: Position = vec.zero(),
    normal: Position = vec.zero(),
    mat: *Material = undefined,
    t: f32 = 0,
    u: f32 = 0,
    v: f32 = 0,
    front_face: bool = false,

    pub fn setFaceNormal(self: *HitRecord, ray: Ray, outward_normal: Position) void {
        // Sets the hit record normal vector.
        // NOTE: the parameter 'outward_normal' is assumed to have unit length.

        self.front_face = vec.dot(ray.direction, outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else -outward_normal;
    }
};

pub const Hittable = union(enum) {
    object: *Object,
    tree: *BVHTree,

    pub fn boundingBox(self: Hittable) Aabb {
        switch (self) {
            inline else => |o| o.boundingBox(),
        }
    }

    pub fn hit(self: Hittable, ray: Ray, ray_t: Interval, hit_record: *HitRecord) bool {
        switch (self) {
            inline else => |o| o.hit(ray, ray_t, hit_record),
        }
    }
};
