const std = @import("std");
const codec = @import("codec.zig");
const err = @import("error.zig");
const ffi = @import("ffi.zig");
const object_handle = @import("object_handle.zig");
const object_store = @import("object_store.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");
const rust_future = @import("rust_future.zig");
const types = @import("types.zig");

pub const WalFileMetadata = struct {
    last_modified_seconds: i64,
    last_modified_nanos: u32,
    size_bytes: u64,
    location: []u8,

    pub fn deinit(self: *WalFileMetadata, allocator: std.mem.Allocator) void {
        allocator.free(self.location);
        self.* = undefined;
    }
};

pub const WalFile = struct {
    handle: object_handle.ObjectHandle,

    pub fn fromRaw(raw: ?*anyopaque) WalFile {
        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_walfile,
                ffi.c.uniffi_slatedb_uniffi_fn_free_walfile,
            ),
        };
    }

    pub fn id(self: *WalFile) rust_call.CallError!u64 {
        try ffi.ensureCompatible();

        const file_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const value = ffi.c.uniffi_slatedb_uniffi_fn_method_walfile_id(file_handle, &status);
        try rust_call.checkStatus(status);
        return value;
    }

    pub fn nextId(self: *WalFile) rust_call.CallError!u64 {
        try ffi.ensureCompatible();

        const file_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const value = ffi.c.uniffi_slatedb_uniffi_fn_method_walfile_next_id(file_handle, &status);
        try rust_call.checkStatus(status);
        return value;
    }

    pub fn nextFile(self: *WalFile) rust_call.CallError!WalFile {
        try ffi.ensureCompatible();

        const file_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const raw = ffi.c.uniffi_slatedb_uniffi_fn_method_walfile_next_file(file_handle, &status);
        try rust_call.checkStatus(status);
        return try walFileFromRaw(raw);
    }

    pub fn metadata(
        self: *WalFile,
        io: std.Io,
        allocator: std.mem.Allocator,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!WalFileMetadata) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WalFileMetadata,
                call_err,
            );
        };

        const file_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!WalFileMetadata,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_walfile_metadata(file_handle);
        return io.async(waitMetadataTask, .{ &self.handle, allocator, future });
    }

    pub fn metadataBlocking(
        self: *WalFile,
        allocator: std.mem.Allocator,
    ) (std.mem.Allocator.Error || rust_call.CallError)!WalFileMetadata {
        try ffi.ensureCompatible();

        const file_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_walfile_metadata(file_handle);

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const metadata_value = try decodeWalFileMetadata(allocator, &reader);
        try reader.finish();
        return metadata_value;
    }

    pub fn iterator(
        self: *WalFile,
        io: std.Io,
    ) std.Io.Future(rust_call.CallError!WalFileIterator) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(rust_call.CallError!WalFileIterator, call_err);
        };

        const file_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(rust_call.CallError!WalFileIterator, call_err);
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_walfile_iterator(file_handle);
        return io.async(waitIteratorTask, .{ &self.handle, future });
    }

    pub fn iteratorBlocking(self: *WalFile) rust_call.CallError!WalFileIterator {
        try ffi.ensureCompatible();

        const file_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_walfile_iterator(file_handle);
        const raw_iterator = try rust_future.waitPointer(future);
        return WalFileIterator.fromRaw(raw_iterator);
    }

    pub fn deinit(self: *WalFile) void {
        self.handle.deinit();
    }

    pub fn deinitSlice(allocator: std.mem.Allocator, files: []WalFile) void {
        for (files) |*file| {
            file.deinit();
        }
        allocator.free(files);
    }
};

