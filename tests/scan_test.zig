const std = @import("std");
const slatedb = @import("slatedb");
const support = @import("support.zig");

const ExpectedRow = struct {
    key: []const u8,
    value: []const u8,
};

test "Db async scan variants" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

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

    var full_scan_future = test_db.db.scan(io, .{});
    var full_iter = try full_scan_future.await(io);
    defer full_iter.deinit();
    try expectRows(io, &full_iter, &seed);

    var bounded_scan_future = test_db.db.scan(io, .{
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

    var prefix_scan_future = test_db.db.scanPrefix(io, "item:");
    var prefix_iter = try prefix_scan_future.await(io);
    defer prefix_iter.deinit();
    try expectRows(io, &prefix_iter, seed[0..3]);

    var seek_scan_future = test_db.db.scan(io, .{});
    var seek_iter = try seek_scan_future.await(io);
    defer seek_iter.deinit();

    var seek_future = seek_iter.seek(io, "item:03");
    try seek_future.await(io);
    try expectRows(io, &seek_iter, &.{
        .{ .key = "item:03", .value = "third" },
        .{ .key = "other:01", .value = "other" },
    });

    var empty_start_scan = test_db.db.scan(io, .{
        .start = "",
        .start_inclusive = true,
    });
    try std.testing.expectError(error.Invalid, empty_start_scan.await(io));

    var reversed_scan = test_db.db.scan(io, .{
        .start = "item:03",
        .start_inclusive = true,
        .end = "item:01",
        .end_inclusive = true,
    });
    try std.testing.expectError(error.Invalid, reversed_scan.await(io));

    try test_db.shutdownAsync(io);
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
        return error.TestUnexpectedResult;
    }
}
