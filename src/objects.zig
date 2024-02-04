const std = @import("std");
const vec3 = @import("vec3.zig");
const rays = @import("ray.zig");
const materials = @import("material.zig");
const intervals = @import("interval.zig");
const aabbs = @import("aabb.zig");
const bvhs = @import("bvh.zig");

const Aabb = aabbs.Aabb;
const BVHTree = bvhs.BVHTree;
const Interval = intervals.Interval;
const Material = materials.Material;
const Vec3 = vec3.Vec3;
const Ray = rays.Ray;

pub const HitRecord = struct {
    p: Vec3 = vec3.zero(),
    normal: Vec3 = vec3.zero(),
    mat: Material = undefined, // NOTE was a pointer
    t: f32 = 0,
    u: f32 = 0,
    v: f32 = 0,
    front_face: bool = false,

    pub fn setFaceNormal(self: *HitRecord, r: Ray, outward_normal: Vec3) void {
        // Sets the hit record normal vector.
        // NOTE: the parameter 'outward_normal' is assumed to have unit length.

        self.front_face = vec3.dot(r.direction, outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else -outward_normal;
    }
};

pub const Hittable = union(enum) {
    sphere: Sphere,
    quad: Quad,
    list: HittableList,
    tree: BVHTree,

    pub fn hit(self: Hittable, r: rays.Ray, ray_t: Interval) ?HitRecord {
        switch (self) {
            inline else => |object| return object.hit(r, ray_t),
        }
    }

    pub fn boundingBox(self: Hittable) Aabb {
        switch (self) {
            inline else => |object| return object.boundingBox(),
        }
    }

    pub fn deinit(self: Hittable) void {
        switch (self) {
            inline else => |object| object.deinit(),
        }
    }
};

pub const Sphere = struct {
    center1: Vec3,
    radius: f32,
    mat: Material, // NOTE this was a pointer
    is_moving: bool = false,
    center_vec: Vec3 = vec3.zero(),
    bounding_box: Aabb = Aabb{},

    pub fn boundingBox(self: Sphere) Aabb {
        return self.bounding_box;
    }

    pub fn init(center1: Vec3, radius: f32, mat: Material) Hittable {
        const rvec = Vec3{ radius, radius, radius };
        return Hittable{ .sphere = Sphere{ .center1 = center1, .radius = radius, .mat = mat, .bounding_box = Aabb.fromPoints(center1 - rvec, center1 + rvec) } };
    }

    pub fn deinit(_: Sphere) void {}

    pub fn initMoving(center1: Vec3, center2: Vec3, radius: f32, mat: Material) Hittable {
        const rvec = Vec3{ radius, radius, radius };
        const box1 = Aabb.fromPoints(center1 - rvec, center1 + rvec);
        const box2 = Aabb.fromPoints(center2 - rvec, center2 + rvec);
        return Hittable{ .sphere = Sphere{ .center1 = center1, .radius = radius, .mat = mat, .center_vec = center2 - center1, .is_moving = true, .bounding_box = Aabb.fromBoxes(box1, box2) } };
    }

    pub fn getCenter(self: Sphere, time: f32) Vec3 {
        // Linearly interpolate from center1 to center2 according to time, where t=0 yields center1, and t=1
        // yields center2.
        return self.center1 + vec3.splat3(time) * self.center_vec;
    }

    // NOTE This name is misleading
    fn getSphereUV(p: Vec3, u: *f32, v: *f32) void {
        // p: a given point on the sphere of radius one, centered at the origin.
        // u: returned value [0,1] of angle around the Y axis from X=-1.
        // v: returned value [0,1] of angle from Y=-1 to Y=+1.
        //     <1 0 0> yields <0.50 0.50>       <-1  0  0> yields <0.00 0.50>
        //     <0 1 0> yields <0.50 1.00>       < 0 -1  0> yields <0.50 0.00>
        //     <0 0 1> yields <0.25 0.50>       < 0  0 -1> yields <0.75 0.50>

        const theta = std.math.acos(-p[1]);
        const phi = std.math.atan2(f32, -p[2], p[0]) + std.math.pi;

        u.* = phi / (2 * std.math.pi);
        v.* = theta / std.math.pi;
    }

    pub fn hit(
        self: Sphere,
        r: Ray,
        ray_t: Interval,
    ) ?HitRecord {
        const center = if (self.is_moving) self.getCenter(r.time) else self.center1;
        const oc = r.origin - center;

        const a = vec3.lengthSquared(r.direction);
        const half_b = vec3.dot(oc, r.direction);
        const c = vec3.lengthSquared(oc) - self.radius * self.radius;
        const discriminant = half_b * half_b - a * c;
        if (discriminant < 0) return null;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (-half_b - sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            root = (-half_b + sqrtd) / a;
            if (!ray_t.surrounds(root)) return null;
        }

        var rec = HitRecord{};
        rec.t = root;
        rec.p = r.at(rec.t);
        const outward_normal = (rec.p - center) / vec3.splat3(self.radius);
        rec.setFaceNormal(r, outward_normal);
        getSphereUV(outward_normal, &rec.u, &rec.v);
        rec.mat = self.mat;

        return rec;
    }
};

pub const Quad = struct {
    q: Vec3,
    u: Vec3,
    v: Vec3,
    mat: Material,
    bounding_box: Aabb = Aabb{},
    normal: Vec3,
    d: f32,
    w: Vec3,

    pub fn init(q: Vec3, u: Vec3, v: Vec3, mat: Material) Hittable {
        const n = vec3.cross(u, v);
        const normal = vec3.unitVector(n);
        const d = vec3.dot(normal, q);
        const w = n / vec3.splat3(vec3.dot(n, n));
        return Hittable{ .quad = Quad{ .q = q, .u = u, .v = v, .mat = mat, .bounding_box = Aabb.fromPoints(q, q + u + v).pad(), .normal = normal, .d = d, .w = w } };
    }

    pub fn boundingBox(self: Quad) Aabb {
        return self.bounding_box;
    }

    pub fn deinit(_: Quad) void {}

    fn isInterior(a: f32, b: f32, rec: *HitRecord) bool {
        // Given the hit point in plane coordinates, return false if it is outside the
        // primitive, otherwise set the hit record UV coordinates and return true.

        if ((a < 0) or (1 < a) or (b < 0) or (1 < b)) return false;

        rec.u = a;
        rec.v = b;
        return true;
    }

    pub fn hit(
        self: Quad,
        r: Ray,
        ray_t: Interval,
    ) ?HitRecord {
        const denom = vec3.dot(self.normal, r.direction);

        // No hit if the ray is parallel to the plane.
        if (@abs(denom) < 1e-8) return null;

        // Return false if the hit point parameter t is outside the ray interval.
        const t = (self.d - vec3.dot(self.normal, r.origin)) / denom;
        if (!ray_t.contains(t)) return null;

        // Determine the hit point lies within the planar shape using its plane coordinates.
        const interesection = r.at(t);
        const planar_hitpt_vector = interesection - self.q;
        const alpha = vec3.dot(self.w, vec3.cross(planar_hitpt_vector, self.v));
        const beta = vec3.dot(self.w, vec3.cross(self.u, planar_hitpt_vector));

        var rec = HitRecord{};
        if (!isInterior(alpha, beta, &rec)) return null;

        // Ray hits the 2D shape; set the rest of the hit record and return true;

        rec.t = t;
        rec.p = interesection;
        rec.mat = self.mat;
        rec.setFaceNormal(r, self.normal);

        return rec;
    }
};

pub const HittableList = struct {
    objects: std.ArrayList(Hittable),
    bounding_box: Aabb = Aabb{},
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Hittable {
        const objects = std.ArrayList(Hittable).init(allocator);
        return Hittable{ .list = HittableList{ .objects = objects, .allocator = allocator } };
    }

    pub fn add(self: *HittableList, object: Hittable) !void {
        try self.objects.append(object);
        self.bounding_box = Aabb.fromBoxes(self.bounding_box, object.boundingBox());
    }

    pub fn boundingBox(self: HittableList) Aabb {
        return self.bounding_box;
    }

    pub fn deinit(self: *HittableList) void {
        self.objects.clearAndFree();
    }

    pub fn hit(
        self: HittableList,
        r: Ray,
        ray_t: Interval,
    ) ?HitRecord {
        var rec: ?HitRecord = null;
        var closest_so_far = ray_t.max;

        for (self.objects.items) |object| {
            const is_hit = object.hit(r, Interval{ .min = ray_t.min, .max = closest_so_far });
            if (is_hit) |h| {
                closest_so_far = h.t;
                rec = h;
            }
        }

        return rec;
    }
};

pub fn createBox(allocator: std.mem.Allocator, a: Vec3, b: Vec3, mat: Material) !Hittable {
    // Returns the 3D box (six sides) that contains the two opposite vertices a & b.

    var sides = HittableList.init(allocator);

    // Construct the two opposite vertices with the minimum and maximum coordinates.

    const min = Vec3{ @min(a[0], b[0]), @min(a[1], b[1]), @min(a[2], b[2]) };
    const max = Vec3{ @max(a[0], b[0]), @max(a[1], b[1]), @max(a[2], b[2]) };

    const dx = Vec3{ max[0] - min[0], 0, 0 };
    const dy = Vec3{ 0, max[1] - min[1], 0 };
    const dz = Vec3{ 0, 0, max[2] - min[2] };

    try sides.list.add(Quad.init(Vec3{ min[0], min[1], min[2] }, dx, dy, mat));
    try sides.list.add(Quad.init(Vec3{ max[0], min[1], max[2] }, -dz, dy, mat));
    try sides.list.add(Quad.init(Vec3{ max[0], min[1], min[2] }, -dx, dy, mat));
    try sides.list.add(Quad.init(Vec3{ min[0], min[1], min[2] }, dz, dy, mat));
    try sides.list.add(Quad.init(Vec3{ min[0], max[1], max[2] }, dx, -dz, mat));
    try sides.list.add(Quad.init(Vec3{ min[0], min[1], min[2] }, dx, dz, mat));

    return sides;
}
