const std = @import("std");

const positions = @import("positions.zig");
const vec = @import("vec.zig");

const Position = positions.Position;
const Vec2 = vec.Vec2;

pub const Animation = struct {
    currently_rendering_animation: bool = false,
    current_frame: u32 = 0,
    current_pass: u32 = 0,
    total_frame_count: u32 = 0,
    position_a: Position = vec.zero(),
    position_b: Position = vec.zero(),
    orientation_a: Vec2 = Vec2{ 0, 0 },
    orientation_b: Vec2 = Vec2{ 0, 0 },
    camera_speed: f32 = 1.0,
    frame_passes: u32 = 16,
    frame_rate: u32 = 24,

    pub fn setStartPosition(self: *Animation, camera_pos: Position, camera_yaw: f32, camera_pitch: f32) void {
        self.position_a = camera_pos;
        self.orientation_a = Vec2{ camera_yaw, camera_pitch };
    }

    pub fn setEndPosition(self: *Animation, camera_pos: Position, camera_yaw: f32, camera_pitch: f32) void {
        self.position_b = camera_pos;
        self.orientation_b = Vec2{ camera_yaw, camera_pitch };
    }

    pub fn recalculateTotalFrameCount(self: *Animation) void {
        self.totalFrameCount = vec.length2(self.position_a - self.position_b) / self.camera_speed * self.frame_rate;
    }

    pub fn calculateCurrentCameraPosition(self: Animation) Position {
        return vec.mixFloat(self.position_a, self.position_b, self.current_frame / self.total_frame_count);
    }

    pub fn calculateCurrentCameraOrientation(self: Animation) Vec2 {
        return vec.mixFloat(self.orientation_a, self.orientation_b, self.current_frame / self.total_frame_count);
    }
};
