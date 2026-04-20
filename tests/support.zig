const std = @import("std");
const slatedb = @import("slatedb");

pub const test_db_path = "test-db";

pub const AsyncRuntime = struct {
    threaded: std.Io.Threaded,

    pub fn init() AsyncRuntime {
        return .{
            .threaded = std.Io.Threaded.init(std.heap.smp_allocator, .{}),
        };
    }

    pub fn io(self: *AsyncRuntime) std.Io {
        return self.threaded.io();
    }

    pub fn deinit(self: *AsyncRuntime) void {
        self.threaded.deinit();
    }
};

pub const ExpectedRow = struct {
    key: []const u8,
    value: []const u8,
};

pub const TestDb = struct {
    store: slatedb.ObjectStore,
    builder: slatedb.DbBuilder,
    db: slatedb.Db,

    pub fn init() !TestDb {
        var store = try slatedb.ObjectStore.resolve("memory:///");
        errdefer store.deinit();

        var builder = try slatedb.DbBuilder.init(test_db_path, &store);
        errdefer builder.deinit();

        var db = try builder.buildBlocking();
        errdefer db.deinit();

        return .{
            .store = store,
            .builder = builder,
            .db = db,
        };
    }

    pub fn initAsync(io: std.Io) !TestDb {
        var store = try slatedb.ObjectStore.resolve("memory:///");
        errdefer store.deinit();

        var builder = try slatedb.DbBuilder.init(test_db_path, &store);
        errdefer builder.deinit();

        var build_future = builder.build(io);
        var db = try build_future.await(io);
        errdefer db.deinit();

        return .{
            .store = store,
            .builder = builder,
            .db = db,
        };
    }

    pub fn shutdown(self: *TestDb) !void {
        try self.db.shutdownBlocking();
    }

    pub fn shutdownAsync(self: *TestDb, io: std.Io) !void {
        var shutdown_future = self.db.shutdown(io);
        try shutdown_future.await(io);
    }

    pub fn deinit(self: *TestDb) void {
        self.db.deinit();
        self.builder.deinit();
        self.store.deinit();
    }
};

pub fn expectRows(
    io: std.Io,
    iter: *slatedb.DbIterator,
    expected: []const ExpectedRow,
) !void {
    for (expected) |want| {
        var next_future = iter.next(io, std.testing.allocator);
        const maybe_row = try next_future.await(io);
        try std.testing.expect(maybe_row != null);

        var row = maybe_row.?;
        defer row.deinit(std.testing.allocator);

        try std.testing.expectEqualSlices(u8, want.key, row.key);
        try std.testing.expectEqualSlices(u8, want.value, row.value);
    }

    var end_future = iter.next(io, std.testing.allocator);
    const end_row = try end_future.await(io);
    if (end_row) |row_value| {
        var row = row_value;
        defer row.deinit(std.testing.allocator);
        return error.TestUnexpectedResult;
    }
}
