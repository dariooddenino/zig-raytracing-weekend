const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const zgui = @import("zgui");
const zstbi = @import("zstbi");

const content_dir = @import("build_options").content_dir;
const embedded_font_data = @embedFile("./FiraCode-Medium.ttf");
const window_title = "HooRay";
const window_width = 1600;
const window_height = 1000;

pub const HooRayState = struct {
    allocator: std.mem.Allocator,
    gctx: *zgpu.GraphicsContext,
};

fn create(allocator: std.mem.Allocator, window: *zglfw.Window) !*HooRayState {
    const gctx = try zgpu.GraphicsContext.create(allocator, window, .{});
    errdefer gctx.destroy(allocator);

    zgui.init(allocator);
    zgui.plot.init();
    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };
    const font_size = 16.0 * scale_factor;
    const font_large = zgui.io.addFontFromMemory(embedded_font_data, @floor(font_size * 1.1));
    const font_normal = zgui.io.addFontFromFile(content_dir ++ "Roboto-Medium.ttf", @floor(font_size));
    std.debug.assert(zgui.io.getFont(0) == font_large);
    std.debug.assert(zgui.io.getFont(1) == font_normal);

    // This needs to be called *after* adding your custom fonts.
    zgui.backend.initWithConfig(
        window,
        gctx.device,
        @intFromEnum(zgpu.GraphicsContext.swapchain_format),
        .{ .texture_filter_mode = .linear, .pipeline_multisample_count = 1 },
    );

    // This call is optional. Initially, zgui.io.getFont(0) is a default font.
    zgui.io.setDefaultFont(font_normal);

    // You can directly manipulate zgui.Style *before* `newFrame()` call.
    // Once frame is started (after `newFrame()` call) you have to use
    // zgui.pushStyleColor*()/zgui.pushStyleVar*() functions.
    const style = zgui.getStyle();

    style.window_min_size = .{ 320.0, 240.0 };
    style.window_border_size = 8.0;
    style.scrollbar_size = 6.0;
    {
        var color = style.getColor(.scrollbar_grab);
        color[1] = 0.8;
        style.setColor(.scrollbar_grab, color);
    }
    style.scaleAllSizes(scale_factor);

    {
        zgui.plot.getStyle().line_weight = 3.0;
        const plot_style = zgui.plot.getStyle();
        plot_style.marker = .circle;
        plot_style.marker_size = 5.0;
    }

    const hooray = try allocator.create(HooRayState);

    hooray.* = .{
        .allocator = allocator,
        .gctx = gctx,
    };

    return hooray;
}

fn destroy(allocator: std.mem.Allocator, hooray: *HooRayState) void {
    zgui.backend.deinit();
    zgui.plot.deinit();
    zgui.deinit();
    hooray.gctx.destroy(allocator);
    allocator.destroy(hooray);
}

fn update(hooray: *HooRayState) !void {
    zgui.backend.newFrame(
        hooray.gctx.swapchain_descriptor.width,
        hooray.gctx.swapchain_descriptor.height,
    );
}

fn draw(hooray: *HooRayState) void {
    const gctx = hooray.gctx;

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

    // var images = std.ArrayList(zstbi.Image).init(allocator);
    // var earth_map = try zstbi.Image.loadFromFile(content_dir ++ "earthmap.jpg", 4);
    // try images.append(earth_map);
    // defer earth_map.deinit();
    // defer images.clearAndFree();

    const hooray = try create(allocator, window);
    defer destroy(allocator, hooray);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        try update(hooray);
        draw(hooray);
    }
}
