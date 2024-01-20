const std = @import("std");
const rtweekend = @import("rtweekend.zig");
const color = @import("color.zig");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const hittable_list = @import("hittable_list.zig");
const interval = @import("interval.zig");
const material = @import("material.zig");
const bvh = @import("bvh.zig");

const toFloat = rtweekend.toFloat;
const Hittable = hittable_list.Hittable;

// TODO move these two to their own file
pub const Task = struct { thread_idx: u32, chunk_size: u32, world: Hittable, camera: *Camera };

pub const SharedStateImageWriter = struct {
    buffer: [][]color.ColorAndSamples,

    pub fn init(buffer: [][]color.ColorAndSamples) SharedStateImageWriter {
        return .{ .buffer = buffer };
    }

    pub fn writeColor(self: SharedStateImageWriter, x: u32, y: u32, col: vec3.Vec3, number_of_samples: u64) !void {
        self.buffer[x][y] += vec3.Vec4{ col[0], col[1], col[2], 0 };
        self.buffer[x][y][3] = @floatFromInt(number_of_samples);
    }
};

pub const Camera = struct {
    aspect_ratio: f32 = 1.0,
    image_width: u32 = 100,
    image_height: u32 = undefined,
    size: u32 = undefined,
    center: vec3.Vec3 = undefined,
    pixel00_loc: vec3.Vec3 = undefined,
    pixel_delta_u: vec3.Vec3 = undefined,
    pixel_delta_v: vec3.Vec3 = undefined,
    samples_per_pixel: u16 = 10,
    max_depth: u8 = 10,
    vfov: f32 = 90,
    lookfrom: vec3.Vec3 = vec3.Vec3{ 0, 0, -1 },
    lookat: vec3.Vec3 = vec3.zero(),
    vup: vec3.Vec3 = vec3.Vec3{ 0, 1, 0 },
    u: vec3.Vec3 = vec3.zero(),
    v: vec3.Vec3 = vec3.zero(),
    w: vec3.Vec3 = vec3.zero(),
    defocus_angle: f32 = 0,
    focus_dist: f32 = 10,
    defocus_disk_u: vec3.Vec3 = vec3.zero(),
    defocus_disk_v: vec3.Vec3 = vec3.zero(),
    writer: SharedStateImageWriter = undefined,

    pub fn render(self: *Camera, context: Task) std.fs.File.Writer.Error!void {
        const start_at = context.thread_idx * context.chunk_size;
        const end_before = start_at + context.chunk_size;

        for (1..self.samples_per_pixel + 1) |number_of_samples| {
            for (start_at..end_before) |i| {
                const x: u32 = @intCast(@mod(i, self.image_width) + 1);
                const y: u32 = @intCast(@divTrunc(i, self.image_width) + 1);

                const r = self.getRay(x, y);
                const ray_color = self.rayColor(r, self.max_depth, context.world);

                try self.writer.writeColor(x - 1, y - 1, ray_color, number_of_samples);
            }
        }
    }

    // Old render
    // pub fn render(self: *Camera, stdout: anytype, world: hittable_list.HittableList, multi_thread: bool) !void {
    //     self.initialize();
    //     try stdout.print("P3\n{d} {d}\n255\n", .{ self.image_width, self.image_height });
    //     // TODO Maybe this should be a general purpose allocator?
    //     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //     const allocator = gpa.allocator();
    //     defer _ = gpa.deinit();

    //     if (multi_thread) {
    //         const threads_num = 8;
    //         const lines_per_thread: u16 = @as(u16, @intFromFloat(@ceil(@as(f32, @floatFromInt(self.image_height)) / @as(f32, @floatFromInt(threads_num)))));
    //         var threads: [threads_num]std.Thread = undefined;
    //         var results: [threads_num]std.ArrayList(vec3.Vec3) = undefined;

    //         for (0..threads_num) |t| {
    //             results[t] = std.ArrayList(vec3.Vec3).init(allocator);
    //             threads[t] = try std.Thread.spawn(.{}, renderThread, .{ world, self.*, lines_per_thread, t, &results[t] });
    //         }

    //         var final_image: std.ArrayList(vec3.Vec3) = std.ArrayList(vec3.Vec3).init(allocator);

    //         for (0..threads_num) |t| {
    //             threads[t].join();

    //             try final_image.appendSlice(results[t].items);

    //             results[t].clearAndFree();
    //         }

    //         for (final_image.items) |pixel_color| {
    //             try color.writeColor(stdout, pixel_color, self.samples_per_pixel);
    //         }
    //         final_image.clearAndFree();
    //     } else {
    //         var j: u16 = 0;

    //         while (j < self.image_height) : (j += 1) {
    //             var i: u16 = 0;
    //             // TODO: I should flush here to avoid overwriting with Done?
    //             std.debug.print("\rScanlines remaining: {d}", .{self.image_height - j});

    //             while (i < self.image_width) : (i += 1) {
    //                 var pixel_color = vec3.zero();
    //                 var k: u16 = 0;
    //                 while (k < self.samples_per_pixel) : (k += 1) {
    //                     const r = self.getRay(i, j);
    //                     pixel_color = pixel_color + rayColor(r, self.max_depth, world);
    //                 }

    //                 try color.writeColor(stdout, pixel_color, self.samples_per_pixel);
    //             }
    //         }
    //     }
    // }

    pub fn initialize(self: *Camera) !void {
        if (self.image_height == undefined)
            self.image_height = @intFromFloat(@round(toFloat(self.image_width) / self.aspect_ratio));
        if (self.image_height < 1) self.image_height = 1;

        self.size = self.image_height * self.image_width;
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

    fn rayColor(self: Camera, r: ray.Ray, depth: u8, world: Hittable) vec3.Vec3 {
        if (depth <= 0) {
            return vec3.zero();
        }

        const ray_t = interval.Interval{ .min = 0.001, .max = rtweekend.infinity };

        const opt_hit_record = world.hit(r, ray_t);

        if (opt_hit_record) |hit_record| {
            var scattered = ray.Ray{};
            var attenuation = vec3.zero();

            if (hit_record.mat.scatter(r, hit_record, &attenuation, &scattered)) {
                return attenuation * self.rayColor(scattered, depth - 1, world);
            }
            return vec3.zero();
        }

        // NOTE: this was giving me a flat white now?
        const unit_direction = vec3.unitVector(r.direction);
        const a: f32 = 0.5 * (unit_direction[1] + 1.0);
        return vec3.Vec3{ 1, 1, 1 } * vec3.splat3(1.0 - a) + vec3.Vec3{ 0.5, 0.7, 1.0 } * vec3.splat3(a);
    }
};
