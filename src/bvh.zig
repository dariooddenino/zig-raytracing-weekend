const std = @import("std");
const hittable_list = @import("hittable_list.zig");
const aabb = @import("aabb.zig");
const ray = @import("ray.zig");
const interval = @import("interval.zig");
const hittable = @import("hittable.zig");
const rtweekend = @import("rtweekend.zig");

const Ray = ray.Ray;
const Hittable = hittable_list.Hittable;
const HitRecord = hittable.HitRecord;
const Aabb = aabb.Aabb;
const Interval = interval.Interval;

pub const BvhNode = struct {
    left: Hittable,
    right: Hittable,
    bounding_box: Aabb = Aabb{},

    pub fn init(allocator: std.mem.Allocator, src_objects: std.ArrayList(Hittable), start: usize, end: usize) BvhNode {
        const objects = src_objects;
        var left = undefined;
        var right = undefined;
        var bounding_box = undefined;

        const axis = rtweekend.randomIntRange(0, 2);
        const comparator = if (axis == 0) {
            BvhNode.box_x_compare;
        } else if (axis == 1) {
            BvhNode.box_y_compare;
        } else BvhNode.box_z_compare;

        const object_span = end - start;

        if (object_span == 1) {
            left = objects.items[start];
            right = objects.items[start];
        } else if (object_span == 2) {
            if (comparator(objects.items[start], objects.items[start + 1])) {
                left = objects.items[start];
                right = objects.items[start + 1];
            } else {
                left = objects.items[start + 1];
                right = objects.items[start];
            }
        } else {
            // TODO need to implement this
            // std::sort (objects.begin() + start, objects.begin() + end, comparator);
            // const lobjects = objects.toOwnedSlice();
            // std.sort.sort(Hittable, lobjects, {}, comparator);
            const objects_slice = try objects.toOwnedSlice();
            std.sort.pdq(Hittable, objects_slice[start..end], {}, comparator);
            objects = std.ArrayList(Hittable).fromOwnedSlice(allocator, objects_slice);

            const mid = start + object_span / 2;
            left = BvhNode.init(objects, start, mid);
            right = BvhNode.init(objects, mid, end);
        }

        bounding_box = Aabb.fromBoxes(left.bounding_box, right.boudning_box);
        return BvhNode{ .left = left, .right = right, .bounding_box = bounding_box };
    }

    pub fn hit(self: BvhNode, r: Ray, ray_t: Interval, rec: *HitRecord) bool {
        if (!self.bounding_box.hit(r, ray_t)) return false;

        const hit_left = self.left.hit(r, ray_t, rec);
        const hit_right = self.right.hit(r, ray_t, rec);

        return hit_left or hit_right;
    }

    fn box_compare(a: Hittable, b: Hittable, axis_index: u32) bool {
        return a.bounding_box.axis(axis_index).min < b.bounding_box.axis(axis_index).min;
    }

    fn box_x_compare(context: void, a: Hittable, b: Hittable) bool {
        _ = context;
        return box_compare(a, b, 0);
    }

    fn box_y_compare(context: void, a: Hittable, b: Hittable) bool {
        _ = context;
        return box_compare(a, b, 1);
    }

    fn box_z_compare(context: void, a: Hittable, b: Hittable) bool {
        _ = context;
        return box_compare(a, b, 2);
    }
};

const Foo = struct { val: u32 };

fn cmpFoo(context: void, a: Foo, b: Foo) bool {
    _ = context;
    if (a.val < b.val) {
        return true;
    } else {
        return false;
    }
}

// test "sort ArrayList" {
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     var foos = std.ArrayList(Foo).init(allocator);
//     // defer foos.deinit();

//     try foos.append(Foo{ .val = 5 });
//     try foos.append(Foo{ .val = 3 });
//     try foos.append(Foo{ .val = 1 });
//     try foos.append(Foo{ .val = 2 });
//     try foos.append(Foo{ .val = 4 });

//     const x = try foos.toOwnedSlice();

//     std.sort.pdq(Foo, x[0..3], {}, cmpFoo);

//     foos = std.ArrayList(Foo).fromOwnedSlice(allocator, x);

//     std.debug.print("{any}\n\n", .{foos});

//     try std.testing.expect(true);
// }