pub const WalFileIterator = struct {
    handle: object_handle.ObjectHandle,

    pub fn fromRaw(raw: ?*anyopaque) WalFileIterator {
        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_walfileiterator,
                ffi.c.uniffi_slatedb_uniffi_fn_free_walfileiterator,
            ),
        };
    }

    pub fn next(
        self: *WalFileIterator,
        io: std.Io,
        allocator: std.mem.Allocator,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)!?types.RowEntry) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?types.RowEntry,
                call_err,
            );
        };

        const iterator_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)!?types.RowEntry,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_walfileiterator_next(iterator_handle);
        return io.async(waitRowEntryTask, .{ &self.handle, allocator, future });
    }

    pub fn nextBlocking(
        self: *WalFileIterator,
        allocator: std.mem.Allocator,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?types.RowEntry {
        try ffi.ensureCompatible();

        const iterator_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_walfileiterator_next(iterator_handle);

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const entry = try codec.decodeOptionalRowEntry(allocator, &reader);
        try reader.finish();
        return entry;
    }

    pub fn deinit(self: *WalFileIterator) void {
        self.handle.deinit();
    }
};

pub const WalReader = struct {
    handle: object_handle.ObjectHandle,

    pub fn init(path: []const u8, store: *const object_store.ObjectStore) rust_call.CallError!WalReader {
        try ffi.ensureCompatible();

        const path_buffer = try rust_buffer.RustBuffer.fromBytes(path);
        const store_handle = try @constCast(&store.handle).beginRustCall();
        defer @constCast(&store.handle).finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const raw = ffi.c.uniffi_slatedb_uniffi_fn_constructor_walreader_new(
            path_buffer.raw,
            store_handle,
            &status,
        );
        try rust_call.checkStatus(status);

        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_walreader,
                ffi.c.uniffi_slatedb_uniffi_fn_free_walreader,
            ),
        };
    }

    pub fn get(self: *WalReader, id: u64) rust_call.CallError!WalFile {
        try ffi.ensureCompatible();

        const reader_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const raw = ffi.c.uniffi_slatedb_uniffi_fn_method_walreader_get(reader_handle, id, &status);
        try rust_call.checkStatus(status);
        return try walFileFromRaw(raw);
    }

    pub fn list(
        self: *WalReader,
        io: std.Io,
        allocator: std.mem.Allocator,
        start_id: ?u64,
        end_id: ?u64,
    ) std.Io.Future((std.mem.Allocator.Error || rust_call.CallError)![]WalFile) {
        ffi.ensureCompatible() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)![]WalFile,
                call_err,
            );
        };

        const reader_handle = self.handle.beginRustCall() catch |call_err| {
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)![]WalFile,
                call_err,
            );
        };

        const start_buffer = encodeOptionalU64(start_id) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)![]WalFile,
                call_err,
            );
        };
        const end_buffer = encodeOptionalU64(end_id) catch |call_err| {
            self.handle.finishRustCall();
            return rust_future.ready(
                (std.mem.Allocator.Error || rust_call.CallError)![]WalFile,
                call_err,
            );
        };

        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_walreader_list(
            reader_handle,
            start_buffer.raw,
            end_buffer.raw,
        );
        return io.async(waitListTask, .{ &self.handle, allocator, future });
    }

    pub fn listBlocking(
        self: *WalReader,
        allocator: std.mem.Allocator,
        start_id: ?u64,
        end_id: ?u64,
    ) (std.mem.Allocator.Error || rust_call.CallError)![]WalFile {
        try ffi.ensureCompatible();

        const reader_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const start_buffer = try encodeOptionalU64(start_id);
        const end_buffer = try encodeOptionalU64(end_id);
        const future = ffi.c.uniffi_slatedb_uniffi_fn_method_walreader_list(
            reader_handle,
            start_buffer.raw,
            end_buffer.raw,
        );

        var result_buffer = try rust_future.waitRustBuffer(future);
        defer result_buffer.deinit();

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const files = try decodeWalFileList(allocator, &reader);
        try reader.finish();
        return files;
    }

    pub fn deinit(self: *WalReader) void {
        self.handle.deinit();
    }
};

