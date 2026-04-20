const std = @import("std");
const err = @import("error.zig");
const ffi = @import("ffi.zig");
const rust_call = @import("rust_call.zig");

pub const CloneFn = *const fn (?*anyopaque, *ffi.c.RustCallStatus) callconv(.c) ?*anyopaque;
pub const FreeFn = *const fn (?*anyopaque, *ffi.c.RustCallStatus) callconv(.c) void;

pub const ObjectHandle = struct {
    mutex: std.atomic.Mutex = .unlocked,
    raw: ?*anyopaque,
    clone_fn: CloneFn,
    free_fn: FreeFn,
    destroyed: bool = false,
    call_count: i64 = 0,

    pub fn init(raw: ?*anyopaque, clone_fn: CloneFn, free_fn: FreeFn) ObjectHandle {
        return .{
            .raw = raw,
            .clone_fn = clone_fn,
            .free_fn = free_fn,
        };
    }

    pub fn beginRustCall(self: *ObjectHandle) rust_call.CallError!?*anyopaque {
        self.lock();
        if (self.destroyed or self.raw == null) {
            self.unlock();
            err.rememberObjectDestroyed();
            return error.ObjectDestroyed;
        }
        if (self.call_count == std.math.maxInt(i64)) {
            self.unlock();
            err.rememberInternalMessage("too many in-flight SlateDB calls");
            return error.Internal;
        }

        const raw = self.raw;
        self.call_count += 1;
        self.unlock();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const cloned = self.clone_fn(raw, &status);
        rust_call.checkStatus(status) catch |call_err| {
            self.finishRustCall();
            return call_err;
        };

        if (cloned == null) {
            self.finishRustCall();
            err.rememberInternalMessage("clone returned a null SlateDB handle");
            return error.Internal;
        }

        return cloned.?;
    }

    pub fn finishRustCall(self: *ObjectHandle) void {
        const raw_to_free = self.updateCallCount(-1);
        if (raw_to_free) |raw| {
            freeRaw(self, raw, "failed to free SlateDB handle after in-flight call");
        }
    }

    pub fn deinit(self: *ObjectHandle) void {
        self.lock();
        if (self.destroyed or self.raw == null) {
            self.unlock();
            return;
        }

        self.destroyed = true;
        self.call_count -= 1;
        const raw_to_free = if (self.call_count == -1) blk: {
            const raw = self.raw;
            self.raw = null;
            break :blk raw;
        } else null;
        self.unlock();

        if (raw_to_free) |raw| {
            freeRaw(self, raw, "failed to free SlateDB handle");
        }
    }

    fn updateCallCount(self: *ObjectHandle, delta: i64) ?*anyopaque {
        self.lock();
        defer self.unlock();

        self.call_count += delta;
        if (self.call_count == -1) {
            const raw = self.raw;
            self.raw = null;
            return raw;
        }
        return null;
    }

    fn freeRaw(self: *ObjectHandle, raw: ?*anyopaque, context: []const u8) void {
        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        self.free_fn(raw, &status);
        rust_call.checkStatusSilent(status) catch |call_err| {
            std.log.err("{s}: {s}", .{ context, @errorName(call_err) });
        };
    }

    fn lock(self: *ObjectHandle) void {
        while (!self.mutex.tryLock()) {
            std.Thread.yield() catch {};
        }
    }

    fn unlock(self: *ObjectHandle) void {
        self.mutex.unlock();
    }
};
