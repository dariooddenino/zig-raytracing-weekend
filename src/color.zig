const std = @import("std");
const vec3 = @import("vec3.zig");

pub fn writeColor(stdout: anytype, pixel_color: vec3.Vec3) !void {
    try stdout.print("{d} {d} {d}\n", .{ @round(255.999 * pixel_color.x), @round(255.999 * pixel_color.y), @round(255.999 * pixel_color.z) });
}
