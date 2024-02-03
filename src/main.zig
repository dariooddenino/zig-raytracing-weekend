const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");
const zstbi = @import("zstbi");
const cameras = @import("camera.zig");
const colors = @import("color.zig");
const objects = @import("objects.zig");
const materials = @import("material.zig");
const vec3 = @import("vec3.zig");
const rtweekend = @import("rtweekend.zig");
const bvh = @import("bvh.zig");
const textures = @import("textures.zig");
const RtwImage = @import("rtw_image.zig").RtwImage;

const BVHTree = bvh.BVHTree;
const Camera = cameras.Camera;
const CheckerTexture = textures.CheckerTexture;
const ColorAndSamples = colors.ColorAndSamples;
const Hittable = objects.Hittable;
const ImageTexture = textures.ImageTexture;
const Material = materials.Material;
const NoiseTexture = textures.NoiseTexture;
const ObjectList = std.ArrayList(Hittable);
const SharedStateImageWriter = cameras.SharedStateImageWriter;
const SolidColor = textures.SolidColor;
const Texture = textures.Texture;
const Sphere = objects.Sphere;
const Task = cameras.Task;
const Vec3 = vec3.Vec3;

const content_dir = @import("build_options").content_dir;
const window_title = "zig-gamedev: gui test (wgpu)";

const embedded_font_data = @embedFile("./FiraCode-Medium.ttf");
const number_of_threads = 8;

// TODO I think I should use zpool
// TODO alter all camera parameters
// TODO alter number of threads
// TODO save to file

pub const RenderThread = struct {
    running: bool = false,
    thread: std.Thread,

    pub fn start(raytrace: *RayTraceState, task: Task) !RenderThread {
        const thread = try std.Thread.spawn(.{ .allocator = raytrace.allocator }, renderFn, .{ raytrace, task });
        return RenderThread{ .running = true, .thread = thread };
    }

    pub fn stop(self: *RenderThread) void {
        self.running = false;
    }

    pub fn join(self: *RenderThread) !void {
        self.thread.join();
    }

    pub fn renderFn(raytrace: *RayTraceState, task: Task) !void {
        try raytrace.camera.render(raytrace, task);
    }
};

pub const RayTraceState = struct {
    gctx: *zgpu.GraphicsContext,
    texture_view: zgpu.TextureViewHandle,
    font_normal: zgui.Font,
    font_large: zgui.Font,
    camera: *Camera,
    writer: SharedStateImageWriter,
    world: Hittable,
    threads: std.ArrayList(RenderThread),
    render_running: *bool,
    allocator: std.mem.Allocator,
    render_start: *i64,
    render_end: *i64,
    images: std.ArrayList(zstbi.Image),
    prev_background_texture: ?zgpu.TextureHandle,
};

fn earthWorld(allocator: std.mem.Allocator, images: std.ArrayList(zstbi.Image), world_objects: *ObjectList) !Hittable {
    const earth_texture = ImageTexture.init(images, 0);
    const earth_surface = Material{ .lambertian = materials.Lambertian.init(earth_texture) };

    const globe = Sphere.init(Vec3{ 0, 0, 0 }, 2, earth_surface);

    try world_objects.append(globe);

    const tree = try BVHTree.init(allocator, world_objects.items, 0, world_objects.items.len);

    return Hittable{ .tree = tree };
}

fn twoSpheresWorld(allocator: std.mem.Allocator, world_objects: *ObjectList) !Hittable {
    const checker_black = SolidColor.init(Vec3{ 0.2, 0.3, 0.1 });
    const checker_white = SolidColor.init(Vec3{ 0.9, 0.9, 0.9 });
    const checker = CheckerTexture.init(0.8, checker_black, checker_white);
    const material = Material{ .lambertian = materials.Lambertian.init(checker) };

    try world_objects.append(Sphere.init(Vec3{ 0, -10, 0 }, 10, material));
    try world_objects.append(Sphere.init(Vec3{ 0, 10, 0 }, 10, material));

    const tree = try BVHTree.init(allocator, world_objects.items, 0, world_objects.items.len);

    return Hittable{ .tree = tree };
}

fn twoPerlinWorld(allocator: std.mem.Allocator, world_objects: *ObjectList) !Hittable {
    const perlin = NoiseTexture.init(4);
    const material = Material{ .lambertian = materials.Lambertian.init(perlin) };

    try world_objects.append(Sphere.init(Vec3{ 0, -1000, 0 }, 1000, material));
    try world_objects.append(Sphere.init(Vec3{ 0, 2, 0 }, 2, material));

    const tree = try BVHTree.init(allocator, world_objects.items, 0, world_objects.items.len);

    return Hittable{ .tree = tree };
}

