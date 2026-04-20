const std = @import("std");
const slatedb = @import("slatedb");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    var builder = try slatedb.DbBuilder.init("smoke-example-db", &store);
    defer builder.deinit();

    var db = try builder.buildBlocking();
    defer db.deinit();

    _ = try db.putBlocking("hello", "world");

    const maybe_value = try db.getBlocking(allocator, "hello");
    defer if (maybe_value) |value| allocator.free(value);

    const value = maybe_value orelse return error.MissingValue;
    if (!std.mem.eql(u8, value, "world")) {
        return error.UnexpectedValue;
    }

    try db.shutdownBlocking();

    std.debug.print("read {s}={s}\n", .{ "hello", value });
}
