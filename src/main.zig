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

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // World
    // TODO: this world can only have one type! (I think)
    var world = hittable_list.HittableList{ .objects = std.ArrayList(sphere.Sphere).init(allocator) };
    var sphere1 = sphere.Sphere{ .center = vec3.Vec3{ .z = -1 }, .radius = 0.5 };
    // var sphere1O = hittable_list.HittableObject{ .sphere = &sphere1 };
    var sphere2 = sphere.Sphere{ .center = vec3.Vec3{ .y = -100.5, .z = -1 }, .radius = 100 };
    // var sphere2O = hittable_list.HittableObject{ .sphere = &sphere2 };
    try world.add(&sphere1);
    try world.add(&sphere2);

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    //Render

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var cam = camera.Camera{};
    cam.aspect_ratio = 16.0 / 9.0;
    cam.image_width = 400;
    cam.samples_per_pixel = 100;
    cam.max_depth = 50;
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
