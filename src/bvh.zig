const std = @import("std");
const aabb = @import("aabb.zig");
const rays = @import("ray.zig");
const interval = @import("interval.zig");
const rtweekend = @import("rtweekend.zig");
const material = @import("material.zig");
const vec3 = @import("vec3.zig");
const objects = @import("objects.zig");

const Vec3 = vec3.Vec3;
const Ray = rays.Ray;
const Hittable = objects.Hittable;
const HitRecord = objects.HitRecord;
const Aabb = aabb.Aabb;
const Interval = interval.Interval;

pub const BVHTree = struct {
    allocator: std.mem.Allocator,
    root: *const BVHNode,
    bounding_box: Aabb,

    pub fn init(allocator: std.mem.Allocator, src_objects: []Hittable, start: usize, end: usize) !BVHTree {
        const root = try constructTree(allocator, src_objects, start, end);
        return BVHTree{
            .allocator = allocator,
            .root = root,
            .bounding_box = root.bounding_box,
        };
    }

    pub fn deinit(self: *const BVHTree) void {
        BVHNode.deinit(self.allocator, self.root);
    }

    pub fn boundingBox(self: BVHTree) Aabb {
        return self.bounding_box;
    }

    pub fn hit(self: *const BVHTree, ray: Ray, ray_t: Interval) ?HitRecord {
        return self.root.hit(ray, ray_t);
    }

    pub fn constructTree(allocator: std.mem.Allocator, src_objects: []Hittable, start: usize, end: usize) !*BVHNode {
        var left: *BVHNode = undefined;
        var right: *BVHNode = undefined;

        const obj_span = end - start;
        const axis = rtweekend.randomIntRange(0, 2);

        switch (obj_span) {
            1 => {
                return makeLeaf(allocator, &src_objects[start]);
            },
            2 => {
                if (boxComparator(axis, src_objects[start], src_objects[start + 1])) {
                    left = try makeLeaf(allocator, &src_objects[start]);
                    right = try makeLeaf(allocator, &src_objects[start + 1]);
                } else {
                    left = try makeLeaf(allocator, &src_objects[start + 1]);
                    right = try makeLeaf(allocator, &src_objects[start]);
                }
            },
            else => {
                std.sort.heap(Hittable, src_objects[start..end], axis, boxComparator);
                const mid = start + obj_span / 2;
                left = try constructTree(allocator, src_objects, start, mid);
                right = try constructTree(allocator, src_objects, mid, end);
            },
        }
        return makeNode(allocator, left, right, Aabb.fromBoxes(left.bounding_box, right.bounding_box));
    }

    fn makeNode(allocator: std.mem.Allocator, left: *const BVHNode, right: *const BVHNode, bounding_box: Aabb) !*BVHNode {
        const result = try allocator.create(BVHNode);
        result.left = left;
        result.right = right;
        result.leaf = null;
        result.bounding_box = bounding_box;
        return result;
    }

    fn makeLeaf(allocator: std.mem.Allocator, hittable: *const Hittable) !*BVHNode {
        const result = try allocator.create(BVHNode);
        result.leaf = hittable;
        result.left = null;
        result.right = null;
        result.bounding_box = hittable.boundingBox();
        return result;
    }

    fn boxCompare(a: Hittable, b: Hittable, axis_index: u32) bool {
        return a.boundingBox().axis(axis_index).min < b.boundingBox().axis(axis_index).min;
    }

    fn boxComparator(axis: u32, a: Hittable, b: Hittable) bool {
        if (axis == 0) {
            return boxCompare(a, b, 0);
        } else if (axis == 1) {
            return boxCompare(a, b, 1);
        } else {
            return boxCompare(a, b, 2);
        }
    }
};

pub const BVHNode = struct {
    leaf: ?*const Hittable = null,
    left: ?*const BVHNode = null,
    right: ?*const BVHNode = null,
    bounding_box: Aabb = undefined,

    pub fn deinit(allocator: std.mem.Allocator, n: *const BvhNode) void {
        if (n.left) |node| {
            deinit(allocator, node);
        }
        if (n.right) |node| {
            deinit(allocator, node);
        }
        allocator.destroy(n);
    }

    pub fn hit(self: *const BVHNode, ray: Ray, ray_t: Interval) ?HitRecord {
        if (self.leaf) |hittable| {
            return hittable.hit(ray, ray_t);
        }

        if (!self.bounding_box.hit(ray, ray_t)) {
            return null;
        }

        const hit_record_left = self.left.?.hit(ray, ray_t);
        const rInterval = Interval{ .min = ray_t.min, .max = if (hit_record_left != null) hit_record_left.?.t else ray_t.max };
        const hit_record_right = self.right.?.hit(ray, rInterval);

        return hit_record_right orelse hit_record_left orelse null;
    }
};

