const std = @import("std");
const slatedb = @import("slatedb");

const SpinLock = struct {
    state: std.atomic.Value(u8) = .init(0),

    fn lock(self: *SpinLock) void {
        while (true) {
            if (self.state.cmpxchgWeak(0, 1, .acquire, .monotonic) == null) {
                return;
            }

            while (self.state.load(.monotonic) != 0) {
                std.atomic.spinLoopHint();
            }
        }
    }

    fn unlock(self: *SpinLock) void {
        const previous = self.state.swap(0, .release);
        std.debug.assert(previous != 0);
    }
};

const CollectedRecord = struct {
    level: slatedb.LogLevel,
    target: []u8,
    message: []u8,
    module_path: ?[]u8,
    file: ?[]u8,
    line: ?u32,

    fn cloneFrom(record: *const slatedb.LogRecord, allocator: std.mem.Allocator) !CollectedRecord {
        return .{
            .level = record.level,
            .target = try allocator.dupe(u8, record.target),
            .message = try allocator.dupe(u8, record.message),
            .module_path = if (record.module_path) |module_path|
                try allocator.dupe(u8, module_path)
            else
                null,
            .file = if (record.file) |file|
                try allocator.dupe(u8, file)
            else
                null,
            .line = record.line,
        };
    }

    fn clone(self: *const CollectedRecord, allocator: std.mem.Allocator) !CollectedRecord {
        return .{
            .level = self.level,
            .target = try allocator.dupe(u8, self.target),
            .message = try allocator.dupe(u8, self.message),
            .module_path = if (self.module_path) |module_path|
                try allocator.dupe(u8, module_path)
            else
                null,
            .file = if (self.file) |file|
                try allocator.dupe(u8, file)
            else
                null,
            .line = self.line,
        };
    }

    fn deinit(self: *CollectedRecord, allocator: std.mem.Allocator) void {
        allocator.free(self.target);
        allocator.free(self.message);
        if (self.module_path) |module_path| {
            allocator.free(module_path);
        }
        if (self.file) |file| {
            allocator.free(file);
        }
        self.* = undefined;
    }
};

const LogCollector = struct {
    mutex: SpinLock = .{},
    records: std.ArrayListUnmanaged(CollectedRecord) = .empty,

    fn onLog(context: *anyopaque, record: *const slatedb.LogRecord) void {
        const self: *LogCollector = @ptrCast(@alignCast(context));
        self.append(record) catch |append_err| {
            std.log.err("failed to store SlateDB log record: {s}", .{@errorName(append_err)});
        };
    }

    fn append(self: *LogCollector, record: *const slatedb.LogRecord) !void {
        var copy = try CollectedRecord.cloneFrom(record, std.heap.smp_allocator);
        errdefer copy.deinit(std.heap.smp_allocator);

        self.mutex.lock();
        defer self.mutex.unlock();
        try self.records.append(std.heap.smp_allocator, copy);
    }

    fn hasOpenRecord(self: *LogCollector, path: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.records.items) |record| {
            if (record.level != .info) {
                continue;
            }
            if (!std.mem.containsAtLeast(u8, record.message, 1, "opening SlateDB database")) {
                continue;
            }
            if (!std.mem.containsAtLeast(u8, record.message, 1, path)) {
                continue;
            }
            return true;
        }

        return false;
    }

    fn cloneOpenRecord(
        self: *LogCollector,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !?CollectedRecord {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.records.items) |record| {
            if (record.level != .info) {
                continue;
            }
            if (!std.mem.containsAtLeast(u8, record.message, 1, "opening SlateDB database")) {
                continue;
            }
            if (!std.mem.containsAtLeast(u8, record.message, 1, path)) {
                continue;
            }
            return try record.clone(allocator);
        }

        return null;
    }

    fn deinit(self: *LogCollector) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.records.items) |*record| {
            record.deinit(std.heap.smp_allocator);
        }
        self.records.deinit(std.heap.smp_allocator);
        self.records = .empty;
    }
};

test "initLogging forwards callback records" {
    const path = "test-db-logging";

    var collector = LogCollector{};
    defer collector.deinit();

    const callback = slatedb.LogCallback{
        .context = @ptrCast(&collector),
        .log_fn = LogCollector.onLog,
    };

    try slatedb.initLogging(.info, &callback);

    try std.testing.expectError(error.Invalid, slatedb.initLogging(.info, &callback));
    var detail = (try slatedb.takeLastCallErrorDetail(std.testing.allocator)).?;
    defer detail.deinit(std.testing.allocator);

    switch (detail) {
        .invalid => |message| try std.testing.expectEqualStrings(
            "logging already initialized",
            message,
        ),
        else => return error.TestUnexpectedResult,
    }

    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    var builder = try slatedb.DbBuilder.init(path, &store);
    defer builder.deinit();

    var db = try builder.buildBlocking();
    defer db.deinit();

    var saw_open_record = false;
    var delay: std.posix.timespec = .{
        .sec = 0,
        .nsec = 10 * std.time.ns_per_ms,
    };
    for (0..500) |_| {
        if (collector.hasOpenRecord(path)) {
            saw_open_record = true;
            break;
        }
        _ = std.posix.system.nanosleep(&delay, null);
    }
    try std.testing.expect(saw_open_record);

    const open_record = try collector.cloneOpenRecord(std.testing.allocator, path);
    try std.testing.expect(open_record != null);
    var open = open_record.?;
    defer open.deinit(std.testing.allocator);

    try std.testing.expect(open.target.len > 0);
    try std.testing.expect(open.module_path != null);
    try std.testing.expect(open.module_path.?.len > 0);
    try std.testing.expect(open.file != null);
    try std.testing.expect(open.file.?.len > 0);
    try std.testing.expect(open.line != null);
    try std.testing.expect(open.line.? > 0);

    try db.shutdownBlocking();
}
