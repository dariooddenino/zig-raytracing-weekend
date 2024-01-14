const std = @import("std");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");

pub const Sphere = struct {
    center: vec3.Vec3,
    radius: f32,

    pub fn hit(self: Sphere, r: ray.Ray, ray_tmin: f32, ray_tmax: f32, rec: *hittable.HitRecord) bool {
        const oc = vec3.sub(r.origin, self.center);

        const a = r.direction.lengthSquared();
        const half_b = vec3.dot(oc, r.direction);
        const c = oc.lengthSquared() - self.radius * self.radius;
        const discriminant = half_b * half_b - a * c;
        if (discriminant < 0) return false;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (-half_b - sqrtd) / a;
        if ((root <= ray_tmin) || (ray_tmax <= root)) {
            root = (-half_b + sqrtd) / a;
            if ((root <= ray_tmin) || (ray_tmax <= root)) return false;
        }

        rec.t = root;
        rec.p = r.at(rec.t);
        const outward_normal = vec3.div(vec3.sub(rec.p, self.center), self.radius);
        rec.setFaceNormal(r, outward_normal);

        return true;
    }
};
