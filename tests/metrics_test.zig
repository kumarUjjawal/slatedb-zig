const std = @import("std");
const support = @import("support.zig");

const write_ops_metric_name = "db/write_ops";

test "Db.metrics tracks write operations" {
    var test_db = try support.TestDb.init();
    defer test_db.deinit();

    var before = try test_db.db.metrics(std.testing.allocator);
    defer before.deinit(std.testing.allocator);

    _ = try test_db.db.putBlocking("metrics-k1", "value-1");
    _ = try test_db.db.putBlocking("metrics-k2", "value-2");

    var after = try test_db.db.metrics(std.testing.allocator);
    defer after.deinit(std.testing.allocator);

    const before_value = before.get(write_ops_metric_name) orelse 0;
    const after_value = after.get(write_ops_metric_name);
    try std.testing.expect(after_value != null);
    try std.testing.expectEqual(before_value + 2, after_value.?);

    try test_db.shutdown();
}