fn generateWorld(allocator: std.mem.Allocator, images: std.ArrayList(zstbi.Image), world_objects: *ObjectList) !Hittable {

    // NOTE Maybe I should make this pointers.
    // NOTE Should allocate and free?
    const checker_black = SolidColor.init(Vec3{ 0.2, 0.3, 0.1 });
    const checker_white = SolidColor.init(Vec3{ 0.9, 0.9, 0.9 });
    const checker = CheckerTexture.init(0.32, checker_black.solid_color, checker_white.solid_color);
    const ground_material = Material{ .lambertian = materials.Lambertian.init(checker) };

    const ground = Sphere.init(vec3.Vec3{ 0, -1000, 0 }, 1000, ground_material);
    try world_objects.append(ground);

    var a: f32 = -11;
    while (a < 11) : (a += 1) {
        var b: f32 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = rtweekend.randomDouble();
            const center = Vec3{ a + 0.9 * rtweekend.randomDouble(), 0.4 * choose_mat, b + 0.9 * rtweekend.randomDouble() };

            if (vec3.length(center - Vec3{ 4, 0.2, 0 }) > 0.9) {
                // TODO: this was a shared_ptr, not entirely sure why and how to replicate.
                // var sphere_material = material.Material{ .lambertian = material.Lambertian.fromColor(vec3.Vec3{}) };

                if (choose_mat < 0.8) {
                    // diffuse
                    const albedo = vec3.random() * vec3.random();
                    const sphere_material = Material{ .lambertian = materials.Lambertian.fromColor(albedo) };
                    const center2 = center + Vec3{ rtweekend.randomDoubleRange(0, 0.5), rtweekend.randomDoubleRange(0, 0.5), rtweekend.randomDoubleRange(0, 0.5) };
                    const spherei = Sphere.initMoving(center, center2, 0.4 * choose_mat, sphere_material);
                    try world_objects.append(spherei);
                } else if (choose_mat < 0.95) {
                    // metal
                    const albedo = vec3.randomRange(0.5, 1);
                    const fuzz = rtweekend.randomDoubleRange(0, 0.5);
                    const sphere_material = Material{ .metal = materials.Metal.fromColor(albedo, fuzz) };
                    try world_objects.append(Sphere.init(center, 0.5 * choose_mat, sphere_material));
                } else {
                    // glass
                    const sphere_material = Material{ .dielectric = materials.Dielectric{ .ir = rtweekend.randomDoubleRange(1, 2) } };
                    try world_objects.append(Sphere.init(center, 0.3 * choose_mat, sphere_material));
                }
            }
        }
    }

    const material1 = Material{ .dielectric = materials.Dielectric{ .ir = 1.5 } };
    try world_objects.append(Sphere.init(Vec3{ 0, 1, 0 }, 1.0, material1));

    const earth_texture = ImageTexture.init(images, 0);
    const earth_surface = Material{ .lambertian = materials.Lambertian.init(earth_texture) };
    // const material2 = Material{ .lambertian = materials.Lambertian.fromColor(Vec3{ 0.4, 0.2, 0.1 }) };
    try world_objects.append(Sphere.init(Vec3{ -4, 1, 0 }, 1.0, earth_surface));

    const material3 = Material{ .metal = materials.Metal.fromColor(Vec3{ 0.7, 0.6, 0.5 }, 0.1) };
    try world_objects.append(Sphere.init(Vec3{ 4, 1, 0 }, 1.0, material3));

    const tree = try BVHTree.init(allocator, world_objects.items, 0, world_objects.items.len);

    return Hittable{ .tree = tree };
}

fn startRender(raytrace: *RayTraceState) !void {
    raytrace.writer.scrub();
    raytrace.render_running.* = true;
    try raytrace.camera.init(); // Reinitialize with new params.
    for (0..number_of_threads) |thread_idx| {
        const chunk_size = raytrace.camera.size / number_of_threads;
        const task = Task{ .thread_idx = @intCast(thread_idx), .chunk_size = chunk_size };
        const render_thread = try RenderThread.start(raytrace, task);

        try raytrace.threads.append(render_thread);
    }
    raytrace.render_start.* = std.time.milliTimestamp();
}

fn stopRender(raytrace: *RayTraceState) !void {
    raytrace.render_running.* = false;
    raytrace.render_end.* = std.time.milliTimestamp();
    for (raytrace.threads.items) |*thread| {
        thread.stop(); // Stopping both here and at the thread level, shouldn't be a problem.
        try thread.join();
    }
    raytrace.threads.clearAndFree();
}

fn shouldStopRender(raytrace: *RayTraceState) !void {
    var any_thread_running = false;
    for (raytrace.threads.items) |thread| {
        any_thread_running = any_thread_running or thread.running;
    }

    if (!any_thread_running and raytrace.render_running.*) {
        // std.debug.print("should stop\n", .{});
        try stopRender(raytrace);
    }
}

fn create(allocator: std.mem.Allocator, window: *zglfw.Window, images: std.ArrayList(zstbi.Image)) !*RayTraceState {
    const gctx = try zgpu.GraphicsContext.create(allocator, window, .{});
    errdefer gctx.destroy(allocator);

    zgui.init(allocator);
    zgui.plot.init();
    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };
    const font_size = 16.0 * scale_factor;
    const font_large = zgui.io.addFontFromMemory(embedded_font_data, math.floor(font_size * 1.1));
    const font_normal = zgui.io.addFontFromFile(content_dir ++ "Roboto-Medium.ttf", math.floor(font_size));
    assert(zgui.io.getFont(0) == font_large);
    assert(zgui.io.getFont(1) == font_normal);

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

    // To reset zgui.Style with default values:
    //zgui.getStyle().* = zgui.Style.init();

    {
        zgui.plot.getStyle().line_weight = 3.0;
        const plot_style = zgui.plot.getStyle();
        plot_style.marker = .circle;
        plot_style.marker_size = 5.0;
    }

    const raytrace = try allocator.create(RayTraceState);

    var camera = try allocator.create(Camera);
    camera.* = Camera{};
    try camera.init();
    // defer camera.deinit();

    const writer = try SharedStateImageWriter.init(allocator, camera.image_width, camera.image_height);
    // NOTE: How to handle this?
    // defer writer.deinit();

    var world_objects = ObjectList.init(allocator);
    // defer world_objects.deinit();

    // const world = try earthWorld(allocator, images, &world_objects);
    // const world = try twoSpheresWorld(allocator, &world_objects);
    // const world = try generateWorld(allocator, images, &world_objects);
    const world = try twoPerlinWorld(allocator, &world_objects);
    // defer world.deinit();

    const threads = std.ArrayList(RenderThread).init(allocator);

    const running = try allocator.create(bool);
    running.* = false;

    const render_start = try allocator.create(i64);
    render_start.* = 0;

    const render_end = try allocator.create(i64);
    render_end.* = 0;

    raytrace.* = .{
        .gctx = gctx,
        .texture_view = undefined,
        .font_normal = font_normal,
        .font_large = font_large,
        .camera = camera,
        .writer = writer,
        .world = world,
        .threads = threads,
        .render_running = running,
        .allocator = allocator,
        .render_start = render_start,
        .render_end = render_end,
        .images = images,
        .prev_background_texture = null,
    };

    try updateTexture(raytrace);
    return raytrace;
}

