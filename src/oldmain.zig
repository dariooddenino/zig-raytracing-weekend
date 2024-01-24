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
const printPpmToStdout = @import("stdout.zig").printPpmToStdout;

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
const BVHTree = bvh.BVHTree;
const BVHNode = bvh.BVHNode;
const Sphere = sphere.Sphere;
const Material = material.Material;

const ObjectList = std.ArrayList(Hittable);

// TODO How can I manipulate objects (i.e. move them?)
// TODO How can I share materials between objects?
// TODO Use Color where appropriate.
// TODO optionally output to a path on quit
// TODO load scene from file
// TODO does it know when it's done?

const image_width: u32 = 800;
const aspect_ratio = 16.0 / 9.0;
const image_height: u32 = @intFromFloat(@round(toFloat(image_width) / aspect_ratio));
const number_of_threads = 8;

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
    const world = try generateWorld(&objects);

    // Initialize camera and render frame.
    var cam = Camera{
        .aspect_ratio = aspect_ratio,
        .image_width = image_width,
        .image_height = image_height,
        .samples_per_pixel = 800,
        .max_depth = 16,
        .vfov = 20,
        .lookfrom = Vec3{ 13, 2, 3 },
        .lookat = vec3.zero(),
        .vup = Vec3{ 0, 1, 0 },
        .defocus_angle = 0.6,
        .focus_dist = 10.0,
        .writer = SharedStateImageWriter.init(image_buffer),
    };

    try cam.initialize();

    var running = true;
    var threads = std.ArrayList(std.Thread).init(allocator);

    for (0..number_of_threads) |thread_idx| {
        const task = Task{ .thread_idx = @intCast(thread_idx), .chunk_size = (image_width * image_height) / number_of_threads, .world = world, .camera = &cam };

        const thread = try std.Thread.spawn(.{ .allocator = allocator }, renderFn, .{ task, &running });

        try threads.append(thread);
    }

    try window.initialize(cam, image_buffer, &running);

    // NOTE I have to read this: https://zig.news/kprotty/resource-efficient-thread-pools-with-zig-3291
    for (threads.items) |thread| {
        thread.join();
    }

    // TODO write to file directly instead of stdout.
    // This put the help text too into the file.
    try printPpmToStdout(image_buffer);
}

pub fn renderFn(context: Task, running: *bool) !void {
    try context.camera.render(context, running);
}

fn generateWorld(objects: *ObjectList) !Hittable {
    const ground_material = Material{ .lambertian = material.Lambertian.fromColor(Vec3{ 0.5, 0.5, 0.5 }) };
    const ground = Sphere.init(vec3.Vec3{ 0, -1000, -1 }, 1000, ground_material);
    try objects.append(ground);

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
                    const spherei = Sphere.initMoving(center, center2, 0.2, sphere_material);
                    try objects.append(spherei);
                } else if (choose_mat < 0.95) {
                    // metal
                    const albedo = vec3.randomRange(0.5, 1);
                    const fuzz = rtweekend.randomDoubleRange(0, 0.5);
                    const sphere_material = material.Material{ .metal = material.Metal.fromColor(albedo, fuzz) };
                    try objects.append(Sphere.init(center, 0.2, sphere_material));
                } else {
                    // glass
                    const sphere_material = material.Material{ .dielectric = material.Dielectric{ .ir = 1.5 } };
                    try objects.append(Sphere.init(center, 0.2, sphere_material));
                }
            }
        }
    }

    const material1 = Material{ .dielectric = material.Dielectric{ .ir = 1.5 } };
    try objects.append(Sphere.init(Vec3{ 0, 1, 0 }, 1.0, material1));

    const material2 = Material{ .lambertian = material.Lambertian.fromColor(Vec3{ 0.4, 0.2, 0.1 }) };
    try objects.append(Sphere.init(Vec3{ -4, 1, 0 }, 1.0, material2));

    const material3 = Material{ .metal = material.Metal.fromColor(Vec3{ 0.7, 0.6, 0.5 }, 0.1) };
    try objects.append(Sphere.init(Vec3{ 4, 1, 0 }, 1.0, material3));

    const tree = try BVHTree.init(allocator, objects.items, 0, objects.items.len);

    return Hittable{ .tree = tree };
}
