const std = @import("std");
const codec = @import("codec.zig");
const config = @import("config.zig");
const ffi = @import("ffi.zig");
const iterator = @import("iterator.zig");
const object_handle = @import("object_handle.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");
const rust_future = @import("rust_future.zig");
const types = @import("types.zig");

pub const DbReader = struct {
    handle: object_handle.ObjectHandle,

    pub fn fromRaw(raw: ?*anyopaque) DbReader {
        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_dbreader,
                ffi.c.uniffi_slatedb_uniffi_fn_free_dbreader,
            ),
        };
    }

    pub fn get(
        self: *DbReader,
        io: std.Io,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!?[]u8) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?[]u8,
                call_err,
            );
        };

        const reader_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?[]u8,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?[]u8,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_get(
            reader_handle,
            key_buffer.raw,
        );
        return io.async(waitGetTask, .{ &self.handle, allocator, future });
    }

    pub fn getBlocking(
        self: *DbReader,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?[]u8 {
        try ffi.ensureCompatible();

        const reader_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_get(
            reader_handle,
            key_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var buffer_reader = codec.BufferReader.init(result_buffer.bytes());
        const value = try codec.decodeOptionalBytes(allocator, &buffer_reader);
        try buffer_reader.finish();
        return value;
    }

    pub fn getWithOptions(
        self: *DbReader,
        io: std.Io,
        allocator: std.mem.Allocator,
        key: []const u8,
        options: config.ReadOptions,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!?[]u8) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?[]u8,
                call_err,
            );
        };

        const reader_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?[]u8,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?[]u8,
                call_err,
            );
        };
        const options_buffer = config.encodeReadOptions(options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?[]u8,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_get_with_options(
            reader_handle,
            key_buffer.raw,
            options_buffer.raw,
        );
        return io.async(waitGetTask, .{ &self.handle, allocator, future });
    }

    pub fn getWithOptionsBlocking(
        self: *DbReader,
        allocator: std.mem.Allocator,
        key: []const u8,
        options: config.ReadOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?[]u8 {
        try ffi.ensureCompatible();

        const reader_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const options_buffer = try config.encodeReadOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_get_with_options(
            reader_handle,
            key_buffer.raw,
            options_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var buffer_reader = codec.BufferReader.init(result_buffer.bytes());
        const value = try codec.decodeOptionalBytes(allocator, &buffer_reader);
        try buffer_reader.finish();
        return value;
    }

    pub fn scan(
        self: *DbReader,
        io: std.Io,
        range: types.KeyRange,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const reader_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const range_buffer = codec.encodeKeyRange(range) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_scan(
            reader_handle,
            range_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanBlocking(
        self: *DbReader,
        range: types.KeyRange,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const reader_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const range_buffer = try codec.encodeKeyRange(range);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_scan(
            reader_handle,
            range_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn scanPrefix(
        self: *DbReader,
        io: std.Io,
        prefix: []const u8,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const reader_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const prefix_buffer = rust_buffer.RustBuffer.fromSerializedBytes(prefix) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_scan_prefix(
            reader_handle,
            prefix_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanPrefixBlocking(
        self: *DbReader,
        prefix: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const reader_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const prefix_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(prefix);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_scan_prefix(
            reader_handle,
            prefix_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn scanWithOptions(
        self: *DbReader,
        io: std.Io,
        range: types.KeyRange,
        options: config.ScanOptions,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const reader_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const range_buffer = codec.encodeKeyRange(range) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };
        const options_buffer = config.encodeScanOptions(options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_scan_with_options(
            reader_handle,
            range_buffer.raw,
            options_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanWithOptionsBlocking(
        self: *DbReader,
        range: types.KeyRange,
        options: config.ScanOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const reader_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const range_buffer = try codec.encodeKeyRange(range);
        const options_buffer = try config.encodeScanOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_scan_with_options(
            reader_handle,
            range_buffer.raw,
            options_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn scanPrefixWithOptions(
        self: *DbReader,
        io: std.Io,
        prefix: []const u8,
        options: config.ScanOptions,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const reader_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const prefix_buffer = rust_buffer.RustBuffer.fromSerializedBytes(prefix) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };
        const options_buffer = config.encodeScanOptions(options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_scan_prefix_with_options(
            reader_handle,
            prefix_buffer.raw,
            options_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanPrefixWithOptionsBlocking(
        self: *DbReader,
        prefix: []const u8,
        options: config.ScanOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const reader_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const prefix_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(prefix);
        const options_buffer = try config.encodeScanOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_scan_prefix_with_options(
            reader_handle,
            prefix_buffer.raw,
            options_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn shutdown(self: *DbReader, io: std.Io) std.Io.Future(rust_call.CallError!void) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(rust_call.CallError!void, call_err);
        };

        const reader_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(rust_call.CallError!void, call_err);
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_shutdown(reader_handle);
        return rust_future.asyncVoid(io, &self.handle, future);
    }

    pub fn shutdownBlocking(self: *DbReader) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const reader_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreader_shutdown(reader_handle);
        try rust_future.waitVoid(future);
    }

    pub fn deinit(self: *DbReader) void {
        self.handle.deinit();
    }
};

fn waitGetTask(
    owner: *object_handle.ObjectHandle,
    allocator: std.mem.Allocator,
    handle: u64,
) (std.mem.Allocator.Error || rust_call.CallError)!?[]u8 {
    defer owner.finishRustCall();

    var result_buffer = try rust_future.waitRustBuffer(handle);
    defer result_buffer.deinit();

    var reader = codec.BufferReader.init(result_buffer.bytes());
    const value = try codec.decodeOptionalBytes(allocator, &reader);
    try reader.finish();
    return value;
}

fn waitScanTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
    defer owner.finishRustCall();

    const raw_iterator = try rust_future.waitPointer(handle);
    return iterator.DbIterator.fromRaw(raw_iterator);
}
