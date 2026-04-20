const std = @import("std");
const slatedb = @import("slatedb");
const support = @import("support.zig");

const ExpectedRow = struct {
    key: []const u8,
    value: []const u8,
};

const SeededReader = struct {
    store: slatedb.ObjectStore,
    reader_builder: slatedb.DbReaderBuilder,
    reader: slatedb.DbReader,

    fn initAsync(io: std.Io, seed: []const ExpectedRow) !SeededReader {
        var store = try slatedb.ObjectStore.resolve("memory:///");
        errdefer store.deinit();

        {
            var db_builder = try slatedb.DbBuilder.init(support.test_db_path, &store);
            defer db_builder.deinit();

            var build_future = db_builder.build(io);
            var db = try build_future.await(io);
            defer db.deinit();

            for (seed) |row| {
                var put_future = db.put(io, row.key, row.value);
                _ = try put_future.await(io);
            }

            var shutdown_future = db.shutdown(io);
            try shutdown_future.await(io);
        }

        var reader_builder = try slatedb.DbReaderBuilder.init(support.test_db_path, &store);
        errdefer reader_builder.deinit();

        var build_future = reader_builder.build(io);
        var reader = try build_future.await(io);
        errdefer reader.deinit();

        return .{
            .store = store,
            .reader_builder = reader_builder,
            .reader = reader,
        };
    }

    fn deinit(self: *SeededReader) void {
        self.reader.deinit();
        self.reader_builder.deinit();
        self.store.deinit();
    }
};

fn concatMerge(
    context: *anyopaque,
    allocator: std.mem.Allocator,
    key: []const u8,
    existing_value: ?[]const u8,
    operand: []const u8,
) std.mem.Allocator.Error!slatedb.MergeOperatorResult {
    _ = context;
    _ = key;

    const prefix_len = if (existing_value) |value| value.len else 0;
    const merged = try allocator.alloc(u8, prefix_len + operand.len);

    if (existing_value) |value| {
        @memcpy(merged[0..value.len], value);
        @memcpy(merged[value.len..], operand);
    } else {
        @memcpy(merged, operand);
    }

    return .{ .value = merged };
}

test "DbReader build needs an existing database" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    var reader_builder = try slatedb.DbReaderBuilder.init(support.test_db_path, &store);
    defer reader_builder.deinit();

    var build_future = reader_builder.build(io);
    try std.testing.expectError(error.Data, build_future.await(io));
}

test "DbReader async point reads" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var seeded_reader = try SeededReader.initAsync(io, &.{
        .{ .key = "alpha", .value = "one" },
        .{ .key = "empty", .value = "" },
    });
    defer seeded_reader.deinit();

    var alpha_future = seeded_reader.reader.get(io, std.testing.allocator, "alpha");
    const alpha_value = try alpha_future.await(io);
    defer if (alpha_value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(alpha_value != null);
    try std.testing.expectEqualSlices(u8, "one", alpha_value.?);

    var empty_future = seeded_reader.reader.get(io, std.testing.allocator, "empty");
    const empty_value = try empty_future.await(io);
    defer if (empty_value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(empty_value != null);
    try std.testing.expectEqual(@as(usize, 0), empty_value.?.len);

    var missing_future = seeded_reader.reader.get(io, std.testing.allocator, "missing");
    const missing_value = try missing_future.await(io);
    defer if (missing_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(missing_value == null);

    var shutdown_future = seeded_reader.reader.shutdown(io);
    try shutdown_future.await(io);

    var closed_future = seeded_reader.reader.get(io, std.testing.allocator, "alpha");
    try std.testing.expectError(error.Closed, closed_future.await(io));
}

test "DbReader async scan variants" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    const seed = [_]ExpectedRow{
        .{ .key = "item:01", .value = "first" },
        .{ .key = "item:02", .value = "second" },
        .{ .key = "item:03", .value = "third" },
        .{ .key = "other:01", .value = "other" },
    };

    var seeded_reader = try SeededReader.initAsync(io, &seed);
    defer seeded_reader.deinit();

    var full_scan_future = seeded_reader.reader.scan(io, .{});
    var full_iter = try full_scan_future.await(io);
    defer full_iter.deinit();
    try expectRows(io, &full_iter, &seed);

    var bounded_scan_future = seeded_reader.reader.scan(io, .{
        .start = "item:02",
        .start_inclusive = true,
        .end = "item:03",
        .end_inclusive = true,
    });
    var bounded_iter = try bounded_scan_future.await(io);
    defer bounded_iter.deinit();
    try expectRows(io, &bounded_iter, &.{
        .{ .key = "item:02", .value = "second" },
        .{ .key = "item:03", .value = "third" },
    });

    var prefix_scan_future = seeded_reader.reader.scanPrefix(io, "item:");
    var prefix_iter = try prefix_scan_future.await(io);
    defer prefix_iter.deinit();
    try expectRows(io, &prefix_iter, seed[0..3]);

    var shutdown_future = seeded_reader.reader.shutdown(io);
    try shutdown_future.await(io);
}

test "DbReader merge operator reads merge rows" {
    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    var db_builder = try slatedb.DbBuilder.init(support.test_db_path, &store);
    defer db_builder.deinit();

    var merge_context: u8 = 0;
    const merge_operator = slatedb.MergeOperator{
        .context = @ptrCast(&merge_context),
        .merge_fn = concatMerge,
    };
    try db_builder.withMergeOperator(&merge_operator);

    var db = try db_builder.buildBlocking();
    defer db.deinit();

    _ = try db.putBlocking("merge", "base");
    _ = try db.mergeBlocking("merge", ":reader");
    try db.flushWithOptionsBlocking(.{ .flush_type = .mem_table });

    var reader_builder = try slatedb.DbReaderBuilder.init(support.test_db_path, &store);
    defer reader_builder.deinit();
    try reader_builder.withMergeOperator(&merge_operator);

    var reader = try reader_builder.buildBlocking();
    defer reader.deinit();

    const value = try reader.getBlocking(std.testing.allocator, "merge");
    defer if (value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(value != null);
    try std.testing.expectEqualSlices(u8, "base:reader", value.?);

    try reader.shutdownBlocking();
    try db.shutdownBlocking();
}

fn expectRows(
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
        try std.testing.expect(false);
    }
}
