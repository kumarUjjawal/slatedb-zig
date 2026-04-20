const std = @import("std");
const config = @import("config.zig");
const db = @import("db.zig");
const db_reader = @import("db_reader.zig");
const ffi = @import("ffi.zig");
const merge_operator = @import("merge_operator.zig");
const object_handle = @import("object_handle.zig");
const object_store = @import("object_store.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");
const rust_future = @import("rust_future.zig");

pub const DbBuilder = struct {
    handle: object_handle.ObjectHandle,

    pub fn init(path: []const u8, store: *const object_store.ObjectStore) rust_call.CallError!DbBuilder {
        try ffi.ensureCompatible();

        const path_buffer = try rust_buffer.RustBuffer.fromBytes(path);
        const store_handle = try @constCast(&store.handle).beginRustCall();
        defer @constCast(&store.handle).finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const raw = ffi.c.uniffi_slatedb_uniffi_fn_constructor_dbbuilder_new(
            path_buffer.raw,
            store_handle,
            &status,
        );
        try rust_call.checkStatus(status);

        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_dbbuilder,
                ffi.c.uniffi_slatedb_uniffi_fn_free_dbbuilder,
            ),
        };
    }

    pub fn build(self: *DbBuilder, io: std.Io) std.Io.Future(rust_call.CallError!db.Db) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(rust_call.CallError!db.Db, call_err);
        };

        const builder_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(rust_call.CallError!db.Db, call_err);
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbbuilder_build(builder_handle);
        return io.async(waitBuildTask, .{ &self.handle, future });
    }

    pub fn buildBlocking(self: *DbBuilder) rust_call.CallError!db.Db {
        try ffi.ensureCompatible();

        const builder_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbbuilder_build(builder_handle);
        const raw_db = try rust_future.waitPointer(future);
        return db.Db.fromRaw(raw_db);
    }

    pub fn withWalObjectStore(
        self: *DbBuilder,
        store: *const object_store.ObjectStore,
    ) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const builder_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const store_handle = try @constCast(&store.handle).beginRustCall();
        defer @constCast(&store.handle).finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_dbbuilder_with_wal_object_store(
            builder_handle,
            store_handle,
            &status,
        );
        try rust_call.checkStatus(status);
    }

    pub fn withMergeOperator(
        self: *DbBuilder,
        operator: *const merge_operator.MergeOperator,
    ) (std.mem.Allocator.Error || rust_call.CallError)!void {
        try ffi.ensureCompatible();

        const builder_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const merge_operator_handle = try merge_operator.lowerMergeOperator(operator);
        errdefer merge_operator.discardLoweredMergeOperator(merge_operator_handle);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_dbbuilder_with_merge_operator(
            builder_handle,
            merge_operator_handle,
            &status,
        );
        try rust_call.checkStatus(status);
    }

    pub fn deinit(self: *DbBuilder) void {
        self.handle.deinit();
    }
};

fn waitBuildTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) rust_call.CallError!db.Db {
    defer owner.finishRustCall();
    const raw_db = try rust_future.waitPointer(handle);
    return db.Db.fromRaw(raw_db);
}

pub const DbReaderBuilder = struct {
    handle: object_handle.ObjectHandle,

    pub fn init(path: []const u8, store: *const object_store.ObjectStore) rust_call.CallError!DbReaderBuilder {
        try ffi.ensureCompatible();

        const path_buffer = try rust_buffer.RustBuffer.fromBytes(path);
        const store_handle = try @constCast(&store.handle).beginRustCall();
        defer @constCast(&store.handle).finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const raw = ffi.c.uniffi_slatedb_uniffi_fn_constructor_dbreaderbuilder_new(
            path_buffer.raw,
            store_handle,
            &status,
        );
        try rust_call.checkStatus(status);

        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_dbreaderbuilder,
                ffi.c.uniffi_slatedb_uniffi_fn_free_dbreaderbuilder,
            ),
        };
    }

    pub fn withOptions(self: *DbReaderBuilder, options: config.ReaderOptions) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const builder_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const options_buffer = try config.encodeReaderOptions(options);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_dbreaderbuilder_with_options(
            builder_handle,
            options_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);
    }

    pub fn build(self: *DbReaderBuilder, io: std.Io) std.Io.Future(rust_call.CallError!db_reader.DbReader) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(rust_call.CallError!db_reader.DbReader, call_err);
        };

        const builder_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(rust_call.CallError!db_reader.DbReader, call_err);
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreaderbuilder_build(builder_handle);
        return io.async(waitReaderBuildTask, .{ &self.handle, future });
    }

    pub fn buildBlocking(self: *DbReaderBuilder) rust_call.CallError!db_reader.DbReader {
        try ffi.ensureCompatible();

        const builder_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_dbreaderbuilder_build(builder_handle);
        const raw_reader = try rust_future.waitPointer(future);
        return db_reader.DbReader.fromRaw(raw_reader);
    }

    pub fn withWalObjectStore(
        self: *DbReaderBuilder,
        store: *const object_store.ObjectStore,
    ) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const builder_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const store_handle = try @constCast(&store.handle).beginRustCall();
        defer @constCast(&store.handle).finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_dbreaderbuilder_with_wal_object_store(
            builder_handle,
            store_handle,
            &status,
        );
        try rust_call.checkStatus(status);
    }

    pub fn withMergeOperator(
        self: *DbReaderBuilder,
        operator: *const merge_operator.MergeOperator,
    ) (std.mem.Allocator.Error || rust_call.CallError)!void {
        try ffi.ensureCompatible();

        const builder_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const merge_operator_handle = try merge_operator.lowerMergeOperator(operator);
        errdefer merge_operator.discardLoweredMergeOperator(merge_operator_handle);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_dbreaderbuilder_with_merge_operator(
            builder_handle,
            merge_operator_handle,
            &status,
        );
        try rust_call.checkStatus(status);
    }

    pub fn deinit(self: *DbReaderBuilder) void {
        self.handle.deinit();
    }
};

fn waitReaderBuildTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) rust_call.CallError!db_reader.DbReader {
    defer owner.finishRustCall();
    const raw_reader = try rust_future.waitPointer(handle);
    return db_reader.DbReader.fromRaw(raw_reader);
}
