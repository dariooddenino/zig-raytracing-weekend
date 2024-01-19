const std = @import("std");
const vec3 = @import("vec3.zig");
const hittable = @import("hittable.zig");
const ray = @import("ray.zig");
const interval = @import("interval.zig");
const sphere = @import("sphere.zig");
const aabb = @import("aabb.zig");

const Aabb = aabb.Aabb;

pub const Hittable = union(enum) {
    sphere: sphere.Sphere,

    pub fn hit(self: Hittable, r: ray.Ray, ray_t: interval.Interval, rec: *hittable.HitRecord) bool {
        switch (self) {
            inline else => |object| return object.hit(r, ray_t, rec),
        }
    }

    // pub fn boundingBox(self: Hittable) Aabb {
    //     switch (self) {
    //         inline else => |object| return object.boundingBox(),
    //     }
    // }
};

// pub fn hittableList(comptime val_type: type) type {
// return struct {
pub const HittableList = struct {
    objects: *std.ArrayList(Hittable),
    bounding_box: Aabb = Aabb{},

    pub inline fn add(self: *HittableList, object: anytype) !void {
        if (@TypeOf(object) == Hittable) {
            try self.objects.append(object);
            switch (object) {
                .sphere => |sph| {
                    self.bounding_box = Aabb.fromBoxes(self.bounding_box, sph.bounding_box);
                },
            }
        } else if (@TypeOf(object) == sphere.Sphere) {
            try self.objects.append(Hittable{ .sphere = object });
            self.bounding_box = Aabb.fromBoxes(self.bounding_box, object.bounding_box);
        } else unreachable;
    }

    pub fn hit(self: HittableList, r: ray.Ray, ray_t: interval.Interval, rec: *hittable.HitRecord) bool {
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
    // };
};
