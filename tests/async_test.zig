const std = @import("std");
const slatedb = @import("slatedb");
const support = @import("support.zig");

test "Db async lifecycle and CRUD" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    try test_db.db.status();

    var put_future = test_db.db.put(io, "hello", "world");
    const write_handle = try put_future.await(io);
    try std.testing.expect(write_handle.seqnum > 0);
    try std.testing.expect(write_handle.create_ts > 0);

    var get_future = test_db.db.get(io, std.testing.allocator, "hello");
    const value = try get_future.await(io);
    defer if (value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(value != null);
    try std.testing.expectEqualSlices(u8, "world", value.?);

    var delete_future = test_db.db.delete(io, "hello");
    const delete_handle = try delete_future.await(io);
    try std.testing.expect(delete_handle.seqnum >= write_handle.seqnum);

    var deleted_get_future = test_db.db.get(io, std.testing.allocator, "hello");
    const deleted_value = try deleted_get_future.await(io);
    defer if (deleted_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(deleted_value == null);

    try test_db.shutdownAsync(io);
    var closed_put_future = test_db.db.put(io, "after-shutdown", "value");
    try std.testing.expectError(error.Closed, closed_put_future.await(io));
}

test "Db async missing key and empty value" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    var put_future = test_db.db.put(io, "empty", "");
    _ = try put_future.await(io);

    var empty_get_future = test_db.db.get(io, std.testing.allocator, "empty");
    const empty_value = try empty_get_future.await(io);
    defer if (empty_value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(empty_value != null);
    try std.testing.expectEqual(@as(usize, 0), empty_value.?.len);

    var missing_get_future = test_db.db.get(io, std.testing.allocator, "missing");
    const missing_value = try missing_get_future.await(io);
    defer if (missing_value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(missing_value == null);
    try test_db.shutdownAsync(io);
}

test "Db async rejects empty keys" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    var invalid_put_future = test_db.db.put(io, "", "value");
    try std.testing.expectError(error.Invalid, invalid_put_future.await(io));

    var invalid_delete_future = test_db.db.delete(io, "");
    try std.testing.expectError(error.Invalid, invalid_delete_future.await(io));
    try test_db.shutdownAsync(io);
}

test "Db async write batch" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    var seed_put_future = test_db.db.put(io, "remove-me", "old");
    _ = try seed_put_future.await(io);

    var batch = try slatedb.WriteBatch.init();
    defer batch.deinit();

    try batch.put("batch-put", "value");
    try batch.delete("remove-me");

    var write_future = test_db.db.write(io, &batch);
    const batch_handle = try write_future.await(io);
    try std.testing.expect(batch_handle.seqnum > 0);

    var batch_get_future = test_db.db.get(io, std.testing.allocator, "batch-put");
    const batch_value = try batch_get_future.await(io);
    defer if (batch_value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(batch_value != null);
    try std.testing.expectEqualSlices(u8, "value", batch_value.?);

    var removed_get_future = test_db.db.get(io, std.testing.allocator, "remove-me");
    const removed_value = try removed_get_future.await(io);
    defer if (removed_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(removed_value == null);

    var second_write_future = test_db.db.write(io, &batch);
    try std.testing.expectError(error.Invalid, second_write_future.await(io));

    try test_db.shutdownAsync(io);
}

test "Db async snapshot read stays stable" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    var old_put_future = test_db.db.put(io, "snapshot", "old");
    _ = try old_put_future.await(io);

    var snapshot_future = test_db.db.snapshot(io);
    var snapshot = try snapshot_future.await(io);
    defer snapshot.deinit();

    var new_put_future = test_db.db.put(io, "snapshot", "new");
    _ = try new_put_future.await(io);

    var snapshot_get_future = snapshot.get(io, std.testing.allocator, "snapshot");
    const snapshot_value = try snapshot_get_future.await(io);
    defer if (snapshot_value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(snapshot_value != null);
    try std.testing.expectEqualSlices(u8, "old", snapshot_value.?);

    var live_get_future = test_db.db.get(io, std.testing.allocator, "snapshot");
    const live_value = try live_get_future.await(io);
    defer if (live_value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(live_value != null);
    try std.testing.expectEqualSlices(u8, "new", live_value.?);

    try test_db.shutdownAsync(io);
}

test "Db async snapshot option and scan methods" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    const seed = [_]support.ExpectedRow{
        .{ .key = "item:01", .value = "first" },
        .{ .key = "item:02", .value = "second" },
        .{ .key = "other:01", .value = "other" },
    };
    const read_options = slatedb.ReadOptions{
        .durability_filter = .memory,
        .dirty = false,
        .cache_blocks = true,
    };
    const scan_options = slatedb.ScanOptions{
        .durability_filter = .memory,
        .dirty = false,
        .read_ahead_bytes = 64,
        .cache_blocks = true,
        .max_fetch_tasks = 2,
    };

    for (seed) |row| {
        var put_future = test_db.db.put(io, row.key, row.value);
        _ = try put_future.await(io);
    }

    var snapshot_future = test_db.db.snapshot(io);
    var snapshot = try snapshot_future.await(io);
    defer snapshot.deinit();

    var update_future = test_db.db.put(io, "item:02", "updated");
    _ = try update_future.await(io);

    var add_future = test_db.db.put(io, "item:03", "third");
    _ = try add_future.await(io);

    var value_future = snapshot.getWithOptions(
        io,
        std.testing.allocator,
        "item:02",
        read_options,
    );
    const value = try value_future.await(io);
    defer if (value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(value != null);
    try std.testing.expectEqualSlices(u8, "second", value.?);

    var metadata_future = snapshot.getKeyValue(io, std.testing.allocator, "item:02");
    const metadata = try metadata_future.await(io);
    try std.testing.expect(metadata != null);
    var metadata_value = metadata.?;
    defer metadata_value.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "item:02", metadata_value.key);
    try std.testing.expectEqualSlices(u8, "second", metadata_value.value);

    var metadata_with_options_future = snapshot.getKeyValueWithOptions(
        io,
        std.testing.allocator,
        "item:02",
        read_options,
    );
    const metadata_with_options = try metadata_with_options_future.await(io);
    try std.testing.expect(metadata_with_options != null);
    var metadata_with_options_value = metadata_with_options.?;
    defer metadata_with_options_value.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "item:02", metadata_with_options_value.key);
    try std.testing.expectEqualSlices(u8, "second", metadata_with_options_value.value);

    var live_get_future = test_db.db.get(io, std.testing.allocator, "item:02");
    const live_value = try live_get_future.await(io);
    defer if (live_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(live_value != null);
    try std.testing.expectEqualSlices(u8, "updated", live_value.?);

    var full_scan_future = snapshot.scan(io, .{});
    var full_iter = try full_scan_future.await(io);
    defer full_iter.deinit();
    try support.expectRows(io, &full_iter, &seed);

    var prefix_scan_future = snapshot.scanPrefix(io, "item:");
    var prefix_iter = try prefix_scan_future.await(io);
    defer prefix_iter.deinit();
    try support.expectRows(io, &prefix_iter, seed[0..2]);

    var range_scan_future = snapshot.scanWithOptions(io, .{
        .start = "item:01",
        .start_inclusive = true,
        .end = "item:99",
        .end_inclusive = false,
    }, scan_options);
    var range_iter = try range_scan_future.await(io);
    defer range_iter.deinit();
    try support.expectRows(io, &range_iter, seed[0..2]);

    var prefix_scan_with_options_future = snapshot.scanPrefixWithOptions(io, "item:", scan_options);
    var prefix_with_options_iter = try prefix_scan_with_options_future.await(io);
    defer prefix_with_options_iter.deinit();
    try support.expectRows(io, &prefix_with_options_iter, seed[0..2]);

    try test_db.shutdownAsync(io);
}
