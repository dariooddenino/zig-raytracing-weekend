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

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // TODO: do we need to pass the objects as references? I'm not sure tbh.
    // NOTE I've been removing almost all pointers because they were making my life harder and I don't know what
    // the point of using them actually was.
    // World
    var world = hittable_list.HittableList{ .objects = std.ArrayList(sphere.Sphere).init(allocator) };

    const ground_material = material.Material{ .lambertian = material.Lambertian.fromColor(vec3.Vec3{ .x = 0.5, .y = 0.5, .z = 0.5 }) };
    const ground = sphere.Sphere{ .center = vec3.Vec3{ .y = -1000, .z = -1 }, .radius = 1000, .mat = ground_material };
    try world.add(ground);

    var a: f32 = -9;
    while (a < 9) : (a += 1) {
        var b: f32 = -9;
        while (b < 9) : (b += 1) {
            const choose_mat = rtweekend.randomDouble();
            const center = vec3.Vec3{ .x = a + 0.9 * rtweekend.randomDouble(), .y = 0.2, .z = b + 0.9 * rtweekend.randomDouble() };

            if ((vec3.sub(center, vec3.Vec3{ .x = 4, .y = 0.2 })).length() > 0.9) {
                // TODO: this was a shared_ptr, not entirely sure why and how to replicate.
                // var sphere_material = material.Material{ .lambertian = material.Lambertian.fromColor(vec3.Vec3{}) };

                if (choose_mat < 0.8) {
                    // diffuse
                    const albedo = vec3.mul(vec3.random(), vec3.random());
                    const sphere_material = material.Material{ .lambertian = material.Lambertian.fromColor(albedo) };
                    const spherei = sphere.Sphere{ .center = center, .radius = 0.2, .mat = sphere_material };
                    try world.add(spherei);
                } else if (choose_mat < 0.95) {
                    // metal
                    const albedo = vec3.randomRange(0.5, 1);
                    const fuzz = rtweekend.randomDoubleRange(0, 0.5);
                    const sphere_material = material.Material{ .metal = material.Metal.fromColor(albedo, fuzz) };
                    try world.add(sphere.Sphere{ .center = center, .radius = 0.2, .mat = sphere_material });
                } else {
                    // glass
                    const sphere_material = material.Material{ .dielectric = material.Dielectric{ .ir = 1.5 } };
                    try world.add(sphere.Sphere{ .center = center, .radius = 0.2, .mat = sphere_material });
                }
            }
        }
    }

    const material1 = material.Material{ .dielectric = material.Dielectric{ .ir = 1.5 } };
    try world.add(sphere.Sphere{ .center = vec3.Vec3{ .y = 1 }, .radius = 1.0, .mat = material1 });
    const material2 = material.Material{ .lambertian = material.Lambertian.fromColor(vec3.Vec3{ .x = 0.4, .y = 0.2, .z = 0.1 }) };
    try world.add(sphere.Sphere{ .center = vec3.Vec3{ .x = -4, .y = 1 }, .radius = 1.0, .mat = material2 });
    const material3 = material.Material{ .metal = material.Metal.fromColor(vec3.Vec3{ .x = 0.7, .y = 0.6, .z = 0.5 }, 0.1) };
    try world.add(sphere.Sphere{ .center = vec3.Vec3{ .x = 4, .y = 1 }, .radius = 1.0, .mat = material3 });

    //Render

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var cam = camera.Camera{};
    cam.aspect_ratio = 16.0 / 9.0;
    cam.image_width = 800;
    cam.samples_per_pixel = 500;
    cam.max_depth = 50;

    cam.vfov = 20;
    cam.lookfrom = vec3.Vec3{ .x = 13, .y = 2, .z = 3 };
    cam.lookat = vec3.Vec3{};
    cam.vup = vec3.Vec3{ .y = 1 };

    cam.defocus_angle = 0.6;
    cam.focus_dist = 10.0;

    try cam.render(stdout, world);

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush();
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
