const std = @import("std");
const zstbi = @import("zstbi");
const content_dir = @import("build_options").content_dir;

// TODO should data be a pointer?
pub const RtwImage = struct {
    bytes_per_pixel: u32 = 3,
    image: *zstbi.Image,
    image_width: u32 = 0,
    image_height: u32 = 0,
    bytes_per_scanline: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, filename: []const u8) !RtwImage {
        _ = filename;
        // TODO I have no idea of how to append to strings...
        const image = try allocator.create(zstbi.Image);
        image.* = try zstbi.Image.loadFromFile(content_dir ++ "earthmap.jpg", 4);
        return RtwImage{
            // TODO not sure about this one
            .bytes_per_pixel = image.bytes_per_component,
            .image = image,
            .image_width = image.width,
            .image_height = image.height,
            .bytes_per_scanline = image.width * image.bytes_per_component,
        };
    }

    pub fn deinit(self: RtwImage) void {
        self.image.deinit();
    }

    pub fn clamp(x: u32, low: u32, high: u32) u32 {
        if (x < low) {
            return low;
        } else if (x < high) {
            return x;
        } else {
            return high - 1;
        }
    }

    pub fn pixelData(self: RtwImage, x: u32, y: u32) []u8 {
        // Return the address of the three bytes of the pixel at x,y (or magenta if no data).
        // TODO no idea of how to do this
        // if (self.data == null) return ([3]u8{ 255, 0, 255 })[0..3];
        _ = x;
        _ = y;
        // const new_x = clamp(x, 0, self.image_width);
        // const new_y = clamp(y, 0, self.image_height);

        // TODO what am I supposed to do here??
        return self.image.data[0..3];
        // return self.data + (new_y * self.bytes_per_scanline) + (new_x * self.bytes_per_pixel);
        // return self.image.data;
    }
};
