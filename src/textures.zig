const std = @import("std");
const vec3 = @import("vec3.zig");
const RtwImage = @import("rtw_image.zig").RtwImage;
const Interval = @import("interval.zig").Interval;

const Vec3 = vec3.Vec3;

pub const Texture = union(enum) {
    solid_color: SolidColor,
    checker_texture: CheckerTexture,
    image_texture: ImageTexture,

    pub fn deinit(self: Texture) void {
        switch (self) {
            inline else => |object| return object.deinit(),
        }
    }

    pub fn value(self: Texture, u: f32, v: f32, p: Vec3) Vec3 {
        switch (self) {
            inline else => |object| return object.value(u, v, p),
        }
    }
};

pub const SolidColor = struct {
    color_value: Vec3,

    pub fn init(color: Vec3) Texture {
        return Texture{ .solid_color = SolidColor{ .color_value = color } };
    }

    pub fn deinit(_: SolidColor) void {}

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

    pub fn init(scale: f32, even: SolidColor, odd: SolidColor) Texture {
        // even and oddhad a make_shared call
        return Texture{ .checker_texture = CheckerTexture{ .inv_scale = 1.0 / scale, .even = even, .odd = odd } };
    }

    pub fn deinit(_: CheckerTexture) void {}

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

pub const ImageTexture = struct {
    image: RtwImage,

    pub fn init(allocator: std.mem.Allocator, image_filename: []const u8) !Texture {
        const image = try RtwImage.init(allocator, image_filename);
        return Texture{ .image_texture = ImageTexture{ .image = image } };
    }

    pub fn deinit(self: ImageTexture) void {
        self.image.deinit();
    }

    pub fn value(self: ImageTexture, u: f32, v: f32, _: Vec3) Vec3 {
        // If we have no texture data, then return soilid cyan as a debugging aid.
        const cyan = Vec3{ 0, 1, 1 };
        if (self.image.image_height <= 0) return cyan;

        // Clamp input texture coordiantes to [0,1] x [1,0]
        const new_u = (Interval{ .min = 0, .max = 1 }).clamp(u);
        const new_v = 1.0 - (Interval{ .min = 0, .max = 1 }).clamp(v); // Flip V

        const i: u32 = @intFromFloat(new_u * @as(f32, @floatFromInt(self.image.image_width)));
        const j: u32 = @intFromFloat(new_v * @as(f32, @floatFromInt(self.image.image_height)));
        // TODO eh
        const pixel = self.image.pixelData(i, j);

        const color_scale: f32 = 1.0 / 255.0;
        return Vec3{ color_scale * @as(f32, @floatFromInt(pixel[0])), color_scale * @as(f32, @floatFromInt(pixel[1])), color_scale * @as(f32, @floatFromInt(pixel[2])) };
    }
};
