const rtweekend = @import("rtweekend.zig");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");

pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,

    pub fn scatter(self: Material, r_in: ray.Ray, rec: hittable.HitRecord, attenuation: *vec3.Vec3, scattered: *ray.Ray) bool {
        switch (self) {
            inline else => |object| return object.scatter(r_in, rec, attenuation, scattered),
        }
    }
};

pub const Lambertian = struct {
    albedo: vec3.Vec3,

    pub fn fromColor(color: vec3.Vec3) Lambertian {
        return Lambertian{ .albedo = color };
    }

    pub fn scatter(self: Lambertian, r_in: ray.Ray, rec: hittable.HitRecord, attenuation: *vec3.Vec3, scattered: *ray.Ray) bool {
        _ = r_in;
        var scatter_direction = vec3.add(rec.normal, vec3.randomUnitVector());

        // Catch degenerate scatter direction
        if (scatter_direction.nearZero()) {
            scatter_direction = rec.normal;
        }

        scattered.* = ray.Ray{ .origin = rec.p, .direction = scatter_direction };
        attenuation.* = self.albedo;
        return true;
    }
};

pub const Metal = struct {
    albedo: vec3.Vec3,

    pub fn fromColor(color: vec3.Vec3) Metal {
        return Metal{ .albedo = color };
    }

    pub fn scatter(self: Metal, r_in: ray.Ray, rec: hittable.HitRecord, attenuation: *vec3.Vec3, scattered: *ray.Ray) bool {
        const reflected = vec3.reflect(vec3.unitVector(r_in.direction), rec.normal);
        scattered.* = ray.Ray{ .origin = rec.p, .direction = reflected };
        attenuation.* = self.albedo;
        return true;
    }
};