fn destroy(allocator: std.mem.Allocator, raytrace: *RayTraceState) void {
    zgui.backend.deinit();
    zgui.plot.deinit();
    // NOTE: Reusing this drawlist didn't worked, so I removed it. But now I'm not destroying it anywere.
    // zgui.destroyDrawList(raytrace.draw_list);
    zgui.deinit();
    raytrace.gctx.destroy(allocator);
    // TODO: I think I should wrap up the threads too here?
    allocator.destroy(raytrace);
}

pub fn countSamples(raytrace: *RayTraceState) f32 {
    const buffer = raytrace.writer.buffer;
    var samples: f32 = 0;
    for (buffer) |pixel| {
        samples += pixel[3];
    }
    return samples;
}

fn controlPanel(raytrace: *RayTraceState) !void {
    zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
    zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });

    zgui.pushStyleVar1f(.{ .idx = .window_rounding, .v = 5.0 });
    zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 5.0, 5.0 } });
    defer zgui.popStyleVar(.{ .count = 2 });

    const current_samples = countSamples(raytrace);
    const total_samples = raytrace.camera.samples_per_pixel * raytrace.writer.buffer.len;
    if (zgui.begin("HooRay", .{})) {
        zgui.bullet();
        zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Render running :");
        zgui.sameLine(.{});
        zgui.text("{}", .{raytrace.render_running.*});
        const render_start = raytrace.render_start.*;
        const now = std.time.milliTimestamp();
        const elapsed = @as(f64, @floatFromInt(now - render_start));
        zgui.bullet();
        zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Elapsed time :");
        zgui.sameLine(.{});
        if (raytrace.render_running.*) {
            zgui.text("{d:.2}s", .{elapsed / 1000});
        } else {
            const total = @as(f64, @floatFromInt(raytrace.render_end.* - render_start));
            zgui.text("{d:.2}s", .{total / 1000});
        }
        zgui.bullet();
        zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "POWER :");
        zgui.sameLine(.{});
        if (raytrace.render_running.*) {
            zgui.text("{d:.0}", .{current_samples / elapsed});
        } else {
            const total = @as(f64, @floatFromInt(raytrace.render_end.* - render_start));
            zgui.textColored(.{ 0.6, 0.6, 0, 1 }, "{d:.0}", .{current_samples / total});
        }
    }

    zgui.separator();
    var samples_per_pixel: i32 = raytrace.camera.samples_per_pixel;
    var max_depth: i32 = raytrace.camera.max_depth;
    var vfov: f32 = raytrace.camera.vfov;
    var defocus_angle: f32 = raytrace.camera.defocus_angle;
    var focus_dist: f32 = raytrace.camera.focus_dist;
    var look_from_x: f32 = raytrace.camera.lookfrom[0];
    var look_from_y: f32 = raytrace.camera.lookfrom[1];
    var look_from_z: f32 = raytrace.camera.lookfrom[2];

    // NOTE: if I update the width I have to recreate the texture with the new image buffer.
    // This is going to be a bit tricky.
    // var width: i32 = raytrace.camera.image_width;
    // _ = zgui.sliderInt("Width", .{ .v = &width, .min = 50, .max = 1920 });
    _ = zgui.sliderInt("Samples", .{ .v = &samples_per_pixel, .min = 10, .max = 2000 });
    _ = zgui.sliderInt("Max depth", .{ .v = &max_depth, .min = 1, .max = 200 });
    _ = zgui.sliderFloat("vFOV", .{ .v = &vfov, .min = 1, .max = 90.0 });
    _ = zgui.sliderFloat("Defocus angle", .{ .v = &defocus_angle, .min = 0.1, .max = 15.0 });
    _ = zgui.sliderFloat("Focus dist", .{ .v = &focus_dist, .min = 0.1, .max = 80 });
    _ = zgui.sliderFloat("Look from x", .{ .v = &look_from_x, .min = 1, .max = 40 });
    _ = zgui.sliderFloat("Look from y", .{ .v = &look_from_y, .min = 1, .max = 40 });
    _ = zgui.sliderFloat("Look from z", .{ .v = &look_from_z, .min = 1, .max = 40 });

    if (!raytrace.render_running.*) {
        raytrace.camera.samples_per_pixel = @intCast(samples_per_pixel);
        raytrace.camera.max_depth = @intCast(max_depth);
        raytrace.camera.vfov = vfov;
        raytrace.camera.focus_dist = focus_dist;
        raytrace.camera.defocus_angle = defocus_angle;
        raytrace.camera.lookfrom = Vec3{ look_from_x, look_from_y, look_from_z };
        // if (raytrace.camera.image_width != width) {
        //     raytrace.camera.image_width = @intCast(width);
        //     raytrace.camera.image_height = 0;
        // }
    }
    zgui.separator();

    zgui.progressBar(.{ .fraction = current_samples / @as(f32, @floatFromInt(total_samples)) });
    if (raytrace.render_running.*) {
        if (zgui.button("STOP RENDER", .{ .w = 200.0 })) {
            try stopRender(raytrace);
        }
    } else {
        if (zgui.button("START RENDER", .{ .w = 200.0 })) {
            try startRender(raytrace);
        }
    }

    zgui.end();
}

