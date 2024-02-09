const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const zgui = @import("zgui");
const zstbi = @import("zstbi");

const GUI = @import("gui.zig").GUI;

const content_dir = @import("build_options").content_dir;
const embedded_font_data = @embedFile("./FiraCode-Medium.ttf");
const window_title = "HooRay";
const window_width = 1600;
const window_height = 1000;

pub const HooRayState = struct {
    allocator: std.mem.Allocator,
    gui: *GUI,
};

fn create(allocator: std.mem.Allocator, window: *zglfw.Window) !*HooRayState {
    const gui = try allocator.create(GUI);
    gui.* = try GUI.init(allocator, window);
    const hooray = try allocator.create(HooRayState);

    hooray.* = .{
        .allocator = allocator,
        .gui = gui,
    };

    return hooray;
}

// TODO I need to come back here to do some more proper cleanup
fn destroy(allocator: std.mem.Allocator, hooray: *HooRayState) void {
    zgui.backend.deinit();
    zgui.plot.deinit();
    zgui.deinit();
    hooray.gui.deinit();
    allocator.destroy(hooray);
}

// TODO this will probably have to be moved to GUI?
// It looks like it's a weird mix of both functions.
// This one in theory should just update the state.
fn update(hooray: *HooRayState) !void {
    zgui.backend.newFrame(
        hooray.gui.gctx.swapchain_descriptor.width,
        hooray.gui.gctx.swapchain_descriptor.height,
    );

    hooray.gui.render();
}

// TODO this will probably have to be moved to GUI?
fn draw(hooray: *HooRayState) void {
    const gctx = hooray.gui.gctx;

    const swapchain_texv = gctx.swapchain.getCurrentTextureView();
    defer swapchain_texv.release();

    const commands = commands: {
        const encoder = gctx.device.createCommandEncoder(null);
        defer encoder.release();

        // Gui pass.
        {
            const pass = zgpu.beginRenderPassSimple(encoder, .load, swapchain_texv, null, null, null);
            defer zgpu.endReleasePass(pass);
            zgui.backend.draw(pass);
        }

        break :commands encoder.finish(null);
    };
    defer commands.release();

    gctx.submit(&.{commands});
    _ = gctx.present();
}

pub fn main() !void {
    zglfw.init() catch {
        std.log.err("Failed to initialize GLFW library.", .{});
        return;
    };
    defer zglfw.terminate();

    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.os.chdir(path) catch {};
    }

    const window = zglfw.Window.create(window_width, window_height, window_title, null) catch {
        std.log.err("Failed to create demo window.", .{});
        return;
    };
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena_state = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena_state.deinit();
    const allocator = arena_state.allocator();

    zstbi.init(allocator);
    defer zstbi.deinit();

    const hooray = try create(allocator, window);
    defer destroy(allocator, hooray);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        try update(hooray);
        draw(hooray);
    }
}
