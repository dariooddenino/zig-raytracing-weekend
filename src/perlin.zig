const std = @import("std");
const rtweekend = @import("rtweekend.zig");
const Vec3 = @import("vec3.zig").Vec3;

const POINT_COUNT: u16 = 256;

fn permute(p: *[POINT_COUNT]u16, n: u16) void {
    var i: u16 = n - 1;
    while (i > 0) : (i -= 1) {
        const target = rtweekend.randomIntRange(0, i);
        const tmp = p[i];
        p[i] = p[target];
        p[target] = tmp;
    }
}

fn perlin_generate_perm() [POINT_COUNT]u16 {
    var p = [_]u16{0} ** POINT_COUNT;
    var i: u16 = 0;
    while (i < POINT_COUNT) : (i += 1) {
        p[i] = i;
    }

    permute(&p, POINT_COUNT);

    return p;
}

// TODO I'm getting banding here.
fn trilinear_interp(c: [2][2][2]f32, u: f32, v: f32, w: f32) f32 {
    var accum: f32 = 0;
    var i: u8 = 0;
    while (i < 2) : (i += 1) {
        var j: u8 = 0;
        while (j < 2) : (j += 1) {
            var k: u8 = 0;
            while (k < 2) : (k += 1) {
                const n_i: f32 = @floatFromInt(i);
                const n_j: f32 = @floatFromInt(j);
                const n_k: f32 = @floatFromInt(k);
                accum += (n_i * u + (1 - n_i) * (1 - u)) *
                    (n_j * v + (1 - n_j) * (1 - v)) *
                    (n_k * w + (1 - n_k) * (1 - w)) * c[i][j][k];
            }
        }
    }

    return accum;
}

pub const Perlin = struct {
    ranfloat: [POINT_COUNT]f32,
    perm_x: [POINT_COUNT]u16,
    perm_y: [POINT_COUNT]u16,
    perm_z: [POINT_COUNT]u16,

    pub fn init() Perlin {
        var ranfloat = [_]f32{0} ** POINT_COUNT;
        var i: u16 = 0;
        while (i < POINT_COUNT) : (i += 1) {
            ranfloat[i] = rtweekend.randomDouble();
        }

        const perm_x = perlin_generate_perm();
        const perm_y = perlin_generate_perm();
        const perm_z = perlin_generate_perm();

        return Perlin{
            .ranfloat = ranfloat,
            .perm_x = perm_x,
            .perm_y = perm_y,
            .perm_z = perm_z,
        };
    }

    pub fn noise(self: Perlin, p: Vec3) f32 {
        var u = p[0] - @floor(p[0]);
        var v = p[1] - @floor(p[1]);
        var w = p[2] - @floor(p[2]);
        u = u * u * (3 - 2 * u);
        v = v * v * (3 - 2 * v);
        w = w * w * (3 - 2 * w);

        // TODO: the abs hack  means that there are issues somewhere upstream.
        const i: i32 = @intFromFloat(@floor(p[0]));
        const j: i32 = @intFromFloat(@floor(p[1]));
        const k: i32 = @intFromFloat(@floor(p[2]));

        var c: [2][2][2]f32 = undefined;

        var di: u8 = 0;
        while (di < 2) : (di += 1) {
            var dj: u8 = 0;
            while (dj < 2) : (dj += 1) {
                var dk: u8 = 0;
                while (dk < 2) : (dk += 1) {
                    const idi: usize = @intCast((i + di) & 255);
                    const idj: usize = @intCast((j + dj) & 255);
                    const idk: usize = @intCast((k + dk) & 255);
                    c[di][dj][dk] = self.ranfloat[self.perm_x[idi] ^ self.perm_y[idj] ^ self.perm_z[idk]];
                }
            }
        }

        return trilinear_interp(c, u, v, w);

        // const i: u32 = @intFromFloat(@abs(@rem(4 * p[0], 256)));
        // const j: u32 = @intFromFloat(@abs(@rem(4 * p[1], 256)));
        // const k: u32 = @intFromFloat(@abs(@rem(4 * p[2], 256)));
        // const i: u8 = (@as(u8, @intFromFloat(4 * p[0]))) & 255;
        // const j: u8 = (@as(u8, @intFromFloat(4 * p[1]))) & 255;
        // const k: u8 = (@as(u8, @intFromFloat(4 * p[2]))) & 255;

        // return self.ranfloat[self.perm_x[i] ^ self.perm_y[j] ^ self.perm_z[k]];
    }
};
