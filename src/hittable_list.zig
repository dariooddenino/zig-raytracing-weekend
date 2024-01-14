const std = @import("std");
const vec3 = @import("vec3.zig");
const hittable = @import("hittable.zig");
const ray = @import("ray.zig");
const interval = @import("interval.zig");

pub fn hittableList(comptime val_type: type) type {
    return struct {
        // NOTE: I think this solution doesn't allow me to mix different types.
        const Self = @This();
        objects: std.ArrayList(val_type),

        pub fn clear(self: *Self) void {
            self.objects.clearAndFree();
        }

        pub fn add(self: *Self, object: *val_type) !void {
            try self.objects.append(object.*);
        }

        pub fn hit(self: Self, r: ray.Ray, ray_t: interval.Interval, rec: *hittable.HitRecord) bool {
            var temp_rec = hittable.HitRecord{};
            var hit_anything = false;
            var closest_so_far = ray_t.max;

            for (self.objects.items) |object| {
                if (object.hit(r, interval.Interval{ .min = ray_t.min, .max = closest_so_far }, &temp_rec)) {
                    hit_anything = true;
                    closest_so_far = temp_rec.t;
                    rec.* = temp_rec;
                }
            }

            return hit_anything;
        }
    };
}