fn updateTexture(raytrace: *RayTraceState) !void {
    // const image_data = try raytrace.writer.updateAndGetTextureBuffer();
    const image_data = raytrace.writer.texture_buffer;

    const image = zstbi.Image{
        .data = image_data,
        .width = raytrace.camera.image_width,
        .height = raytrace.camera.image_height,
        .num_components = 4,
        .bytes_per_component = 1,
        .bytes_per_row = raytrace.camera.image_width * 4,
        .is_hdr = false,
    };

    const texture = raytrace.gctx.createTexture(.{ .usage = .{ .texture_binding = true, .copy_dst = true }, .size = .{
        .width = image.width,
        .height = image.height,
        .depth_or_array_layers = 1,
    }, .format = zgpu.imageInfoToTextureFormat(
        image.num_components,
        image.bytes_per_component,
        image.is_hdr,
    ), .mip_level_count = 1 });

    const texture_view = raytrace.gctx.createTextureView(texture, .{});

    raytrace.gctx.queue.writeTexture(
        .{ .texture = raytrace.gctx.lookupResource(texture).? },
        .{
            .bytes_per_row = image.bytes_per_row,
            .rows_per_image = image.height,
        },
        .{ .width = image.width, .height = image.height },
        u8,
        image.data,
    );

    if (raytrace.prev_background_texture) |handle| {
        raytrace.gctx.destroyResource(handle);
        raytrace.gctx.releaseResource(raytrace.texture_view);
    }

    raytrace.prev_background_texture = texture;
    raytrace.texture_view = texture_view;
}

fn update(raytrace: *RayTraceState) !void {
    zgui.backend.newFrame(
        raytrace.gctx.swapchain_descriptor.width,
        raytrace.gctx.swapchain_descriptor.height,
    );

    try shouldStopRender(raytrace);
    try controlPanel(raytrace);
    try updateTexture(raytrace);

    const tex_id = raytrace.gctx.lookupResource(raytrace.texture_view).?;

    const draw_list = zgui.getBackgroundDrawList();
    draw_list.addImage(tex_id, .{ .pmin = .{ 20, 20 }, .pmax = .{ @floatFromInt(raytrace.camera.image_width + 20), @floatFromInt(raytrace.camera.image_height + 20) } });

    // Movement test
    // Assumes the starting camera parameters.
    // TODO this was a very naive attempt. Currently not working.
    // I need a way to keep track of frames, this is running at every single tick.
    const move: bool = true;
    if (move and raytrace.render_running.*) {
        const now = std.time.milliTimestamp();
        const elapsed = now - raytrace.render_start.*;

        const z = 3 + @as(f32, @floatFromInt(elapsed - now)) * 0.001;

        // try stopRender(raytrace);
        raytrace.camera.lookfrom = Vec3{ raytrace.camera.lookfrom[0], raytrace.camera.lookfrom[1], z };
        // try raytrace.camera.init();
        // try startRender(raytrace);
    }
}

// fn updatez(demo: *DemoState) !void {
//     zgui.backend.newFrame(
//         demo.gctx.swapchain_descriptor.width,
//         demo.gctx.swapchain_descriptor.height,
//     );

//     zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
//     zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });

//     zgui.pushStyleVar1f(.{ .idx = .window_rounding, .v = 5.0 });
//     zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 5.0, 5.0 } });
//     defer zgui.popStyleVar(.{ .count = 2 });

//     if (zgui.begin("Demo Settings", .{})) {
//         zgui.bullet();
//         zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Average :");
//         zgui.sameLine(.{});
//         zgui.text(
//             "{d:.3} ms/frame ({d:.1} fps)",
//             .{ demo.gctx.stats.average_cpu_time, demo.gctx.stats.fps },
//         );

//         zgui.pushFont(demo.font_large);
//         zgui.separator();
//         zgui.dummy(.{ .w = -1.0, .h = 20.0 });
//         zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "zgui -");
//         zgui.sameLine(.{});
//         zgui.textWrapped("Zig bindings for 'dear imgui' library. " ++
//             "Easy to use, hand-crafted API with default arguments, " ++
//             "named parameters and Zig style text formatting.", .{});
//         zgui.dummy(.{ .w = -1.0, .h = 20.0 });
//         zgui.separator();
//         zgui.popFont();

//         if (zgui.collapsingHeader("Widgets: Main", .{})) {
//             zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Button");
//             if (zgui.button("Button 1", .{ .w = 200.0 })) {
//                 // 'Button 1' pressed.
//             }
//             zgui.sameLine(.{ .spacing = 20.0 });
//             if (zgui.button("Button 2", .{ .h = 60.0 })) {
//                 // 'Button 2' pressed.
//             }
//             zgui.sameLine(.{});
//             {
//                 const label = "Button 3 is special ;)";
//                 const s = zgui.calcTextSize(label, .{});
//                 _ = zgui.button(label, .{ .w = s[0] + 30.0 });
//             }
//             zgui.sameLine(.{});
//             _ = zgui.button("Button 4", .{});
//             _ = zgui.button("Button 5", .{ .w = -1.0, .h = 100.0 });

