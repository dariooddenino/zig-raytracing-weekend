const std = @import("std");
const rtweekend = @import("rtweekend.zig");
const color = @import("color.zig");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const interval = @import("interval.zig");

fn toFloat(v: u32) f32 {
    return @as(f32, @floatFromInt(v));
}

pub const Camera = struct {
    aspect_ratio: f32 = 1.0,
    image_width: u32 = 100,
    image_height: u32 = undefined,
    center: vec3.Vec3 = undefined,
    pixel00_loc: vec3.Vec3 = undefined,
    pixel_delta_u: vec3.Vec3 = undefined,
    pixel_delta_v: vec3.Vec3 = undefined,

    pub fn render(self: *Camera, stdout: anytype, world: anytype) !void {
        self.initialize();
        try stdout.print("P3\n{d} {d}\n255\n", .{ self.image_width, self.image_height });

        var j: u16 = 0;

        while (j < self.image_height) : (j += 1) {
            var i: u16 = 0;
            // TODO: I should flush here to avoid overwriting with Done?
            std.debug.print("\rScanlines remaining: {d}", .{self.image_height - j});

            while (i < self.image_width) : (i += 1) {
                const pixel_center = vec3.add(self.pixel00_loc, vec3.add(vec3.mul(toFloat(i), self.pixel_delta_u), vec3.mul(toFloat(j), self.pixel_delta_v)));
                const ray_direction = vec3.sub(pixel_center, self.center);
                const r = ray.Ray{ .origin = self.center, .direction = ray_direction };
                // TODO the argument?
                const pixel_color = rayColor(r, world);

                try color.writeColor(stdout, pixel_color);
            }
        }

        // std.debug.print("\rDone.          \n", .{});
    }

    pub fn initialize(self: *Camera) void {
        self.image_height = @intFromFloat(@round(toFloat(self.image_width) / self.aspect_ratio));
        if (self.image_height < 1) self.image_height = 1;

        self.center = vec3.Vec3{};

        // Determine viewport dimensions.
        const focal_length: f32 = 1.0;
        const viewport_height: f32 = 2.0;
        const viewport_width: f32 = viewport_height * (toFloat(self.image_width) / toFloat(self.image_height));

        // Calculate the vectors across the horizontal and down the vertical viewport edges.
        const viewport_u: vec3.Vec3 = vec3.Vec3{ .x = viewport_width };
        const viewport_v: vec3.Vec3 = vec3.Vec3{ .y = -viewport_height };

        // Calculate the horizontal and vertical delta vectors from pixel to pixel.
        self.pixel_delta_u = vec3.div(viewport_u, toFloat(self.image_width));
        self.pixel_delta_v = vec3.div(viewport_v, toFloat(self.image_height));

        // Calculate the location of the upper left pixel.
        const viewport_upper_left = vec3.sub(vec3.sub(vec3.sub(self.center, vec3.Vec3{ .z = focal_length }), vec3.div(viewport_u, 2.0)), vec3.div(viewport_v, 2.0));
        self.pixel00_loc = vec3.add(viewport_upper_left, vec3.mul(0.5, vec3.add(self.pixel_delta_u, self.pixel_delta_v)));
    }

    pub fn rayColor(r: ray.Ray, world: anytype) vec3.Vec3 {
        var rec = hittable.HitRecord{};

        if (world.hit(r, interval.Interval{ .min = 0 }, &rec)) {
            return vec3.mul(0.5, vec3.add(rec.normal, vec3.Vec3{ .x = 1, .y = 1, .z = 1 }));
        }

        const unit_direction = vec3.unitVector(r.direction);
        const a: f32 = 0.5 * (unit_direction.y + 1.0);
        return vec3.add(vec3.mul(1.0 - a, vec3.Vec3{ .x = 1, .y = 1, .z = 1 }), vec3.mul(a, vec3.Vec3{ .x = 0.5, .y = 0.7, .z = 1.0 }));
    }
};
