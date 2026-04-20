const std = @import("std");
const callback_handle_map = @import("callback_handle_map.zig");
const codec = @import("codec.zig");
const ffi = @import("ffi.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");
const spin_lock = @import("spin_lock.zig");

pub const MergeOperatorResult = union(enum) {
    value: []u8,
    failed: []u8,

    pub fn deinit(self: *MergeOperatorResult, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .value => |value| allocator.free(value),
            .failed => |message| allocator.free(message),
        }
        self.* = undefined;
    }
};

pub const MergeOperator = struct {
    // `context` must stay valid for as long as the DB or reader may invoke the
    // merge callback.
    context: *anyopaque,
    merge_fn: *const fn (
        context: *anyopaque,
        allocator: std.mem.Allocator,
        key: []const u8,
        existing_value: ?[]const u8,
        operand: []const u8,
    ) std.mem.Allocator.Error!MergeOperatorResult,

    pub fn merge(
        self: *const MergeOperator,
        allocator: std.mem.Allocator,
        key: []const u8,
        existing_value: ?[]const u8,
        operand: []const u8,
    ) std.mem.Allocator.Error!MergeOperatorResult {
        return self.merge_fn(self.context, allocator, key, existing_value, operand);
    }
};

var merge_operator_handles: callback_handle_map.HandleMap(MergeOperator) = .{};
var merge_operator_vtable_registered = false;
var merge_operator_vtable_mutex: spin_lock.SpinLock = .{};

var merge_operator_vtable = ffi.c.UniffiVTableCallbackInterfaceMergeOperator{
    .merge = @ptrCast(&slatedb_uniffi_cgo_dispatchCallbackInterfaceMergeOperatorMethod0),
    .uniffiFree = @ptrCast(&slatedb_uniffi_cgo_dispatchCallbackInterfaceMergeOperatorFree),
};

pub fn lowerMergeOperator(
    merge_operator: *const MergeOperator,
) std.mem.Allocator.Error!?*anyopaque {
    ensureMergeOperatorVTableRegistered();
    const handle = try merge_operator_handles.insert(std.heap.smp_allocator, merge_operator.*);
    return @ptrFromInt(handle);
}

pub fn discardLoweredMergeOperator(raw_handle: ?*anyopaque) void {
    const handle = @intFromPtr(raw_handle);
    if (handle == 0) {
        return;
    }
    merge_operator_handles.remove(handle);
}

fn ensureMergeOperatorVTableRegistered() void {
    if (merge_operator_vtable_registered) {
        return;
    }

    merge_operator_vtable_mutex.lock();
    defer merge_operator_vtable_mutex.unlock();

    if (merge_operator_vtable_registered) {
        return;
    }

    ffi.c.uniffi_slatedb_uniffi_fn_init_callback_vtable_mergeoperator(&merge_operator_vtable);
    merge_operator_vtable_registered = true;
}

fn encodeMergeOperatorCallbackError(
    message: []const u8,
) (std.mem.Allocator.Error || rust_call.CallError)!rust_buffer.RustBuffer {
    if (message.len > std.math.maxInt(i32)) {
        return error.BufferTooLarge;
    }

    const encoded_len = 8 + message.len;
    const encoded = try std.heap.page_allocator.alloc(u8, encoded_len);
    defer std.heap.page_allocator.free(encoded);

    std.mem.writeInt(i32, encoded[0..4], 1, .big);
    std.mem.writeInt(i32, encoded[4..8], @intCast(message.len), .big);
    @memcpy(encoded[8..], message);
    return rust_buffer.RustBuffer.fromBytes(encoded);
}

