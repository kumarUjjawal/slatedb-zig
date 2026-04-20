const std = @import("std");
const codec = @import("codec.zig");
const ffi = @import("ffi.zig");
const object_handle = @import("object_handle.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");
const rust_future = @import("rust_future.zig");
const types = @import("types.zig");

pub const KeyValue = types.KeyValue;

pub const DbIterator = struct {
    handle: object_handle.ObjectHandle,

    pub fn fromRaw(raw: ?*anyopaque) DbIterator {
        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_dbiterator,
                ffi.c.uniffi_slatedb_uniffi_fn_free_dbiterator,
            ),
        };
    }

    pub fn next(
        self: *DbIterator,
        io: std.Io,
        allocator: std.mem.Allocator,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!?KeyValue) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?KeyValue,
                call_err,
            );
        };

        const iterator_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?KeyValue,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbiterator_next(iterator_handle);
        return io.async(waitNextTask, .{ &self.handle, allocator, future });
    }

    pub fn nextBlocking(
        self: *DbIterator,
        allocator: std.mem.Allocator,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?KeyValue {
        try ffi.ensureCompatible();

        const iterator_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbiterator_next(iterator_handle);

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const value = try codec.decodeOptionalKeyValue(allocator, &reader);
        try reader.finish();
        return value;
    }

    pub fn seek(
        self: *DbIterator,
        io: std.Io,
        key: []const u8,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!void) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!void,
                call_err,
            );
        };

        const iterator_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!void,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!void,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbiterator_seek(
            iterator_handle,
            key_buffer.raw,
        );
        return io.async(waitSeekTask, .{ &self.handle, future });
    }

    pub fn seekBlocking(
        self: *DbIterator,
        key: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!void {
        try ffi.ensureCompatible();

        const iterator_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbiterator_seek(
            iterator_handle,
            key_buffer.raw,
        );
        try rust_future.waitVoid(future);
    }

    pub fn deinit(self: *DbIterator) void {
        self.handle.deinit();
    }
};

fn waitNextTask(
    owner: *object_handle.ObjectHandle,
    allocator: std.mem.Allocator,
    handle: u64,
) (std.mem.Allocator.Error || rust_call.CallError)!?KeyValue {
    defer owner.finishRustCall();

    var result_buffer = try rust_future.waitRustBuffer(handle);
    defer result_buffer.deinit();

    var reader = codec.BufferReader.init(result_buffer.bytes());
    const value = try codec.decodeOptionalKeyValue(allocator, &reader);
    try reader.finish();
    return value;
}

fn waitSeekTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) (std.mem.Allocator.Error || rust_call.CallError)!void {
    defer owner.finishRustCall();
    try rust_future.waitVoid(handle);
}
