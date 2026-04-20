const std = @import("std");
const err = @import("error.zig");
const metrics = @import("metrics.zig");
const rust_buffer = @import("rust_buffer.zig");
const types = @import("types.zig");

pub const WriteHandle = types.WriteHandle;
pub const KeyRange = types.KeyRange;
pub const KeyValue = types.KeyValue;
pub const RowEntry = types.RowEntry;
pub const RowEntryKind = types.RowEntryKind;

pub const BufferReader = struct {
    bytes: []const u8,
    pos: usize = 0,

    pub fn init(bytes: []const u8) BufferReader {
        return .{ .bytes = bytes };
    }

    pub fn finish(self: *BufferReader) err.CallError!void {
        if (self.pos != self.bytes.len) {
            return unexpectedRustBufferData();
        }
    }

    pub fn readInt8(self: *BufferReader) err.CallError!i8 {
        const value = try self.readByte();
        return @bitCast(value);
    }

    pub fn readI32(self: *BufferReader) err.CallError!i32 {
        return @bitCast(try self.readU32());
    }

    pub fn readU32(self: *BufferReader) err.CallError!u32 {
        const bytes = try self.readSlice(4);
        return std.mem.readInt(u32, bytes[0..4], .big);
    }

    pub fn readU64(self: *BufferReader) err.CallError!u64 {
        const bytes = try self.readSlice(8);
        return std.mem.readInt(u64, bytes[0..8], .big);
    }

    pub fn readI64(self: *BufferReader) err.CallError!i64 {
        return @bitCast(try self.readU64());
    }

    pub fn readSlice(self: *BufferReader, len: usize) err.CallError![]const u8 {
        if (self.pos + len > self.bytes.len) {
            return unexpectedEndOfBuffer();
        }
        const out = self.bytes[self.pos .. self.pos + len];
        self.pos += len;
        return out;
    }

    fn readByte(self: *BufferReader) err.CallError!u8 {
        if (self.pos >= self.bytes.len) {
            return unexpectedEndOfBuffer();
        }
        const value = self.bytes[self.pos];
        self.pos += 1;
        return value;
    }
};

pub fn decodeLiftedString(bytes: []const u8) err.CallError![]const u8 {
    var reader = BufferReader.init(bytes);
    const value = try decodeString(&reader);
    try reader.finish();
    return value;
}

pub fn decodeString(reader: *BufferReader) err.CallError![]const u8 {
    const len = try reader.readI32();
    if (len < 0) {
        return unexpectedRustBufferData();
    }
    return reader.readSlice(@intCast(len));
}

pub fn decodeOptionalBytes(
    allocator: std.mem.Allocator,
    reader: *BufferReader,
) (std.mem.Allocator.Error || err.CallError)!?[]u8 {
    return switch (try reader.readInt8()) {
        0 => null,
        1 => @as(?[]u8, try decodeOwnedBytes(allocator, reader)),
        else => unexpectedEnumTag(),
    };
}

pub fn decodeWriteHandle(reader: *BufferReader) err.CallError!WriteHandle {
    return .{
        .seqnum = try reader.readU64(),
        .create_ts = try reader.readI64(),
    };
}

pub fn decodeOptionalWriteHandle(reader: *BufferReader) err.CallError!?WriteHandle {
    return switch (try reader.readInt8()) {
        0 => null,
        1 => try decodeWriteHandle(reader),
        else => unexpectedEnumTag(),
    };
}

pub fn decodeOptionalKeyValue(
    allocator: std.mem.Allocator,
    reader: *BufferReader,
) (std.mem.Allocator.Error || err.CallError)!?KeyValue {
    return switch (try reader.readInt8()) {
        0 => null,
        1 => try decodeKeyValue(allocator, reader),
        else => unexpectedEnumTag(),
    };
}