pub export fn slatedb_uniffi_cgo_dispatchCallbackInterfaceMergeOperatorMethod0(
    uniffi_handle: u64,
    key: ffi.c.RustBuffer,
    existing_value: ffi.c.RustBuffer,
    operand: ffi.c.RustBuffer,
    uniffi_out_return: *ffi.c.RustBuffer,
    call_status: *ffi.c.RustCallStatus,
) callconv(.c) void {
    call_status.* = std.mem.zeroes(ffi.c.RustCallStatus);

    const merge_operator = merge_operator_handles.get(uniffi_handle) orelse {
        std.log.err("missing SlateDB merge operator handle {d}", .{uniffi_handle});
        call_status.code = 2;
        return;
    };

    var key_buffer = rust_buffer.RustBuffer{ .raw = key };
    defer key_buffer.deinit();
    var existing_value_buffer = rust_buffer.RustBuffer{ .raw = existing_value };
    defer existing_value_buffer.deinit();
    var operand_buffer = rust_buffer.RustBuffer{ .raw = operand };
    defer operand_buffer.deinit();

    var key_reader = codec.BufferReader.init(key_buffer.bytes());
    const owned_key = codec.decodeOwnedBytes(std.heap.smp_allocator, &key_reader) catch |decode_err| {
        std.log.err("failed to decode SlateDB merge key: {s}", .{@errorName(decode_err)});
        call_status.code = 2;
        return;
    };
    defer std.heap.smp_allocator.free(owned_key);
    key_reader.finish() catch |decode_err| {
        std.log.err("SlateDB merge key had trailing data: {s}", .{@errorName(decode_err)});
        call_status.code = 2;
        return;
    };

    var existing_value_reader = codec.BufferReader.init(existing_value_buffer.bytes());
    const owned_existing_value = codec.decodeOptionalBytes(
        std.heap.smp_allocator,
        &existing_value_reader,
    ) catch |decode_err| {
        std.log.err("failed to decode SlateDB merge existing value: {s}", .{@errorName(decode_err)});
        call_status.code = 2;
        return;
    };
    defer if (owned_existing_value) |value| std.heap.smp_allocator.free(value);
    existing_value_reader.finish() catch |decode_err| {
        std.log.err("SlateDB merge existing value had trailing data: {s}", .{@errorName(decode_err)});
        call_status.code = 2;
        return;
    };

    var operand_reader = codec.BufferReader.init(operand_buffer.bytes());
    const owned_operand = codec.decodeOwnedBytes(std.heap.smp_allocator, &operand_reader) catch |decode_err| {
        std.log.err("failed to decode SlateDB merge operand: {s}", .{@errorName(decode_err)});
        call_status.code = 2;
        return;
    };
    defer std.heap.smp_allocator.free(owned_operand);
    operand_reader.finish() catch |decode_err| {
        std.log.err("SlateDB merge operand had trailing data: {s}", .{@errorName(decode_err)});
        call_status.code = 2;
        return;
    };

    var result = merge_operator.merge(
        std.heap.smp_allocator,
        owned_key,
        owned_existing_value,
        owned_operand,
    ) catch |merge_err| {
        const encoded_error = encodeMergeOperatorCallbackError(@errorName(merge_err)) catch {
            call_status.code = 2;
            return;
        };
        call_status.* = .{
            .code = 1,
            .errorBuf = encoded_error.raw,
        };
        return;
    };
    defer result.deinit(std.heap.smp_allocator);

    switch (result) {
        .value => |value| {
            const out_buffer = rust_buffer.RustBuffer.fromSerializedBytes(value) catch {
                call_status.code = 2;
                return;
            };
            uniffi_out_return.* = out_buffer.raw;
        },
        .failed => |message| {
            const encoded_error = encodeMergeOperatorCallbackError(message) catch {
                call_status.code = 2;
                return;
            };
            call_status.* = .{
                .code = 1,
                .errorBuf = encoded_error.raw,
            };
        },
    }
}

pub export fn slatedb_uniffi_cgo_dispatchCallbackInterfaceMergeOperatorFree(
    handle: u64,
) callconv(.c) void {
    merge_operator_handles.remove(handle);
}