//             zgui.pushStyleColor4f(.{ .idx = .text, .c = .{ 1.0, 0.0, 0.0, 1.0 } });
//             _ = zgui.button("  Red Text Button  ", .{});
//             zgui.popStyleColor(.{});

//             zgui.sameLine(.{});
//             zgui.pushStyleColor4f(.{ .idx = .text, .c = .{ 1.0, 1.0, 0.0, 1.0 } });
//             _ = zgui.button("  Yellow Text Button  ", .{});
//             zgui.popStyleColor(.{});

//             _ = zgui.smallButton("  Small Button  ");
//             zgui.sameLine(.{});
//             _ = zgui.arrowButton("left_button_id", .{ .dir = .left });
//             zgui.sameLine(.{});
//             _ = zgui.arrowButton("right_button_id", .{ .dir = .right });
//             zgui.spacing();

//             const static = struct {
//                 var check0: bool = true;
//                 var bits: u32 = 0xf;
//                 var radio_value: u32 = 1;
//                 var month: i32 = 1;
//                 var progress: f32 = 0.0;
//             };
//             zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Checkbox");
//             _ = zgui.checkbox("Magic Is Everywhere", .{ .v = &static.check0 });
//             zgui.spacing();

//             zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Checkbox bits");
//             zgui.text("Bits value: {b} ({d})", .{ static.bits, static.bits });
//             _ = zgui.checkboxBits("Bit 0", .{ .bits = &static.bits, .bits_value = 0x1 });
//             _ = zgui.checkboxBits("Bit 1", .{ .bits = &static.bits, .bits_value = 0x2 });
//             _ = zgui.checkboxBits("Bit 2", .{ .bits = &static.bits, .bits_value = 0x4 });
//             _ = zgui.checkboxBits("Bit 3", .{ .bits = &static.bits, .bits_value = 0x8 });
//             zgui.spacing();

//             zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Radio buttons");
//             if (zgui.radioButton("One", .{ .active = static.radio_value == 1 })) static.radio_value = 1;
//             if (zgui.radioButton("Two", .{ .active = static.radio_value == 2 })) static.radio_value = 2;
//             if (zgui.radioButton("Three", .{ .active = static.radio_value == 3 })) static.radio_value = 3;
//             if (zgui.radioButton("Four", .{ .active = static.radio_value == 4 })) static.radio_value = 4;
//             if (zgui.radioButton("Five", .{ .active = static.radio_value == 5 })) static.radio_value = 5;
//             zgui.spacing();

//             _ = zgui.radioButtonStatePtr("January", .{ .v = &static.month, .v_button = 1 });
//             zgui.sameLine(.{});
//             _ = zgui.radioButtonStatePtr("February", .{ .v = &static.month, .v_button = 2 });
//             zgui.sameLine(.{});
//             _ = zgui.radioButtonStatePtr("March", .{ .v = &static.month, .v_button = 3 });
//             zgui.spacing();

//             zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Progress bar");
//             zgui.progressBar(.{ .fraction = static.progress });
//             static.progress += 0.005;
//             if (static.progress > 1.0) static.progress = 0.0;
//             zgui.spacing();

//             zgui.bulletText("keep going...", .{});
//         }

//         if (zgui.collapsingHeader("Widgets: Combo Box", .{})) {
//             const static = struct {
//                 var selection_index: u32 = 0;
//                 var current_item: i32 = 0;
//             };

//             const items = [_][:0]const u8{ "aaa", "bbb", "ccc", "ddd", "eee", "FFF", "ggg", "hhh" };
//             if (zgui.beginCombo("Combo 0", .{ .preview_value = items[static.selection_index] })) {
//                 for (items, 0..) |item, index| {
//                     const i = @as(u32, @intCast(index));
//                     if (zgui.selectable(item, .{ .selected = static.selection_index == i }))
//                         static.selection_index = i;
//                 }
//                 zgui.endCombo();
//             }

//             _ = zgui.combo("Combo 1", .{
//                 .current_item = &static.current_item,
//                 .items_separated_by_zeros = "Item 0\x00Item 1\x00Item 2\x00Item 3\x00\x00",
//             });
//         }

