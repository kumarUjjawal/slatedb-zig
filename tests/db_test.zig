const std = @import("std");
const slatedb = @import("slatedb");
const support = @import("support.zig");

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

test "Db missing key read" {
    var test_db = try support.TestDb.init();
    defer test_db.deinit();

    const value = try test_db.db.getBlocking(std.testing.allocator, "missing");
    defer if (value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(value == null);
    try test_db.shutdown();
}

test "Db status after build" {
    var test_db = try support.TestDb.init();
    defer test_db.deinit();

    try test_db.db.status();
}

test "Db lifecycle and basic CRUD" {
    var test_db = try support.TestDb.init();
    defer test_db.deinit();

    try test_db.db.status();

    const write_handle = try test_db.db.putBlocking("hello", "world");
    try std.testing.expect(write_handle.seqnum > 0);
    try std.testing.expect(write_handle.create_ts > 0);

    const value = try test_db.db.getBlocking(std.testing.allocator, "hello");
    defer if (value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(value != null);
    try std.testing.expectEqualSlices(u8, "world", value.?);

    try test_db.shutdown();
    try std.testing.expectError(error.Closed, test_db.db.status());
    try std.testing.expectError(error.Closed, test_db.db.putBlocking("after-shutdown", "value"));
}

test "Db delete removes a value" {
    var test_db = try support.TestDb.init();
    defer test_db.deinit();

    _ = try test_db.db.putBlocking("delete-me", "value");

    const delete_handle = try test_db.db.deleteBlocking("delete-me");
    try std.testing.expect(delete_handle.seqnum > 0);
    try std.testing.expect(delete_handle.create_ts > 0);

    const value = try test_db.db.getBlocking(std.testing.allocator, "delete-me");
    defer if (value) |bytes| std.testing.allocator.free(bytes);

    try std.testing.expect(value == null);
    try test_db.shutdown();
}

test "Db merge uses the configured merge operator" {
    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    var builder = try slatedb.DbBuilder.init(support.test_db_path, &store);
    defer builder.deinit();

    var merge_context: u8 = 0;
    const merge_operator = slatedb.MergeOperator{
        .context = @ptrCast(&merge_context),
        .merge_fn = concatMerge,
    };
    try builder.withMergeOperator(&merge_operator);

    var db = try builder.buildBlocking();
    defer db.deinit();

    _ = try db.putBlocking("merge", "base");
    _ = try db.mergeBlocking("merge", ":one");

    const first_value = try db.getBlocking(std.testing.allocator, "merge");
    defer if (first_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(first_value != null);
    try std.testing.expectEqualSlices(u8, "base:one", first_value.?);

    _ = try db.mergeWithOptionsBlocking(
        "merge",
        ":two",
        .{ .ttl = .default },
        .{ .await_durable = true },
    );

    const second_value = try db.getBlocking(std.testing.allocator, "merge");
    defer if (second_value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(second_value != null);
    try std.testing.expectEqualSlices(u8, "base:one:two", second_value.?);

    try db.shutdownBlocking();
}
