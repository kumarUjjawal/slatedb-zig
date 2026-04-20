const std = @import("std");
const slatedb = @import("slatedb");
const support = @import("support.zig");

const ExpectedRow = struct {
    key: []const u8,
    value: []const u8,
};

test "Db async read and write option methods" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    const read_options = slatedb.ReadOptions{
        .durability_filter = .memory,
        .dirty = false,
        .cache_blocks = true,
    };
    const put_options = slatedb.PutOptions{
        .ttl = .default,
    };
    const write_options = slatedb.WriteOptions{
        .await_durable = true,
    };

    var first_put_future = test_db.db.put(io, "alpha", "one");
    const first_write = try first_put_future.await(io);
    try std.testing.expect(first_write.seqnum > 0);
    try std.testing.expect(first_write.create_ts > 0);

    var get_with_options_future = test_db.db.getWithOptions(
        io,
        std.testing.allocator,
        "alpha",
        read_options,
    );
    const value = try get_with_options_future.await(io);
    defer if (value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(value != null);
    try std.testing.expectEqualSlices(u8, "one", value.?);

    var metadata_future = test_db.db.getKeyValue(io, std.testing.allocator, "alpha");
    const metadata = try metadata_future.await(io);
    try std.testing.expect(metadata != null);
    var metadata_value = metadata.?;
    defer metadata_value.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u8, "alpha", metadata_value.key);
    try std.testing.expectEqualSlices(u8, "one", metadata_value.value);
    try std.testing.expectEqual(first_write.seqnum, metadata_value.seq);
    try std.testing.expectEqual(first_write.create_ts, metadata_value.create_ts);

    var metadata_with_options_future = test_db.db.getKeyValueWithOptions(
        io,
        std.testing.allocator,
        "alpha",
        read_options,
    );
    const metadata_with_options = try metadata_with_options_future.await(io);
    try std.testing.expect(metadata_with_options != null);
    var metadata_with_options_value = metadata_with_options.?;
    defer metadata_with_options_value.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "one", metadata_with_options_value.value);

    var second_put_future = test_db.db.putWithOptions(
        io,
        "beta",
        "two",
        put_options,
        write_options,
    );
    const second_write = try second_put_future.await(io);
    try std.testing.expect(second_write.seqnum > first_write.seqnum);
    try std.testing.expect(second_write.create_ts > 0);

    var delete_future = test_db.db.deleteWithOptions(io, "beta", write_options);
    const delete_write = try delete_future.await(io);
    try std.testing.expect(delete_write.seqnum > second_write.seqnum);

    var deleted_get_future = test_db.db.get(io, std.testing.allocator, "beta");
    const deleted_value = try deleted_get_future.await(io);
    defer if (deleted_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(deleted_value == null);

    try test_db.shutdownAsync(io);
}

