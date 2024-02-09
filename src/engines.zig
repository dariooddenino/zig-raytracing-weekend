const std = @import("std");

pub const Engine = union(enum) {
    weekend: Weekend,
};

// Non real time old engine from "ray tracing in a weekend".
pub const Weekend = struct {};