// NOTE: old code below

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

    pub fn count(self: BvhInner) u32 {
        switch (self) {
            .bvh => |b| return b.count(),
            .hittable => |_| return 1,
            .empty => |_| return 0,
        }
    }

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

    pub fn count(self: BvhNode) u32 {
        var le: u32 = 0;
        var re: u32 = 0;

        le += self.left.count();
        re += self.right.count();
        return le + re;
    }

    pub fn boundingBox(self: BvhNode) Aabb {
        return self.bounding_box;
    }

    pub fn init(allocator: std.mem.Allocator, world_objects: *std.ArrayList(Hittable)) !BvhNode {
        return try BvhNode.initDet(allocator, world_objects, 0, objects.items.len);
    }

    pub fn initDet(allocator: std.mem.Allocator, world_objects: *std.ArrayList(Hittable), start: usize, end: usize) !BvhNode {
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
            left.* = BvhInner{ .hittable = world_objects.items[start] };
            right.* = BvhInner{ .empty = Empty{} };
        } else if (object_span == 2) {
            // std.debug.print("Getting into span 2\n", .{});
            if (comparator(axis, world_objects.items[start], world_objects.items[start + 1])) {
                left.* = BvhInner{ .hittable = world_objects.items[start] };
                right.* = BvhInner{ .hittable = world_objects.items[start + 1] };
            } else {
                left.* = BvhInner{ .hittable = world_objects.items[start + 1] };
                right.* = BvhInner{ .hittable = world_objects.items[start] };
            }
        } else {
            // std.debug.print("Getting into span 3\n", .{});
            // TODO need to implement this
            // std::sort (objects.begin() + start, objects.begin() + end, comparator);
            // const lobjects = objects.toOwnedSlice();
            // std.sort.sort(Hittable, lobjects, {}, comparator);
            const objects_slice = try world_objects.toOwnedSlice();
            std.sort.pdq(Hittable, objects_slice[start..end], axis, comparator);
            objects.* = std.ArrayList(Hittable).fromOwnedSlice(allocator, objects_slice);

            const mid = start + object_span / 2;
            left.* = BvhInner{ .bvh = try BvhNode.initDet(allocator, world_objects, start, mid) };
            right.* = BvhInner{ .bvh = try BvhNode.initDet(allocator, world_objects, mid, end) };
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

        // var temp_rec_l = HitRecord{};
        // var temp_rec_r = HitRecord{};

        const hit_left = self.left.hit(r, ray_t, rec);
        // var hit_right = false;
        // if (self.right.*) |right| {
        // const hit_right = self.right.hit(r, ray_t, &temp_rec_r);
        // }
        var rInterval = Interval{ .min = ray_t.min, .max = if (hit_left) rec.t else ray_t.max };
        const hit_right = self.right.hit(r, &rInterval, rec);

        // if (hit_left) rec.* = temp_rec_l;
        // if (hit_right) rec.* = temp_rec_r;

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

// test "bounding box" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     var arena = std.heap.ArenaAllocator.init(gpa.allocator());
//     const allocator = arena.allocator();
//     defer arena.deinit();

//     var objects = std.ArrayList(Hittable).init(allocator);
//     defer objects.deinit();

//     var world = hittable_list.HittableList{ .objects = objects };

//     const ground_material = material.Material{ .lambertian = material.Lambertian.fromColor(vec3.Vec3{ 0.5, 0.5, 0.5 }) };
//     const ground = sphere.Sphere.init(vec3.Vec3{ 0, -1000, -1 }, 1000, ground_material);
//     try world.add(ground);

//     const material2 = material.Material{ .lambertian = material.Lambertian.fromColor(vec3.Vec3{ 0.4, 0.2, 0.1 }) };
//     try world.add(sphere.Sphere.init(vec3.Vec3{ 0, 0, 0 }, 1.0, material2));

//     const node = try BvhNode.init(allocator, &world.objects);

//     const r = Ray{ .origin = vec3.Vec3{ 1, 1, 1 }, .direction = vec3.Vec3{ -1, -1, -1 } };
//     var ray_t = interval.Interval{ .min = 0.001, .max = rtweekend.infinity };
//     var rec = HitRecord{};

//     const hit = node.hit(r, &ray_t, &rec);

//     try std.testing.expect(hit);

//     const r2 = Ray{ .origin = vec3.Vec3{ 1, 1, 1 }, .direction = vec3.Vec3{ 1, 1, 1 } };
//     var ray_t2 = interval.Interval{ .min = 0.001, .max = rtweekend.infinity };
//     var rec2 = HitRecord{};

//     const hit2 = node.hit(r2, &ray_t2, &rec2);

//     try std.testing.expect(!hit2);
// }
