const std = @import("std");
const slatedb = @import("slatedb");

test "UniFFI ABI is compatible" {
    try slatedb.ffi.ensureCompatible();
    try std.testing.expect(
        slatedb.ffi.c.ffi_slatedb_uniffi_uniffi_contract_version() != 0,
    );
}
