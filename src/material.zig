const std = @import("std");
const rtweekend = @import("rtweekend.zig");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const objects = @import("objects.zig");
const textures = @import("textures.zig");

const Texture = textures.Texture;
const SolidColor = textures.SolidColor;

pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,
    dielectric: Dielectric,
    diffuse_light: DiffuseLight,

    pub fn scatter(self: Material, r_in: ray.Ray, rec: objects.HitRecord, attenuation: *vec3.Vec3, scattered: *ray.Ray) bool {
        switch (self) {
            inline else => |object| return object.scatter(r_in, rec, attenuation, scattered),
        }
    }

    pub fn emitted(self: Material, u: f32, v: f32, p: vec3.Vec3) vec3.Vec3 {
        switch (self) {
            .diffuse_light => |object| return object.emitted(u, v, p),
            inline else => |_| return vec3.Vec3{ 0, 0, 0 },
        }
    }
};

pub const Lambertian = struct {
    albedo: Texture,

    pub fn init(texture: Texture) Material {
        return Material{ .lambertian = Lambertian{ .albedo = texture } };
    }

    pub fn fromColor(color: vec3.Vec3) Material {
        return Material{ .lambertian = Lambertian{ .albedo = SolidColor.init(color) } };
    }

    pub fn scatter(self: Lambertian, r_in: ray.Ray, rec: objects.HitRecord, attenuation: *vec3.Vec3, scattered: *ray.Ray) bool {
        var scatter_direction = rec.normal + vec3.randomUnitVector();

        // Catch degenerate scatter direction
        if (vec3.nearZero(scatter_direction)) {
            scatter_direction = rec.normal;
        }

        scattered.* = ray.Ray{ .origin = rec.p, .direction = scatter_direction, .time = r_in.time };
        attenuation.* = self.albedo.value(rec.u, rec.v, rec.p);
        return true;
    }
};

pub const Metal = struct {
    albedo: vec3.Vec3,
    fuzz: f32 = 1,

    pub fn fromColor(color: vec3.Vec3, f: f32) Material {
        return Material{ .metal = Metal{ .albedo = color, .fuzz = if (f < 1) f else 1 } };
    }

    pub fn scatter(self: Metal, r_in: ray.Ray, rec: objects.HitRecord, attenuation: *vec3.Vec3, scattered: *ray.Ray) bool {
        const reflected = vec3.reflect(vec3.unitVector(r_in.direction), rec.normal);
        scattered.* = ray.Ray{ .origin = rec.p, .direction = reflected + vec3.splat3(self.fuzz) * vec3.randomUnitVector(), .time = r_in.time };
        attenuation.* = self.albedo;
        return vec3.dot(scattered.direction, rec.normal) > 0;
    }
};

pub const Dielectric = struct {
    ir: f32 = 1,

    pub fn init(ir: f32) Material {
        return Material{ .dielectric = Dielectric{ .ir = ir } };
    }

    pub fn scatter(self: Dielectric, r_in: ray.Ray, rec: objects.HitRecord, attenuation: *vec3.Vec3, scattered: *ray.Ray) bool {
        attenuation.* = vec3.Vec3{ 1, 1, 1 };
        const refraction_ratio = if (rec.front_face) (1.0 / self.ir) else self.ir;

        const unit_direction = vec3.unitVector(r_in.direction);

        const cos_theta = @min(vec3.dot(-unit_direction, rec.normal), 1.0);
        const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

        const cannot_refract = refraction_ratio * sin_theta > 1.0;
        var direction = vec3.zero();

        if (cannot_refract or reflectance(cos_theta, refraction_ratio) > rtweekend.randomDouble()) {
            direction = vec3.reflect(unit_direction, rec.normal);
        } else direction = vec3.refract(unit_direction, rec.normal, refraction_ratio);

        scattered.* = ray.Ray{ .origin = rec.p, .direction = direction, .time = r_in.time };
        return true;
    }
};

fn reflectance(cosine: f32, ref_idx: f32) f32 {
    // Use Schlick's approximation for reflectance.
    var r0 = (1 - ref_idx) / (1 + ref_idx);
    r0 = r0 * r0;
    return r0 + (1 - r0) * std.math.pow(f32, (1 - cosine), 5);
}

pub const DiffuseLight = struct {
    emit: Texture,

    pub fn init(texture: Texture) Material {
        return Material{ .diffuse_light = DiffuseLight{ .emit = texture } };
    }

    pub fn fromColor(color: vec3.Vec3) Material {
        return Material{ .diffuse_light = DiffuseLight{ .emit = SolidColor.init(color) } };
    }

    pub fn scatter(_: DiffuseLight, _: ray.Ray, _: objects.HitRecord, _: *vec3.Vec3, _: *ray.Ray) bool {
        return false;
    }

    pub fn emitted(self: DiffuseLight, u: f32, v: f32, p: vec3.Vec3) vec3.Vec3 {
        return self.emit.value(u, v, p);
    }
};
