const std = @import("std");
const slatedb = @import("slatedb");
const support = @import("support.zig");

test "Db invalid error detail includes message" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var test_db = try support.TestDb.initAsync(io);
    defer test_db.deinit();

    var invalid_put_future = test_db.db.put(io, "", "value");
    try std.testing.expectError(error.Invalid, invalid_put_future.await(io));

    var detail = try expectCallErrorDetail();
    defer detail.deinit(std.testing.allocator);

    switch (detail) {
        .invalid => |message| {
            try std.testing.expectEqualSlices(u8, "key cannot be empty", message);
        },
        else => return error.TestUnexpectedResult,
    }

    const next_detail = try slatedb.takeLastCallErrorDetail(std.testing.allocator);
    try std.testing.expect(next_detail == null);

    try test_db.shutdownAsync(io);
}

test "Db closed error detail includes close reason" {
    var runtime = support.AsyncRuntime.init();
    defer runtime.deinit();
    const io = runtime.io();

    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    var primary_builder = try slatedb.DbBuilder.init(support.test_db_path, &store);
    defer primary_builder.deinit();

    var primary_build_future = primary_builder.build(io);
    var primary = try primary_build_future.await(io);
    defer primary.deinit();

    var primary_put_future = primary.put(io, "primary", "value");
    _ = try primary_put_future.await(io);

    var secondary_builder = try slatedb.DbBuilder.init(support.test_db_path, &store);
    defer secondary_builder.deinit();

    var secondary_build_future = secondary_builder.build(io);
    var secondary = try secondary_build_future.await(io);
    defer secondary.deinit();

    var secondary_put_future = secondary.put(io, "secondary", "value");
    _ = try secondary_put_future.await(io);

    var stale_put_future = primary.put(io, "stale", "value");
    try std.testing.expectError(error.Closed, stale_put_future.await(io));

    var detail = try expectCallErrorDetail();
    defer detail.deinit(std.testing.allocator);

    switch (detail) {
        .closed => |closed| {
            try std.testing.expectEqual(slatedb.CloseReason.fenced, closed.reason);
            try std.testing.expect(closed.message.len > 0);
        },
        else => return error.TestUnexpectedResult,
    }

    var shutdown_future = secondary.shutdown(io);
    try shutdown_future.await(io);
}

fn expectCallErrorDetail() !slatedb.CallErrorDetail {
    const detail = try slatedb.takeLastCallErrorDetail(std.testing.allocator);
    if (detail) |value| {
        return value;
    }
    return error.TestUnexpectedResult;
}
