const std = @import("std");
const codec = @import("codec.zig");
const config = @import("config.zig");
const db_snapshot = @import("db_snapshot.zig");
const db_transaction = @import("db_transaction.zig");
const ffi = @import("ffi.zig");
const iterator = @import("iterator.zig");
const metrics_api = @import("metrics.zig");
const object_handle = @import("object_handle.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");
const rust_future = @import("rust_future.zig");
const types = @import("types.zig");
const write_batch = @import("write_batch.zig");

pub const WriteHandle = codec.WriteHandle;

pub const Db = struct {
    handle: object_handle.ObjectHandle,

    pub fn fromRaw(raw: ?*anyopaque) Db {
        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_db,
                ffi.c.uniffi_slatedb_uniffi_fn_free_db,
            ),
        };
    }

    pub fn status(self: *Db) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        var status_info = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_db_status(db_handle, &status_info);
        try rust_call.checkStatus(status_info);
    }

    pub fn begin(
        self: *Db,
        io: std.Io,
        isolation_level: config.IsolationLevel,
    ) std.Io.Future(rust_call.CallError!db_transaction.DbTransaction) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                rust_call.CallError!db_transaction.DbTransaction,
                call_err,
            );
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                rust_call.CallError!db_transaction.DbTransaction,
                call_err,
            );
        };

        const isolation_level_buffer = rust_buffer.RustBuffer.fromI32(
            @intFromEnum(isolation_level),
        ) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                rust_call.CallError!db_transaction.DbTransaction,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_begin(
            db_handle,
            isolation_level_buffer.raw,
        );
        return io.async(waitBeginTask, .{ &self.handle, future });
    }

    pub fn beginBlocking(
        self: *Db,
        isolation_level: config.IsolationLevel,
    ) rust_call.CallError!db_transaction.DbTransaction {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const isolation_level_buffer = try rust_buffer.RustBuffer.fromI32(
            @intFromEnum(isolation_level),
        );
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_begin(
            db_handle,
            isolation_level_buffer.raw,
        );
        const raw_tx = try rust_future.waitPointer(future);
        return db_transaction.DbTransaction.fromRaw(raw_tx);
    }

    pub fn put(
        self: *Db,
        io: std.Io,
        key: []const u8,
        value: []const u8,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!WriteHandle) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };
        const value_buffer = rust_buffer.RustBuffer.fromSerializedBytes(value) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_put(
            db_handle,
            key_buffer.raw,
            value_buffer.raw,
        );

        return io.async(waitPutTask, .{ &self.handle, future });
    }

    pub fn putBlocking(
        self: *Db,
        key: []const u8,
        value: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const value_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(value);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_put(
            db_handle,
            key_buffer.raw,
            value_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const handle = try codec.decodeWriteHandle(&reader);
        try reader.finish();
        return handle;
    }

    pub fn putWithOptions(
        self: *Db,
        io: std.Io,
        key: []const u8,
        value: []const u8,
        put_options: config.PutOptions,
        write_options: config.WriteOptions,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!WriteHandle) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };
        const value_buffer = rust_buffer.RustBuffer.fromSerializedBytes(value) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };
        const put_options_buffer = config.encodePutOptions(put_options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };
        const write_options_buffer = config.encodeWriteOptions(write_options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_put_with_options(
            db_handle,
            key_buffer.raw,
            value_buffer.raw,
            put_options_buffer.raw,
            write_options_buffer.raw,
        );

        return io.async(waitPutTask, .{ &self.handle, future });
    }

    pub fn putWithOptionsBlocking(
        self: *Db,
        key: []const u8,
        value: []const u8,
        put_options: config.PutOptions,
        write_options: config.WriteOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const value_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(value);
        const put_options_buffer = try config.encodePutOptions(put_options);
        const write_options_buffer = try config.encodeWriteOptions(write_options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_put_with_options(
            db_handle,
            key_buffer.raw,
            value_buffer.raw,
            put_options_buffer.raw,
            write_options_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const handle = try codec.decodeWriteHandle(&reader);
        try reader.finish();
        return handle;
    }

    pub fn get(
        self: *Db,
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

        const db_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_get(
            db_handle,
            key_buffer.raw,
        );

        return io.async(waitGetTask, .{ &self.handle, allocator, future });
    }

    pub fn getBlocking(
        self: *Db,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?[]u8 {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_get(
            db_handle,
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
        self: *Db,
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

        const db_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_get_with_options(
            db_handle,
            key_buffer.raw,
            options_buffer.raw,
        );

        return io.async(waitGetTask, .{ &self.handle, allocator, future });
    }

    pub fn getWithOptionsBlocking(
        self: *Db,
        allocator: std.mem.Allocator,
        key: []const u8,
        options: config.ReadOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?[]u8 {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const options_buffer = try config.encodeReadOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_get_with_options(
            db_handle,
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
        self: *Db,
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

        const db_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_get_key_value(
            db_handle,
            key_buffer.raw,
        );

        return io.async(waitKeyValueTask, .{ &self.handle, allocator, future });
    }

    pub fn getKeyValueBlocking(
        self: *Db,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_get_key_value(
            db_handle,
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
        self: *Db,
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

        const db_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_get_key_value_with_options(
            db_handle,
            key_buffer.raw,
            options_buffer.raw,
        );

        return io.async(waitKeyValueTask, .{ &self.handle, allocator, future });
    }

    pub fn getKeyValueWithOptionsBlocking(
        self: *Db,
        allocator: std.mem.Allocator,
        key: []const u8,
        options: config.ReadOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?types.KeyValue {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const options_buffer = try config.encodeReadOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_get_key_value_with_options(
            db_handle,
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
        self: *Db,
        io: std.Io,
        range: types.KeyRange,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_scan(
            db_handle,
            range_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanBlocking(
        self: *Db,
        range: types.KeyRange,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const range_buffer = try codec.encodeKeyRange(range);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_scan(
            db_handle,
            range_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn scanPrefix(
        self: *Db,
        io: std.Io,
        prefix: []const u8,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator,
                call_err,
            );
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_scan_prefix(
            db_handle,
            prefix_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanPrefixBlocking(
        self: *Db,
        prefix: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const prefix_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(prefix);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_scan_prefix(
            db_handle,
            prefix_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn scanWithOptions(
        self: *Db,
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

        const db_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_scan_with_options(
            db_handle,
            range_buffer.raw,
            options_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanWithOptionsBlocking(
        self: *Db,
        range: types.KeyRange,
        options: config.ScanOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const range_buffer = try codec.encodeKeyRange(range);
        const options_buffer = try config.encodeScanOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_scan_with_options(
            db_handle,
            range_buffer.raw,
            options_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn scanPrefixWithOptions(
        self: *Db,
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

        const db_handle = self.handle.beginRustCall() catch |call_err| {
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

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_scan_prefix_with_options(
            db_handle,
            prefix_buffer.raw,
            options_buffer.raw,
        );
        return io.async(waitScanTask, .{ &self.handle, future });
    }

    pub fn scanPrefixWithOptionsBlocking(
        self: *Db,
        prefix: []const u8,
        options: config.ScanOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!iterator.DbIterator {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const prefix_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(prefix);
        const options_buffer = try config.encodeScanOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_scan_prefix_with_options(
            db_handle,
            prefix_buffer.raw,
            options_buffer.raw,
        );
        const raw_iterator = try rust_future.waitPointer(future);
        return iterator.DbIterator.fromRaw(raw_iterator);
    }

    pub fn metrics(
        self: *Db,
        allocator: std.mem.Allocator,
    ) (std.mem.Allocator.Error || rust_call.CallError)!metrics_api.IntMetricsSnapshot {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        var status_info = std.mem.zeroes(ffi.c.RustCallStatus);
        var result_buffer = rust_buffer.RustBuffer{
            .raw = ffi.c.uniffi_slatedb_uniffi_fn_method_db_metrics(
                db_handle,
                &status_info,
            ),
        };
        defer result_buffer.deinit();
        try rust_call.checkStatus(status_info);

        var reader = codec.BufferReader.init(result_buffer.bytes());
        var metrics_snapshot = try codec.decodeIntMetricsSnapshot(allocator, &reader);
        errdefer metrics_snapshot.deinit(allocator);
        try reader.finish();
        return metrics_snapshot;
    }

    pub fn delete(
        self: *Db,
        io: std.Io,
        key: []const u8,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!WriteHandle) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_delete(
            db_handle,
            key_buffer.raw,
        );

        return io.async(waitDeleteTask, .{ &self.handle, future });
    }

    pub fn deleteBlocking(
        self: *Db,
        key: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_delete(
            db_handle,
            key_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const handle = try codec.decodeWriteHandle(&reader);
        try reader.finish();
        return handle;
    }

    pub fn deleteWithOptions(
        self: *Db,
        io: std.Io,
        key: []const u8,
        options: config.WriteOptions,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!WriteHandle) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };
        const options_buffer = config.encodeWriteOptions(options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_delete_with_options(
            db_handle,
            key_buffer.raw,
            options_buffer.raw,
        );

        return io.async(waitDeleteTask, .{ &self.handle, future });
    }

    pub fn deleteWithOptionsBlocking(
        self: *Db,
        key: []const u8,
        options: config.WriteOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const options_buffer = try config.encodeWriteOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_delete_with_options(
            db_handle,
            key_buffer.raw,
            options_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const handle = try codec.decodeWriteHandle(&reader);
        try reader.finish();
        return handle;
    }

    pub fn merge(
        self: *Db,
        io: std.Io,
        key: []const u8,
        operand: []const u8,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!WriteHandle) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };
        const operand_buffer = rust_buffer.RustBuffer.fromSerializedBytes(operand) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_merge(
            db_handle,
            key_buffer.raw,
            operand_buffer.raw,
        );

        return io.async(waitPutTask, .{ &self.handle, future });
    }

    pub fn mergeBlocking(
        self: *Db,
        key: []const u8,
        operand: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const operand_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(operand);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_merge(
            db_handle,
            key_buffer.raw,
            operand_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const handle = try codec.decodeWriteHandle(&reader);
        try reader.finish();
        return handle;
    }

    pub fn mergeWithOptions(
        self: *Db,
        io: std.Io,
        key: []const u8,
        operand: []const u8,
        merge_options: config.MergeOptions,
        write_options: config.WriteOptions,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!WriteHandle) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const key_buffer = rust_buffer.RustBuffer.fromSerializedBytes(key) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };
        const operand_buffer = rust_buffer.RustBuffer.fromSerializedBytes(operand) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };
        const merge_options_buffer = config.encodeMergeOptions(merge_options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };
        const write_options_buffer = config.encodeWriteOptions(write_options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_merge_with_options(
            db_handle,
            key_buffer.raw,
            operand_buffer.raw,
            merge_options_buffer.raw,
            write_options_buffer.raw,
        );

        return io.async(waitPutTask, .{ &self.handle, future });
    }

    pub fn mergeWithOptionsBlocking(
        self: *Db,
        key: []const u8,
        operand: []const u8,
        merge_options: config.MergeOptions,
        write_options: config.WriteOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const operand_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(operand);
        const merge_options_buffer = try config.encodeMergeOptions(merge_options);
        const write_options_buffer = try config.encodeWriteOptions(write_options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_merge_with_options(
            db_handle,
            key_buffer.raw,
            operand_buffer.raw,
            merge_options_buffer.raw,
            write_options_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const handle = try codec.decodeWriteHandle(&reader);
        try reader.finish();
        return handle;
    }

    pub fn flush(self: *Db, io: std.Io) std.Io.Future(rust_call.CallError!void) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(rust_call.CallError!void, call_err);
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(rust_call.CallError!void, call_err);
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_flush(db_handle);
        return rust_future.asyncVoid(io, &self.handle, future);
    }

    pub fn flushWithOptions(
        self: *Db,
        io: std.Io,
        options: config.FlushOptions,
    ) std.Io.Future(rust_call.CallError!void) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(rust_call.CallError!void, call_err);
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(rust_call.CallError!void, call_err);
        };

        const options_buffer = config.encodeFlushOptions(options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(rust_call.CallError!void, call_err);
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_flush_with_options(
            db_handle,
            options_buffer.raw,
        );
        return rust_future.asyncVoid(io, &self.handle, future);
    }

    pub fn shutdown(self: *Db, io: std.Io) std.Io.Future(rust_call.CallError!void) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(rust_call.CallError!void, call_err);
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(rust_call.CallError!void, call_err);
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_shutdown(db_handle);
        return rust_future.asyncVoid(io, &self.handle, future);
    }

    pub fn snapshot(self: *Db, io: std.Io) std.Io.Future(rust_call.CallError!db_snapshot.DbSnapshot) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(rust_call.CallError!db_snapshot.DbSnapshot, call_err);
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(rust_call.CallError!db_snapshot.DbSnapshot, call_err);
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_snapshot(db_handle);
        return io.async(waitSnapshotTask, .{ &self.handle, future });
    }

    pub fn write(
        self: *Db,
        io: std.Io,
        batch: *write_batch.WriteBatch,
    ) std.Io.Future(rust_call.CallError!WriteHandle) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(rust_call.CallError!WriteHandle, call_err);
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(rust_call.CallError!WriteHandle, call_err);
        };

        const batch_handle = batch.handle.beginRustCall() catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(rust_call.CallError!WriteHandle, call_err);
        };
        defer batch.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_write(
            db_handle,
            batch_handle,
        );
        return io.async(waitWriteTask, .{ &self.handle, future });
    }

    pub fn writeWithOptions(
        self: *Db,
        io: std.Io,
        batch: *write_batch.WriteBatch,
        options: config.WriteOptions,
    ) std.Io.Future(rust_call.CallError!WriteHandle) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(rust_call.CallError!WriteHandle, call_err);
        };

        const db_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(rust_call.CallError!WriteHandle, call_err);
        };

        const batch_handle = batch.handle.beginRustCall() catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(rust_call.CallError!WriteHandle, call_err);
        };
        defer batch.handle.finishRustCall();

        const options_buffer = config.encodeWriteOptions(options) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(rust_call.CallError!WriteHandle, call_err);
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_write_with_options(
            db_handle,
            batch_handle,
            options_buffer.raw,
        );
        return io.async(waitWriteTask, .{ &self.handle, future });
    }

    pub fn flushBlocking(self: *Db) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_flush(db_handle);
        try rust_future.waitVoid(future);
    }

    pub fn flushWithOptionsBlocking(
        self: *Db,
        options: config.FlushOptions,
    ) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const options_buffer = try config.encodeFlushOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_flush_with_options(
            db_handle,
            options_buffer.raw,
        );
        try rust_future.waitVoid(future);
    }

    pub fn shutdownBlocking(self: *Db) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_shutdown(db_handle);
        try rust_future.waitVoid(future);
    }

    pub fn snapshotBlocking(self: *Db) rust_call.CallError!db_snapshot.DbSnapshot {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_snapshot(db_handle);
        const raw_snapshot = try rust_future.waitPointer(future);
        return db_snapshot.DbSnapshot.fromRaw(raw_snapshot);
    }

    pub fn writeBlocking(
        self: *Db,
        batch: *write_batch.WriteBatch,
    ) rust_call.CallError!WriteHandle {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const batch_handle = try batch.handle.beginRustCall();
        defer batch.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_write(
            db_handle,
            batch_handle,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const handle = try codec.decodeWriteHandle(&reader);
        try reader.finish();
        return handle;
    }

    pub fn writeWithOptionsBlocking(
        self: *Db,
        batch: *write_batch.WriteBatch,
        options: config.WriteOptions,
    ) rust_call.CallError!WriteHandle {
        try ffi.ensureCompatible();

        const db_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const batch_handle = try batch.handle.beginRustCall();
        defer batch.handle.finishRustCall();

        const options_buffer = try config.encodeWriteOptions(options);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_db_write_with_options(
            db_handle,
            batch_handle,
            options_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const handle = try codec.decodeWriteHandle(&reader);
        try reader.finish();
        return handle;
    }

    pub fn deinit(self: *Db) void {
        self.handle.deinit();
    }
};

fn waitPutTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle {
    defer owner.finishRustCall();

    var result_buffer = try rust_future.waitRustBuffer(handle);
    defer result_buffer.deinit();

    var reader = codec.BufferReader.init(result_buffer.bytes());
    const write_handle = try codec.decodeWriteHandle(&reader);
    try reader.finish();
    return write_handle;
}

fn waitBeginTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) rust_call.CallError!db_transaction.DbTransaction {
    defer owner.finishRustCall();

    const raw_tx = try rust_future.waitPointer(handle);
    return db_transaction.DbTransaction.fromRaw(raw_tx);
}

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

fn waitDeleteTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) (std.mem.Allocator.Error || rust_call.CallError)!WriteHandle {
    defer owner.finishRustCall();

    var result_buffer = try rust_future.waitRustBuffer(handle);
    defer result_buffer.deinit();

    var reader = codec.BufferReader.init(result_buffer.bytes());
    const write_handle = try codec.decodeWriteHandle(&reader);
    try reader.finish();
    return write_handle;
}

fn waitWriteTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) rust_call.CallError!WriteHandle {
    defer owner.finishRustCall();

    var result_buffer = try rust_future.waitRustBuffer(handle);
    defer result_buffer.deinit();

    var reader = codec.BufferReader.init(result_buffer.bytes());
    const write_handle = try codec.decodeWriteHandle(&reader);
    try reader.finish();
    return write_handle;
}

fn waitSnapshotTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) rust_call.CallError!db_snapshot.DbSnapshot {
    defer owner.finishRustCall();

    const raw_snapshot = try rust_future.waitPointer(handle);
    return db_snapshot.DbSnapshot.fromRaw(raw_snapshot);
}