fn waitMetadataTask(
    owner: *object_handle.ObjectHandle,
    allocator: std.mem.Allocator,
    handle: u64,
) (std.mem.Allocator.Error || rust_call.CallError)!WalFileMetadata {
    defer owner.finishRustCall();

    var result_buffer = try rust_future.waitRustBuffer(handle);
    defer result_buffer.deinit();

    var reader = codec.BufferReader.init(result_buffer.bytes());
    const metadata_value = try decodeWalFileMetadata(allocator, &reader);
    try reader.finish();
    return metadata_value;
}

fn waitIteratorTask(
    owner: *object_handle.ObjectHandle,
    handle: u64,
) rust_call.CallError!WalFileIterator {
    defer owner.finishRustCall();

    const raw_iterator = try rust_future.waitPointer(handle);
    return WalFileIterator.fromRaw(raw_iterator);
}

fn waitRowEntryTask(
    owner: *object_handle.ObjectHandle,
    allocator: std.mem.Allocator,
    handle: u64,
) (std.mem.Allocator.Error || rust_call.CallError)!?types.RowEntry {
    defer owner.finishRustCall();

    var result_buffer = try rust_future.waitRustBuffer(handle);
    defer result_buffer.deinit();

    var reader = codec.BufferReader.init(result_buffer.bytes());
    const entry = try codec.decodeOptionalRowEntry(allocator, &reader);
    try reader.finish();
    return entry;
}

fn waitListTask(
    owner: *object_handle.ObjectHandle,
    allocator: std.mem.Allocator,
    handle: u64,
) (std.mem.Allocator.Error || rust_call.CallError)![]WalFile {
    defer owner.finishRustCall();

    var result_buffer = try rust_future.waitRustBuffer(handle);
    defer result_buffer.deinit();

    var reader = codec.BufferReader.init(result_buffer.bytes());
    const files = try decodeWalFileList(allocator, &reader);
    try reader.finish();
    return files;
}

fn walFileFromRaw(raw: ?*anyopaque) rust_call.CallError!WalFile {
    if (raw == null) {
        err.rememberInternalMessage("Rust returned a null WalFile handle");
        return error.Internal;
    }
    return WalFile.fromRaw(raw);
}

fn decodeWalFileMetadata(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)!WalFileMetadata {
    const last_modified_seconds = try reader.readI64();
    const last_modified_nanos = try reader.readU32();
    const size_bytes = try reader.readU64();
    const location = try allocator.dupe(u8, try codec.decodeString(reader));
    errdefer allocator.free(location);

    return .{
        .last_modified_seconds = last_modified_seconds,
        .last_modified_nanos = last_modified_nanos,
        .size_bytes = size_bytes,
        .location = location,
    };
}

fn decodeWalFileList(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)![]WalFile {
    const len = try reader.readI32();
    if (len < 0) {
        err.rememberUnexpectedRustBufferData();
        return error.UnexpectedRustBufferData;
    }

    const files = try allocator.alloc(WalFile, @intCast(len));
    errdefer allocator.free(files);

    var initialized: usize = 0;
    errdefer {
        for (files[0..initialized]) |*file| {
            file.deinit();
        }
    }

    for (files, 0..) |*file, index| {
        const raw_pointer = try reader.readU64();
        if (raw_pointer == 0) {
            err.rememberInternalMessage("Rust returned a null WalFile list item");
            return error.Internal;
        }

        file.* = WalFile.fromRaw(@ptrFromInt(@as(usize, @intCast(raw_pointer))));
        initialized = index + 1;
    }

    return files;
}

fn encodeOptionalU64(value: ?u64) rust_call.CallError!rust_buffer.RustBuffer {
    if (value) |inner| {
        var encoded: [9]u8 = undefined;
        encoded[0] = 1;
        std.mem.writeInt(u64, encoded[1..9], inner, .big);
        return rust_buffer.RustBuffer.fromBytes(&encoded);
    }

    const encoded = [_]u8{0};
    return rust_buffer.RustBuffer.fromBytes(&encoded);
}
