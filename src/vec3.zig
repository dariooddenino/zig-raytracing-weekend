const std = @import("std");
const rtweekend = @import("rtweekend.zig");

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
        const p = Vec3{ rtweekend.randomDoubleRange(-1, 1), rtweekend.randomDoubleRange(-1, 1), 0 };
        if (lengthSquared(p) < 1) return p;
    }
}

pub inline fn random() Vec3 {
    return Vec3{ rtweekend.randomDouble(), rtweekend.randomDouble(), rtweekend.randomDouble() };
}

pub inline fn randomRange(min: f32, max: f32) Vec3 {
    return Vec3{
        rtweekend.randomDoubleRange(min, max),
        rtweekend.randomDoubleRange(min, max),
        rtweekend.randomDoubleRange(min, max),
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

// pub const Vec3 = struct {
//     x: f32 = 0,
//     y: f32 = 0,
//     z: f32 = 0,

//     pub inline fn neg(self: Vec3) Vec3 {
//         return Vec3{ .x = -self.x, .y = -self.y, .z = -self.z };
//     }

//     pub inline fn get(self: Vec3, i: u8) ?f32 {
//         switch (i) {
//             0 => {
//                 return self.x;
//             },
//             1 => {
//                 return self.y;
//             },
//             2 => {
//                 return self.z;
//             },
//             else => {
//                 return null;
//             },
//         }
//     }

//     pub inline fn plus(self: *Vec3, other: Vec3) *Vec3 {
//         self.x += other.x;
//         self.y += other.y;
//         self.z += other.z;
//         return self;
//     }

//     pub inline fn mul(self: *Vec3, t: f32) *Vec3 {
//         self.x *= t;
//         self.y *= t;
//         self.z *= t;
//         return self;
//     }

//     pub inline fn div(self: *Vec3, t: f32) *Vec3 {
//         self.x /= t;
//         self.y /= t;
//         self.z /= t;
//         return self;
//     }

//     pub inline fn lengthSquared(self: Vec3) f32 {
//         return self.x * self.x + self.y * self.y + self.z * self.z;
//     }

//     pub inline fn length(self: Vec3) f32 {
//         return std.math.sqrt(self.lengthSquared());
//     }

//     pub fn nearZero(self: Vec3) bool {
//         const s = 1e-8;
//         return (@abs(self.x) < s) and (@abs(self.y) < s) and (@abs(self.z) < s);
//     }
// };

// // << non ho idea di cosa sia, forse per stampare.

// pub inline fn add(u: Vec3, v: Vec3) Vec3 {
//     return Vec3{ .x = u.x + v.x, .y = u.y + v.y, .z = u.z + v.z };
// }

// pub inline fn sub(u: Vec3, v: Vec3) Vec3 {
//     return Vec3{ .x = u.x - v.x, .y = u.y - v.y, .z = u.z - v.z };
// }

// pub inline fn mul(u: anytype, v: anytype) Vec3 {
//     if (@TypeOf(u) == Vec3 and @TypeOf(v) == Vec3) {
//         return Vec3{ .x = u.x * v.x, .y = u.y * v.y, .z = u.z * v.z };
//     } else if (@TypeOf(u) == Vec3 and (@TypeOf(v) == f32) or @TypeOf(v) == comptime_float) {
//         return Vec3{ .x = u.x * v, .y = u.y * v, .z = u.z * v };
//     } else if ((@TypeOf(u) == f32 or @TypeOf(u) == comptime_float) and @TypeOf(v) == Vec3) {
//         return Vec3{ .x = u * v.x, .y = u * v.y, .z = u * v.z };
//     }
//     unreachable;
// }

// pub inline fn div(u: Vec3, t: f32) Vec3 {
//     return mul(1 / t, u);
// }

// pub inline fn dot(u: Vec3, v: Vec3) f32 {
//     return u.x * v.x + u.y * v.y + u.z * v.z;
// }

// pub inline fn cross(u: Vec3, v: Vec3) Vec3 {
//     return Vec3{ .x = u.y * v.z - u.z * v.y, .y = u.z * v.x - u.x * v.z, .z = u.x * v.y - u.y * v.x };
// }

// pub inline fn unitVector(v: Vec3) Vec3 {
//     return div(v, v.length());
// }

// pub inline fn randomInUnitDisk() Vec3 {
//     var p = Vec3{};
//     while (true) {
//         p = Vec3{ .x = rtweekend.randomDoubleRange(-1, 1), .y = rtweekend.randomDoubleRange(-1, 1) };
//         if (p.lengthSquared() < 1)
//             break;
//     }
//     return p;
// }

// pub inline fn random() Vec3 {
//     return Vec3{ .x = rtweekend.randomDouble(), .y = rtweekend.randomDouble(), .z = rtweekend.randomDouble() };
// }

// pub inline fn randomRange(min: f32, max: f32) Vec3 {
//     return Vec3{ .x = rtweekend.randomDoubleRange(min, max), .y = rtweekend.randomDoubleRange(min, max), .z = rtweekend.randomDoubleRange(min, max) };
// }

// pub inline fn randomInUnitSphere() Vec3 {
//     var vec = Vec3{};
//     while (true) {
//         vec = randomRange(-1, 1);
//         if (vec.lengthSquared() < 1) break;
//     }
//     return vec;
// }

// pub inline fn randomUnitVector() Vec3 {
//     return unitVector(randomInUnitSphere());
// }

// pub inline fn randomOnHemisphere(normal: Vec3) Vec3 {
//     const on_unit_sphere = randomUnitVector();
//     if (dot(on_unit_sphere, normal) > 0.0) // In the same hemisphere
//         return on_unit_sphere;

//     return mul(on_unit_sphere, -1.0);
// }

// pub fn reflect(v: Vec3, n: Vec3) Vec3 {
//     return sub(v, mul(2.0, mul(dot(v, n), n)));
// }

// pub fn refract(uv: Vec3, n: Vec3, etai_over_etat: f32) Vec3 {
//     const cos_theta = @min(dot(mul(-1.0, uv), n), 1.0);
//     const r_out_perp = mul(etai_over_etat, (add(uv, mul(cos_theta, n))));
//     const r_out_parallel = mul(-@sqrt(@abs(1.0 - r_out_perp.lengthSquared())), n);
//     return add(r_out_perp, r_out_parallel);
// }

// // TODO div, dot, cross, unitvector

// const expectEqual = std.testing.expectEqual;
// test "neg" {
//     const vec = Vec3{ .x = -5 };
//     const val = vec.neg();
//     try expectEqual(Vec3{ .x = 5 }, val);
// }

// test "get" {
//     const vec = Vec3{ .x = -5 };
//     try expectEqual(-5, vec.get(0));
//     try expectEqual(null, vec.get(4));
// }

// test "plus" {
//     var vec = Vec3{};
//     const other = Vec3{ .x = 1, .y = 2, .z = 3 };

//     try expectEqual(other, vec.plus(other).*);

//     try expectEqual(&vec, vec.plus(other));
// }

// test "mul" {
//     var vec = Vec3{ .x = 1, .y = 2, .z = 3 };
//     const res = vec.mul(2);

//     try expectEqual(Vec3{ .x = 2, .y = 4, .z = 6 }, res.*);
// }

// test "div" {
//     var vec = Vec3{ .x = 1, .y = 2, .z = 3 };
//     const res = vec.div(2);

//     try expectEqual(Vec3{ .x = 0.5, .y = 1, .z = 1.5 }, res.*);
// }

// test "length" {
//     const vec = Vec3{ .x = 1, .y = 2, .z = 3 };

//     try expectEqual(3.74165749, vec.length());
// }

// test "outer mul" {
//     const vecU = Vec3{ .x = 1, .y = 2, .z = 3 };
//     const vecV = Vec3{ .x = 2, .y = 4, .z = 6 };
//     const t: f32 = 2;
//     const t2: f32 = 0.5;

//     try expectEqual(vecV, mul(vecU, t));
//     try expectEqual(vecU, mul(vecV, t2));
//     try expectEqual(Vec3{ .x = 2, .y = 8, .z = 18 }, mul(vecU, vecV));
// }

// test "outer div" {
//     const vec = Vec3{ .x = 2, .y = 4, .z = 6 };
//     const t: f32 = 2;

//     try expectEqual(Vec3{ .x = 1, .y = 2, .z = 3 }, div(vec, t));
// }

// test "dot" {
//     const vecU = Vec3{ .x = 1, .y = 2, .z = 3 };
//     const vecV = Vec3{ .x = 2, .y = 4, .z = 6 };

//     try expectEqual(28, dot(vecU, vecV));
// }

// test "cross" {
//     const vecU = Vec3{ .x = 1, .y = 2, .z = 3 };
//     const vecV = Vec3{ .x = 2, .y = 4, .z = 6 };
//     try expectEqual(Vec3{ .x = 0, .y = 0, .z = 0 }, cross(vecU, vecV));
// }

// test "unitVector" {
//     const vec = Vec3{ .x = 4, .y = 4, .z = 4 };
//     // mmm
//     try expectEqual(1, @round(unitVector(vec).length()));
// }
