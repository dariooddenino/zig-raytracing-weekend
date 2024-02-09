const std = @import("std");
const aabbs = @import("aabbs.zig");
const hittables = @import("hittables.zig");
const intervals = @import("intervals.zig");
const materials = @import("materials.zig");
const rays = @import("rays.zig");
const vec = @import("vec.zig");

const Aabb = aabbs.Aabb;
const HitRecord = hittables.HitRecord;
const Interval = intervals.Interval;
const Material = materials.Material;
const Position = vec.Position;
const Ray = rays.Ray;
const Vec3 = vec.Vec3;

pub const Object = struct {
    position: Position,
    scale: Vec3,
    material: *Material,
    shape: *Shape,

    pub fn init(position: Position, scale: Vec3, material: *Material, shape: *Shape) Object {
        return Object{ position, scale, material, shape };
    }

    pub fn hit(self: Object, ray: Ray, ray_t: Interval, hit_record: *HitRecord) bool {
        return self.shape.hit(self.position, self.scale, ray, ray_t, hit_record, self.position, self.scale);
    }
};

pub const Shape = union(enum) {
    sphere: Sphere,

    pub fn hit(self: Shape, ray: Ray, ray_t: Interval, hit_record: *HitRecord, position: Position, scale: Vec3) bool {
        return switch (self) {
            inline else => |o| o.hit(ray, ray_t, hit_record, position, scale),
        };
    }
};

pub const Sphere = struct {
    radius: f32,
    bounding_box: Aabb,

    pub fn init(radius: f32) Shape {
        const bounding_box = Aabb.fromPoints(vec.splat3(-radius), vec.splat3(radius));
        return Shape{ .sphere = Sphere{ .radius = radius, .bounding_box = bounding_box } };
    }

    pub fn hit(self: Sphere, ray: Ray, ray_t: Interval, hit_record: *HitRecord, position: Position, scale: Vec3) bool {
        // Move the ray to the object's space
        // TODO this scale thing is completely random.
        const r = Ray{ .origin = (ray.origin - position) / scale, .direction = (ray.direction - position) / scale, .time = ray.time };
        const center = vec.splat3(0);
        const oc = r.origin - center;

        const a = vec.lengthSquared(r.direction);
        const half_b = vec.dot(oc, r.direction);
        const c = vec.lengthSquared(oc) - self.radius * self.radius;
        const discriminant = half_b * half_b - a * c;
        if (discriminant < 0) return false;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (-half_b - sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            root = (-half_b + sqrtd) / a;
            if (!ray_t.surrounds(root)) return false;
        }

        hit_record.t = root;
        hit_record.p = r.at(hit_record.t);
        const outward_normal = (hit_record.p - center) / vec.splat3(self.radius);
        hit_record.setFaceNormal(r, outward_normal);
        // getSphereUV(outward_normal, &rec.u, &rec.v);
        hit_record.mat = self.mat;

        return true;
    }
};
