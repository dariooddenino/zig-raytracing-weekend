const std = @import("std");
const vec3 = @import("vec3.zig");
const interval = @import("interval.zig");
const rtweekend = @import("rtweekend.zig");

fn linearToGamma(linear_component: f32) f32 {
    return @sqrt(linear_component);
}

pub fn writeColor(stdout: anytype, pixel_color: vec3.Vec3, samples_per_pixel: u16) !void {
    var r = pixel_color.x;
    var g = pixel_color.y;
    var b = pixel_color.z;

    // Divide the color by the number of samples.
    const scale: f32 = 1.0 / rtweekend.toFloat(samples_per_pixel);
    r *= scale;
    g *= scale;
    b *= scale;

    // Apply the linear to gamma transform
    r = linearToGamma(r);
    g = linearToGamma(g);
    b = linearToGamma(b);

    const intensity = interval.Interval{ .max = 0.999 };

    try stdout.print("{d} {d} {d}\n", .{ @round(256 * intensity.clamp(r)), @round(256 * intensity.clamp(g)), @round(256 * intensity.clamp(b)) });
}
