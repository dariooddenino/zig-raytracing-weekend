const std = @import("std");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const interval = @import("interval.zig");
const material = @import("material.zig");
const aabb = @import("aabb.zig");
const hittable_list = @import("hittable_list.zig");

const Aabb = aabb.Aabb;
const Vec3 = vec3.Vec3;
const Material = material.Material;
const Hittable = hittable_list.Hittable;
const HitRecord = hittable.HitRecord;

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

    // NOTE This name is misleading
    fn getSphereUV(p: Vec3, u: *f32, v: *f32) void {
        // p: a given point on the sphere of radius one, centered at the origin.
        // u: returned value [0,1] of angle around the Y axis from X=-1.
        // v: returned value [0,1] of angle from Y=-1 to Y=+1.
        //     <1 0 0> yields <0.50 0.50>       <-1  0  0> yields <0.00 0.50>
        //     <0 1 0> yields <0.50 1.00>       < 0 -1  0> yields <0.50 0.00>
        //     <0 0 1> yields <0.25 0.50>       < 0  0 -1> yields <0.75 0.50>

        const theta = std.math.acos(-p[1]);
        const phi = std.math.atan2(-p[2], p[0]) + std.math.pi;

        u.* = phi / (2 * std.math.pi);
        v.* = theta / std.math.pi;
    }

    pub fn hit(
        self: Sphere,
        r: ray.Ray,
        ray_t: interval.Interval,
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

        var rec = hittable.HitRecord{};
        rec.t = root;
        rec.p = r.at(rec.t);
        const outward_normal = (rec.p - center) / vec3.splat3(self.radius);
        rec.setFaceNormal(r, outward_normal);
        getSphereUV(outward_normal, &rec.u, &rec.v);
        rec.mat = self.mat;

        return rec;
    }
};
