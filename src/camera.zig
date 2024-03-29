const std = @import("std");
const rtweekend = @import("rtweekend.zig");
const color = @import("color.zig");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const interval = @import("interval.zig");
const material = @import("material.zig");
const bvh = @import("bvh.zig");
const objects = @import("objects.zig");
const RayTraceState = @import("main.zig").RayTraceState;

const toFloat = rtweekend.toFloat;
const ColorAndSamples = color.ColorAndSamples;
const Hittable = objects.Hittable;
const Vec3 = vec3.Vec3;
const Vec4 = vec3.Vec4;

// TODO move these two to their own file
pub const Task = struct { thread_idx: u32, chunk_size: u32 };

// The buffer stores all lines sequentially.
pub const SharedStateImageWriter = struct {
    buffer: []ColorAndSamples,
    texture_buffer: []u8,
    width: u32,
    height: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, image_width: u32, image_height: u32) !SharedStateImageWriter {
        const size = image_height * image_width;
        const image_buffer = try allocator.alloc(ColorAndSamples, size);
        const texture_buffer = try allocator.alloc(u8, image_buffer.len * 4);

        for (0..size) |pos| {
            image_buffer[pos] = ColorAndSamples{ 0, 0, 0, 1 };
        }

        return .{ .buffer = image_buffer, .texture_buffer = texture_buffer, .width = image_width, .height = image_height, .allocator = allocator };
    }

    pub fn scrub(self: *SharedStateImageWriter) void {
        for (0..self.width * self.height) |pos| {
            self.buffer[pos] = ColorAndSamples{ 0, 0, 0, 1 };
        }
    }

    pub fn deinit(self: SharedStateImageWriter) void {
        for (0..self.width) |x| {
            self.allocator.free(self.buffer[x]);
        }
        self.allocator.free(self.buffer);
    }

    pub fn writeColor(self: SharedStateImageWriter, i: usize, col: Vec3, number_of_samples: u64) !void {
        self.buffer[i] += Vec4{ col[0], col[1], col[2], 0 };
        self.buffer[i][3] = @floatFromInt(number_of_samples);
        // Update the texture_buffer too.
        const gamma_col = color.toGamma2(self.buffer[i]);
        for (0..4) |pixel_component| {
            var pixel_value: u8 = 255;
            if (pixel_component < 3) {
                pixel_value = @as(u8, @intFromFloat(gamma_col[pixel_component]));
            }
            self.texture_buffer[pixel_component + (4 * i)] = pixel_value;
        }
    }
};

