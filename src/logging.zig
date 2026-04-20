const std = @import("std");
const callback_handle_map = @import("callback_handle_map.zig");
const codec = @import("codec.zig");
const ffi = @import("ffi.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");
const spin_lock = @import("spin_lock.zig");

pub const LogLevel = enum(i32) {
    off = 1,
    @"error" = 2,
    warn = 3,
    info = 4,
    debug = 5,
    trace = 6,
};

pub const LogRecord = struct {
    level: LogLevel,
    target: []u8,
    message: []u8,
    module_path: ?[]u8,
    file: ?[]u8,
    line: ?u32,

    pub fn deinit(self: *LogRecord, allocator: std.mem.Allocator) void {
        allocator.free(self.target);
        allocator.free(self.message);
        if (self.module_path) |module_path| {
            allocator.free(module_path);
        }
        if (self.file) |file| {
            allocator.free(file);
        }
        self.* = undefined;
    }
};

pub const LogCallback = struct {
    // `context` must stay valid for as long as Rust may emit log callbacks.
    // Since logging is process-global, treat this as a process-lifetime callback.
    context: *anyopaque,
    log_fn: *const fn (context: *anyopaque, record: *const LogRecord) void,

    pub fn log(self: *const LogCallback, record: *const LogRecord) void {
        self.log_fn(self.context, record);
    }
};

const LoweredOptionalLogCallback = struct {
    buffer: rust_buffer.RustBuffer,
    handle: ?u64 = null,
};

var log_callback_handles: callback_handle_map.HandleMap(LogCallback) = .{};
var log_callback_vtable_registered = false;
var log_callback_vtable_mutex: spin_lock.SpinLock = .{};

var log_callback_vtable = ffi.c.UniffiVTableCallbackInterfaceLogCallback{
    .log = @ptrCast(&slatedb_uniffi_cgo_dispatchCallbackInterfaceLogCallbackMethod0),
    .uniffiFree = @ptrCast(&slatedb_uniffi_cgo_dispatchCallbackInterfaceLogCallbackFree),
};

pub fn initLogging(
    level: LogLevel,
    callback: ?*const LogCallback,
) (std.mem.Allocator.Error || rust_call.CallError)!void {
    try ffi.ensureCompatible();

    const level_buffer = try rust_buffer.RustBuffer.fromI32(@intFromEnum(level));
    const lowered_callback = try lowerOptionalLogCallback(callback);
    errdefer if (lowered_callback.handle) |handle| log_callback_handles.remove(handle);

    var status = std.mem.zeroes(ffi.c.RustCallStatus);
    ffi.c.uniffi_slatedb_uniffi_fn_func_init_logging(
        level_buffer.raw,
        lowered_callback.buffer.raw,
        &status,
    );
    try rust_call.checkStatus(status);
}

fn ensureLogCallbackVTableRegistered() void {
    if (log_callback_vtable_registered) {
        return;
    }

    log_callback_vtable_mutex.lock();
    defer log_callback_vtable_mutex.unlock();

    if (log_callback_vtable_registered) {
        return;
    }

    ffi.c.uniffi_slatedb_uniffi_fn_init_callback_vtable_logcallback(&log_callback_vtable);
    log_callback_vtable_registered = true;
}

fn lowerOptionalLogCallback(
    callback: ?*const LogCallback,
) (std.mem.Allocator.Error || rust_call.CallError)!LoweredOptionalLogCallback {
    if (callback == null) {
        const encoded = [_]u8{0};
        return .{ .buffer = try rust_buffer.RustBuffer.fromBytes(&encoded) };
    }

    ensureLogCallbackVTableRegistered();

    const handle = try log_callback_handles.insert(std.heap.smp_allocator, callback.?.*);
    errdefer log_callback_handles.remove(handle);

    var encoded: [9]u8 = undefined;
    encoded[0] = 1;
    std.mem.writeInt(u64, encoded[1..9], handle, .big);

    return .{
        .buffer = try rust_buffer.RustBuffer.fromBytes(encoded[0..]),
        .handle = handle,
    };
}

fn decodeLogRecord(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)!LogRecord {
    const level = try decodeLogLevel(reader);

    const target = try codec.decodeOwnedString(allocator, reader);
    errdefer allocator.free(target);

    const message = try codec.decodeOwnedString(allocator, reader);
    errdefer allocator.free(message);

    const module_path = try decodeOptionalOwnedString(allocator, reader);
    errdefer if (module_path) |value| allocator.free(value);

    const file = try decodeOptionalOwnedString(allocator, reader);
    errdefer if (file) |value| allocator.free(value);

    return .{
        .level = level,
        .target = target,
        .message = message,
        .module_path = module_path,
        .file = file,
        .line = try decodeOptionalU32(reader),
    };
}

fn decodeLogLevel(reader: *codec.BufferReader) rust_call.CallError!LogLevel {
    return switch (try reader.readI32()) {
        1 => .off,
        2 => .@"error",
        3 => .warn,
        4 => .info,
        5 => .debug,
        6 => .trace,
        else => error.UnexpectedEnumTag,
    };
}

fn decodeOptionalOwnedString(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)!?[]u8 {
    return switch (try reader.readInt8()) {
        0 => null,
        1 => @as(?[]u8, try codec.decodeOwnedString(allocator, reader)),
        else => error.UnexpectedEnumTag,
    };
}

fn decodeOptionalU32(reader: *codec.BufferReader) rust_call.CallError!?u32 {
    return switch (try reader.readInt8()) {
        0 => null,
        1 => try reader.readU32(),
        else => error.UnexpectedEnumTag,
    };
}

pub export fn slatedb_uniffi_cgo_dispatchCallbackInterfaceLogCallbackMethod0(
    uniffi_handle: u64,
    record: ffi.c.RustBuffer,
    uniffi_out_return: ?*anyopaque,
    call_status: *ffi.c.RustCallStatus,
) callconv(.c) void {
    _ = uniffi_out_return;
    call_status.* = std.mem.zeroes(ffi.c.RustCallStatus);

    const callback = log_callback_handles.get(uniffi_handle) orelse {
        std.log.err("missing SlateDB log callback handle {d}", .{uniffi_handle});
        return;
    };

    var record_buffer = rust_buffer.RustBuffer{ .raw = record };
    defer record_buffer.deinit();

    var reader = codec.BufferReader.init(record_buffer.bytes());
    var decoded_record = decodeLogRecord(std.heap.smp_allocator, &reader) catch |decode_err| {
        std.log.err("failed to decode SlateDB log record: {s}", .{@errorName(decode_err)});
        return;
    };
    defer decoded_record.deinit(std.heap.smp_allocator);

    reader.finish() catch |decode_err| {
        std.log.err("SlateDB log record had trailing data: {s}", .{@errorName(decode_err)});
        return;
    };

    callback.log(&decoded_record);
}

pub export fn slatedb_uniffi_cgo_dispatchCallbackInterfaceLogCallbackFree(
    handle: u64,
) callconv(.c) void {
    log_callback_handles.remove(handle);
}
