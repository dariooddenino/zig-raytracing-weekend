const std = @import("std");
const vec = @import("vec.zig");

const Position = vec.Position;
const Color = vec.Color;

pub const Light = union(enum) { point_light: PointLight };

pub const PointLight = struct {
    position: Position,
    radius: f32,
    color: Color,
    power: f32,
    reach: f32, // Only points within this distance of the light will be affected.

    pub fn init(position: Position, radius: f32, color: Color, power: f32) PointLight {
        return Light{ .point_light = PointLight{
            .position = position,
            .radius = radius,
            .color = color,
            .power = power,
            .reach = radius * 2.0,
        } };
    }
};