//         if (zgui.collapsingHeader("Widgets: Drag Sliders", .{})) {
//             const static = struct {
//                 var v1: f32 = 0.0;
//                 var v2: [2]f32 = .{ 0.0, 0.0 };
//                 var v3: [3]f32 = .{ 0.0, 0.0, 0.0 };
//                 var v4: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 };
//                 var range: [2]f32 = .{ 0.0, 0.0 };
//                 var v1i: i32 = 0.0;
//                 var v2i: [2]i32 = .{ 0, 0 };
//                 var v3i: [3]i32 = .{ 0, 0, 0 };
//                 var v4i: [4]i32 = .{ 0, 0, 0, 0 };
//                 var rangei: [2]i32 = .{ 0, 0 };
//                 var si8: i8 = 123;
//                 var vu16: [3]u16 = .{ 10, 11, 12 };
//                 var sd: f64 = 0.0;
//             };
//             _ = zgui.dragFloat("Drag float 1", .{ .v = &static.v1 });
//             _ = zgui.dragFloat2("Drag float 2", .{ .v = &static.v2 });
//             _ = zgui.dragFloat3("Drag float 3", .{ .v = &static.v3 });
//             _ = zgui.dragFloat4("Drag float 4", .{ .v = &static.v4 });
//             _ = zgui.dragFloatRange2(
//                 "Drag float range 2",
//                 .{ .current_min = &static.range[0], .current_max = &static.range[1] },
//             );
//             _ = zgui.dragInt("Drag int 1", .{ .v = &static.v1i });
//             _ = zgui.dragInt2("Drag int 2", .{ .v = &static.v2i });
//             _ = zgui.dragInt3("Drag int 3", .{ .v = &static.v3i });
//             _ = zgui.dragInt4("Drag int 4", .{ .v = &static.v4i });
//             _ = zgui.dragIntRange2(
//                 "Drag int range 2",
//                 .{ .current_min = &static.rangei[0], .current_max = &static.rangei[1] },
//             );
//             _ = zgui.dragScalar("Drag scalar (i8)", i8, .{ .v = &static.si8, .min = -20 });
//             _ = zgui.dragScalarN(
//                 "Drag scalar N ([3]u16)",
//                 @TypeOf(static.vu16),
//                 .{ .v = &static.vu16, .max = 100 },
//             );
//             _ = zgui.dragScalar(
//                 "Drag scalar (f64)",
//                 f64,
//                 .{ .v = &static.sd, .min = -1.0, .max = 1.0, .speed = 0.005 },
//             );
//         }

//         if (zgui.collapsingHeader("Widgets: Regular Sliders", .{})) {
//             const static = struct {
//                 var v1: f32 = 0;
//                 var v2: [2]f32 = .{ 0, 0 };
//                 var v3: [3]f32 = .{ 0, 0, 0 };
//                 var v4: [4]f32 = .{ 0, 0, 0, 0 };
//                 var v1i: i32 = 0;
//                 var v2i: [2]i32 = .{ 0, 0 };
//                 var v3i: [3]i32 = .{ 10, 10, 10 };
//                 var v4i: [4]i32 = .{ 0, 0, 0, 0 };
//                 var su8: u8 = 1;
//                 var vu16: [3]u16 = .{ 10, 11, 12 };
//                 var vsf: f32 = 0;
//                 var vsi: i32 = 0;
//                 var vsu8: u8 = 1;
//                 var angle: f32 = 0;
//             };
//             _ = zgui.sliderFloat("Slider float 1", .{ .v = &static.v1, .min = 0.0, .max = 1.0 });
//             _ = zgui.sliderFloat2("Slider float 2", .{ .v = &static.v2, .min = -1.0, .max = 1.0 });
//             _ = zgui.sliderFloat3("Slider float 3", .{ .v = &static.v3, .min = 0.0, .max = 1.0 });
//             _ = zgui.sliderFloat4("Slider float 4", .{ .v = &static.v4, .min = 0.0, .max = 1.0 });
//             _ = zgui.sliderInt("Slider int 1", .{ .v = &static.v1i, .min = 0, .max = 100 });
//             _ = zgui.sliderInt2("Slider int 2", .{ .v = &static.v2i, .min = -20, .max = 20 });
//             _ = zgui.sliderInt3("Slider int 3", .{ .v = &static.v3i, .min = 10, .max = 50 });
//             _ = zgui.sliderInt4("Slider int 4", .{ .v = &static.v4i, .min = 0, .max = 10 });
//             _ = zgui.sliderScalar(
//                 "Slider scalar (u8)",
//                 u8,
//                 .{ .v = &static.su8, .min = 0, .max = 100, .cfmt = "%Xh" },
//             );
//             _ = zgui.sliderScalarN(
//                 "Slider scalar N ([3]u16)",
//                 [3]u16,
//                 .{ .v = &static.vu16, .min = 1, .max = 100 },
//             );
//             _ = zgui.sliderAngle("Slider angle", .{ .vrad = &static.angle });
//             _ = zgui.vsliderFloat(
//                 "VSlider float",
//                 .{ .w = 80.0, .h = 200.0, .v = &static.vsf, .min = 0.0, .max = 1.0 },
//             );
//             zgui.sameLine(.{});
//             _ = zgui.vsliderInt(
//                 "VSlider int",
//                 .{ .w = 80.0, .h = 200.0, .v = &static.vsi, .min = 0, .max = 100 },
//             );
//             zgui.sameLine(.{});
//             _ = zgui.vsliderScalar(
//                 "VSlider scalar (u8)",
//                 u8,
//                 .{ .w = 80.0, .h = 200.0, .v = &static.vsu8, .min = 0, .max = 200 },
//             );
//         }

