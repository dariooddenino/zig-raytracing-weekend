const std = @import("std");
const zstbi = @import("zstbi");

// TODO should data be a pointer?
pub const RtwImage = struct {
    images: std.ArrayList(zstbi.Image),
    image_index: u8,
    // bytes_per_pixel: u32 = 3,
    // image: *zstbi.Image,
    // image_width: u32 = 0,
    // image_height: u32 = 0,
    // bytes_per_scanline: u32 = 0,

    pub fn init(images: std.ArrayList(zstbi.Image), image_index: u8) RtwImage {

        // TODO I have no idea of how to append to strings...
        return RtwImage{
            .images = images,
            .image_index = image_index,
        };
        // const image = try allocator.create(zstbi.Image);
        // image.* = try zstbi.Image.loadFromFile(content_dir ++ "earthmap.jpg", 4);
        // return RtwImage{
        //     // TODO not sure about this one
        //     .bytes_per_pixel = image.bytes_per_component,
        //     .image = image,
        //     .image_width = image.width,
        //     .image_height = image.height,
        //     .bytes_per_scanline = image.width * image.bytes_per_component,
        // };
    }

    // pub fn deinit(self: RtwImage) void {
    //     self.image.deinit();
    // }

    pub fn clamp(x: u32, low: u32, high: u32) u32 {
        if (x < low) {
            return low;
        } else if (x < high) {
            return x;
        } else {
            return high - 1;
        }
    }

    pub fn getImage(self: RtwImage) zstbi.Image {
        return self.images.items[self.image_index];
    }

    pub fn pixelData(self: RtwImage, x: u32, y: u32) [3]u8 {
        const image = self.getImage();

        const new_x = clamp(x, 0, image.width);
        const new_y = clamp(y, 0, image.height);
        // The image incorrectly has 1.
        const bytes_per_component = 4;
        const start: u32 = (new_y * image.bytes_per_row) + (new_x * bytes_per_component);
        const color = [3]u8{ image.data[start], image.data[start + 1], image.data[start + 2] };

        return color;
    }
};
