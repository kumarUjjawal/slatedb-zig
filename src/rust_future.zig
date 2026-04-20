const std = @import("std");
const err = @import("error.zig");
const ffi = @import("ffi.zig");
const object_handle = @import("object_handle.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");

const rust_future_poll_ready: i8 = 0;
const pending_poll_result: i8 = -1;

const Waiter = struct {
    poll_result: std.atomic.Value(i8) = .init(pending_poll_result),
};

pub fn ready(comptime Result: type, result: Result) std.Io.Future(Result) {
    return .{
        .any_future = null,
        .result = result,
    };
}

pub fn asyncRustBuffer(
    io: std.Io,
    owner: *object_handle.ObjectHandle,
    handle: u64,
) std.Io.Future(rust_call.CallError!rust_buffer.RustBuffer) {
    return io.async(waitRustBufferTask, .{ owner, handle });
}

pub fn asyncPointer(
    io: std.Io,
    owner: *object_handle.ObjectHandle,
    handle: u64,
) std.Io.Future(rust_call.CallError!?*anyopaque) {
    return io.async(waitPointerTask, .{ owner, handle });
}

pub fn asyncVoid(
    io: std.Io,
    owner: *object_handle.ObjectHandle,
    handle: u64,
) std.Io.Future(rust_call.CallError!void) {
    return io.async(waitVoidTask, .{ owner, handle });
}

pub fn waitRustBuffer(handle: u64) rust_call.CallError!rust_buffer.RustBuffer {
    defer ffi.c.ffi_slatedb_uniffi_rust_future_free_rust_buffer(@intCast(handle));

    waitUntilReady(handle, ffi.c.ffi_slatedb_uniffi_rust_future_poll_rust_buffer);

    var status = std.mem.zeroes(ffi.c.RustCallStatus);
    const raw = ffi.c.ffi_slatedb_uniffi_rust_future_complete_rust_buffer(@intCast(handle), &status);
    try rust_call.checkStatus(status);
    return .{ .raw = raw };
}

pub fn waitU64(handle: u64) rust_call.CallError!u64 {
    defer ffi.c.ffi_slatedb_uniffi_rust_future_free_u64(@intCast(handle));

    waitUntilReady(handle, ffi.c.ffi_slatedb_uniffi_rust_future_poll_u64);

    var status = std.mem.zeroes(ffi.c.RustCallStatus);
    const value = ffi.c.ffi_slatedb_uniffi_rust_future_complete_u64(@intCast(handle), &status);
    try rust_call.checkStatus(status);
    return value;
}

pub fn waitPointer(handle: u64) rust_call.CallError!?*anyopaque {
    defer ffi.c.ffi_slatedb_uniffi_rust_future_free_pointer(handle);

    waitUntilReady(handle, ffi.c.ffi_slatedb_uniffi_rust_future_poll_pointer);

    var status = std.mem.zeroes(ffi.c.RustCallStatus);
    const value = ffi.c.ffi_slatedb_uniffi_rust_future_complete_pointer(handle, &status);
    try rust_call.checkStatus(status);
    if (value == null) {
        err.rememberInternalMessage("Rust future returned a null pointer");
        return error.Internal;
    }
    return value;
}

pub fn waitVoid(handle: u64) rust_call.CallError!void {
    defer ffi.c.ffi_slatedb_uniffi_rust_future_free_void(@intCast(handle));

    waitUntilReady(handle, ffi.c.ffi_slatedb_uniffi_rust_future_poll_void);

    var status = std.mem.zeroes(ffi.c.RustCallStatus);
    ffi.c.ffi_slatedb_uniffi_rust_future_complete_void(@intCast(handle), &status);
    try rust_call.checkStatus(status);
}

fn waitRustBufferTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) rust_call.CallError!rust_buffer.RustBuffer {
    defer owner.finishRustCall();
    return waitRustBuffer(handle);
}

fn waitPointerTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) rust_call.CallError!?*anyopaque {
    defer owner.finishRustCall();
    return waitPointer(handle);
}

fn waitVoidTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) rust_call.CallError!void {
    defer owner.finishRustCall();
    return waitVoid(handle);
}

fn waitUntilReady(
    handle: u64,
    poll_fn: *const fn (u64, ffi.c.UniffiRustFutureContinuationCallback, u64) callconv(.c) void,
) void {
    var waiter = Waiter{};
    var poll_result: i8 = pending_poll_result;

    while (poll_result != rust_future_poll_ready) {
        waiter.poll_result.store(pending_poll_result, .release);
        poll_fn(@intCast(handle), continuationCallback, @intFromPtr(&waiter));

        while (true) {
            poll_result = waiter.poll_result.load(.acquire);
            if (poll_result != pending_poll_result) {
                break;
            }
            std.Thread.yield() catch {};
        }
    }
}

fn continuationCallback(data: u64, poll_result: i8) callconv(.c) void {
    const waiter: *Waiter = @ptrFromInt(@as(usize, @intCast(data)));
    waiter.poll_result.store(poll_result, .release);
}
