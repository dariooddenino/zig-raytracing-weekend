const std = @import("std");
const vec3 = @import("vec3.zig");

const Vec3 = vec3.Vec3;

pub const Texture = union(enum) {
    solid_color: SolidColor,
    checker_texture: CheckerTexture,

    pub fn value(self: Texture, u: f32, v: f32, p: Vec3) Vec3 {
        switch (self) {
            inline else => |object| return object.value(u, v, p),
        }
    }
};

pub const SolidColor = struct {
    color_value: Vec3,

    pub fn init(color: Vec3) SolidColor {
        return SolidColor{ .color_value = color };
    }

    pub fn initFromComponents(red: f32, green: f32, blue: f32) SolidColor {
        return SolidColor.init(Vec3{ .x = red, .y = green, .z = blue });
    }

    // const point3& p as third arg
    pub fn value(self: SolidColor, _: f32, _: f32, _: Vec3) Vec3 {
        return self.color_value;
    }
};

pub const CheckerTexture = struct {
    inv_scale: f32,
    even: SolidColor,
    odd: SolidColor,

    pub fn init(scale: f32, even: SolidColor, odd: SolidColor) CheckerTexture {
        // even and oddhad a make_shared call
        return CheckerTexture{ .inv_scale = 1.0 / scale, .even = even, .odd = odd };
    }

    pub fn value(self: CheckerTexture, u: f32, v: f32, p: Vec3) Vec3 {
        const x_integer: i32 = @intFromFloat(@floor(self.inv_scale * p[0]));
        const y_integer: i32 = @intFromFloat(@floor(self.inv_scale * p[1]));
        const z_integer: i32 = @intFromFloat(@floor(self.inv_scale * p[2]));

        const isEven = @rem(x_integer + y_integer + z_integer, 2) == 0;

        if (isEven) {
            return self.even.value(u, v, p);
        } else {
            return self.odd.value(u, v, p);
        }
    }
};
