const std = @import("std");
const utils = @import("utils.zig");

pub const Color = @Vector(3, f32);
pub const Position = @Vector(3, f32);
pub const Vec3 = @Vector(3, f32);

pub inline fn zero() Vec3 {
    return Vec3{ 0, 0, 0 };
}

pub inline fn length(u: Vec3) f32 {
    return @sqrt(lengthSquared(u));
}

pub inline fn lengthSquared(u: Vec3) f32 {
    return u[0] * u[0] + u[1] * u[1] + u[2] * u[2];
}

pub inline fn nearZero(u: Vec3) bool {
    const s = 1e-8;
    return @abs(u[0]) < s and @abs(u[1]) < s and @abs(u[2]) < s;
}

pub inline fn splat3(v: f32) Vec3 {
    return @as(Vec3, @splat(v));
}

pub inline fn dot(u: Vec3, v: Vec3) f32 {
    return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
}

pub inline fn cross(u: Vec3, v: Vec3) Vec3 {
    return Vec3{ u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0] };
}

pub inline fn unitVector(v: Vec3) Vec3 {
    return v / splat3(length(v));
}

pub inline fn randomInUnitDisk() Vec3 {
    while (true) {
        const p = Vec3{ utils.randomDoubleRange(-1, 1), utils.randomDoubleRange(-1, 1), 0 };
        if (lengthSquared(p) < 1) return p;
    }
}

pub inline fn random() Vec3 {
    return Vec3{ utils.randomDouble(), utils.randomDouble(), utils.randomDouble() };
}

pub inline fn randomRange(min: f32, max: f32) Vec3 {
    return Vec3{
        utils.randomDoubleRange(min, max),
        utils.randomDoubleRange(min, max),
        utils.randomDoubleRange(min, max),
    };
}

pub inline fn randomInUnitSphere() Vec3 {
    while (true) {
        const p = randomRange(-1, 1);
        if (lengthSquared(p) < 1) return p;
    }
}

pub inline fn randomUnitVector() Vec3 {
    return unitVector(randomInUnitSphere());
}

pub inline fn randomOnHemisphere(normal: Vec3) Vec3 {
    const on_unit_sphere = randomUnitVector();
    if (dot(on_unit_sphere, normal) > 0.0) return on_unit_sphere;

    return -on_unit_sphere;
}

pub fn reflect(v: Vec3, n: Vec3) Vec3 {
    return v - n * splat3(dot(v, n) * 2);
}

pub fn refract(uv: Vec3, n: Vec3, etai_over_etat: f32) Vec3 {
    const cos_theta = @min(dot(-uv, n), 1.0);
    const r_out_perp = splat3(etai_over_etat) * (uv + n * splat3(cos_theta));
    const r_out_parallel = n * splat3(-@sqrt(@abs(1.0 - lengthSquared(r_out_perp))));
    return r_out_perp + r_out_parallel;
}

test "mixing different aliases" {
    const v = Vec3{ 1, 2, 3 };
    const p = Position{ 1, 2, 3 };
    const c = Color{ 1, 2, 3 };

    try std.testing.expectEqual(v, p);
    try std.testing.expectEqual(v, c);
    try std.testing.expectEqual(p, c);
    try std.testing.expectEqual(v + p, Color{ 2, 4, 6 });
}