pub const Camera = struct {
    aspect_ratio: f32 = 16.0 / 9.0,
    image_width: u16 = 800,
    image_height: u16 = 0,
    size: u32 = undefined,
    center: vec3.Vec3 = undefined,
    pixel00_loc: vec3.Vec3 = undefined,
    pixel_delta_u: vec3.Vec3 = undefined,
    pixel_delta_v: vec3.Vec3 = undefined,
    samples_per_pixel: u16 = 100,
    max_depth: u8 = 16,
    background: Vec3 = vec3.Vec3{ 0, 0, 0 },
    vfov: f32 = 20,
    lookfrom: vec3.Vec3 = vec3.Vec3{ 13, 2, 3 },
    lookat: vec3.Vec3 = vec3.zero(),
    vup: vec3.Vec3 = vec3.Vec3{ 0, 1, 0 },
    u: vec3.Vec3 = vec3.zero(),
    v: vec3.Vec3 = vec3.zero(),
    w: vec3.Vec3 = vec3.zero(),
    defocus_angle: f32 = 0.6,
    focus_dist: f32 = 10,
    defocus_disk_u: Vec3 = vec3.zero(),
    defocus_disk_v: Vec3 = vec3.zero(),

    pub fn render(self: *Camera, raytrace: *RayTraceState, context: Task) !void {
        const start_at = context.thread_idx * context.chunk_size;
        const end_before = start_at + context.chunk_size;
        // std.debug.print("TASK: {any}, start: {d}, end: {d}\n", .{ context, start_at, end_before });
        // std.debug.print("THREAD: {any}\n", .{raytrace.threads.items[context.thread_idx]});
        for (1..self.samples_per_pixel + 1) |number_of_samples| {
            for (start_at..end_before) |i| {
                const x: u32 = @intCast(@mod(i, self.image_width) + 1);
                const y: u32 = @intCast(@divTrunc(i, self.image_width) + 1);

                const r = self.getRay(x, y);
                const ray_color = self.rayColor(r, self.max_depth, raytrace.world);
                // TODO I think I will pass this as an arg.
                try raytrace.writer.writeColor(i, ray_color, number_of_samples);
                if (!raytrace.threads.items[context.thread_idx].running) {
                    // std.debug.print("RETURNING TASK: {any}\n", .{context});
                    return;
                }
            }
        }
        // std.debug.print("ENDING TASK: {any}\n", .{context});
        // std.debug.print("THREAD: {any}\n", .{raytrace.threads.items[context.thread_idx]});
        raytrace.threads.items[context.thread_idx].stop();
    }

    pub fn init(self: *Camera) !void {
        if (self.image_height == 0)
            self.image_height = @intFromFloat(@round(toFloat(self.image_width) / self.aspect_ratio));
        if (self.image_height < 1) self.image_height = 1;

        self.size = @as(u32, @intCast(self.image_height)) * @as(u32, @intCast(self.image_width));
        self.center = self.lookfrom;

        // Determine viewport dimensions.
        const theta = rtweekend.degreesToRadians(self.vfov);
        const h = @tan(theta / 2.0);
        const viewport_height = 2 * h * self.focus_dist;
        const viewport_width: f32 = viewport_height * (toFloat(self.image_width) / toFloat(self.image_height));

        // Calculate the u,v,w unit basis vectors for the camera coordinate frame.
        self.w = vec3.unitVector(self.lookfrom - self.lookat);
        self.u = vec3.unitVector(vec3.cross(self.vup, self.w));
        self.v = vec3.cross(self.w, self.u);

        // Calculate the vectors across the horizontal and down the vertical viewport edges.
        const viewport_u = vec3.splat3(viewport_width) * self.u;
        const viewport_v = vec3.splat3(viewport_height) * -self.v;

        // Calculate the horizontal and vertical delta vectors from pixel to pixel.
        self.pixel_delta_u = viewport_u / vec3.splat3(toFloat(self.image_width));
        self.pixel_delta_v = viewport_v / vec3.splat3(toFloat(self.image_height));

        // Calculate the location of the upper left pixel.
        const viewport_upper_left = self.center - vec3.splat3(self.focus_dist) * self.w - viewport_u / vec3.splat3(2.0) - viewport_v / vec3.splat3(2.0);

        self.pixel00_loc = viewport_upper_left + vec3.splat3(0.5) * (self.pixel_delta_u + self.pixel_delta_v);

        // Calculate the camera defocus disk basis vector.
        const defocus_radius = self.focus_dist * @tan(rtweekend.degreesToRadians(self.defocus_angle / 2.0));
        self.defocus_disk_u = self.u * vec3.splat3(defocus_radius);
        self.defocus_disk_v = self.v * vec3.splat3(defocus_radius);
    }

    fn defocusDiskSample(self: Camera) vec3.Vec3 {
        // Returns a random point in the camera defocus disk.
        const p = vec3.randomInUnitDisk();
        return self.center + self.defocus_disk_u * vec3.splat3(p[0]) + self.defocus_disk_v * vec3.splat3(p[1]);
    }

    fn pixelSampleSquare(self: Camera) vec3.Vec3 {
        // Returns a random point in the square surrounding a pixel at the origin.
        const px = -0.5 + rtweekend.randomDouble();
        const py = -0.5 + rtweekend.randomDouble();
        return vec3.splat3(px) * self.pixel_delta_u + vec3.splat3(py) * self.pixel_delta_v;
    }

    fn getRay(self: Camera, i: u32, j: u32) ray.Ray {
        // Get a randomly sampled camera ray for the pixel at location i,j, originating from the camera defocus disk.

        const pixel_center = self.pixel00_loc + self.pixel_delta_u * vec3.splat3(toFloat(i)) + self.pixel_delta_v * vec3.splat3(toFloat(j));
        const pixel_sample = pixel_center + self.pixelSampleSquare();

        const ray_origin = if (self.defocus_angle <= 0) self.center else self.defocusDiskSample();
        const ray_direction = pixel_sample - ray_origin;
        const ray_time = rtweekend.randomDouble();

        return ray.Ray{ .origin = ray_origin, .direction = ray_direction, .time = ray_time };
    }

    fn rayColor(self: Camera, r: ray.Ray, depth: u8, world: Hittable) Vec3 {
        if (depth <= 0) {
            return vec3.zero();
        }

        const ray_t = interval.Interval{ .min = 0.001, .max = rtweekend.infinity };

        const opt_hit_record = world.hit(r, ray_t);

        if (opt_hit_record) |hit_record| {
            var scattered = ray.Ray{};
            var attenuation = vec3.zero();
            const color_from_emission = hit_record.mat.emitted(hit_record.u, hit_record.v, hit_record.p);

            if (hit_record.mat.scatter(r, hit_record, &attenuation, &scattered)) {
                const color_from_scatter = attenuation * self.rayColor(scattered, depth - 1, world);

                return color_from_emission + color_from_scatter;
            }
            // return vec3.zero();
            return color_from_emission;
        }
        // const unit_direction = vec3.unitVector(r.direction);
        // const a: f32 = 0.5 * (unit_direction[1] + 1.0);
        // return vec3.Vec3{ 1, 1, 1 } * vec3.splat3(1.0 - a) + vec3.Vec3{ 0.5, 0.7, 1.0 } * vec3.splat3(a);
        return self.background;
    }
};
