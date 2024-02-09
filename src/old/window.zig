const std = @import("std");
const color = @import("color.zig");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const assert = std.debug.assert;
const Camera = @import("camera.zig").Camera;

const SDL_WINDOWPOS_UNDEFINED = @as(c_int, @bitCast(c.SDL_WINDOWPOS_UNDEFINED_MASK));

const ColorAndSamples = color.ColorAndSamples;

pub fn initialize(cam: Camera, image_buffer: [][]ColorAndSamples, running: *bool) !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Raytracer", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, @intCast(cam.image_width), @intCast(cam.image_height), c.SDL_WINDOW_OPENGL) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    const surface = c.SDL_GetWindowSurface(window) orelse {
        c.SDL_Log("Unble to get window surface: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    if (c.SDL_UpdateWindowSurface(window) != 0) {
        c.SDL_Log("Error updating window surface: %s", c.SDL_GetError());
        return error.SDLUpdateWindowFailed;
    }

    // TODO hardcoded test
    const wait: u64 = 0.5 * 1000 * 1000 * 1000;
    const total_work: f32 = @floatFromInt(cam.image_width * cam.image_height * cam.samples_per_pixel);
    var last_progress: u32 = 0;

    // TODO this progress text is only useful in debug mode ofc.
    std.debug.print("\nPRESS S TO STOP", .{});
    std.debug.print("\nPROGRESS: ", .{});

    while (running.*) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    running.* = false;
                },
                // TODO: this works in the window only!
                c.SDL_KEYUP => {
                    if (event.key.keysym.sym == c.SDLK_s) {
                        running.* = false;
                    }
                },
                else => {},
            }
        }

        renderImageBuffer(cam.image_width, cam.image_height, surface, image_buffer);

        if (c.SDL_UpdateWindowSurface(window) != 0) {
            c.SDL_Log("Error updating window surface: %s", c.SDL_GetError());
        }

        var processed_samples: f32 = 0;
        for (image_buffer) |x| {
            for (x) |y| {
                processed_samples += y[3];
            }
        }
        const progress: u32 = @as(u32, @intFromFloat(100 * processed_samples / total_work));

        for (last_progress..progress) |i| {
            if (i % 5 == 0) {
                std.debug.print("|", .{});
            } else {
                std.debug.print(".", .{});
            }
        }

        last_progress = progress;

        std.time.sleep(wait);
        if (progress >= 100) {
            std.debug.print(" DONE!\n", .{});
            running.* = false;
        }

        c.SDL_Delay(16);
    }

    c.SDL_DestroyWindow(window);
    c.SDL_Quit();
}

fn renderImageBuffer(w: u32, h: u32, surface: *c.SDL_Surface, image_buffer: [][]ColorAndSamples) void {
    for (0..@intCast(w)) |x| {
        for (0..@intCast(h)) |y| {
            setPixel(surface, @intCast(x), @intCast(y), color.toBgra(color.toGamma(image_buffer[x][y])));
        }
    }
}

fn setPixel(surf: *c.SDL_Surface, x: c_int, y: c_int, pixel: u32) void {
    const target_pixel = @intFromPtr(surf.pixels) +
        @as(usize, @intCast(y)) * @as(usize, @intCast(surf.pitch)) +
        @as(usize, @intCast(x)) * 4;
    @as(*u32, @ptrFromInt(target_pixel)).* = pixel;
}
