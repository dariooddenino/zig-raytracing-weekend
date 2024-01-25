const std = @import("std");
const vec3 = @import("vec3.zig");
const rays = @import("ray.zig");
const materials = @import("material.zig");
const intervals = @import("interval.zig");
const aabbs = @import("aabb.zig");
const bvhs = @import("bvh.zig");

const Aabb = aabbs.Aabb;
const BVHTree = bvhs.BVHTree;
const Interval = intervals.Interval;
const Material = materials.Material;
const Vec3 = vec3.Vec3;
const Ray = rays.Ray;

pub const HitRecord = struct {
    p: Vec3 = vec3.zero(),
    normal: Vec3 = vec3.zero(),
    mat: Material = undefined, // NOTE was a pointer
    t: f32 = 0,
    front_face: bool = false,

    pub fn setFaceNormal(self: *HitRecord, r: Ray, outward_normal: Vec3) void {
        // Sets the hit record normal vector.
        // NOTE: the parameter 'outward_normal' is assumed to have unit length.

        self.front_face = vec3.dot(r.direction, outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else -outward_normal;
    }
};

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

pub const Sphere = struct {
    center1: Vec3,
    radius: f32,
    mat: Material, // NOTE this was a pointer
    is_moving: bool = false,
    center_vec: Vec3 = vec3.zero(),
    bounding_box: Aabb = Aabb{},

    pub fn boundingBox(self: Sphere) Aabb {
        return self.bounding_box;
    }

    pub fn init(center1: Vec3, radius: f32, mat: Material) Hittable {
        const rvec = Vec3{ radius, radius, radius };
        return Hittable{ .sphere = Sphere{ .center1 = center1, .radius = radius, .mat = mat, .bounding_box = Aabb.fromPoints(center1 - rvec, center1 + rvec) } };
    }

    pub fn initMoving(center1: Vec3, center2: Vec3, radius: f32, mat: Material) Hittable {
        const rvec = Vec3{ radius, radius, radius };
        const box1 = Aabb.fromPoints(center1 - rvec, center1 + rvec);
        const box2 = Aabb.fromPoints(center2 - rvec, center2 + rvec);
        return Hittable{ .sphere = Sphere{ .center1 = center1, .radius = radius, .mat = mat, .center_vec = center2 - center1, .is_moving = true, .bounding_box = Aabb.fromBoxes(box1, box2) } };
    }

    pub fn getCenter(self: Sphere, time: f32) Vec3 {
        // Linearly interpolate from center1 to center2 according to time, where t=0 yields center1, and t=1
        // yields center2.
        return self.center1 + vec3.splat3(time) * self.center_vec;
    }

    pub fn hit(
        self: Sphere,
        r: Ray,
        ray_t: Interval,
    ) ?HitRecord {
        const center = if (self.is_moving) self.getCenter(r.time) else self.center1;
        const oc = r.origin - center;

        const a = vec3.lengthSquared(r.direction);
        const half_b = vec3.dot(oc, r.direction);
        const c = vec3.lengthSquared(oc) - self.radius * self.radius;
        const discriminant = half_b * half_b - a * c;
        if (discriminant < 0) return null;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (-half_b - sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            root = (-half_b + sqrtd) / a;
            if (!ray_t.surrounds(root)) return null;
        }

        var rec = HitRecord{};
        rec.t = root;
        rec.p = r.at(rec.t);
        const outward_normal = (rec.p - center) / vec3.splat3(self.radius);
        rec.setFaceNormal(r, outward_normal);
        rec.mat = self.mat;

        return rec;
    }
};
