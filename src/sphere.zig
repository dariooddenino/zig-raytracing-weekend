const std = @import("std");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const interval = @import("interval.zig");
const material = @import("material.zig");

pub const Sphere = struct {
    center: vec3.Vec3,
    radius: f32,
    mat: material.Material, // NOTE this was a pointer

    pub fn hit(self: Sphere, r: ray.Ray, ray_t: interval.Interval, rec: *hittable.HitRecord) bool {
        const oc = r.origin - self.center;

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
        const outward_normal = (rec.p - self.center) / vec3.splat3(self.radius);
        // const outward_normal = vec3.div(vec3.sub(rec.p, self.center), self.radius);
        rec.setFaceNormal(r, outward_normal);
        rec.mat = self.mat;

        return true;
    }
};
