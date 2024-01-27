const std = @import("std");
const interval = @import("interval.zig");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const rtweekend = @import("rtweekend.zig");
const objects = @import("objects.zig");

const Interval = interval.Interval;
const Vec3 = vec3.Vec3;
const Ray = ray.Ray;
const HitRecord = objects.HitRecord;

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
        const x = interval.fromIntervals(box0.x, box1.x);
        const y = interval.fromIntervals(box0.y, box1.y);
        const z = interval.fromIntervals(box0.z, box1.z);

        return Aabb{ .x = x, .y = y, .z = z };
    }

    pub fn axis(self: Aabb, n: usize) Interval {
        if (n == 1) return self.y;
        if (n == 2) return self.z;
        return self.x;
    }

    // pub fn hit(self: Aabb, r: Ray, ray_t: *Interval) bool {
    //     for (0..3) |a| {
    //         // std.debug.print("\nLOOP {d}\n", .{a});
    //         // std.debug.print("Initial {} {d} {d}\n", .{ self.axis(a), r.origin[a], r.direction[a] });

    //         // std.debug.print("CALC {d}\n", .{self.axis(a).min - r.origin[a]});

    //         // NOTE: Temp hack
    //         const t0 = @min((self.axis(a).min - r.origin[a]) / r.direction[a], (self.axis(a).max - r.origin[a]) / r.direction[a]);
    //         const t1 = @max((self.axis(a).min - r.origin[a]) / r.direction[a], (self.axis(a).max - r.origin[a]) / r.direction[a]);
    //         // std.debug.print("T0 {d} T1 {d}\n", .{ t0, t1 });
    //         // std.debug.print("PRE ray_t {}\n", .{ray_t});

    //         ray_t.min = @max(t0, ray_t.min);
    //         ray_t.max = @min(t1, ray_t.max);

    //         // std.debug.print("POST ray_t {}\n", .{ray_t});

    //         if (ray_t.max <= ray_t.min) return false;
    //     }
    //     return true;
    // }

    pub fn hit(self: Aabb, r: Ray, ray_t: Interval) bool {
        var ray_t_min = ray_t.min;
        var ray_t_max = ray_t.max;

        for (0..3) |a| {
            const invD = 1 / r.direction[a];
            const orig = r.origin[a];

            // std.debug.print("\nLOOP {d}\n", .{a});
            // std.debug.print("Initial {d} {d}\n", .{ invD, orig });

            var t0: f32 = (self.axis(@intCast(a)).min - orig) * invD;
            var t1: f32 = (self.axis(@intCast(a)).max - orig) * invD;

            if (invD < 0) {
                // std.debug.print("SWAPPING\n", .{});
                const temp = t1;
                t1 = t0;
                t0 = temp;
            }
            // std.mem.swap(f32, t0, t1);
            // std.debug.print("T0 {d} T1 {d}\n", .{ t0, t1 });
            // std.debug.print("PRE ray_t {}\n", .{ray_t});

            if (t0 > ray_t_min) ray_t_min = t0;
            if (t1 < ray_t_max) ray_t_max = t1;

            // std.debug.print("POST ray_t {}\n", .{ray_t});

            if (ray_t_max <= ray_t_min) return false;
        }
        return true;
    }
};

test "aabb hit" {
    // Unit box
    const aabb = Aabb{ .x = Interval{ .min = -1, .max = 1 }, .y = Interval{ .min = -1, .max = 1 }, .z = Interval{ .min = -1, .max = 1 } };
    const ray_t_o = interval.Interval{ .min = 0.001, .max = rtweekend.infinity };

    const r = Ray{ .origin = Vec3{ 13, 2, 3 }, .direction = Vec3{ 0, 0, 0 } };
    var ray_t = ray_t_o;

    try std.testing.expect(!aabb.hit(r, &ray_t));

    const r2 = Ray{ .origin = Vec3{ 2, 2, 2 }, .direction = Vec3{ -1, -1, -1 } };
    var ray_t2 = ray_t_o;

    try std.testing.expect(aabb.hit(r2, &ray_t2));

    const r3 = Ray{ .origin = Vec3{ 1, 1, 1 }, .direction = Vec3{ -1, -1, -1 } };
    var ray_t3 = ray_t_o;

    try std.testing.expect(aabb.hit(r3, &ray_t3));
}
