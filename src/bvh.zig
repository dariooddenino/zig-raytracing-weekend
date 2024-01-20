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

pub const BvhInner = union(enum) {
    bvh: BvhNode,
    hittable: Hittable,

    pub fn boundingBox(self: BvhInner) Aabb {
        switch (self) {
            inline else => |o| return o.boundingBox(),
        }
    }

    pub fn hit(self: BvhInner, r: Ray, ray_t: *Interval, rec: *HitRecord) bool {
        switch (self) {
            inline else => |object| return object.hit(r, ray_t, rec),
        }
    }
};

pub const BvhNode = struct {
    left: *BvhInner,
    right: *BvhInner,
    bounding_box: Aabb = Aabb{},

    pub fn boundingBox(self: BvhNode) Aabb {
        return self.bounding_box;
    }

    pub fn init(allocator: std.mem.Allocator, objects: *std.ArrayList(Hittable)) !BvhNode {
        return try BvhNode.initDet(allocator, objects, 0, objects.items.len);
    }

    pub fn initDet(allocator: std.mem.Allocator, objects: *std.ArrayList(Hittable), start: usize, end: usize) !BvhNode {
        // var objects = src_objects;
        var left: BvhInner = undefined;
        var right: BvhInner = undefined;
        var bounding_box: Aabb = undefined;

        const axis = rtweekend.randomIntRange(0, 2);

        const object_span = end - start;

        // Last object.
        if (object_span == 1) {
            left = BvhInner{ .hittable = objects.items[start] };
            right = left;
        } else if (object_span == 2) {
            if (comparator(axis, objects.items[start], objects.items[start + 1])) {
                left = BvhInner{ .hittable = objects.items[start] };
                right = BvhInner{ .hittable = objects.items[start + 1] };
            } else {
                left = BvhInner{ .hittable = objects.items[start + 1] };
                right = BvhInner{ .hittable = objects.items[start] };
            }
        } else {
            // TODO need to implement this
            // std::sort (objects.begin() + start, objects.begin() + end, comparator);
            // const lobjects = objects.toOwnedSlice();
            // std.sort.sort(Hittable, lobjects, {}, comparator);
            const objects_slice = try objects.toOwnedSlice();
            std.sort.pdq(Hittable, objects_slice[start..end], axis, comparator);
            objects.* = std.ArrayList(Hittable).fromOwnedSlice(allocator, objects_slice);

            const mid = start + object_span / 2;
            left = BvhInner{ .bvh = try BvhNode.initDet(allocator, objects, start, mid) };
            right = BvhInner{ .bvh = try BvhNode.initDet(allocator, objects, mid, end) };
        }

        bounding_box = Aabb.fromBoxes(left.boundingBox(), right.boundingBox());
        return BvhNode{ .left = &left, .right = &right, .bounding_box = bounding_box };
    }

    pub fn hit(self: BvhNode, r: Ray, ray_t: *Interval, rec: *HitRecord) bool {
        if (!self.boundingBox().hit(r, ray_t)) return false;

        const hit_left = self.left.hit(r, ray_t, rec);
        const hit_right = self.right.hit(r, ray_t, rec);

        return hit_left or hit_right;
    }

    fn box_compare(a: Hittable, b: Hittable, axis_index: u32) bool {
        return a.boundingBox().axis(axis_index).min < b.boundingBox().axis(axis_index).min;
    }

    fn comparator(axis: u32, a: Hittable, b: Hittable) bool {
        if (axis == 0) {
            return box_compare(a, b, 0);
        } else if (axis == 1) {
            return box_compare(a, b, 1);
        } else {
            return box_compare(a, b, 2);
        }
    }
};
