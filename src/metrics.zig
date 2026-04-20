const std = @import("std");

pub const IntMetric = struct {
    name: []u8,
    value: i64,
};

pub const IntMetricsSnapshot = struct {
    entries: []IntMetric = &.{},

    pub fn count(self: *const IntMetricsSnapshot) usize {
        return self.entries.len;
    }

    pub fn get(self: *const IntMetricsSnapshot, name: []const u8) ?i64 {
        for (self.entries) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return entry.value;
            }
        }
        return null;
    }

    pub fn deinit(self: *IntMetricsSnapshot, allocator: std.mem.Allocator) void {
        for (self.entries) |entry| {
            allocator.free(entry.name);
        }
        if (self.entries.len > 0) {
            allocator.free(self.entries);
        }
        self.* = .{};
    }
};