pub fn decodeOptionalRowEntry(
    allocator: std.mem.Allocator,
    reader: *BufferReader,
) (std.mem.Allocator.Error || err.CallError)!?RowEntry {
    return switch (try reader.readInt8()) {
        0 => null,
        1 => try decodeRowEntry(allocator, reader),
        else => unexpectedEnumTag(),
    };
}

pub fn decodeOwnedString(
    allocator: std.mem.Allocator,
    reader: *BufferReader,
) (std.mem.Allocator.Error || err.CallError)![]u8 {
    const value = try decodeString(reader);
    return allocator.dupe(u8, value);
}

pub fn decodeIntMetricsSnapshot(
    allocator: std.mem.Allocator,
    reader: *BufferReader,
) (std.mem.Allocator.Error || err.CallError)!metrics.IntMetricsSnapshot {
    const len = try reader.readI32();
    if (len < 0) {
        return unexpectedRustBufferData();
    }

    const count: usize = @intCast(len);
    var entries: []metrics.IntMetric = &.{};
    if (count > 0) {
        entries = try allocator.alloc(metrics.IntMetric, count);
    }
    errdefer if (entries.len > 0) allocator.free(entries);

    var initialized: usize = 0;
    errdefer {
        for (entries[0..initialized]) |entry| {
            allocator.free(entry.name);
        }
    }

    while (initialized < count) {
        const name = try decodeOwnedString(allocator, reader);
        var keep_name = true;
        errdefer if (keep_name) allocator.free(name);

        const value = try reader.readI64();
        entries[initialized] = .{
            .name = name,
            .value = value,
        };
        initialized += 1;
        keep_name = false;
    }

    return .{ .entries = entries };
}

pub fn encodeKeyRange(range: KeyRange) (std.mem.Allocator.Error || err.CallError)!rust_buffer.RustBuffer {
    const total_len = try keyRangeEncodedLen(range);
    const encoded = try std.heap.page_allocator.alloc(u8, total_len);
    defer std.heap.page_allocator.free(encoded);

    var writer = BufferWriter.init(encoded);
    try writer.writeOptionalBytes(range.start);
    writer.writeBool(range.start_inclusive);
    try writer.writeOptionalBytes(range.end);
    writer.writeBool(range.end_inclusive);

    if (writer.pos != encoded.len) {
        err.rememberInternalMessage("failed to encode key range");
        return error.Internal;
    }

    return rust_buffer.RustBuffer.fromBytes(encoded);
}

pub fn decodeApiError(reader: *BufferReader) err.CallError!err.ApiErrorPayload {
    return switch (try reader.readU32()) {
        1 => .{ .transaction = try decodeString(reader) },
        2 => .{
            .closed = .{
                .reason = try decodeCloseReason(reader),
                .message = try decodeString(reader),
            },
        },
        3 => .{ .unavailable = try decodeString(reader) },
        4 => .{ .invalid = try decodeString(reader) },
        5 => .{ .data = try decodeString(reader) },
        6 => .{ .internal = try decodeString(reader) },
        else => unexpectedEnumTag(),
    };
}

fn decodeBytes(reader: *BufferReader) err.CallError![]const u8 {
    const len = try reader.readI32();
    if (len < 0) {
        return unexpectedRustBufferData();
    }
    return reader.readSlice(@intCast(len));
}

pub fn decodeOwnedBytes(
    allocator: std.mem.Allocator,
    reader: *BufferReader,
) (std.mem.Allocator.Error || err.CallError)![]u8 {
    const bytes = try decodeBytes(reader);
    return allocator.dupe(u8, bytes);
}

fn decodeKeyValue(
    allocator: std.mem.Allocator,
    reader: *BufferReader,
) (std.mem.Allocator.Error || err.CallError)!KeyValue {
    const key = try decodeOwnedBytes(allocator, reader);
    errdefer allocator.free(key);

    const value = try decodeOwnedBytes(allocator, reader);
    errdefer allocator.free(value);

    return .{
        .key = key,
        .value = value,
        .seq = try reader.readU64(),
        .create_ts = try reader.readI64(),
        .expire_ts = try decodeOptionalI64(reader),
    };
}

