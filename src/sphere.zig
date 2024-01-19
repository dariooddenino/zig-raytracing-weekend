const std = @import("std");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const interval = @import("interval.zig");
const material = @import("material.zig");
const aabb = @import("aabb.zig");

const Aabb = aabb.Aabb;
const Vec3 = vec3.Vec3;
const Material = material.Material;

pub const Sphere = struct {
    center1: Vec3,
    radius: f32,
    mat: Material, // NOTE this was a pointer
    is_moving: bool = false,
    center_vec: Vec3 = vec3.zero(),
    bounding_box: Aabb = Aabb{},

    pub fn init(center1: Vec3, radius: f32, mat: Material) Sphere {
        const rvec = Vec3{ radius, radius, radius };
        return Sphere{ .center1 = center1, .radius = radius, .mat = mat, .bounding_box = Aabb.fromPoints(center1 - rvec, center1 + rvec) };
    }

    pub fn initMoving(center1: Vec3, center2: Vec3, radius: f32, mat: Material) Sphere {
        const rvec = Vec3(radius, radius, radius);
        const box1 = Aabb.fromPoints(center1 - rvec, center1 + rvec);
        const box2 = Aabb.fromPoints(center2 - rvec, center2 + rvec);
        return Sphere{ .center1 = center1, .radius = radius, .mat = mat, .center_vec = center2 - center1, .is_moving = true, .bounding_box = Aabb.fromBoxes(box1, box2) };
    }

    pub fn getCenter(self: Sphere, time: f32) Vec3 {
        // Linearly interpolate from center1 to center2 according to time, where t=0 yields center1, and t=1
        // yields center2.
        return self.center1 + vec3.splat3(time) * self.center_vec;
    }

    pub fn hit(self: Sphere, r: ray.Ray, ray_t: interval.Interval, rec: *hittable.HitRecord) bool {
        const center = if (self.is_moving) self.getCenter(r.time) else self.center1;
        const oc = r.origin - center;

        const a = vec3.lengthSquared(r.direction);
        const half_b = vec3.dot(oc, r.direction);
        const c = vec3.lengthSquared(oc) - self.radius * self.radius;
        const discriminant = half_b * half_b - a * c;
        if (discriminant < 0) return false;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (-half_b - sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            root = (-half_b + sqrtd) / a;
            if (!ray_t.surrounds(root)) return false;
        }

        rec.t = root;
        rec.p = r.at(rec.t);
        const outward_normal = (rec.p - center) / vec3.splat3(self.radius);
        // const outward_normal = vec3.div(vec3.sub(rec.p, self.center), self.radius);
        rec.setFaceNormal(r, outward_normal);
        rec.mat = self.mat;

        return true;
    }
};
