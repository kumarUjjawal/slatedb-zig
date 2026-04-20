const std = @import("std");

pub const CallError = error{
    ApiChecksumMismatch,
    BufferTooLarge,
    Closed,
    ContractVersionMismatch,
    Data,
    Internal,
    Invalid,
    ObjectDestroyed,
    RustPanic,
    RustPanicWhileHandlingPanic,
    Transaction,
    UnexpectedEnumTag,
    UnexpectedRustBufferData,
    Unavailable,
    UnexpectedEndOfBuffer,
};

pub const CloseReason = enum(i32) {
    clean = 1,
    fenced = 2,
    background_panic = 3,
    unknown = 4,
};

pub const ApiErrorPayload = union(enum) {
    transaction: []const u8,
    closed: struct {
        reason: CloseReason,
        message: []const u8,
    },
    unavailable: []const u8,
    invalid: []const u8,
    data: []const u8,
    internal: []const u8,
};

pub const CallErrorDetail = union(enum) {
    api_checksum_mismatch: struct {
        symbol: []u8,
        expected: u16,
        actual: u16,
    },
    buffer_too_large: struct {
        len: usize,
        max_len: usize,
    },
    closed: struct {
        reason: CloseReason,
        message: []u8,
    },
    contract_version_mismatch: struct {
        expected: u32,
        actual: u32,
    },
    data: []u8,
    internal: []u8,
    invalid: []u8,
    object_destroyed,
    rust_panic: []u8,
    rust_panic_while_handling_panic,
    transaction: []u8,
    unavailable: []u8,
    unexpected_end_of_buffer,
    unexpected_enum_tag,
    unexpected_rust_buffer_data,

    pub fn deinit(self: *CallErrorDetail, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .api_checksum_mismatch => |detail| allocator.free(detail.symbol),
            .closed => |detail| allocator.free(detail.message),
            .data => |message| allocator.free(message),
            .internal => |message| allocator.free(message),
            .invalid => |message| allocator.free(message),
            .rust_panic => |message| allocator.free(message),
            .transaction => |message| allocator.free(message),
            .unavailable => |message| allocator.free(message),
            .buffer_too_large,
            .contract_version_mismatch,
            .object_destroyed,
            .rust_panic_while_handling_panic,
            .unexpected_end_of_buffer,
            .unexpected_enum_tag,
            .unexpected_rust_buffer_data,
            => {},
        }
        self.* = undefined;
    }

    pub fn clone(
        self: CallErrorDetail,
        allocator: std.mem.Allocator,
    ) std.mem.Allocator.Error!CallErrorDetail {
        return switch (self) {
            .api_checksum_mismatch => |detail| .{
                .api_checksum_mismatch = .{
                    .symbol = try allocator.dupe(u8, detail.symbol),
                    .expected = detail.expected,
                    .actual = detail.actual,
                },
            },
            .buffer_too_large => |detail| .{ .buffer_too_large = detail },
            .closed => |detail| .{
                .closed = .{
                    .reason = detail.reason,
                    .message = try allocator.dupe(u8, detail.message),
                },
            },
            .contract_version_mismatch => |detail| .{ .contract_version_mismatch = detail },
            .data => |message| .{ .data = try allocator.dupe(u8, message) },
            .internal => |message| .{ .internal = try allocator.dupe(u8, message) },
            .invalid => |message| .{ .invalid = try allocator.dupe(u8, message) },
            .object_destroyed => .object_destroyed,
            .rust_panic => |message| .{ .rust_panic = try allocator.dupe(u8, message) },
            .rust_panic_while_handling_panic => .rust_panic_while_handling_panic,
            .transaction => |message| .{ .transaction = try allocator.dupe(u8, message) },
            .unavailable => |message| .{ .unavailable = try allocator.dupe(u8, message) },
            .unexpected_end_of_buffer => .unexpected_end_of_buffer,
            .unexpected_enum_tag => .unexpected_enum_tag,
            .unexpected_rust_buffer_data => .unexpected_rust_buffer_data,
        };
    }
};

var last_call_error_mutex: std.atomic.Mutex = .unlocked;
var last_call_error_detail: ?CallErrorDetail = null;

pub fn toCallError(payload: ApiErrorPayload) CallError {
    return switch (payload) {
        .transaction => error.Transaction,
        .closed => error.Closed,
        .unavailable => error.Unavailable,
        .invalid => error.Invalid,
        .data => error.Data,
        .internal => error.Internal,
    };
}

pub fn logApiError(payload: ApiErrorPayload) void {
    switch (payload) {
        .transaction => |message| std.log.err("SlateDB transaction error: {s}", .{message}),
        .closed => |closed| std.log.err(
            "SlateDB closed error ({s}): {s}",
            .{ @tagName(closed.reason), closed.message },
        ),
        .unavailable => |message| std.log.err("SlateDB unavailable error: {s}", .{message}),
        .invalid => |message| std.log.err("SlateDB invalid error: {s}", .{message}),
        .data => |message| std.log.err("SlateDB data error: {s}", .{message}),
        .internal => |message| std.log.err("SlateDB internal error: {s}", .{message}),
    }
}