fn decodeRowEntry(
    allocator: std.mem.Allocator,
    reader: *BufferReader,
) (std.mem.Allocator.Error || err.CallError)!RowEntry {
    const kind = try decodeRowEntryKind(reader);

    const key = try decodeOwnedBytes(allocator, reader);
    errdefer allocator.free(key);

    const value = try decodeOptionalBytes(allocator, reader);
    errdefer if (value) |bytes| allocator.free(bytes);

    return .{
        .kind = kind,
        .key = key,
        .value = value,
        .seq = try reader.readU64(),
        .create_ts = try decodeOptionalI64(reader),
        .expire_ts = try decodeOptionalI64(reader),
    };
}

fn decodeCloseReason(reader: *BufferReader) err.CallError!err.CloseReason {
    return switch (try reader.readI32()) {
        1 => .clean,
        2 => .fenced,
        3 => .background_panic,
        4 => .unknown,
        else => unexpectedEnumTag(),
    };
}

fn decodeRowEntryKind(reader: *BufferReader) err.CallError!RowEntryKind {
    return switch (try reader.readI32()) {
        1 => .value,
        2 => .tombstone,
        3 => .merge,
        else => unexpectedEnumTag(),
    };
}

fn decodeOptionalI64(reader: *BufferReader) err.CallError!?i64 {
    return switch (try reader.readInt8()) {
        0 => null,
        1 => try reader.readI64(),
        else => unexpectedEnumTag(),
    };
}

const BufferWriter = struct {
    bytes: []u8,
    pos: usize = 0,

    fn init(bytes: []u8) BufferWriter {
        return .{ .bytes = bytes };
    }

    fn writeBool(self: *BufferWriter, value: bool) void {
        self.bytes[self.pos] = if (value) 1 else 0;
        self.pos += 1;
    }

    fn writeOptionalBytes(self: *BufferWriter, value: ?[]const u8) err.CallError!void {
        if (value) |bytes| {
            self.bytes[self.pos] = 1;
            self.pos += 1;
            try self.writeBytes(bytes);
        } else {
            self.bytes[self.pos] = 0;
            self.pos += 1;
        }
    }

    fn writeBytes(self: *BufferWriter, value: []const u8) err.CallError!void {
        const len: i32 = @intCast(value.len);
        var len_bytes: [4]u8 = undefined;
        std.mem.writeInt(i32, &len_bytes, len, .big);
        @memcpy(self.bytes[self.pos .. self.pos + 4], len_bytes[0..]);
        self.pos += 4;
        @memcpy(self.bytes[self.pos .. self.pos + value.len], value);
        self.pos += value.len;
    }
};

fn keyRangeEncodedLen(range: KeyRange) err.CallError!usize {
    var total_len: usize = 0;
    total_len = try addOptionalBytesLen(total_len, range.start);
    total_len += 1;
    total_len = try addOptionalBytesLen(total_len, range.end);
    total_len += 1;
    return total_len;
}

fn addOptionalBytesLen(base: usize, value: ?[]const u8) err.CallError!usize {
    var total = base + 1;
    if (value) |bytes| {
        if (bytes.len > std.math.maxInt(i32)) {
            return bufferTooLarge(bytes.len);
        }
        total += 4 + bytes.len;
    }
    return total;
}

fn bufferTooLarge(len: usize) err.CallError {
    err.rememberBufferTooLarge(len, std.math.maxInt(i32));
    return error.BufferTooLarge;
}

fn unexpectedEndOfBuffer() err.CallError {
    err.rememberUnexpectedEndOfBuffer();
    return error.UnexpectedEndOfBuffer;
}

fn unexpectedEnumTag() err.CallError {
    err.rememberUnexpectedEnumTag();
    return error.UnexpectedEnumTag;
}

fn unexpectedRustBufferData() err.CallError {
    err.rememberUnexpectedRustBufferData();
    return error.UnexpectedRustBufferData;
}
