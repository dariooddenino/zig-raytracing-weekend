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

// TODO: can I avoid duplicating the last object? Maybe a null terminated pointer
// TODO: why with one sphere I get two different objects??
// TODO: why is it not rendering anything?
pub const BvhInner = union(enum) {
    bvh: BvhNode,
    hittable: Hittable,

    pub fn print(self: BvhInner, i: u32) void {
        switch (self) {
            .bvh => |b| {
                b.print(i);
            },
            .hittable => |h| {
                std.debug.print("HIT [{d}]: {}\n\n", .{ i, h.sphere.center1 });
            },
        }
    }

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
    right: *?BvhInner,
    bounding_box: Aabb = Aabb{},

    pub fn print(self: BvhNode, i: u32) void {
        std.debug.print("\nNODE [{d}]\n", .{i});
        std.debug.print("LEFT [{d}]  {}\n", .{ i, @TypeOf(self.left.*) });
        self.left.print(i + 1);
        if (self.right.*) |right| {
            std.debug.print("RIGHT [{d}] {}\n", .{ i, @TypeOf(right) });
            right.print(i + 1);
        } else {
            std.debug.print("NO RIGHT\n", .{});
        }
    }

    pub fn boundingBox(self: BvhNode) Aabb {
        return self.bounding_box;
    }

    pub fn init(allocator: std.mem.Allocator, objects: *std.ArrayList(Hittable)) !BvhNode {
        return try BvhNode.initDet(allocator, objects, 0, objects.items.len);
    }

    pub fn initDet(allocator: std.mem.Allocator, objects: *std.ArrayList(Hittable), start: usize, end: usize) !BvhNode {
        // var objects = src_objects;
        var left: BvhInner = undefined;
        var right: ?BvhInner = null;
        var bounding_box: Aabb = undefined;
        std.debug.print("\ninitDet with {d} objects, start {d}, end {d}\n", .{ objects.items.len, start, end });
        const axis = rtweekend.randomIntRange(0, 2);

        const object_span = end - start;
        // @breakpoint();

        if (object_span == 1) {
            // Last object.
            std.debug.print("Getting into span 1\n", .{});
            left = BvhInner{ .hittable = objects.items[start] };
        } else if (object_span == 2) {
            std.debug.print("Getting into span 2\n", .{});
            if (comparator(axis, objects.items[start], objects.items[start + 1])) {
                left = BvhInner{ .hittable = objects.items[start] };
                right = BvhInner{ .hittable = objects.items[start + 1] };
            } else {
                left = BvhInner{ .hittable = objects.items[start + 1] };
                right = BvhInner{ .hittable = objects.items[start] };
            }
        } else {
            std.debug.print("Getting into span 3\n", .{});
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

        if (right) |r| {
            bounding_box = Aabb.fromBoxes(left.boundingBox(), r.boundingBox());
        } else {
            bounding_box = left.boundingBox();
        }

        // @breakpoint();
        left.print(0);
        if (right) |r| {
            r.print(0);
        } else {
            std.debug.print("No right\n", .{});
        }

        std.debug.print("The step bounding box is {}\n", .{bounding_box});

        return BvhNode{ .left = &left, .right = &right, .bounding_box = bounding_box };
    }

    pub fn hit(self: BvhNode, r: Ray, ray_t: *Interval, rec: *HitRecord) bool {
        if (!self.boundingBox().hit(r, ray_t)) return false;

        const hit_left = self.left.hit(r, ray_t, rec);
        var hit_right = false;
        if (self.right.*) |right| {
            hit_right = right.hit(r, ray_t, rec);
        }

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
