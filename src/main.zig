const std = @import("std");
const vec3 = @import("vec3.zig");
const color = @import("color.zig");
const ray = @import("ray.zig");

fn hitSphere(center: vec3.Vec3, radius: f32, r: ray.Ray) f32 {
    const oc = vec3.sub(r.origin, center);
    const a = vec3.dot(r.direction, r.direction);
    const b = 2.0 * vec3.dot(oc, r.direction);
    const c = vec3.dot(oc, oc) - radius * radius;
    const discriminant = b * b - 4 * a * c;

    if (discriminant < 0) {
        return -1.0;
    } else {
        return ((-b - @sqrt(discriminant)) / (2.0 * a));
    }
}

fn rayColor(r: ray.Ray) vec3.Vec3 {
    const t = hitSphere(vec3.Vec3{ .z = -1 }, 0.5, r);
    if (t > 0.0) {
        const n = vec3.unitVector(vec3.sub(r.at(t), vec3.Vec3{ .z = -1 }));
        return vec3.mul(0.5, vec3.Vec3{ .x = n.x + 1, .y = n.y + 1, .z = n.z + 1 });
    }
    const unit_direction = vec3.unitVector(r.direction);
    const a: f32 = 0.5 * (unit_direction.y + 1.0);
    return vec3.add(vec3.mul(1.0 - a, vec3.Vec3{ .x = 1, .y = 1, .z = 1 }), vec3.mul(a, vec3.Vec3{ .x = 0.5, .y = 0.7, .z = 1.0 }));
}

fn toFloat(v: u32) f32 {
    return @as(f32, @floatFromInt(v));
}

pub fn main() !void {

    // Image
    const aspect_ratio: f32 = 16.0 / 9.0;
    const image_width: u32 = 400;

    // TODO can I write this in a better way?
    var image_height: u32 = @round(image_width / aspect_ratio);
    if (image_height < 1) image_height = 1;

    std.debug.print("Image is {d}x{d}\n", .{ image_width, image_height });

    // Camera
    const focal_length: f32 = 1.0;
    const viewport_height: f32 = 2.0;
    const viewport_width: f32 = viewport_height * (toFloat(image_width) / toFloat(image_height));
    const camera_center = vec3.Vec3{};

    // Calculate the vectors across the horizontal and down the vertical viewport edges.
    const viewport_u: vec3.Vec3 = vec3.Vec3{ .x = viewport_width };
    const viewport_v: vec3.Vec3 = vec3.Vec3{ .y = -viewport_height };

    // Calculate the horizontal and vertical delta vectors from pixel to pixel.
    const pixel_delta_u = vec3.div(viewport_u, toFloat(image_width));
    const pixel_delta_v = vec3.div(viewport_v, toFloat(image_height));

    // Calculate the location of the upper left pixel.
    const viewport_upper_left = vec3.sub(vec3.sub(vec3.sub(camera_center, vec3.Vec3{ .z = focal_length }), vec3.div(viewport_u, 2.0)), vec3.div(viewport_v, 2.0));
    const pixel100_loc = vec3.add(viewport_upper_left, vec3.mul(0.5, vec3.add(pixel_delta_u, pixel_delta_v)));

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    //Render

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.print("P3\n{d} {d}\n255\n", .{ image_width, image_height });

    var j: u16 = 0;

    while (j < image_height) : (j += 1) {
        var i: u16 = 0;
        std.debug.print("\rScanlines remaining: {d}", .{image_height - j});

        while (i < image_width) : (i += 1) {
            const pixel_center = vec3.add(pixel100_loc, vec3.add(vec3.mul(toFloat(i), pixel_delta_u), vec3.mul(toFloat(j), pixel_delta_v)));
            const ray_direction = vec3.sub(pixel_center, camera_center);
            const r = ray.Ray{ .origin = camera_center, .direction = ray_direction };
            // TODO the argument?
            const pixel_color = rayColor(r);

            try color.writeColor(stdout, pixel_color);
        }
    }

    try bw.flush();
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
