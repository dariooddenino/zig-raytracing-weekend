const std = @import("std");
const gl = @import("zopengl").bindings;
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const zgui = @import("zgui");
const zstbi = @import("zstbi");

const engines = @import("engines.zig");
const materials = @import("materials.zig");

const Engine = engines.Engine;
const GUI = @import("gui.zig").GUI;
const Light = @import("lights.zig").Light;
const Material = materials.Material;
const Object = @import("objects.zig").Object;

const content_dir = @import("build_options").content_dir;
const embedded_font_data = @embedFile("./FiraCode-Medium.ttf");
const window_title = "HooRay";

// TODO not a big fan of having these here.
var window_width: i32 = 1600;
var window_height: i32 = 1000;
var screen_texture: gl.Uint = undefined;
var refresh_required: bool = false;
var mouse_absorbe3d: bool = false;

pub fn framebufferSizeCallback(_: *zglfw.Window, width: i32, height: i32) callconv(.C) void {
    gl.viewport(0, 0, width, height);
    window_width = width;
    window_height = height;

    gl.bindTexture(gl.TEXTURE_2D, screen_texture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, window_width, window_height, 0, gl.RGBA, gl.FLOAT, null);

    refresh_required = true;
}

pub const HooRayState = struct {
    allocator: std.mem.Allocator,
    gui: *GUI,
    // These three should be somewhere else maybe
    objects: std.ArrayList(Object),
    lights: std.ArrayList(Light),
    plane_material: *Material,
    engine: *Engine,
};

fn init(allocator: std.mem.Allocator, window: *zglfw.Window) !*HooRayState {
    const gui = try allocator.create(GUI);
    gui.* = try GUI.init(allocator, window);
    const hooray = try allocator.create(HooRayState);

    const objects = std.ArrayList(Object).init(allocator);
    const lights = std.ArrayList(Light).init(allocator);

    const engine = try allocator.create(Engine);
    // TODO until I know what to do
    // engine.* = Engine{ .weekend = engines.Weekend{} };

    const plane_material = try allocator.create(Material);

    hooray.* = .{
        .allocator = allocator,
        .gui = gui,
        .objects = objects,
        .lights = lights,
        .engine = engine,
        .plane_material = plane_material,
    };

    return hooray;
}

// TODO I need to come back here to do some more proper cleanup
fn deinit(allocator: std.mem.Allocator, hooray: *HooRayState) void {
    zgui.backend.deinit();
    zgui.plot.deinit();
    zgui.deinit();
    hooray.gui.deinit();
    hooray.objects.deinit();
    hooray.lights.deinit();
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

    const hooray = try init(allocator, window);
    defer deinit(allocator, hooray);

    _ = window.setFramebufferSizeCallback(framebufferSizeCallback);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        try update(hooray);
        draw(hooray);
    }
}
