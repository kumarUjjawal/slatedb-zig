const std = @import("std");
const config = @import("config.zig");
const ffi = @import("ffi.zig");
const object_handle = @import("object_handle.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");

pub const WriteBatch = struct {
    handle: object_handle.ObjectHandle,

    pub fn init() rust_call.CallError!WriteBatch {
        try ffi.ensureCompatible();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const raw = ffi.c.uniffi_slatedb_uniffi_fn_constructor_writebatch_new(&status);
        try rust_call.checkStatus(status);

        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_writebatch,
                ffi.c.uniffi_slatedb_uniffi_fn_free_writebatch,
            ),
        };
    }

    pub fn put(
        self: *WriteBatch,
        key: []const u8,
        value: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!void {
        try ffi.ensureCompatible();

        const batch_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const value_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(value);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_writebatch_put(
            batch_handle,
            key_buffer.raw,
            value_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);
    }

    pub fn putWithOptions(
        self: *WriteBatch,
        key: []const u8,
        value: []const u8,
        options: config.PutOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!void {
        try ffi.ensureCompatible();

        const batch_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const value_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(value);
        const options_buffer = try config.encodePutOptions(options);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_writebatch_put_with_options(
            batch_handle,
            key_buffer.raw,
            value_buffer.raw,
            options_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);
    }

    pub fn delete(
        self: *WriteBatch,
        key: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!void {
        try ffi.ensureCompatible();

        const batch_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_writebatch_delete(
            batch_handle,
            key_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);
    }

    pub fn merge(
        self: *WriteBatch,
        key: []const u8,
        operand: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!void {
        try ffi.ensureCompatible();

        const batch_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const operand_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(operand);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_writebatch_merge(
            batch_handle,
            key_buffer.raw,
            operand_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);
    }

    pub fn mergeWithOptions(
        self: *WriteBatch,
        key: []const u8,
        operand: []const u8,
        options: config.MergeOptions,
    ) (std.mem.Allocator.Error || rust_call.CallError)!void {
        try ffi.ensureCompatible();

        const batch_handle = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const key_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(key);
        const operand_buffer = try rust_buffer.RustBuffer.fromSerializedBytes(operand);
        const options_buffer = try config.encodeMergeOptions(options);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.c.uniffi_slatedb_uniffi_fn_method_writebatch_merge_with_options(
            batch_handle,
            key_buffer.raw,
            operand_buffer.raw,
            options_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);
    }

    pub fn deinit(self: *WriteBatch) void {
        self.handle.deinit();
    }
};
