const std = @import("std");
const err = @import("error.zig");
const ffi = @import("ffi.zig");
const rust_call = @import("rust_call.zig");

pub const CloneFn = *const fn (u64, *ffi.c.RustCallStatus) callconv(.c) u64;
pub const FreeFn = *const fn (u64, *ffi.c.RustCallStatus) callconv(.c) void;

pub const U64Handle = struct {
    mutex: std.atomic.Mutex = .unlocked,
    raw: u64,
    clone_fn: CloneFn,
    free_fn: FreeFn,
    destroyed: bool = false,
    call_count: i64 = 0,

    pub fn init(raw: u64, clone_fn: CloneFn, free_fn: FreeFn) U64Handle {
        return .{
            .raw = raw,
            .clone_fn = clone_fn,
            .free_fn = free_fn,
        };
    }

    pub fn beginRustCall(self: *U64Handle) rust_call.CallError!u64 {
        self.lock();
        if (self.destroyed or self.raw == 0) {
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

        if (cloned == 0) {
            self.finishRustCall();
            err.rememberInternalMessage("clone returned a null SlateDB handle");
            return error.Internal;
        }

        return cloned;
    }

    pub fn cloneForTransfer(self: *U64Handle) rust_call.CallError!u64 {
        self.lock();
        if (self.destroyed or self.raw == 0) {
            self.unlock();
            err.rememberObjectDestroyed();
            return error.ObjectDestroyed;
        }
        const raw = self.raw;
        self.unlock();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const cloned = self.clone_fn(raw, &status);
        try rust_call.checkStatus(status);

        if (cloned == 0) {
            err.rememberInternalMessage("clone returned a null SlateDB handle");
            return error.Internal;
        }

        return cloned;
    }

    pub fn finishRustCall(self: *U64Handle) void {
        const raw_to_free = self.updateCallCount(-1);
        if (raw_to_free) |raw| {
            freeRaw(self, raw, "failed to free SlateDB handle after in-flight call");
        }
    }

    pub fn deinit(self: *U64Handle) void {
        self.lock();
        if (self.destroyed or self.raw == 0) {
            self.unlock();
            return;
        }

        self.destroyed = true;
        self.call_count -= 1;
        const raw_to_free = if (self.call_count == -1) blk: {
            const raw = self.raw;
            self.raw = 0;
            break :blk raw;
        } else null;
        self.unlock();

        if (raw_to_free) |raw| {
            freeRaw(self, raw, "failed to free SlateDB handle");
        }
    }

    pub fn freeTransferredClone(self: *const U64Handle, raw: u64, context: []const u8) void {
        freeRaw(self, raw, context);
    }

    fn updateCallCount(self: *U64Handle, delta: i64) ?u64 {
        self.lock();
        defer self.unlock();

        self.call_count += delta;
        if (self.call_count == -1) {
            const raw = self.raw;
            self.raw = 0;
            return raw;
        }
        return null;
    }

    fn freeRaw(self: *const U64Handle, raw: u64, context: []const u8) void {
        if (raw == 0) {
            return;
        }

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        self.free_fn(raw, &status);
        rust_call.checkStatusSilent(status) catch |call_err| {
            std.log.err("{s}: {s}", .{ context, @errorName(call_err) });
        };
    }

    fn lock(self: *U64Handle) void {
        while (!self.mutex.tryLock()) {
            std.Thread.yield() catch {};
        }
    }

    fn unlock(self: *U64Handle) void {
        self.mutex.unlock();
    }
};
