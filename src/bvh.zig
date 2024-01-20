const std = @import("std");
const hittable_list = @import("hittable_list.zig");
const aabb = @import("aabb.zig");
const ray = @import("ray.zig");
const interval = @import("interval.zig");
const hittable = @import("hittable.zig");
const rtweekend = @import("rtweekend.zig");
const material = @import("material.zig");
const vec3 = @import("vec3.zig");
const sphere = @import("sphere.zig");

const Vec3 = vec3.Vec3;
const Ray = ray.Ray;
const Hittable = hittable_list.Hittable;
const HitRecord = hittable.HitRecord;
const Aabb = aabb.Aabb;
const Interval = interval.Interval;

// NOTE: trying to make this work in any way...
pub const Empty = struct {
    pub fn boundingBox(_: Empty) Aabb {
        return Aabb{};
    }

    pub fn hit(_: Empty, _: Ray, _: *Interval, _: *HitRecord) bool {
        return false;
    }
};

pub const BvhInner = union(enum) {
    bvh: BvhNode,
    hittable: Hittable,
    empty: Empty,

    pub fn print(self: BvhInner, i: u32) void {
        switch (self) {
            .bvh => |b| {
                b.print(i);
            },
            .hittable => |h| {
                std.debug.print("{d}: HITTABLE {}\n", .{ i, h.sphere.center1 });
            },
            .empty => |_| {
                std.debug.print("{d}: EMPTY\n", .{i});
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
    right: *BvhInner,
    bounding_box: Aabb = Aabb{},

    pub fn print(self: BvhNode, i: u32) void {
        std.debug.print("\n\n{d}: NODE\n", .{i});
        self.left.print(i + 1);
        self.right.print(i + 1);

        // if (self.right.*) |right| {
        //     std.debug.print("RIGHT [{d}] {}\n", .{ i, right });
        //     right.print(i + 1);
        // } else {
        //     std.debug.print("NO RIGHT\n", .{});
        // }
    }

    pub fn boundingBox(self: BvhNode) Aabb {
        return self.bounding_box;
    }

    pub fn init(allocator: std.mem.Allocator, objects: *std.ArrayList(Hittable)) !BvhNode {
        return try BvhNode.initDet(allocator, objects, 0, objects.items.len);
    }

    pub fn initDet(allocator: std.mem.Allocator, objects: *std.ArrayList(Hittable), start: usize, end: usize) !BvhNode {
        // var objects = src_objects;
        var left: *BvhInner = try allocator.create(BvhInner);
        var right: *BvhInner = try allocator.create(BvhInner);
        var bounding_box: Aabb = undefined;
        // std.debug.print("\ninitDet with {d} objects, start {d}, end {d}\n", .{ objects.items.len, start, end });
        const axis = rtweekend.randomIntRange(0, 2);

        const object_span = end - start;
        // @breakpoint();

        if (object_span == 1) {
            // Last object.
            // std.debug.print("Getting into span 1\n", .{});
            left.* = BvhInner{ .hittable = objects.items[start] };
            right.* = BvhInner{ .empty = Empty{} };
        } else if (object_span == 2) {
            // std.debug.print("Getting into span 2\n", .{});
            if (comparator(axis, objects.items[start], objects.items[start + 1])) {
                left.* = BvhInner{ .hittable = objects.items[start] };
                right.* = BvhInner{ .hittable = objects.items[start + 1] };
            } else {
                left.* = BvhInner{ .hittable = objects.items[start + 1] };
                right.* = BvhInner{ .hittable = objects.items[start] };
            }
        } else {
            // std.debug.print("Getting into span 3\n", .{});
            // TODO need to implement this
            // std::sort (objects.begin() + start, objects.begin() + end, comparator);
            // const lobjects = objects.toOwnedSlice();
            // std.sort.sort(Hittable, lobjects, {}, comparator);
            const objects_slice = try objects.toOwnedSlice();
            std.sort.pdq(Hittable, objects_slice[start..end], axis, comparator);
            objects.* = std.ArrayList(Hittable).fromOwnedSlice(allocator, objects_slice);

            const mid = start + object_span / 2;
            left.* = BvhInner{ .bvh = try BvhNode.initDet(allocator, objects, start, mid) };
            right.* = BvhInner{ .bvh = try BvhNode.initDet(allocator, objects, mid, end) };
        }

        // if (right) |r| {
        bounding_box = Aabb.fromBoxes(left.boundingBox(), right.boundingBox());
        // } else {
        //     bounding_box = left.boundingBox();
        // }

        // @breakpoint();
        // left.print(0);
        // if (right) |r| {
        //     r.print(0);
        // } else {
        //     std.debug.print("No right\n", .{});
        // }

        // std.debug.print("The step bounding box is {}\n", .{bounding_box});

        return BvhNode{ .left = left, .right = right, .bounding_box = bounding_box };
    }

    pub fn hit(self: BvhNode, r: Ray, ray_t: *Interval, rec: *HitRecord) bool {
        if (!self.boundingBox().hit(r, ray_t)) return false;

        const hit_left = self.left.hit(r, ray_t, rec);
        // var hit_right = false;
        // if (self.right.*) |right| {
        const hit_right = self.right.hit(r, ray_t, rec);
        // }

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

test "bounding box" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    const allocator = arena.allocator();
    defer arena.deinit();

    var objects = std.ArrayList(Hittable).init(allocator);
    defer objects.deinit();

    var world = hittable_list.HittableList{ .objects = objects };

    const ground_material = material.Material{ .lambertian = material.Lambertian.fromColor(vec3.Vec3{ 0.5, 0.5, 0.5 }) };
    const ground = sphere.Sphere.init(vec3.Vec3{ 0, -1000, -1 }, 1000, ground_material);
    try world.add(ground);

    const material2 = material.Material{ .lambertian = material.Lambertian.fromColor(vec3.Vec3{ 0.4, 0.2, 0.1 }) };
    try world.add(sphere.Sphere.init(vec3.Vec3{ 0, 0, 0 }, 1.0, material2));

    const node = try BvhNode.init(allocator, &world.objects);

    const r = Ray{ .origin = vec3.Vec3{ 1, 1, 1 }, .direction = vec3.Vec3{ -1, -1, -1 } };
    var ray_t = interval.Interval{ .min = 0.001, .max = rtweekend.infinity };
    var rec = hittable.HitRecord{};

    const hit = node.hit(r, &ray_t, &rec);

    try std.testing.expect(hit);

    const r2 = Ray{ .origin = vec3.Vec3{ 1, 1, 1 }, .direction = vec3.Vec3{ 1, 1, 1 } };
    var ray_t2 = interval.Interval{ .min = 0.001, .max = rtweekend.infinity };
    var rec2 = hittable.HitRecord{};

    const hit2 = node.hit(r2, &ray_t2, &rec2);

    try std.testing.expect(!hit2);
}
