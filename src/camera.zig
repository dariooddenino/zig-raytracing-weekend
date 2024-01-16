const std = @import("std");
const rtweekend = @import("rtweekend.zig");
const color = @import("color.zig");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const interval = @import("interval.zig");
const material = @import("material.zig");

const toFloat = rtweekend.toFloat;

pub const Camera = struct {
    aspect_ratio: f32 = 1.0,
    image_width: u32 = 100,
    image_height: u32 = undefined,
    center: vec3.Vec3 = undefined,
    pixel00_loc: vec3.Vec3 = undefined,
    pixel_delta_u: vec3.Vec3 = undefined,
    pixel_delta_v: vec3.Vec3 = undefined,
    samples_per_pixel: u8 = 10,
    max_depth: u8 = 10,

    pub fn render(self: *Camera, stdout: anytype, world: anytype) !void {
        self.initialize();
        try stdout.print("P3\n{d} {d}\n255\n", .{ self.image_width, self.image_height });

        var j: u16 = 0;

        while (j < self.image_height) : (j += 1) {
            var i: u16 = 0;
            // TODO: I should flush here to avoid overwriting with Done?
            std.debug.print("\rScanlines remaining: {d}", .{self.image_height - j});

            while (i < self.image_width) : (i += 1) {
                var pixel_color = vec3.Vec3{};
                var k: u8 = 0;
                while (k < self.samples_per_pixel) : (k += 1) {
                    const r = self.getRay(i, j);
                    pixel_color = vec3.add(pixel_color, rayColor(r, self.max_depth, world));
                }

                try color.writeColor(stdout, pixel_color, self.samples_per_pixel);
            }
        }

        // std.debug.print("\rDone.          \n", .{});
    }

    fn initialize(self: *Camera) void {
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

    fn getRay(self: Camera, i: u16, j: u16) ray.Ray {
        // Get a randomly sampled camera ray for the pixel at location i,j.
        const pixel_center = vec3.add(self.pixel00_loc, vec3.add(vec3.mul(toFloat(i), self.pixel_delta_u), vec3.mul(toFloat(j), self.pixel_delta_v)));
        const pixel_sample = vec3.add(pixel_center, self.pixelSampleSquare());

        const ray_origin = self.center;
        const ray_direction = vec3.sub(pixel_sample, ray_origin);

        return ray.Ray{ .origin = ray_origin, .direction = ray_direction };
    }

    fn pixelSampleSquare(self: Camera) vec3.Vec3 {
        // Returns a random point in the square surrounding a pixel at the origin.
        const px = -0.5 + rtweekend.randomDouble();
        const py = -0.5 + rtweekend.randomDouble();
        return (vec3.add(vec3.mul(px, self.pixel_delta_u), vec3.mul(py, self.pixel_delta_v)));
    }

    fn rayColor(r: ray.Ray, depth: u8, world: anytype) vec3.Vec3 {
        var rec = hittable.HitRecord{};

        if (depth <= 0) {
            return vec3.Vec3{};
        }

        if (world.hit(r, interval.Interval{ .min = 0.001 }, &rec)) {
            var scattered = ray.Ray{};
            var attenuation = vec3.Vec3{};
            const mat = rec.mat;
            if (mat.scatter(r, rec, &attenuation, &scattered))
                return vec3.mul(attenuation, rayColor(scattered, depth - 1, world));

            return vec3.Vec3{};

            // const direction = vec3.add(rec.normal, vec3.randomUnitVector());
            // // const direction = vec3.randomOnHemisphere(rec.normal);
            // const newColor = rayColor(ray.Ray{ .origin = rec.p, .direction = direction }, depth - 1, world);
            // return vec3.mul(0.5, newColor);
        }

        const unit_direction = vec3.unitVector(r.direction);
        const a: f32 = 0.5 * (unit_direction.y + 1.0);
        return vec3.add(vec3.mul(1.0 - a, vec3.Vec3{ .x = 1, .y = 1, .z = 1 }), vec3.mul(a, vec3.Vec3{ .x = 0.5, .y = 0.7, .z = 1.0 }));
    }
};
