const std = @import("std");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");

pub const IsolationLevel = enum(i32) {
    snapshot = 1,
    serializable_snapshot = 2,
};

pub const DurabilityLevel = enum(i32) {
    remote = 1,
    memory = 2,
};

pub const FlushType = enum(i32) {
    mem_table = 1,
    wal = 2,
};

pub const Ttl = union(enum) {
    default,
    no_expiry,
    expire_after_ticks: u64,
    expire_at: i64,
};

pub const ReadOptions = struct {
    durability_filter: DurabilityLevel = .memory,
    dirty: bool = false,
    cache_blocks: bool = true,
};

pub const ReaderOptions = struct {
    manifest_poll_interval_ms: u64 = 10_000,
    checkpoint_lifetime_ms: u64 = 600_000,
    max_memtable_bytes: u64 = 64 * 1024 * 1024,
    skip_wal_replay: bool = false,
};

pub const ScanOptions = struct {
    durability_filter: DurabilityLevel = .memory,
    dirty: bool = false,
    read_ahead_bytes: u64 = 1,
    cache_blocks: bool = false,
    max_fetch_tasks: u64 = 1,
};

pub const WriteOptions = struct {
    await_durable: bool = true,
};

pub const PutOptions = struct {
    ttl: Ttl = .default,
};

pub const MergeOptions = struct {
    ttl: Ttl = .default,
};

pub const FlushOptions = struct {
    flush_type: FlushType = .wal,
};

pub fn encodeReadOptions(options: ReadOptions) rust_call.CallError!rust_buffer.RustBuffer {
    var encoded: [6]u8 = undefined;
    var writer = BufferWriter.init(encoded[0..]);
    writer.writeI32(@intFromEnum(options.durability_filter));
    writer.writeBool(options.dirty);
    writer.writeBool(options.cache_blocks);
    return rust_buffer.RustBuffer.fromBytes(encoded[0..]);
}

pub fn encodeReaderOptions(options: ReaderOptions) rust_call.CallError!rust_buffer.RustBuffer {
    var encoded: [25]u8 = undefined;
    var writer = BufferWriter.init(encoded[0..]);
    writer.writeU64(options.manifest_poll_interval_ms);
    writer.writeU64(options.checkpoint_lifetime_ms);
    writer.writeU64(options.max_memtable_bytes);
    writer.writeBool(options.skip_wal_replay);
    return rust_buffer.RustBuffer.fromBytes(encoded[0..]);
}

pub fn encodeScanOptions(options: ScanOptions) rust_call.CallError!rust_buffer.RustBuffer {
    var encoded: [22]u8 = undefined;
    var writer = BufferWriter.init(encoded[0..]);
    writer.writeI32(@intFromEnum(options.durability_filter));
    writer.writeBool(options.dirty);
    writer.writeU64(options.read_ahead_bytes);
    writer.writeBool(options.cache_blocks);
    writer.writeU64(options.max_fetch_tasks);
    return rust_buffer.RustBuffer.fromBytes(encoded[0..]);
}

pub fn encodeWriteOptions(options: WriteOptions) rust_call.CallError!rust_buffer.RustBuffer {
    var encoded: [1]u8 = undefined;
    var writer = BufferWriter.init(encoded[0..]);
    writer.writeBool(options.await_durable);
    return rust_buffer.RustBuffer.fromBytes(encoded[0..]);
}

pub fn encodePutOptions(options: PutOptions) rust_call.CallError!rust_buffer.RustBuffer {
    return encodeTtl(options.ttl);
}

pub fn encodeMergeOptions(options: MergeOptions) rust_call.CallError!rust_buffer.RustBuffer {
    return encodeTtl(options.ttl);
}

pub fn encodeFlushOptions(options: FlushOptions) rust_call.CallError!rust_buffer.RustBuffer {
    var encoded: [4]u8 = undefined;
    var writer = BufferWriter.init(encoded[0..]);
    writer.writeI32(@intFromEnum(options.flush_type));
    return rust_buffer.RustBuffer.fromBytes(encoded[0..]);
}

fn encodeTtl(ttl: Ttl) rust_call.CallError!rust_buffer.RustBuffer {
    const len: usize = switch (ttl) {
        .default, .no_expiry => 4,
        .expire_after_ticks, .expire_at => 12,
    };

    var encoded: [12]u8 = undefined;
    var writer = BufferWriter.init(encoded[0..len]);
    switch (ttl) {
        .default => writer.writeI32(1),
        .no_expiry => writer.writeI32(2),
        .expire_after_ticks => |ticks| {
            writer.writeI32(3);
            writer.writeU64(ticks);
        },
        .expire_at => |ts| {
            writer.writeI32(4);
            writer.writeI64(ts);
        },
    }

    return rust_buffer.RustBuffer.fromBytes(encoded[0..len]);
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

    fn writeI32(self: *BufferWriter, value: i32) void {
        var encoded: [4]u8 = undefined;
        std.mem.writeInt(i32, &encoded, value, .big);
        @memcpy(self.bytes[self.pos .. self.pos + 4], encoded[0..]);
        self.pos += 4;
    }

    fn writeU64(self: *BufferWriter, value: u64) void {
        var encoded: [8]u8 = undefined;
        std.mem.writeInt(u64, &encoded, value, .big);
        @memcpy(self.bytes[self.pos .. self.pos + 8], encoded[0..]);
        self.pos += 8;
    }

    fn writeI64(self: *BufferWriter, value: i64) void {
        self.writeU64(@bitCast(value));
    }
};
