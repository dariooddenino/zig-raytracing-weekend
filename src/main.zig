const std = @import("std");
const vec3 = @import("vec3.zig");
const color = @import("color.zig");
const ray = @import("ray.zig");
const rtweekend = @import("rtweekend.zig");
const hittable = @import("hittable.zig");
const hittable_list = @import("hittable_list.zig");
const sphere = @import("sphere.zig");
const interval = @import("interval.zig");
const camera = @import("camera.zig");
const material = @import("material.zig");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const window = @import("window.zig");
const bvh = @import("bvh.zig");

const toFloat = rtweekend.toFloat;

const Vec3 = vec3.Vec3;
const Ray = ray.Ray;
const BvhNode = bvh.BvhNode;
const ColorAndSamples = color.ColorAndSamples;
const Hittable = hittable_list.Hittable;
const HittableList = hittable_list.HittableList;
const Camera = camera.Camera;
const SharedStateImageWriter = camera.SharedStateImageWriter;
const Task = camera.Task;

const ObjectList = std.ArrayList(Hittable);

// TODO How can I manipulate objects (i.e. move them?)
// TODO How can I share materials between objects?
// TODO Use Color where appropriate.
// TODO optionally output to a path on quit
// TODO load scene from file
// TODO does it know when it's done?
// TODO cleanup unused code

const image_width: u32 = 400;
const aspect_ratio = 16.0 / 9.0;
const image_height: u32 = @intFromFloat(@round(toFloat(image_width) / aspect_ratio));
const number_of_threads = 1;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var arena = std.heap.ArenaAllocator.init(gpa.allocator());
var allocator = arena.allocator();

pub fn main() !void {
    defer arena.deinit();
    const image_buffer = try allocator.alloc([]ColorAndSamples, image_width);

    for (0..image_width) |x| {
        image_buffer[x] = try allocator.alloc(ColorAndSamples, image_height);
    }

    for (0..image_width) |x| {
        for (0..image_height) |y| {
            image_buffer[x][y] = ColorAndSamples{ 0, 0, 0, 1 };
        }
    }

    // Allocate heap.
    var objects = ObjectList.init(allocator);
    defer objects.deinit();

    // Generate a random world.
    const world = try generateWorld(objects);

    std.debug.print("World bounding box: {}", .{world.bounding_box});

    // Initialize camera and render frame.
    var cam = Camera{
        .aspect_ratio = aspect_ratio,
        .image_width = image_width,
        .image_height = image_height,
        .samples_per_pixel = 500,
        .max_depth = 80,
        .vfov = 20,
        .lookfrom = Vec3{ 13, 2, 3 },
        .lookat = vec3.zero(),
        .vup = Vec3{ 0, 1, 0 },
        .defocus_angle = 0.6,
        .focus_dist = 10.0,
        .writer = SharedStateImageWriter.init(image_buffer),
    };

    var threads = std.ArrayList(std.Thread).init(allocator);

    for (0..number_of_threads) |thread_idx| {
        const task = Task{ .thread_idx = @intCast(thread_idx), .chunk_size = (image_width * image_height) / number_of_threads, .world = world, .camera = &cam };

        const thread = try std.Thread.spawn(.{ .allocator = allocator }, renderFn, .{task});

        try threads.append(thread);
    }

    try window.initialize(image_width, image_height, image_buffer);

    for (threads.items) |thread| {
        thread.join();
    }

    //// OLD CODE BELOW

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();
    // try cam.render(stdout, world, true);

    // try bw.flush();
}

pub fn renderFn(context: Task) !void {
    try context.camera.render(context);
}

fn generateWorld(objects: ObjectList) !BvhNode {
    var world = hittable_list.HittableList{ .objects = objects };

    // NOTE: I get a crash by enabling this
    // const ground_material = material.Material{ .lambertian = material.Lambertian.fromColor(vec3.Vec3{ 0.5, 0.5, 0.5 }) };
    // const ground = sphere.Sphere.init(vec3.Vec3{ 0, -1000, -1 }, 1000, ground_material);
    // try world.add(ground);

    var a: f32 = -11;
    while (a < 11) : (a += 1) {
        var b: f32 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = rtweekend.randomDouble();
            const center = Vec3{ a + 0.9 * rtweekend.randomDouble(), 0.2, b + 0.9 * rtweekend.randomDouble() };

            if (vec3.length(center - Vec3{ 4, 0.2, 0 }) > 0.9) {
                // TODO: this was a shared_ptr, not entirely sure why and how to replicate.
                // var sphere_material = material.Material{ .lambertian = material.Lambertian.fromColor(vec3.Vec3{}) };

                if (choose_mat < 0.8) {
                    // diffuse
                    const albedo = vec3.random() * vec3.random();
                    const sphere_material = material.Material{ .lambertian = material.Lambertian.fromColor(albedo) };
                    const center2 = center + Vec3{ 0, rtweekend.randomDoubleRange(0, 0.5), 0 };
                    const spherei = sphere.Sphere.initMoving(center, center2, 0.2, sphere_material);
                    try world.add(spherei);
                } else if (choose_mat < 0.95) {
                    // metal
                    const albedo = vec3.randomRange(0.5, 1);
                    const fuzz = rtweekend.randomDoubleRange(0, 0.5);
                    const sphere_material = material.Material{ .metal = material.Metal.fromColor(albedo, fuzz) };
                    try world.add(sphere.Sphere{ .center1 = center, .radius = 0.2, .mat = sphere_material });
                } else {
                    // glass
                    const sphere_material = material.Material{ .dielectric = material.Dielectric{ .ir = 1.5 } };
                    try world.add(sphere.Sphere{ .center1 = center, .radius = 0.2, .mat = sphere_material });
                }
            }
        }
    }

    const material1 = material.Material{ .dielectric = material.Dielectric{ .ir = 1.5 } };
    try world.add(sphere.Sphere.init(Vec3{ 0, 1, 0 }, 1.0, material1));

    const material2 = material.Material{ .lambertian = material.Lambertian.fromColor(Vec3{ 0.4, 0.2, 0.1 }) };
    try world.add(sphere.Sphere.init(Vec3{ -4, 1, 0 }, 1.0, material2));

    const material3 = material.Material{ .metal = material.Metal.fromColor(Vec3{ 0.7, 0.6, 0.5 }, 0.1) };
    try world.add(sphere.Sphere.init(Vec3{ 4, 1, 0 }, 1.0, material3));

    return try BvhNode.init(allocator, &world.objects);
}