test "Db async scan, batch, and flush option methods" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    const put_options = slatedb.PutOptions{
        .ttl = .default,
    };
    const write_options = slatedb.WriteOptions{
        .await_durable = true,
    };
    const scan_options = slatedb.ScanOptions{
        .durability_filter = .memory,
        .dirty = false,
        .read_ahead_bytes = 64,
        .cache_blocks = true,
        .max_fetch_tasks = 2,
    };

    const seed = [_]ExpectedRow{
        .{ .key = "item:01", .value = "first" },
        .{ .key = "item:02", .value = "second" },
        .{ .key = "item:03", .value = "third" },
        .{ .key = "other:01", .value = "other" },
    };

    for (seed) |row| {
        var put_future = test_db.db.put(io, row.key, row.value);
        _ = try put_future.await(io);
    }

    var range_scan_future = test_db.db.scanWithOptions(io, .{
        .start = "item:01",
        .start_inclusive = true,
        .end = "item:99",
        .end_inclusive = false,
    }, scan_options);
    var range_iter = try range_scan_future.await(io);
    defer range_iter.deinit();
    try expectRows(io, &range_iter, seed[0..3]);

    var prefix_scan_future = test_db.db.scanPrefixWithOptions(io, "item:", scan_options);
    var prefix_iter = try prefix_scan_future.await(io);
    defer prefix_iter.deinit();
    try expectRows(io, &prefix_iter, seed[0..3]);

    var batch = try slatedb.WriteBatch.init();
    defer batch.deinit();

    try batch.putWithOptions("batch-put", "value", put_options);

    var write_future = test_db.db.writeWithOptions(io, &batch, write_options);
    const batch_write = try write_future.await(io);
    try std.testing.expect(batch_write.seqnum > 0);

    var batch_get_future = test_db.db.get(io, std.testing.allocator, "batch-put");
    const batch_value = try batch_get_future.await(io);
    defer if (batch_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(batch_value != null);
    try std.testing.expectEqualSlices(u8, "value", batch_value.?);

    var flush_future = test_db.db.flush(io);
    try flush_future.await(io);

    var flush_wal_future = test_db.db.flushWithOptions(io, .{
        .flush_type = .wal,
    });
    try flush_wal_future.await(io);

    var flush_memtable_future = test_db.db.flushWithOptions(io, .{
        .flush_type = .mem_table,
    });
    try flush_memtable_future.await(io);

    try test_db.shutdownAsync(io);
}

test "DbReader async option methods" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    var db_builder = try slatedb.DbBuilder.init(support.test_db_path, &store);
    defer db_builder.deinit();

    var db_build_future = db_builder.build(io);
    var db = try db_build_future.await(io);
    defer db.deinit();

    const seed = [_]ExpectedRow{
        .{ .key = "alpha", .value = "one" },
        .{ .key = "item:01", .value = "first" },
        .{ .key = "item:02", .value = "second" },
        .{ .key = "item:03", .value = "third" },
        .{ .key = "other:01", .value = "other" },
    };

    for (seed) |row| {
        var put_future = db.put(io, row.key, row.value);
        _ = try put_future.await(io);
    }

    var flush_future = db.flushWithOptions(io, .{
        .flush_type = .mem_table,
    });
    try flush_future.await(io);

    var reader_builder = try slatedb.DbReaderBuilder.init(support.test_db_path, &store);
    defer reader_builder.deinit();

    try reader_builder.withOptions(.{
        .manifest_poll_interval_ms = 100,
        .checkpoint_lifetime_ms = 1_000,
        .max_memtable_bytes = 1024 * 1024,
        .skip_wal_replay = false,
    });

    var reader_build_future = reader_builder.build(io);
    var reader = try reader_build_future.await(io);
    defer reader.deinit();

    const read_options = slatedb.ReadOptions{
        .durability_filter = .memory,
        .dirty = false,
        .cache_blocks = true,
    };
    const scan_options = slatedb.ScanOptions{
        .durability_filter = .memory,
        .dirty = false,
        .read_ahead_bytes = 32,
        .cache_blocks = false,
        .max_fetch_tasks = 1,
    };

    var alpha_future = reader.getWithOptions(io, std.testing.allocator, "alpha", read_options);
    const alpha_value = try alpha_future.await(io);
    defer if (alpha_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(alpha_value != null);
    try std.testing.expectEqualSlices(u8, "one", alpha_value.?);

    var range_scan_future = reader.scanWithOptions(io, .{
        .start = "item:01",
        .start_inclusive = true,
        .end = "item:99",
        .end_inclusive = false,
    }, scan_options);
    var range_iter = try range_scan_future.await(io);
    defer range_iter.deinit();
    try expectRows(io, &range_iter, seed[1..4]);

    var prefix_scan_future = reader.scanPrefixWithOptions(io, "item:", scan_options);
    var prefix_iter = try prefix_scan_future.await(io);
    defer prefix_iter.deinit();
    try expectRows(io, &prefix_iter, seed[1..4]);

    var reader_shutdown_future = reader.shutdown(io);
    try reader_shutdown_future.await(io);

    var db_shutdown_future = db.shutdown(io);
    try db_shutdown_future.await(io);
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
