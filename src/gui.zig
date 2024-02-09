const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const zgui = @import("zgui");

const embedded_font_data = @embedFile("./FiraCode-Medium.ttf");
const content_dir = @import("build_options").content_dir;

pub const GUI = struct {
    allocator: std.mem.Allocator,
    animation_render_window_visible: bool,
    gctx: *zgpu.GraphicsContext,
    should_quit: bool,
    window: *zglfw.Window,

    pub fn init(allocator: std.mem.Allocator, window: *zglfw.Window) !GUI {
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

        // // You can directly manipulate zgui.Style *before* `newFrame()` call.
        // // Once frame is started (after `newFrame()` call) you have to use
        // // zgui.pushStyleColor*()/zgui.pushStyleVar*() functions.
        // const style = zgui.getStyle();

        // style.window_min_size = .{ 320.0, 240.0 };
        // style.window_border_size = 8.0;
        // style.scrollbar_size = 6.0;
        // {
        //     var color = style.getColor(.scrollbar_grab);
        //     color[1] = 0.8;
        //     style.setColor(.scrollbar_grab, color);
        // }
        // style.scaleAllSizes(scale_factor);

        // {
        //     zgui.plot.getStyle().line_weight = 3.0;
        //     const plot_style = zgui.plot.getStyle();
        //     plot_style.marker = .circle;
        //     plot_style.marker_size = 5.0;
        // }

        return GUI{
            .allocator = allocator,
            .animation_render_window_visible = false,
            .gctx = gctx,
            .should_quit = false,
            .window = window,
        };
    }

    pub fn deinit(self: GUI) void {
        self.gctx.destroy(self.allocator);
    }

    // TODO for now a simple version of the old controlPanel
    // target version looks to be doing a lot more here
    pub fn render(_: GUI) void {
        zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
        zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });

        zgui.pushStyleVar1f(.{ .idx = .window_rounding, .v = 5.0 });
        zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 5.0, 5.0 } });
        defer zgui.popStyleVar(.{ .count = 2 });
        if (zgui.begin("HooRay", .{})) {}

        zgui.end();
    }
};
