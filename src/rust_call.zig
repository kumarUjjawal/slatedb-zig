const std = @import("std");
const codec = @import("codec.zig");
const err = @import("error.zig");
const ffi = @import("ffi.zig");
const rust_buffer = @import("rust_buffer.zig");

pub const CallError = err.CallError;

const StatusMode = enum {
    record,
    silent,
};

pub fn checkStatus(status: ffi.c.RustCallStatus) CallError!void {
    return checkStatusWithMode(status, .record);
}

pub fn checkStatusSilent(status: ffi.c.RustCallStatus) CallError!void {
    return checkStatusWithMode(status, .silent);
}

fn checkStatusWithMode(status: ffi.c.RustCallStatus, mode: StatusMode) CallError!void {
    return switch (status.code) {
        0 => if (mode == .record) err.clearLastCallErrorDetail(),
        1 => handleApiError(status.errorBuf, mode),
        2 => handleRustPanic(status.errorBuf, mode),
        else => {
            if (mode == .record) {
                err.rememberInternalMessageFmt(
                    "unexpected RustCallStatus code: {d}",
                    .{status.code},
                );
            }
            std.log.err("unexpected RustCallStatus code: {d}", .{status.code});
            return error.Internal;
        },
    };
}

fn handleApiError(raw: ffi.c.RustBuffer, mode: StatusMode) CallError {
    var error_buffer = rust_buffer.RustBuffer{ .raw = raw };
    defer error_buffer.deinit();

    var reader = codec.BufferReader.init(error_buffer.bytes());
    const payload = codec.decodeApiError(&reader) catch |decode_err| {
        if (mode == .record) {
            err.rememberInternalMessageFmt(
                "failed to decode SlateDB API error: {s}",
                .{@errorName(decode_err)},
            );
        }
        std.log.err("failed to decode SlateDB API error: {s}", .{@errorName(decode_err)});
        return error.Internal;
    };

    reader.finish() catch |decode_err| {
        if (mode == .record) {
            err.rememberInternalMessageFmt(
                "SlateDB API error buffer had trailing data: {s}",
                .{@errorName(decode_err)},
            );
        }
        std.log.err("SlateDB API error buffer had trailing data: {s}", .{@errorName(decode_err)});
        return error.Internal;
    };

    if (mode == .record) {
        err.rememberApiErrorPayload(payload);
    }
    return err.toCallError(payload);
}

fn handleRustPanic(raw: ffi.c.RustBuffer, mode: StatusMode) CallError {
    var panic_buffer = rust_buffer.RustBuffer{ .raw = raw };
    defer panic_buffer.deinit();

    if (panic_buffer.raw.len == 0) {
        if (mode == .record) {
            err.rememberRustPanicWhileHandlingPanic();
        }
        std.log.err("Rust panicked while handling a Rust panic", .{});
        return error.RustPanicWhileHandlingPanic;
    }

    const message = panic_buffer.bytes();
    if (mode == .record) {
        err.rememberRustPanic(message);
    }
    std.log.err("Rust panic: {s}", .{message});
    return error.RustPanic;
}