pub fn takeLastCallErrorDetail(
    allocator: std.mem.Allocator,
) std.mem.Allocator.Error!?CallErrorDetail {
    lockLastCallErrorDetail();
    defer unlockLastCallErrorDetail();

    if (last_call_error_detail) |*detail| {
        const cloned = try detail.clone(allocator);
        detail.deinit(std.heap.page_allocator);
        last_call_error_detail = null;
        return cloned;
    }
    return null;
}

pub fn clearLastCallErrorDetail() void {
    lockLastCallErrorDetail();
    defer unlockLastCallErrorDetail();
    clearLastCallErrorDetailLocked();
}

pub fn rememberApiChecksumMismatch(symbol: []const u8, expected: u16, actual: u16) void {
    const stored_symbol = std.heap.page_allocator.dupe(u8, symbol) catch {
        clearLastCallErrorDetail();
        std.log.err("failed to store SlateDB ABI checksum detail", .{});
        return;
    };

    replaceLastCallErrorDetail(.{
        .api_checksum_mismatch = .{
            .symbol = stored_symbol,
            .expected = expected,
            .actual = actual,
        },
    });
}

pub fn rememberBufferTooLarge(len: usize, max_len: usize) void {
    replaceLastCallErrorDetail(.{
        .buffer_too_large = .{
            .len = len,
            .max_len = max_len,
        },
    });
}

pub fn rememberContractVersionMismatch(expected: u32, actual: u32) void {
    replaceLastCallErrorDetail(.{
        .contract_version_mismatch = .{
            .expected = expected,
            .actual = actual,
        },
    });
}

pub fn rememberApiErrorPayload(payload: ApiErrorPayload) void {
    const detail = cloneApiErrorPayload(std.heap.page_allocator, payload) catch {
        clearLastCallErrorDetail();
        std.log.err("failed to store SlateDB API error detail", .{});
        return;
    };
    replaceLastCallErrorDetail(detail);
}

pub fn rememberObjectDestroyed() void {
    replaceLastCallErrorDetail(.object_destroyed);
}

pub fn rememberRustPanic(message: []const u8) void {
    const stored_message = std.heap.page_allocator.dupe(u8, message) catch {
        clearLastCallErrorDetail();
        std.log.err("failed to store Rust panic detail", .{});
        return;
    };
    replaceLastCallErrorDetail(.{ .rust_panic = stored_message });
}

pub fn rememberRustPanicWhileHandlingPanic() void {
    replaceLastCallErrorDetail(.rust_panic_while_handling_panic);
}

pub fn rememberUnexpectedEndOfBuffer() void {
    replaceLastCallErrorDetail(.unexpected_end_of_buffer);
}

pub fn rememberUnexpectedEnumTag() void {
    replaceLastCallErrorDetail(.unexpected_enum_tag);
}

pub fn rememberUnexpectedRustBufferData() void {
    replaceLastCallErrorDetail(.unexpected_rust_buffer_data);
}

pub fn rememberInternalMessage(message: []const u8) void {
    const stored_message = std.heap.page_allocator.dupe(u8, message) catch {
        clearLastCallErrorDetail();
        std.log.err("failed to store SlateDB internal error detail", .{});
        return;
    };
    replaceLastCallErrorDetail(.{ .internal = stored_message });
}

pub fn rememberInternalMessageFmt(comptime fmt: []const u8, args: anytype) void {
    const stored_message = std.fmt.allocPrint(std.heap.page_allocator, fmt, args) catch {
        clearLastCallErrorDetail();
        std.log.err("failed to format SlateDB internal error detail", .{});
        return;
    };
    replaceLastCallErrorDetail(.{ .internal = stored_message });
}

fn replaceLastCallErrorDetail(detail: CallErrorDetail) void {
    lockLastCallErrorDetail();
    defer unlockLastCallErrorDetail();
    clearLastCallErrorDetailLocked();
    last_call_error_detail = detail;
}

fn cloneApiErrorPayload(
    allocator: std.mem.Allocator,
    payload: ApiErrorPayload,
) std.mem.Allocator.Error!CallErrorDetail {
    return switch (payload) {
        .transaction => |message| .{ .transaction = try allocator.dupe(u8, message) },
        .closed => |detail| .{
            .closed = .{
                .reason = detail.reason,
                .message = try allocator.dupe(u8, detail.message),
            },
        },
        .unavailable => |message| .{ .unavailable = try allocator.dupe(u8, message) },
        .invalid => |message| .{ .invalid = try allocator.dupe(u8, message) },
        .data => |message| .{ .data = try allocator.dupe(u8, message) },
        .internal => |message| .{ .internal = try allocator.dupe(u8, message) },
    };
}

fn clearLastCallErrorDetailLocked() void {
    if (last_call_error_detail) |*detail| {
        detail.deinit(std.heap.page_allocator);
        last_call_error_detail = null;
    }
}

fn lockLastCallErrorDetail() void {
    while (!last_call_error_mutex.tryLock()) {
        std.Thread.yield() catch {};
    }
}

fn unlockLastCallErrorDetail() void {
    last_call_error_mutex.unlock();
}
