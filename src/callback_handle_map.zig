const std = @import("std");
const spin_lock = @import("spin_lock.zig");

pub fn HandleMap(comptime T: type) type {
    return struct {
        mutex: spin_lock.SpinLock = .{},
        next_handle: u64 = 1,
        handles: std.AutoHashMapUnmanaged(u64, T) = .empty,

        const Self = @This();

        pub fn insert(self: *Self, allocator: std.mem.Allocator, value: T) std.mem.Allocator.Error!u64 {
            self.mutex.lock();
            defer self.mutex.unlock();

            const handle = self.next_handle;
            // UniFFI uses odd handles for foreign callbacks so they do not
            // overlap with Rust-backed object handles.
            self.next_handle += 2;
            try self.handles.put(allocator, handle, value);
            return handle;
        }

        pub fn get(self: *Self, handle: u64) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.handles.get(handle);
        }

        pub fn remove(self: *Self, handle: u64) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            _ = self.handles.remove(handle);
        }
    };
}

test "callback handles stay odd" {
    var handle_map: HandleMap(u8) = .{};
    defer handle_map.handles.deinit(std.testing.allocator);

    const first = try handle_map.insert(std.testing.allocator, 1);
    defer handle_map.remove(first);

    const second = try handle_map.insert(std.testing.allocator, 2);
    defer handle_map.remove(second);

    try std.testing.expectEqual(@as(u64, 1), first);
    try std.testing.expectEqual(@as(u64, 3), second);
}