//         if (zgui.collapsingHeader("Widgets: Input with Keyboard", .{})) {
//             const static = struct {
//                 var buf: [128]u8 = undefined;
//                 var buf1: [128]u8 = undefined;
//                 var buf2: [128]u8 = undefined;
//                 var v1: f32 = 0;
//                 var v2: [2]f32 = .{ 0, 0 };
//                 var v3: [3]f32 = .{ 0, 0, 0 };
//                 var v4: [4]f32 = .{ 0, 0, 0, 0 };
//                 var v1i: i32 = 0;
//                 var v2i: [2]i32 = .{ 0, 0 };
//                 var v3i: [3]i32 = .{ 0, 0, 0 };
//                 var v4i: [4]i32 = .{ 0, 0, 0, 0 };
//                 var sf64: f64 = 0.0;
//                 var si8: i8 = 0;
//                 var v3u8: [3]u8 = .{ 0, 0, 0 };
//             };
//             _ = zgui.inputText("Input text", .{ .buf = static.buf[0..] });
//             _ = zgui.inputTextMultiline("Input text multiline", .{ .buf = static.buf1[0..] });
//             _ = zgui.inputTextWithHint(
//                 "Input text with hint",
//                 .{ .hint = "Enter your name", .buf = static.buf2[0..] },
//             );
//             _ = zgui.inputFloat("Input float 1", .{ .v = &static.v1 });
//             _ = zgui.inputFloat2("Input float 2", .{ .v = &static.v2 });
//             _ = zgui.inputFloat3("Input float 3", .{ .v = &static.v3 });
//             _ = zgui.inputFloat4("Input float 4", .{ .v = &static.v4 });
//             _ = zgui.inputInt("Input int 1", .{ .v = &static.v1i });
//             _ = zgui.inputInt2("Input int 2", .{ .v = &static.v2i });
//             _ = zgui.inputInt3("Input int 3", .{ .v = &static.v3i });
//             _ = zgui.inputInt4("Input int 4", .{ .v = &static.v4i });
//             _ = zgui.inputDouble("Input double", .{ .v = &static.sf64 });
//             _ = zgui.inputScalar("Input scalar (i8)", i8, .{ .v = &static.si8 });
//             _ = zgui.inputScalarN("Input scalar N ([3]u8)", [3]u8, .{ .v = &static.v3u8 });
//         }

//         if (zgui.collapsingHeader("Widgets: Color Editor/Picker", .{})) {
//             const static = struct {
//                 var col3: [3]f32 = .{ 0, 0, 0 };
//                 var col4: [4]f32 = .{ 0, 0, 0, 0 };
//                 var col3p: [3]f32 = .{ 0, 0, 0 };
//                 var col4p: [4]f32 = .{ 0, 0, 0, 0 };
//             };
//             _ = zgui.colorEdit3("Color edit 3", .{ .col = &static.col3 });
//             _ = zgui.colorEdit4("Color edit 4", .{ .col = &static.col4 });
//             _ = zgui.colorPicker3("Color picker 3", .{ .col = &static.col3p });
//             _ = zgui.colorPicker4("Color picker 4", .{ .col = &static.col4p });
//             _ = zgui.colorButton("color_button_id", .{ .col = .{ 0, 1, 0, 1 } });
//         }

//         if (zgui.collapsingHeader("Widgets: Trees", .{})) {
//             if (zgui.treeNodeStrId("tree_id", "My Tree {d}", .{1})) {
//                 zgui.textUnformatted("Some content...");
//                 zgui.treePop();
//             }
//             if (zgui.collapsingHeader("Collapsing header 1", .{})) {
//                 zgui.textUnformatted("Some content...");
//             }
//         }

//         if (zgui.collapsingHeader("Widgets: List Boxes", .{})) {
//             const static = struct {
//                 var selection_index: u32 = 0;
//             };
//             const items = [_][:0]const u8{ "aaa", "bbb", "ccc", "ddd", "eee", "FFF", "ggg", "hhh" };
//             if (zgui.beginListBox("List Box 0", .{})) {
//                 for (items, 0..) |item, index| {
//                     const i = @as(u32, @intCast(index));
//                     if (zgui.selectable(item, .{ .selected = static.selection_index == i }))
//                         static.selection_index = i;
//                 }
//                 zgui.endListBox();
//             }
//         }

//         if (zgui.collapsingHeader("Widgets: Image", .{})) {
//             const tex_id = demo.gctx.lookupResource(demo.texture_view).?;
//             zgui.image(tex_id, .{ .w = 512.0, .h = 512.0 });
//             _ = zgui.imageButton("image_button_id", tex_id, .{ .w = 512.0, .h = 512.0 });
//         }

//         const draw_list = zgui.getBackgroundDrawList();
//         draw_list.pushClipRect(.{ .pmin = .{ 0, 0 }, .pmax = .{ 400, 400 } });
//         draw_list.addLine(.{
//             .p1 = .{ 0, 0 },
//             .p2 = .{ 400, 400 },
//             .col = zgui.colorConvertFloat3ToU32([_]f32{ 1, 0, 1 }),
//             .thickness = 5.0,
//         });
//         draw_list.popClipRect();

//         draw_list.pushClipRectFullScreen();
//         draw_list.addRectFilled(.{
//             .pmin = .{ 100, 100 },
//             .pmax = .{ 300, 200 },
//             .col = zgui.colorConvertFloat3ToU32([_]f32{ 1, 1, 1 }),
//             .rounding = 25.0,
//         });
//         draw_list.addRectFilledMultiColor(.{
//             .pmin = .{ 100, 300 },
//             .pmax = .{ 200, 400 },
//             .col_upr_left = zgui.colorConvertFloat3ToU32([_]f32{ 1, 0, 0 }),
//             .col_upr_right = zgui.colorConvertFloat3ToU32([_]f32{ 0, 1, 0 }),
//             .col_bot_right = zgui.colorConvertFloat3ToU32([_]f32{ 0, 0, 1 }),
//             .col_bot_left = zgui.colorConvertFloat3ToU32([_]f32{ 1, 1, 0 }),
//         });
//         draw_list.addQuadFilled(.{
//             .p1 = .{ 150, 400 },
//             .p2 = .{ 250, 400 },
//             .p3 = .{ 200, 500 },
//             .p4 = .{ 100, 500 },
//             .col = 0xff_ff_ff_ff,
//         });
//         draw_list.addQuad(.{
//             .p1 = .{ 170, 420 },
//             .p2 = .{ 270, 420 },
//             .p3 = .{ 220, 520 },
//             .p4 = .{ 120, 520 },
//             .col = zgui.colorConvertFloat3ToU32([_]f32{ 1, 0, 0 }),
//             .thickness = 3.0,
//         });
//         draw_list.addText(.{ 130, 130 }, 0xff_00_00_ff, "The number is: {}", .{7});
//         draw_list.addCircleFilled(.{
//             .p = .{ 200, 600 },
//             .r = 50,
//             .col = zgui.colorConvertFloat3ToU32([_]f32{ 1, 1, 1 }),
//         });
//         draw_list.addCircle(.{
//             .p = .{ 200, 600 },
//             .r = 30,
//             .col = zgui.colorConvertFloat3ToU32([_]f32{ 1, 0, 0 }),
//             .thickness = 11,
//         });
//         draw_list.addPolyline(
//             &.{ .{ 100, 700 }, .{ 200, 600 }, .{ 300, 700 }, .{ 400, 600 } },
//             .{ .col = zgui.colorConvertFloat3ToU32([_]f32{ 0x11.0 / 0xff.0, 0xaa.0 / 0xff.0, 0 }), .thickness = 7 },
//         );
//         _ = draw_list.getClipRectMin();
//         _ = draw_list.getClipRectMax();
//         draw_list.popClipRect();

