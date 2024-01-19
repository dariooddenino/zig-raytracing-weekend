const std = @import("std");
const interval = @import("interval.zig");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");

const Interval = interval.Interval;
const Vec3 = vec3.Vec3;
const Ray = ray.Ray;

pub const Aabb = struct {
    x: Interval = Interval{ .min = 0, .max = 0 },
    y: Interval = Interval{ .min = 0, .max = 0 },
    z: Interval = Interval{ .min = 0, .max = 0 },

    pub fn fromPoints(a: Vec3, b: Vec3) Aabb {
        // Treat the two points a and b as extrema for the bounding box, so we don't require a
        // particular minimum/maximum coordinate order.
        const x = Interval{ .min = @min(a[0], b[0]), .max = @max(a[0], b[0]) };
        const y = Interval{ .min = @min(a[1], b[1]), .max = @max(a[1], b[1]) };
        const z = Interval{ .min = @min(a[2], b[2]), .max = @max(a[2], b[2]) };

        return Aabb{ .x = x, .y = y, .z = z };
    }

    pub fn fromBoxes(box0: Aabb, box1: Aabb) Aabb {
        // TODO I think I'm missing a method here.
        const x = Interval{ .min = box0.x, .max = box1.x };
        const y = Interval{ .min = box0.y, .max = box1.y };
        const z = Interval{ .min = box0.z, .max = box1.z };

        return Aabb{ .x = x, .y = y, .z = z };
    }

    pub fn axis(self: Aabb, n: u32) Interval {
        if (n == 1) return self.y;
        if (n == 2) return self.z;
        return self.x;
    }

    pub fn hit(self: Aabb, r: Ray, ray_t: *Interval) bool {
        for (0..3) |a| {
            const invD = 1 / r.direction[a];
            const orig = r.origin[a];

            const t0: f32 = (self.axis[a].min - orig) * invD;
            const t1: f32 = (self.axis[a].max - orig) * invD;

            // NOTE: not sure if this is what I should use here for c++ std::swap
            if (invD < 0)
                std.mem.swap(f32, t0, t1);

            if (t0 > ray_t.min) ray_t.min = t0;
            if (t1 < ray_t.max) ray_t.max = t1;

            if (ray_t.max <= ray_t.min) return false;
        }
        return true;
    }
};
