const std = @import("std");
const vec3 = @import("vec3.zig");
const hittable = @import("hittable.zig");
const ray = @import("ray.zig");

// NOTE: this should probably use more performant structures.
// NOTE: I think I have to use https://zig.guide/standard-library/arraylist but I have no idea of how to deallocate inside of a struct?
// NOTE: objects should be a shared_ptr, do I need an arena allocator?
pub const HittableList = struct {
    objects: std.ArrayList(*hittable.HitRecord),

    pub fn clear(self: HittableList) void {
        self.objects.clearAndFree();
    }

    pub fn add(self: HittableList, object: *hittable.HitRecord) void {
        self.objects.append(object);
    }

    pub fn hit(self: HittableList, r: ray.Ray, ray_tmin: f32, ray_tmax: f32, rec: *hittable.Hittable) bool {
        const temp_rec = hittable.HitRecord{};
        var hit_anything = false;
        var closest_so_far = ray_tmax;

        for (self.objects) |object| {
            if (object.hit(r, ray_tmin, closest_so_far, temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                rec = temp_rec;
            }
        }

        return hit_anything;
    }
};