//         if (zgui.collapsingHeader("Plot: Scatter", .{})) {
//             zgui.plot.pushStyleVar1f(.{ .idx = .marker_size, .v = 3.0 });
//             zgui.plot.pushStyleVar1f(.{ .idx = .marker_weight, .v = 1.0 });
//             if (zgui.plot.beginPlot("Scatter Plot", .{ .flags = .{ .no_title = true } })) {
//                 zgui.plot.setupAxis(.x1, .{ .label = "xaxis" });
//                 zgui.plot.setupAxisLimits(.x1, .{ .min = 0, .max = 5 });
//                 zgui.plot.setupLegend(.{ .north = true, .east = true }, .{});
//                 zgui.plot.setupFinish();
//                 zgui.plot.plotScatterValues("y data", i32, .{ .v = &.{ 0, 1, 0, 1, 0, 1 } });
//                 zgui.plot.plotScatter("xy data", f32, .{
//                     .xv = &.{ 0.1, 0.2, 0.5, 2.5 },
//                     .yv = &.{ 0.1, 0.3, 0.5, 0.9 },
//                 });
//                 zgui.plot.endPlot();
//             }
//             zgui.plot.popStyleVar(.{ .count = 2 });
//         }
//     }
//     zgui.end();

//     if (zgui.begin("Plot", .{})) {
//         if (zgui.plot.beginPlot("Line Plot", .{ .h = -1.0 })) {
//             zgui.plot.setupAxis(.x1, .{ .label = "xaxis" });
//             zgui.plot.setupAxisLimits(.x1, .{ .min = 0, .max = 5 });
//             zgui.plot.setupLegend(.{ .south = true, .west = true }, .{});
//             zgui.plot.setupFinish();
//             zgui.plot.plotLineValues("y data", i32, .{ .v = &.{ 0, 1, 0, 1, 0, 1 } });
//             zgui.plot.plotLine("xy data", f32, .{
//                 .xv = &.{ 0.1, 0.2, 0.5, 2.5 },
//                 .yv = &.{ 0.1, 0.3, 0.5, 0.9 },
//             });
//             zgui.plot.endPlot();
//         }
//     }
//     zgui.end();

//     // TODO: will not draw on screen for now
//     demo.draw_list.reset();
//     demo.draw_list.addCircle(.{
//         .p = .{ 200, 700 },
//         .r = 30,
//         .col = zgui.colorConvertFloat3ToU32([_]f32{ 1, 1, 0 }),
//         .thickness = 15 + 15 * @as(f32, @floatCast(@sin(demo.gctx.stats.time))),
//     });
// }

fn draw(demo: *RayTraceState) void {
    const gctx = demo.gctx;
    //const fb_width = gctx.swapchain_descriptor.width;
    //const fb_height = gctx.swapchain_descriptor.height;

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

    const window = zglfw.Window.create(1600, 1000, window_title, null) catch {
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

    var images = std.ArrayList(zstbi.Image).init(allocator);
    var earth_map = try zstbi.Image.loadFromFile(content_dir ++ "earthmap.jpg", 4);
    try images.append(earth_map);
    defer earth_map.deinit();
    defer images.clearAndFree();

    const raytrace = try create(allocator, window, images);
    defer destroy(allocator, raytrace);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        try update(raytrace);
        draw(raytrace);
    }
}

// test "bufferToData" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer _ = gpa.deinit();
//     var arena_state = std.heap.ArenaAllocator.init(gpa.allocator());
//     defer arena_state.deinit();
//     const allocator = arena_state.allocator();

//     const image_width = 5;
//     const image_height = 3;

//     const image_buffer = try allocator.alloc([]ColorAndSamples, image_width);

//     for (0..image_width) |x| {
//         image_buffer[x] = try allocator.alloc(ColorAndSamples, image_height);
//     }

//     for (0..image_width) |x| {
//         for (0..image_height) |y| {
//             image_buffer[x][y] = ColorAndSamples{ @floatFromInt(x), @floatFromInt(y), 0, 1 };
//         }
//     }

//     const data = try bufferToData(allocator, image_buffer);
//     defer allocator.free(data);
//     std.debug.print("{any}\n", .{image_buffer});
//     std.debug.print("{any}\n", .{data});
//     // for (data, 0..) |_, i| {
//     //     expectEqual(data[i], @as(u8, @intCast(i)));
//     // }
// }
