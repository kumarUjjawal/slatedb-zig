const std = @import("std");
const err = @import("error.zig");
const ffi = @import("ffi.zig");
const rust_call = @import("rust_call.zig");

pub const RustBuffer = struct {
    raw: ffi.c.RustBuffer,

    pub fn fromBytes(input: []const u8) rust_call.CallError!RustBuffer {
        if (input.len == 0) {
            return .{ .raw = std.mem.zeroes(ffi.c.RustBuffer) };
        }
        if (input.len > std.math.maxInt(i32)) {
            err.rememberBufferTooLarge(input.len, std.math.maxInt(i32));
            return error.BufferTooLarge;
        }

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const foreign = ffi.c.ForeignBytes{
            .len = @intCast(input.len),
            .data = @ptrCast(input.ptr),
        };
        const raw = ffi.c.ffi_slatedb_uniffi_rustbuffer_from_bytes(foreign, &status);
        try rust_call.checkStatus(status);
        return .{ .raw = raw };
    }

    pub fn fromSerializedBytes(
        value: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!RustBuffer {
        if (value.len > std.math.maxInt(i32)) {
            err.rememberBufferTooLarge(value.len, std.math.maxInt(i32));
            return error.BufferTooLarge;
        }

        const total_len = 4 + value.len;
        const encoded = try std.heap.page_allocator.alloc(u8, total_len);
        defer std.heap.page_allocator.free(encoded);

        std.mem.writeInt(i32, encoded[0..4], @intCast(value.len), .big);
        @memcpy(encoded[4 .. 4 + value.len], value);

        return try fromBytes(encoded);
    }

    pub fn fromI32(value: i32) rust_call.CallError!RustBuffer {
        var encoded: [4]u8 = undefined;
        std.mem.writeInt(i32, &encoded, value, .big);
        return fromBytes(&encoded);
    }

    pub fn bytes(self: RustBuffer) []const u8 {
        if (self.raw.len == 0 or self.raw.data == null) {
            return &.{};
        }

        const ptr: [*]const u8 = @ptrCast(self.raw.data);
        return ptr[0..@intCast(self.raw.len)];
    }

    pub fn deinit(self: *RustBuffer) void {
        if (self.raw.len == 0 and self.raw.capacity == 0 and self.raw.data == null) {
            return;
        }

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.ffi_slatedb_uniffi_rustbuffer_free(self.raw, &status);
        rust_call.checkStatusSilent(status) catch |call_err| {
            std.log.err("failed to free RustBuffer: {s}", .{@errorName(call_err)});
        };
        self.raw = std.mem.zeroes(ffi.c.RustBuffer);
    }
};
