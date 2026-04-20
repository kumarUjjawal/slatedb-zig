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

pub const DbSnapshot = struct {
    handle: object_handle.ObjectHandle,

    pub fn fromRaw(raw: ?*anyopaque) DbSnapshot {
        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_dbsnapshot,
                ffi.c.uniffi_slatedb_uniffi_fn_free_dbsnapshot,
            ),
        };
    }

    pub fn get(
        self: *DbSnapshot,
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

        const snapshot_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_get(
            snapshot_handle,
            key_buffer.raw,
        );

        return io.async(waitGetTask, .{ &self.handle, allocator, future });
    }

    pub fn getBlocking(
        self: *DbSnapshot,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?[]u8 {
        try ffi.ensureCompatible();

        const snapshot_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_get(
            snapshot_handle,
            key_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const value = try codec.decodeOptionalBytes(allocator, &reader);
        try reader.finish();
        return value;
    }

    pub fn getWithOptions(
        self: *DbSnapshot,
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

        const snapshot_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_get_with_options(
            snapshot_handle,
            key_buffer.raw,
            options_buffer.raw,
        );

        return io.async(waitGetTask, .{ &self.handle, allocator, future });
    }

    pub fn getWithOptionsBlocking(
        self: *DbSnapshot,
        allocator: std.mem.Allocator,
        key: []const u8,
        options: config.ReadOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?[]u8 {
        try ffi.ensureCompatible();

        const snapshot_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const options_buffer = try config.encodeReadOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_get_with_options(
            snapshot_handle,
            key_buffer.raw,
            options_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const value = try codec.decodeOptionalBytes(allocator, &reader);
        try reader.finish();
        return value;
    }

    pub fn getKeyValue(
        self: *DbSnapshot,
        io: std.Io,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue,
                call_err,
            );
        };

        const snapshot_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_get_key_value(
            snapshot_handle,
            key_buffer.raw,
        );

        return io.async(waitKeyValueTask, .{ &self.handle, allocator, future });
    }

    pub fn getKeyValueBlocking(
        self: *DbSnapshot,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue {
        try ffi.ensureCompatible();

        const snapshot_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_get_key_value(
            snapshot_handle,
            key_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const value = try codec.decodeOptionalKeyValue(allocator, &reader);
        try reader.finish();
        return value;
    }

    pub fn getKeyValueWithOptions(
        self: *DbSnapshot,
        io: std.Io,
        allocator: std.mem.Allocator,
        key: []const u8,
        options: config.ReadOptions,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue,
                call_err,
            );
        };

        const snapshot_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue,
                call_err,
            );
        };
        const options_buffer = config.encodeReadOptions(options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_get_key_value_with_options(
            snapshot_handle,
            key_buffer.raw,
            options_buffer.raw,
        );

        return io.async(waitKeyValueTask, .{ &self.handle, allocator, future });
    }

    pub fn getKeyValueWithOptionsBlocking(
        self: *DbSnapshot,
        allocator: std.mem.Allocator,
        key: []const u8,
        options: config.ReadOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue {
        try ffi.ensureCompatible();

        const snapshot_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const options_buffer = try config.encodeReadOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_get_key_value_with_options(
            snapshot_handle,
            key_buffer.raw,
            options_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const value = try codec.decodeOptionalKeyValue(allocator, &reader);
        try reader.finish();
        return value;
    }

    pub fn scan(
        self: *DbSnapshot,
        io: std.Io,
        range: types.KeyRange,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const snapshot_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_scan(
            snapshot_handle,
            range_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanBlocking(
        self: *DbSnapshot,
        range: types.KeyRange,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const snapshot_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const range_buffer = try codec.encodeKeyRange(range);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_scan(
            snapshot_handle,
            range_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn scanPrefix(
        self: *DbSnapshot,
        io: std.Io,
        prefix: []const u8,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const snapshot_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_scan_prefix(
            snapshot_handle,
            prefix_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanPrefixBlocking(
        self: *DbSnapshot,
        prefix: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const snapshot_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const prefix_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(prefix);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_scan_prefix(
            snapshot_handle,
            prefix_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn scanWithOptions(
        self: *DbSnapshot,
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

        const snapshot_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_scan_with_options(
            snapshot_handle,
            range_buffer.raw,
            options_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanWithOptionsBlocking(
        self: *DbSnapshot,
        range: types.KeyRange,
        options: config.ScanOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const snapshot_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const range_buffer = try codec.encodeKeyRange(range);
        const options_buffer = try config.encodeScanOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_scan_with_options(
            snapshot_handle,
            range_buffer.raw,
            options_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn scanPrefixWithOptions(
        self: *DbSnapshot,
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

        const snapshot_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_scan_prefix_with_options(
            snapshot_handle,
            prefix_buffer.raw,
            options_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanPrefixWithOptionsBlocking(
        self: *DbSnapshot,
        prefix: []const u8,
        options: config.ScanOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const snapshot_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const prefix_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(prefix);
        const options_buffer = try config.encodeScanOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbsnapshot_scan_prefix_with_options(
            snapshot_handle,
            prefix_buffer.raw,
            options_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn deinit(self: *DbSnapshot) void {
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

fn waitKeyValueTask(
    owner: *object_handle.ObjectHandle,
    allocator: std.mem.Allocator,
    handle: u64,
) (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue {
    defer owner.finishRustCall();

    var result_buffer = try rust_future.waitRustBuffer(handle);
    defer result_buffer.deinit();

    var reader = codec.BufferReader.init(result_buffer.bytes());
    const value = try codec.decodeOptionalKeyValue(allocator, &reader);
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
