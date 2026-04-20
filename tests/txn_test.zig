const std = @import("std");
const slatedb = @import("slatedb");
const support = @import("support.zig");

test "Db async transactions commit and rollback" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    var begin_future = test_db.db.begin(io, .snapshot);
    var tx = try begin_future.await(io);
    defer tx.deinit();

    const tx_seqnum = try tx.seqnum();

    const tx_id = try tx.id(std.testing.allocator);
    defer std.testing.allocator.free(tx_id);
    try std.testing.expect(tx_id.len > 0);

    var tx_put_future = tx.put(io, "txn-key", "pending");
    try tx_put_future.await(io);

    var tx_get_future = tx.get(io, std.testing.allocator, "txn-key");
    const tx_value = try tx_get_future.await(io);
    defer if (tx_value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(tx_value != null);
    try std.testing.expectEqualSlices(u8, "pending", tx_value.?);

    var live_before_future = test_db.db.get(io, std.testing.allocator, "txn-key");
    const live_before_value = try live_before_future.await(io);
    defer if (live_before_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(live_before_value == null);

    var commit_future = tx.commit(io);
    const commit_handle = try commit_future.await(io);
    try std.testing.expect(commit_handle != null);
    try std.testing.expect(commit_handle.?.seqnum > 0);
    try std.testing.expect(commit_handle.?.seqnum >= tx_seqnum);

    var live_after_future = test_db.db.get(io, std.testing.allocator, "txn-key");
    const live_after_value = try live_after_future.await(io);
    defer if (live_after_value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(live_after_value != null);
    try std.testing.expectEqualSlices(u8, "pending", live_after_value.?);

    var begin_rollback_future = test_db.db.begin(io, slatedb.IsolationLevel.snapshot);
    var rollback_tx = try begin_rollback_future.await(io);
    defer rollback_tx.deinit();

    var rollback_put_future = rollback_tx.put(io, "rolled-back", "value");
    try rollback_put_future.await(io);

    var rollback_future = rollback_tx.rollback(io);
    try rollback_future.await(io);

    var rolled_back_get_future = test_db.db.get(io, std.testing.allocator, "rolled-back");
    const rolled_back_value = try rolled_back_get_future.await(io);
    defer if (rolled_back_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(rolled_back_value == null);

    try test_db.shutdownAsync(io);
}

test "Db async transaction option and scan methods" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    const put_options = slatedb.PutOptions{
        .ttl = .default,
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
    const write_options = slatedb.WriteOptions{
        .await_durable = true,
    };
    const expected_rows = [_]support.ExpectedRow{
        .{ .key = "txn:01", .value = "first" },
        .{ .key = "txn:02", .value = "second" },
        .{ .key = "txn:03", .value = "third" },
    };

    var live_seed_future = test_db.db.put(io, "live:01", "outside");
    _ = try live_seed_future.await(io);

    var begin_future = test_db.db.begin(io, .snapshot);
    var tx = try begin_future.await(io);
    defer tx.deinit();

    var first_put_future = tx.putWithOptions(io, "txn:01", "first", put_options);
    try first_put_future.await(io);

    var second_put_future = tx.putWithOptions(io, "txn:02", "second", put_options);
    try second_put_future.await(io);

    var third_put_future = tx.put(io, "txn:03", "third");
    try third_put_future.await(io);

    var live_read_future = tx.getWithOptions(io, std.testing.allocator, "live:01", read_options);
    const live_read = try live_read_future.await(io);
    defer if (live_read) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(live_read != null);
    try std.testing.expectEqualSlices(u8, "outside", live_read.?);

    var tx_read_future = tx.getWithOptions(io, std.testing.allocator, "txn:02", read_options);
    const tx_read = try tx_read_future.await(io);
    defer if (tx_read) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(tx_read != null);
    try std.testing.expectEqualSlices(u8, "second", tx_read.?);

    var metadata_future = tx.getKeyValue(io, std.testing.allocator, "txn:02");
    const metadata = try metadata_future.await(io);
    try std.testing.expect(metadata != null);
    var metadata_value = metadata.?;
    defer metadata_value.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "txn:02", metadata_value.key);
    try std.testing.expectEqualSlices(u8, "second", metadata_value.value);

    var metadata_with_options_future = tx.getKeyValueWithOptions(
        io,
        std.testing.allocator,
        "txn:03",
        read_options,
    );
    const metadata_with_options = try metadata_with_options_future.await(io);
    try std.testing.expect(metadata_with_options != null);
    var metadata_with_options_value = metadata_with_options.?;
    defer metadata_with_options_value.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "txn:03", metadata_with_options_value.key);
    try std.testing.expectEqualSlices(u8, "third", metadata_with_options_value.value);

    var live_before_commit_future = test_db.db.get(io, std.testing.allocator, "txn:01");
    const live_before_commit = try live_before_commit_future.await(io);
    defer if (live_before_commit) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(live_before_commit == null);

    var range_scan_future = tx.scan(io, .{
        .start = "txn:01",
        .start_inclusive = true,
        .end = "txn:99",
        .end_inclusive = false,
    });
    var range_iter = try range_scan_future.await(io);
    defer range_iter.deinit();
    try support.expectRows(io, &range_iter, &expected_rows);

    var prefix_scan_future = tx.scanPrefix(io, "txn:");
    var prefix_iter = try prefix_scan_future.await(io);
    defer prefix_iter.deinit();
    try support.expectRows(io, &prefix_iter, &expected_rows);

    var range_scan_with_options_future = tx.scanWithOptions(io, .{
        .start = "txn:01",
        .start_inclusive = true,
        .end = "txn:99",
        .end_inclusive = false,
    }, scan_options);
    var range_with_options_iter = try range_scan_with_options_future.await(io);
    defer range_with_options_iter.deinit();
    try support.expectRows(io, &range_with_options_iter, &expected_rows);

    var prefix_scan_with_options_future = tx.scanPrefixWithOptions(io, "txn:", scan_options);
    var prefix_with_options_iter = try prefix_scan_with_options_future.await(io);
    defer prefix_with_options_iter.deinit();
    try support.expectRows(io, &prefix_with_options_iter, &expected_rows);

    var commit_future = tx.commitWithOptions(io, write_options);
    const commit_handle = try commit_future.await(io);
    try std.testing.expect(commit_handle != null);
    try std.testing.expect(commit_handle.?.seqnum > 0);

    var live_after_commit_future = test_db.db.get(io, std.testing.allocator, "txn:03");
    const live_after_commit = try live_after_commit_future.await(io);
    defer if (live_after_commit) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(live_after_commit != null);
    try std.testing.expectEqualSlices(u8, "third", live_after_commit.?);

    try test_db.shutdownAsync(io);
}
