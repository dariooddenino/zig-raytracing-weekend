const std = @import("std");
const materials = @import("materials.zig");
const obs = @import("objects.zig");
const vec = @import("vec.zig");

const Color = vec.Color;
const Light = @import("lights.zig").Light;
const Material = materials.Material;
const Object = obs.Object;
const Position = vec.Position;
const Sphere = obs.Sphere;

pub fn createSimpleScene(objects: *std.ArrayList(Object), lights: *std.ArrayList(Light), plane_material: *Material) !void {
    const material = Material.initAlbedo(Color{ 0.8, 0.2, 0.4 });
    const f_material = Material.initAlbedo(Color{ 0.2, 0.2, 0.2 });
    const shape = Sphere.init(2.0);
    const object = Object.init(Position{ 0, 2, 0 }, 1.0, material, shape);
    const light = Light.init(Position{ 0, 10, 0 }, 1.0, Color{ 1.0, 1.0, 1.0 }, 1.0, 10.0);

    try objects.append(object);
    try lights.append(light);
    try plane_material.append(f_material);
}
