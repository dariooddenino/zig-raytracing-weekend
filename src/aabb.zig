const std = @import("std");
const interval = @import("interval.zig");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");

const Interval = interval.Interval;
const Vec3 = vec3.Vec3;
const Ray = ray.Ray;

pub const Aabb = struct {
    x: Interval = Interval{},
    y: Interval = Interval{},
    z: Interval = Interval{},

    pub fn fromPoints(a: Vec3, b: Vec3) Aabb {
        // Treat the two points a and b as extrema for the bounding box, so we don't require a
        // particular minimum/maximum coordinate order.
        const x = Interval{ .min = @min(a[0], b[0]), .max = @max(a[0], b[0]) };
        const y = Interval{ .min = @min(a[1], b[1]), .max = @max(a[1], b[1]) };
        const z = Interval{ .min = @min(a[2], b[2]), .max = @max(a[2], b[2]) };

        return Aabb{ .x = x, .y = y, .z = z };
    }

    pub fn fromBoxes(box0: Aabb, box1: Aabb) Aabb {
        const x = interval.fromIntervals(box0.x, box1.x);
        const y = interval.fromIntervals(box0.y, box1.y);
        const z = interval.fromIntervals(box0.z, box1.z);

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
