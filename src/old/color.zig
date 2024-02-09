const std = @import("std");
const vec3 = @import("vec3.zig");
const interval = @import("interval.zig");
const rtweekend = @import("rtweekend.zig");

pub const Color = vec3.Vec3;
pub const ColorAndSamples = vec3.Vec4;

fn linearToGamma(linear_component: f32) f32 {
    return @sqrt(linear_component);
}

pub fn toBgra(color: vec3.Vec3) u32 {
    const r: u32 = @intFromFloat(color[0] * 255.999);
    const g: u32 = @intFromFloat(color[1] * 255.999);
    const b: u32 = @intFromFloat(color[2] * 255.999);

    return 255 << 24 | r << 16 | g << 8 | b;
}

pub fn toGamma(pixel_color: ColorAndSamples) vec3.Vec3 {
    const scale = 1.0 / pixel_color[3];
    var r = pixel_color[0];
    var g = pixel_color[1];
    var b = pixel_color[2];

    // Divide the color by the number of samples.
    r *= scale;
    g *= scale;
    b *= scale;

    // Apply the linear to gamma transform
    r = linearToGamma(r);
    g = linearToGamma(g);
    b = linearToGamma(b);

    const intensity = interval.Interval{ .min = 0, .max = 0.999 };

    return vec3.Vec3{ intensity.clamp(r), intensity.clamp(g), intensity.clamp(b) };
}

// TODO: test to see what works
pub fn toGamma2(pixel_color: ColorAndSamples) vec3.Vec3 {
    const scale = 1.0 / pixel_color[3];
    var r = pixel_color[0];
    var g = pixel_color[1];
    var b = pixel_color[2];

    // Divide the color by the number of samples.
    r *= scale;
    g *= scale;
    b *= scale;

    // Apply the linear to gamma transform
    r = linearToGamma(r);
    g = linearToGamma(g);
    b = linearToGamma(b);

    const intensity = interval.Interval{ .min = 0, .max = 0.999 };

    return vec3.Vec3{ 256 * intensity.clamp(r), 256 * intensity.clamp(g), 256 * intensity.clamp(b) };
}

pub fn writeColor(stdout: anytype, pixel_color: Color, samples_per_pixel: u16) !void {
    const color_and_samples = ColorAndSamples{ pixel_color[0], pixel_color[1], pixel_color[2], samples_per_pixel };
    const gamma = toGamma(color_and_samples);

    try stdout.print("{d} {d} {d}\n", .{ @round(256 * gamma[0]), @round(256 * gamma[1]), @round(256 * gamma[2]) });
}
